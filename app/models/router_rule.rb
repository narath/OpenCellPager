class RouterRule < ActiveRecord::Base
  validates_presence_of :pattern
  validates_uniqueness_of :pattern
  validates_presence_of :backend_id

  belongs_to :backend

  # returns the rules in order
  def self.rules
    RouterRule.all(:order=>'position ASC')
  end

  def self.find_matching_rule(phone)
    rules.detect { |r| r.match(phone) }
  end

  def match(phone)
    # strip +
    phone = User.clean_phone(phone)

    case
      when pattern =~ /^\d+$/
        logger.debug "Matching #{pattern} to #{phone}: Just a number"
        phone.match('^'+pattern)
      when pattern =~ /^\d*,[\d,]*$/
        logger.debug "Matching #{pattern} to #{phone}: a list of numbers"
        p = pattern.split(',').join('|')
        p = "^(#{p})"
        phone.match(p)
      when pattern == '*'
        logger.debug "Matching #{pattern} to #{phone}: all"
        true
      else
        logger.debug "Matching #{pattern} to #{phone}: Regular expression"
        phone.match(pattern)
    end
  end
end
