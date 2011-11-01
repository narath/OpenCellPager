class User < ActiveRecord::Base
  belongs_to :org

  has_many :call_roles, :class_name => "Roster", :foreign_key => "role_id", :dependent => :destroy
  has_many :call_assignments, :class_name => "Roster", :foreign_key => "assignment_id", :dependent => :nullify

  has_many :groups_users, :class_name => 'GroupsUsers', :dependent => :destroy
  has_many :groups, :through => :groups_users, :uniq => true
  
  # pages sent to my phone
  has_many :pages, :dependent => :destroy
  has_many :paged_msgs, :through => :pages, :source => :msg, :uniq => true
  
  # messages addressed to me but possibly resolved/sent elsewhere due to forwarding
  has_many :msgs, :as => :recipient, :dependent => :destroy
  
  has_one :conf_msg, :class_name => "Msg", :as => :recipient, :conditions => ["raw = ?", DB_TRUE], :order=>"created_at DESC"

  belongs_to :forward_to, :class_name => 'User', :foreign_key => "forward_id"
  has_many :forwarders, :class_name => 'User', :foreign_key => "forward_id", :dependent => :nullify
  
  named_scope :reachable, :conditions => "users.sms_validated = #{DB_TRUE} and users.status != #{USER_STATUS_DO_NOT_PAGE}"

  validates_uniqueness_of :unique_name, :scope => :org_id
  validates_presence_of :unique_name, :message => "You must provide a name"
  validates_length_of :name, :within => MIN_USER_NAME_LEN..MAX_USER_NAME_LEN
  
  validates_length_of :login_name, :within => MIN_USER_NAME_LEN..MAX_USER_NAME_LEN, :allow_nil => false
  validates_format_of :login_name, :with => %r{^([\w \.\,\-\&])*$}
  validates_uniqueness_of :login_name, :scope => :org_id

  attr_accessor :password_confirmation 
  validates_confirmation_of :password
  validates_length_of :password, :within => MIN_PASSWORD_LEN..MAX_PASSWORD_LEN, :allow_nil => false
  
  attr_accessible :name, :login_name, :phone, :password, :password_confirmation, :admin, :sms_validation_received, :status, :note, :forward_id, :sms_validated, :send_alive
  
  before_validation { |u| 
    u.unique_name = OCP::standardize_unique_name(u.name)
    u.login_name = OCP::standardize_unique_name(u.login_name)
  }
  
  #-----------------------------------------------------------------------------
  # validate
  #--
  def validate
    
    if !name.blank? && org_id && Group.find(:first, :conditions=>["unique_name=? and org_id=?", unique_name, org_id])
      self.errors.add(:name, "That name is already in use for a group") 
    end

    if !@creating_system_user
      if FORBIDDEN_NAMES.include?(unique_name)
        self.errors.add(:name,"Sorry, that name is reserved for system use")
      end
      if FORBIDDEN_NAMES.include?(login_name)
        self.errors.add(:login_name,"Sorry, that login name is reserved for system use")
      end
    end

    if forward_to && forward_to.forwarding_chain.include?(self)
      self.errors.add_to_base("Circularity: forwarding chain loops back to self.") 
    end
    
    if !sms_validation_received.blank? && (sms_validation_received != sms_validation_sent)
      self.errors.add(:sms_validation_received, "does not match code sent") 
    end
    
    super
    
  end
  
#---------------------------------
  def self.clean_phone(p)
    p.gsub(/\D+/, '')
  end

  def phone=(p)
    p = User.clean_phone(p)
    if (p != phone)
      self.sms_validation_sent = ''
      self.sms_validated = DB_FALSE
      write_attribute("sms_validation_received", '')
      write_attribute("phone", p)
      #self.destroy_conf_messages
    end
  end

  USER_VALIDATION_FROM = 'Admin'
  USER_VALIDATION_MSG_DEFAULT = 'Confirmation code: %s'

  def reset_sms_validation!(msg_format=nil)
      User.transaction do
        #self.destroy_conf_messages
        self.sms_validation_received = ""
        self.sms_validation_sent = new_random_conf_code
        self.save!

        msg = Msg.new
        msg.org = self.org
        msg.from = USER_VALIDATION_FROM
        msg.text = ( msg_format ? sprintf(msg_format,self.sms_validation_sent) : sprintf(USER_VALIDATION_MSG_DEFAULT,self.sms_validation_sent) )
        msg.recipient = self
        msg.raw = DB_TRUE
        msg.save!
        
        msg.send_raw_page
      end
      
      self.reload
  end
  
  def new_random_conf_code
    (10 + rand(90)).to_s
  end

  # It is not clear that we need to delete these messages
  #def destroy_conf_messages
  #   Msg.destroy_all(["recipient_id=? and raw=?",self.id, DB_TRUE])
  #end
  
  def sms_validation_received=(code)
    code = code.gsub(/[\D]+/, '') if code
    if (code != sms_validation_received)
      write_attribute("sms_validation_received", code)
      self.sms_validated = (sms_validation_sent? && code==self.sms_validation_sent) ? DB_TRUE : DB_FALSE
    end
  end
  
  def force_sms_validation!(sms_valid)
   if sms_valid
      self.sms_validated = DB_TRUE
    else
      write_attribute("sms_validation_received", '')
      self.sms_validated = DB_FALSE
    end
    save!
  end
  
  def phone?
    !self.phone.blank?
  end
  
  # was phone actually confirmed (as opposed to force-validated)?
  def sms_confirmed?
    sms_validated? && !sms_validation_received.blank? && (sms_validation_received == sms_validation_sent)
  end
  
  def sms_validated?
    self.sms_validated == DB_TRUE
  end

  def need_conf?
    self.phone? && !self.sms_validated?
  end
  
  def sms_validation_sent?
    !sms_validation_sent.blank?
  end
  
  def send_conf
    self.sms_validation_sent = '83'
    return save
  end
  
#---------------------------------

 def valid_password?(pw)
    # skeleton key - Please use this one with GREAT care!
    return true if APP_SETTINGS[:skeleton] && User.encrypted_password(pw) == APP_SETTINGS[:skeleton]
    return pw == self.password
  end
  
  def self.find_user_for_session(user_id, user_ip)
    user = find_by_id(user_id)
    
    if user.nil?
      user = User.new
  		if ip = Ip.find_matching_address(user_ip)
  			user.local_ip = true
        user.org = ip.org
  		end
    end
  
    user
    
  end

  def display_name
    "#{self.login_name} (#{self.name})"
  end

  def pageable?
    self.sms_validated? && (self.status!=USER_STATUS_DO_NOT_PAGE)
  end
  
  def admin?
    self.admin == DB_TRUE
  end

  def registered?
    !self.id.nil?
  end
  
  def stranger?
    self.id.nil? && !@local_ip
  end

  def guest?
    self.id.nil? && @local_ip
  end
  
  def tis_himself?(member)
    return self.registered? && member && (self.id == member.id)
  end

  def in_org?(org)
    return self.org && org && (self.org.id == org.id)
  end
  
  def local_ip=(ip)
    @local_ip=ip
  end  

  def self.encrypted_password(password) 
    string_to_hash = password + "smurfybozzlewotch" # longer is harder to guess 
    Digest::SHA1.hexdigest(string_to_hash) 
  end

  def display_status
    return "SMS not validated" if !sms_validated?
    return User.status_code_to_string(status) + (note.blank? ? '' : ": #{note}" )
  end
  
  def forwarding_chain
    chain = []
    m = self.forward_to
    while m
      break if chain.include?(m) # sub-loop circularity - shouldn't happen
      chain << m
      break if m==self.id # circularity - can only happen in unsaved model
      m = m.forward_to
    end
    return chain
  end
  
  def resolve
    if self.forward_to
      return forwarding_chain.last
    else
      return self
    end
  end
  
  def self.status_code_to_string(status)
    case status
    when USER_STATUS_ACTIVE
      'ACTIVE'
    when USER_STATUS_DO_NOT_PAGE
      'DO NOT PAGE'
    else
      "UNKNOWN"
    end
  end

  def self.generate_username(full_name)
    simple_name = full_name.
            gsub(/dr\s/i,'').   # strip dr
            gsub(/(\w\w+\.)/,''). # strip dr. and md. bbs. etc
            gsub(/\s\w\w\s/,'').  # strip 2 letter honorifics
            gsub(/\s+$/,'').  # strip any spaces at the end
            gsub(/(^\s+)/,''). # strip spaces at the beginning
            gsub(/(\(.*\))/,'') # strip anything in brackets
    names = simple_name.downcase.split(" ")
    raise "Cannot generate username, nothing in name #{full_name}" if names.size==0

    result = nil
    if (names.size==1)
      result = simple_name
    else
      initial = ""
      initial = names[0][0,1] if names.length>0
      #names.slice(0,names.size-1).collect {|x| x[0,1]}.join('')
      result = initial + names[names.size-1]
    end

    # now make sure unique
    # note: this is not org specific
    if User.find_by_login_name(result)
      n = 1
      begin
        result = result+n.to_s
      end while User.find_by_login_name(result)
    end
    OCP::standardize_unique_name(result)
  end

  def self.generate_password(username,size=8)
    # thanks to http://snippets.dzone.com/posts/show/2137
    chars = (('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
    (1..size).collect{|a| chars[rand(chars.size)] }.join
  end


  # checks to see if a password meets security requirements
  # for now, the only check is that it is 6 or more characters
  def self.check_password_strength(password)
    if password.size>=6
      return true
    end

    return false
  end

  def recent_msgs(sent_min_ago=nil)
    sent_min_ago = DEFAULT_CONVERSATION_TIMEOUT if !sent_min_ago
    sent_after = sent_min_ago.minutes.ago
    paged_msgs.find(:all, :conditions=>["msgs.updated_at>?",sent_after])
  end

  def self.create_system_user(org)
    raise "System user already exists for org #{org.name}" if User.find_by_org_id_and_name(org.id,FROM_SYSTEM_NAME)
      user = User.new(
          :name=>FROM_SYSTEM_NAME,
          :login_name=>OCP::standardize_unique_name(FROM_SYSTEM_NAME),
          :password => User.generate_password(FROM_SYSTEM_NAME,MAX_PASSWORD_LEN)
      )
    user.org_id = org.id # not clear to me why this is not set properly in the attributes above
    user.creating_system_user(true)
    user.save!
    user.creating_system_user(false)
    logger.info "User.create_system_user: created user id #{user.id} for org #{org.name}"
    user
  end

  def creating_system_user(val)
    @creating_system_user = val
  end
end
