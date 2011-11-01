require 'test_helper'

class OrgTest < ActiveSupport::TestCase

  def add_msgs(num,org,user,status,dt)
    num.times do |i|
      msg = Msg.new()
      msg.org = org
      msg.from = "test"
      msg.recipient = user
      msg.text = "test msg #{i}"
      msg.save!

      # create the pages ourselves so we can control the attributes
      pg = Page.new(:org=>org,:user=>user,:msg=>msg)
      pg.save!

      ob = pg.outbounds.new(
          :phone => pg.user.phone,
          :text => pg.msg.text,
          :status=>status
      )
      Outbound.record_timestamps = false
      ob.update_attributes :updated_at => dt, :created_at => dt
      ob.save!
      Outbound.record_timestamps = true
      ob.reload
      assert_equal ob.updated_at.to_s,dt.to_s
      Rails.logger.debug "Set outbound update_at to #{ob.updated_at.to_s}"
    end
  end

  test "send msg" do
    # can send a message using a name
    org = orgs(:sample)
    assert_difference 'org.msgs.count',1,'A message should have been created' do
      org.send_msg('joe',"jake","Hi Jake")
    end

    # send from a user
    assert_difference 'org.msgs.count',1,'A message should have been created' do
      msg = org.send_msg(users(:joe),"jake","Hi Jake")
      assert_equal users(:joe).login_name,msg.from
    end

    # send from a group - not allowed
    assert_raises RuntimeError do
      msg = org.send_msg(groups(:all_users),"jake","Hi Jake")
    end

    # send to a user
    assert_difference 'org.msgs.count',1,'A message should have been created' do
      msg = org.send_msg(users(:joe),users(:jake),"Hi Jake")
      assert_equal users(:jake),msg.recipient
    end

    # send to a group
    assert_difference 'org.msgs.count',1,'A message should have been created' do
      msg = org.send_msg(users(:joe),groups(:all_users),"Hey everyone")
      assert_equal groups(:all_users),msg.recipient
    end
  end

  test "find recipient by name" do
    o = orgs(:sample)

    # finds user by full name
    assert_equal users(:joe).id, o.find_recipient_by_name('Joe Smith').id

    # finds user by login name
    assert_equal users(:jake).id, o.find_recipient_by_name('jake').id

    # finds group by full name
    assert_equal groups(:all_users).id, o.find_recipient_by_name('All Users').id

    # finds group by short name
    assert_equal groups(:all_users).id, o.find_recipient_by_name(groups(:all_users).short_name).id

    # not case sensitive for user, or group, name or login_name or short_name
    assert_equal users(:joe).id, o.find_recipient_by_name('joe SMITH').id

    # finds user by login name
    assert_equal users(:jake).id, o.find_recipient_by_name('JAKE').id

    # finds group by full name
    assert_equal groups(:all_users).id, o.find_recipient_by_name('ALL Users').id

    # finds group by short name
    assert_equal groups(:all_users).id, o.find_recipient_by_name('eVERyone').id

  end

  test "find by keyword" do
    org = orgs(:sample)
    assert_equal "Joe Jones,Joe Smith", org.find_users_or_groups_by_keywords('joe').collect{|u|u.name}.join(',')

    # finds by username, not name
    assert_equal "Jonathan Smith", org.find_users_or_groups_by_keywords('jake').collect{|u|u.name}.join(',')

    # finds by group name
    assert_equal "All Users", org.find_users_or_groups_by_keywords('All Users').collect{|u|u.name}.join(',')

    # find by shortname
    assert_equal "All Users", org.find_users_or_groups_by_keywords('everyone').collect{|u|u.name}.join(',')



  end


  test "check monitor sending messages" do
    # create a new org
    # using test channel
    # with monitor definitions
    org = Org.new(:name=>"test monitor",
                  :gateway_type => "test",
                  :monitor_on => true,
                  :monitor_minutes => 5,
                  :monitor_unsent_pages => 5,
                  :monitor_check_in_minutes => 1)
    org.save!

    # check monitor with NO messages
    org.check_monitor_sending_messages
    assert_equal true, org.monitor_on
    assert_equal false, org.monitor_is_panicking

    # add enough unsent pages
    user = User.new()
    user.org = org
    user.login_name = "john"
    user.name = "John"
    user.phone = "8025551212"
    user.password = "password"
    user.save!

    # delete prior messages since these may be sent after the following
    # in which case the monitor will not panic
    Page.destroy_all
    assert_equal 0,Outbound.all.count
    add_msgs(1,org,user,STATUS_DELIVERED,10.minutes.ago)
    add_msgs(5,org,user,STATUS_PENDING,6.minutes.ago)

    org.monitor_last_check = 10.minutes.ago
    org.check_monitor_sending_messages
    assert_equal false, org.monitor_on
    assert_equal true, org.monitor_is_panicking
    dt_last_check = org.monitor_last_check

    # if we check now, nothing changes since the monitor is not on
    org.monitor_last_check = 10.minutes.ago
    org.check_monitor_sending_messages
    assert_equal false, org.monitor_on
    assert_equal true, org.monitor_is_panicking

    # now we send a successful message and all should be alright
    add_msgs(1,org,user,STATUS_DELIVERED,1.minutes.ago)
    org.monitor_on = true
    org.monitor_is_panicking = false
    org.monitor_last_check = 10.minutes.ago
    dt_last_check = org.monitor_last_check
    org.check_monitor_sending_messages
    assert_equal true, org.monitor_on
    assert_equal false, org.monitor_is_panicking
    assert_not_equal(dt_last_check,org.monitor_last_check)

    # even if we add pending messages, still too soon to be alright
    add_msgs(6,org,user,STATUS_PENDING,30.seconds.ago)

    org.monitor_last_check = 10.minutes.ago
    org.check_monitor_sending_messages
    assert_equal true, org.monitor_on
    assert_equal false, org.monitor_is_panicking

    # now add a sent message that is too old
    Msg.destroy_all
    assert_equal 0,Page.count 

    add_msgs(1,org,user,STATUS_DELIVERED,7.minutes.ago)

    org.monitor_on = true
    org.monitor_is_panicking = false
    org.monitor_last_check = 10.minutes.ago
    org.check_monitor_sending_messages
    assert_equal true, org.monitor_on
    assert_equal false, org.monitor_is_panicking

    add_msgs(5,org,user,STATUS_PENDING,6.minutes.ago)
    org.monitor_last_check = 10.minutes.ago
    org.check_monitor_sending_messages
    assert_equal false, org.monitor_on
    assert_equal true, org.monitor_is_panicking
  end

  test "auto creates system user" do
    org = orgs(:sample)
    assert !org.users.find_by_name(FROM_SYSTEM_NAME),"system user already exists"
    assert_equal FROM_SYSTEM_NAME,org.system_user.name
  end

end
