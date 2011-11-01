require 'util'

class Msg < ActiveRecord::Base
  
  belongs_to :org
  belongs_to :recipient, :polymorphic => true
  
  has_many :pages, :dependent => :destroy

  validates_presence_of :from
  validates_length_of :from, :maximum => MAX_FROM_LEN, :allow_nil => true

  validates_presence_of :text
  validates_length_of :text, :maximum => MAX_MSG_LEN, :allow_nil => true
  
  attr_accessible :text, :from

  named_scope :pending, :conditions => ["status=?", STATUS_PENDING]
  
  def self.sweep
    return "msg sweep called"
  end
  
  def body
    "#{self.from || ''}: #{self.text || ''}"
  end
  
  #-----------------------------------------------------------------------------
  # validate
  #--
  def validate
    
    # require recipient association
    self.errors.add_to_base("Recipient is invalid") if  self.recipient.nil?
    
    self.errors.add_to_base("Combined length of from and text must not exceed #{MAX_MSG_LEN}, msg=#{self.body}") if  self.body.length > MAX_MSG_LEN
    
    super
    
  end

  def in_org?(org)
    return org && (self.org_id == org.id)
  end

  # creates a message
  def self.create(org,from,to,text)
    msg = Msg.new
    msg.org = org
    case
      when from.instance_of?(User)
        msg.from = from.login_name
      when from.instance_of?(Group)
        raise "Cannot send a message from a group"
      else
        msg.from = from
        Rails.logger.warning "send_msg from should be a string, but was #{from.class}" if !from.instance_of?(String)
    end

    case
      when to.instance_of?(User) || to.instance_of?(Group)
        msg.recipient = to
      else
        msg.recipient = org.find_recipient_by_name(to)
        raise "Could not find user or group with name #{to}" if !msg.recipient
    end

    msg.text = text
    msg.save!
    msg
  end

  # sends all the pages in this message
  # returns the message
  def send_pages
    Msg.resolve(recipient).each do |user|
      next if !user.sms_validated?
      p = Page.new_page_to_user(self, user)
    end
    self
  end
  
  def send_raw_page
    #todo: what is the value of send_raw_page?
    raise(ActiveRecord::RecordInvalid) unless self.raw?
    raise(ActiveRecord::RecordInvalid) unless self.recipient.is_a?(User)
    p = Page.new_page_to_user(self, self.recipient)
    self
  end

  def refresh_raw_status
    # todo: refactor out refresh_raw_status, is the same logic as refresh_status
    p = pages.first
    return unless p && p.status==STATUS_PENDING
    p.refresh_status
  end

  def refresh_status
    return self.status unless self.status==STATUS_PENDING
    pages.each {|page| page.refresh_status}
    update_status
  end

  def update_status
    return self.status unless self.status==STATUS_PENDING

    stats = { STATUS_PENDING=>0, STATUS_FAILED=>0, STATUS_DELIVERED=>0, STATUS_UNKNOWN=>0}

    pages.each do |p|
      stat = p.status
      stats[ stat ]  += 1 if stat
    end

    if stats[STATUS_PENDING] > 0
      # append so they can see what's up
      self.status = STATUS_PENDING
    elsif stats[STATUS_FAILED] == pages.size
      # append so they can see why it failed
      self.status = STATUS_FAILED
    elsif stats[STATUS_UNKNOWN] == pages.size
      self.status = STATUS_UNKNOWN
    elsif (stats[STATUS_FAILED] > 0) || (stats[STATUS_UNKNOWN] > 0)
      # append so they can see what's up
      self.status = STATUS_PARTIAL
    elsif stats[STATUS_DELIVERED] > 0
      # at least one has succeeded so we say this has succeeded
      self.status = STATUS_DELIVERED
    else
      self.status = STATUS_UNKNOWN
    end
    self.save!
    self.status
  end
  
  def summary
    text_help.truncate( text, 30)
  end

  
  def self.resolve(recipient)
    users = []
    if recipient.is_a?(Group)
      users = recipient.users
    elsif  recipient.is_a?(User)
      users = [recipient]
    end
    users.map {|user| user.resolve }.uniq.select {|user| user.pageable? }
  end

  def self.new_msg_for_org(org)
    m = Msg.new()
    m.org = org
    m.status = STATUS_PENDING
    return m
  end
  
end
