require 'util'

class Group < ActiveRecord::Base
  
  belongs_to :org
  has_many :msgs, :as => :recipient, :dependent => :destroy
  
  has_many :groups_users, :class_name => 'GroupsUsers', :dependent => :destroy
  has_many :users, :through => :groups_users, :uniq => true

  validates_uniqueness_of :unique_name, :scope => :org_id
  validates_presence_of :unique_name, :message => "You must provide a name"
  validates_length_of :name, :within => MIN_USER_NAME_LEN..MAX_USER_NAME_LEN
  validates_format_of :name, :with => %r{^([\w \.\,\-\&])*$}

  validates_uniqueness_of :short_name, :scope => :org_id

  before_validation { |u| 
    u.unique_name = OCP::standardize_unique_name(u.name)
    u.short_name = OCP::standardize_unique_name(u.short_name) if u.short_name
  }

  def display_name
    "#{self.name} (group)"
  end
  
  #-----------------------------------------------------------------------------
  # validate
  #--
  def validate
    
    if !name.blank? && org_id && User.find(:first, :conditions=>["unique_name=? and org_id=?", unique_name, org_id])
        self.errors.add(:name, "That name is already taken by a user")
    end

    if !short_name.blank? && org_id && User.find(:first, :conditions=>["org_id=? and (login_name=? or unique_name=?)",org_id, short_name, short_name])
      self.errors.add(:short_name, "That short name is already taken by a user")
    end

    if FORBIDDEN_NAMES.include?(unique_name)
      self.errors.add(:name,"Sorry, that name is reserved for system use")
    end
    if FORBIDDEN_NAMES.include?(short_name)
      self.errors.add(:short_name,"Sorry, that short_name is reserved for system use")
    end

  
    super
    
  end
  
  def in_org?(org)
    return org && (self.org_id == org.id)
  end
  
end
