class Org < ActiveRecord::Base

  has_many :users, :dependent => :destroy
  has_many :msgs, :dependent => :destroy
  has_many :pages, :dependent => :destroy
  has_many :groups, :dependent => :destroy
  has_many :ips, :dependent => :destroy
  has_many :rosters, :dependent => :destroy

  validates_uniqueness_of :name, :case_sensitive => false
  validates_presence_of :name, :message => "You must provide a name"

  attr_accessible :name, :gateway_type, :gateway_config

  REFRESH_ONLY_WITHIN_X_DAYS = 3
  def refresh_pending_msgs
    self.msgs.pending.each do |msg|
      begin
        days_since_sent = (Time.zone.now - msg.created_at).to_i / (60*60*24)
        if (days_since_sent && days_since_sent <= REFRESH_ONLY_WITHIN_X_DAYS)
          msg.refresh_status
        end
      rescue Exception => ex
        Rails.logger.error "ORG.refresh_pending_msgs exception when refreshing msg id #{msg.id} error=#{ex.message}"
      end
    end
  end

  # returns a list of all possible recipients in the system
  # this combines users and groups
  def recipients
    all_users = self.users.find(:all)
    all_groups = self.groups.find(:all)
    all = Array.new
    all_users.each { |user| all << user }
    all_groups.each { |group| all << group }
    all = all.sort_by { |obj| obj.name.downcase }
  end

  # searches for all terms
  # opts = array of elements to include, if nil = all
  # e.g. [:users, :groups]
  FIND_OPTS_ALL = [:users,:groups]
  def find_users_or_groups_by_keywords(search_for,opts=nil)
    terms = search_for.strip.split.collect do |word|
      "%#{word.downcase}%"
    end

    opts = FIND_OPTS_ALL if !opts
    all = Array.new

    if opts.include?(:users)
      users = self.users.find(:all,
                            :conditions => [(["(LOWER(name) LIKE ?)"] * terms.size).join(" AND "),
                                            * terms.flatten])
      users.each { |user| all << user }
      all_id = all.collect {|u| u.id}

      users = self.users.find(:all,
                            :conditions => [(["(LOWER(login_name) LIKE ?)"] * terms.size).join(" AND "),
                                            * terms.flatten])
      users.each { |user| all << user if !all_id.include?(user.id) }
    end

    if opts.include?(:groups)
      groups = self.groups.find(:all,
                              :conditions => [(["(LOWER(name) LIKE ?)"] * terms.size).join(" AND "),
                                              * terms.flatten])
      groups.each { |group| all << group }
      all_group_id = all.collect {|ug| ug.id if ug.is_a?(Group)}

      groups = self.groups.find(:all,
                              :conditions => [(["(LOWER(short_name) LIKE ?)"] * terms.size).join(" AND "),
                                              * terms.flatten])
      groups.each { |group| all << group if !all_group_id.include?(group.id) }
    end

    all = all.sort_by { |obj| obj.name.downcase }
  end

  # finds the user or group with the particular name
  def find_recipient_by_name(a_name)
    a_name = OCP::standardize_unique_name(a_name)

    # in order of the most particular
    # login name first
    if (user=users.find_by_login_name(a_name))
      return user
    elsif (user=users.find_by_unique_name(a_name))
      return user
    elsif (group=groups.find_by_short_name(a_name))
      return group
    elsif (group=groups.find_by_unique_name(a_name))
      return group
    else
      return nil
    end
  end

  def recipient_name_unique?(a_name)
    return (find_recipient_by_name != nil)
  end

  # sends a message for this organization
  # @params:
  # from = the user sending this message
  # to = if a string the name is searched for, if a user/group used directly
  # returns: a message which can be checked for status updates
  def send_msg(from, to, text)
    return Msg.create(self,from,to,text).send_pages
  end
  
  # a direct message is one that is to be sent directly to a phone number
  # that may not be registered in the system
  # this is designed to allow:
  # 1. responses from the gateways
  # 2. messages to outsiders (i.e. patients)
  # @Parameters:
  # phone : phone to send this to
  # text : message to send
  # block : this allows additional handling once the backend is selected
  # Example:
  #  o = org.send_direct(org, phone, text) do |outbound|
  #   if outbound.backend.backend_type=="tropo"
  #     outbound.status = tropo.say(outbound.text)
  #     return true
  #   end
  #    return false
  # Returns: the outbound object
  def send_direct(from, phone, text, &block)
    logger.info "Org.send_direct: from #{from.login_name} to #{phone} '#{text}'"
    Outbound.post(self, nil, phone, text, &block)        
  end

  # the message sending monitor
  # here we check to see if the monitor can detect a problem sending messages
  # pass data in the panic_email_data (should be a hash) to be included in the panic email
  # useful info to include would be:
  # send panic email
  #  panic_email_data = { :host => (request.env["HTTP_X_FORWARDED_HOST"] || request.env["HTTP_HOST"]),
  #             :rails_root => Pathname.new(RAILS_ROOT).cleanpath.to_s }
  #}
    # does not return anything, check the monitor_ vars for monitor state (i.e. panicking)
  #
  #How message monitor works:
  #Must be on
  #Checks only every monitor_check_minutes minutes (if checked before then, just exits)
  #if there are unsent messages after the last successfully sent message
  #and if there are more than X of these unsent messages since the last successfully sent message
  #and if the first unsent message was more than Y minutes ago
  #then I am worried that messages are not being sent
  #(x messages, because don�t want to worry about a single wrong number not being sent)
  #(y minutes since the first unsent message has not been sent, because I want to give the system a chance to process any queued messages)

  def check_monitor_sending_messages(panic_email_data={})
    return if !self.monitor_on

    panic_after_minutes = self.monitor_minutes ? self.monitor_minutes : DEFAULT_MONITOR_MINUTES
    panic_after_unsent_pages = self.monitor_unsent_pages ? self.monitor_unsent_pages : DEFAULT_MONITOR_UNSENT_PAGES
    last_monitor_check = self.monitor_last_check
    check_in_minutes = self.monitor_check_in_minutes ? self.monitor_check_in_minutes : DEFAULT_MONITOR_CHECK_IN_MINUTES
    logger.debug "MONITOR:Checking msg_monitor panic_after_minutes=#{panic_after_minutes} panic_after_unsent_pages=#{panic_after_unsent_pages} last_checked_at=#{last_monitor_check} check_in_minutes=#{check_in_minutes}"

    # do we need to check?
    if last_monitor_check && (Time.zone.now<last_monitor_check+(check_in_minutes*60))
      logger.debug "MONITOR:Only check every #{check_in_minutes}"
      return
    end

    self.monitor_last_check = Time.zone.now
    self.save!

    # Find last successfully sent page
    last_successful_page_sent_at = nil
    begin
      ob = Outbound.find(:first, :conditions=>{:status=>STATUS_DELIVERED}, :order=>"updated_at DESC")
      last_successful_page_sent_at = ob.updated_at if ob
    rescue ActiveRecord::RecordNotFound
      # just continue (perhaps a successful page has never been sent
    end

    # Find the pages since then
    num_unsent_pages = 0
    if last_successful_page_sent_at
      num_unsent_pages = Outbound.count(:conditions=>["updated_at>? AND status<>?", last_successful_page_sent_at, STATUS_DELIVERED])
    else
      num_unsent_pages = Outbound.count
    end
    if num_unsent_pages<panic_after_unsent_pages
      logger.debug "MONITOR:Not enough pages to panic about #{num_unsent_pages}"
      return
    end

    # we check the number of pages, because even though we would care if only one message was not being sent correctly
    # this could be because of an incorrect number
    # in a reasonably used system, there should not just be a single user sending to the same address
    # if in fact they send 5 messages to the same address we should probable help them anyway

    # Time of the first unsent msg  > X_MSGS
    if last_successful_page_sent_at
      ob_first_unsent = Outbound.find(:first,
                                  :conditions=>["updated_at>? AND status<>?", last_successful_page_sent_at, STATUS_DELIVERED],
                                  :order=>"updated_at ASC")
    else
      ob_first_unsent = Outbound.first(:order=>'updated_at ASC')
    end
    dt_first_unsent_msg = ob_first_unsent.updated_at

    # is this less than the panic time (we want to give the system a chance to send queued messages)
    if Time.zone.now<(dt_first_unsent_msg+(panic_after_minutes*60))
      logger.debug "MONITOR:Not enough time elapsed since first unsent message #{dt_first_unsent_msg} Time.now=#{Time.zone.now}"
      return
    end

    # otherwise, panic
    logger.debug "MONITOR:panic about not sending messages"
    # set org state to panic
    self.monitor_is_panicking = true
    self.monitor_on = false
    self.monitor_last_panic = self.monitor_last_check
    self.save!

    # we do this before sending the email, since if the email fails, support will get an email about it anyway (if possible)

    data = panic_email_data.merge({:info => "The system has been unable to send #{num_unsent_pages} since #{dt_first_unsent_msg}."+
            "I'm worried that the system is not able to send messages. Please check on the opencellpager system. I became worried at #{monitor_last_panic}"})

    ApplicationMailer.deliver_panic_email(data)

    logger.debug "MONITOR:sent panic email"
    return
  end

  # the system user is the user account used to send replies to gateways
  # this returns the system user, or creates one if it does not exist
  def system_user
    user = users.find_by_name(FROM_SYSTEM_NAME)
    if !user
      user = User.create_system_user(self)
    end
    user
  end
  
end
