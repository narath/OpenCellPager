class Ip < ActiveRecord::Base
  
  belongs_to :org

  validates_uniqueness_of :address, :scope => :org_id
  #validates_format_of :address, :with => /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.(\*|[0-9]{1,3})$/
  validates_format_of :address, :with => /^[0-9]{1,3}\.[0-9]{1,3}\.(\*|[0-9]{1,3})\.(\*|[0-9]{1,3})$/
  validates_presence_of :address, :message => "You must provide an address"


  def in_org?(org)
    return org && (self.org_id == org.id)
  end
  
  def regexp
    Regexp.new("^" + address.gsub('*', '[0-9]{1,3}' ) + '$')
  end
  
  def self.find_matching_address(address)
    
    self.find(:all).each do |ip|
      return ip if address =~ ip.regexp
    end
    return nil
     
  end
  
end
