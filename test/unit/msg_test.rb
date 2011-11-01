require 'test_helper'

class MsgTest < ActiveSupport::TestCase

  def setup
    @org = orgs(:sample)
    @joe = users(:joe)
  end

  test "can add a message successfully" do
    msg = Msg.new()

    assert !msg.valid?
    assert msg.errors.invalid?(:from)
    assert msg.errors.invalid?(:text)
    assert_match /Recipient/, msg.errors.on(:base)
    
    msg.from = "Mr. T"
    msg.text = "Hello world"
    msg.recipient = @joe
    
    # must have an org - violates NOT NULL constraint
    assert_raise ActiveRecord::StatementInvalid do
      msg.save!
    end
    msg.org = @org
    
    msg.errors.clear
    assert msg.valid?, msg.errors.full_messages
    assert msg.save
  end

  test "updates status correctly" do
    # create a new message
    msg = @org.send_msg(@joe,users(:jake),"hello world")
    assert_equal STATUS_DELIVERED, msg.pages.first.status
    # refresh status
    msg.update_status
    assert_equal STATUS_DELIVERED, msg.status

    # pending
    assert_equal STATUS_PENDING, change_msg_page_to(msg,STATUS_PENDING)

    # failure
    assert_equal STATUS_FAILED, change_msg_page_to(msg,STATUS_FAILED)

    # now with multiple pages
    g = @org.groups.create!(:name=>"many", :short_name=>"many")
    g.users << users(:joe)
    g.users << users(:jake)
    g.users << users(:joe_jones)
    assert_equal 3, g.users.length

    msg = @org.send_msg(@joe,g,"hello world")
    assert_equal STATUS_DELIVERED, msg.pages.first.status
    # refresh status
    msg.update_status
    assert_equal STATUS_DELIVERED, msg.status

    # pending
    # if there is one pending they are all pending
    assert_equal STATUS_PENDING, change_msg_page_to(msg,STATUS_PENDING)

    # failure
    # some success, and any failure = partial
    assert_equal STATUS_PARTIAL, change_msg_page_to(msg,STATUS_FAILED)

    # unknown
    assert_equal STATUS_PARTIAL, change_msg_page_to(msg,STATUS_UNKNOWN)

    # change all to failed
    assert_equal STATUS_FAILED, change_all_msg_page_to(msg,STATUS_FAILED)
    assert_equal STATUS_PENDING, change_msg_page_to(msg,STATUS_PENDING)

    assert_equal STATUS_UNKNOWN, change_all_msg_page_to(msg,STATUS_UNKNOWN)

    assert_equal STATUS_DELIVERED, change_all_msg_page_to(msg,STATUS_DELIVERED)

  end

  def change_msg_page_to(msg,status)
    out = msg.pages.last.outbounds.last
    out.status = status
    out.save
    msg.status = STATUS_PENDING
    msg.update_status
  end

  def change_all_msg_page_to(msg,status)
    msg.pages.each do |page|
      o = page.outbounds.last
      o.status = status
      o.save
    end
    msg.status = STATUS_PENDING
    msg.update_status
  end

end
