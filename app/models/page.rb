class Page < ActiveRecord::Base
  belongs_to :msg
  belongs_to :user
  belongs_to :org
  
  # page generally would only have one outbound
  # if for some strange reason, more than one, we use the last one as the most accurate regarding paging status
  has_many :outbounds, :dependent => :destroy
  
  named_scope :pending, :conditions => ["pages.status=?", STATUS_PENDING]
  
  def refresh_status
    # request refresh from outbound
    self.outbounds.last.request_refresh if self.outbounds && self.outbounds.last
  end

  def status
    self.outbounds.last.status if self.outbounds && self.outbounds.last
  end

  def status_string
    self.outbounds.last.status_string if self.outbounds && self.outbounds.last
  end

  def send_page
    msg_text = "#{self.msg.from[0..MAX_FROM_LEN-1]}:#{self.msg.text}"
    Outbound.post(self.org,self,self.user.phone,msg_text)
  end

  def self.new_page_to_user(msg, user)
    p = Page.new()
    p.msg = msg
    p.user = user
    p.org = msg.org
    p.save!
    p.send_page
    return p 
  end
  
end
