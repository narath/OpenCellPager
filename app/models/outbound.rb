class Outbound < ActiveRecord::Base
  belongs_to :page
  belongs_to :backend
  
  validates_presence_of :text
  validates_length_of :text, :maximum => MAX_MSG_LEN, :allow_nil => true
  
  validates_presence_of :phone

  named_scope :sent_direct, :conditions=>{:page_id=>nil}

  # creates an outbound message, and initiates a delayed send
  # if a block is passed, then this is called before with the backend that will be used
  # to send the text, if the caller handles the message, then it should return false
  # if it returns true then this will assume the text was sent using the block
  # Example:
  #  o = Outbound.post(org, phone, text) do |outbound|
  #   if outbound.backend.name=="tropo"
  #     outbound.status = tropo.say(outbound.text)
  #     return true
  #   end
  #    return false
  #
  def self.post(org, page, phone, text, &block)
    rule = RouterRule.find_matching_rule(phone)
    raise "I don't know how to send a message to #{phone} - no routing rule applies" if !rule

    o = Outbound.new()
    # direct message = no page specified
    # otherwise outbound is bound to a page
    o.page_id = page.id if page
    o.attributes = {
        :phone => User.clean_phone(phone),
        :text => text,
        :status => STATUS_PENDING,
        :backend_id => rule.backend.id
    }
    o.save!

    handled = false
    handled = yield(o) if block_given?

    if !handled
      case ENV['RAILS_ENV']
        when 'test'
          o.route(rule.backend)
        else
          if APP_SETTINGS[:use_delayed_job]
            o.delay.route(rule.backend)
            o.status_string = 'Submitted for processing'
          else
            o.route(rule.backend)
            o.status_string = 'Routed immediately'
          end
          o.save
      end
    end
    o
  end

  # actually routes the message to the user
  def route(backend)
    Rails.logger.info "OUTBOUND.route: Routing backend=#{backend.name} phone=#{self.phone} text=#{self.text}"
    begin
      gateway = Gateway::Session.create(backend.backend_type, backend.config)
      gateway.send_page(self)
    rescue Exception => exc
      Rails.logger.error "OUTBOUND.route: error sending to #{self.phone}: #{exc.message}"
      self.status_string = "Error sending: #{exc.message}"
      self.status = STATUS_FAILED
      self.save
    end
  end

  # requests a refresh of all of the messages
  def request_refresh
    raise "No backend" if !self.backend
    return self.status unless self.status==STATUS_PENDING
    # if this is just queued, or has no message id, no way to check status, so just return
    return self.status if !self.sent_id

    gateway = Gateway::Session.create(self.backend.backend_type, self.backend.config)

    begin
      message_status = gateway.check_page_status( self.sent_id )
      if message_status
        self.status_string = message_status.message
        self.status = message_status.state
        self.save!
      end
    rescue Gateway::Error => e
      Rails.logger.error "OUTBOUND.request_refresh:", "Gateway status check failed for outbound #{self.id}: #{e.message}"
      self.status_string = "Status check failed: #{e.message}"
      self.status = STATUS_UNKNOWN
      self.save!
    end

    return self.status
  end

end
