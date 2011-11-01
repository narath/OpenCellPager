require 'test_helper'

class KannelControllerTest < ActionController::TestCase
  test "receive" do
    get :receive
    assert_response :success

    # handle cmd_time_msg

    # handle send
    # user not registered
    get :receive, :phone => '+16175104446', :text => 'Send narath: from phone', :time=>'2011-09-21+00:01:10s'
    assert_response :success
    assert assigns["result"]
    assert @response.body =~ /errors/
    assert @response.body =~ /phone is not registered/

    # to known user
    u = users(:joe)
    get :receive, :phone => u.phone, :text => "Send jake: test", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent to/
    assert @response.body =~ /confirmation sent/i

    # note: the above is someone sending a message to themselves - we might want to prevent this

    # empty send
    get :receive, :phone => u.phone, :text => "Send ", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    assert @response.body =~ /invalid send command/i

    # to group by name with spaces
    get :receive, :phone => u.phone, :text => "Send #{groups(:all_users).name}: hello world group", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent to/
    # joe is a member, so no confirmation
    assert groups(:all_users).users.find_by_id(users(:joe).id),"Joe should be a member of the all users group"
    assert @response.body =~ /unconfirmed/i

    # send a very long message
    long_text = ""
    500.times { long_text += "A"}
    get :receive, :phone => u.phone, :text => "Send #{groups(:all_users).name}: "+long_text, :time=>'2011-09-21+00:01:10s'
    assert_response :success
    assert @response.body =~ /sent to/
    assert @response.body =~ /truncated/i

    # send to multiple users
    get :receive, :phone => u.phone, :text => "Send joe,joe_jones,jake: test", :time=>'2011-09-21+00:01:10s'
    #assert_equal "",@response.body
    assert_response :success
    assert @response.body =~ /sent to 3/i
    assert @response.body =~ /unconfirmed/i

    # lookup
    get :receive, :phone => u.phone, :text => "lookup joe", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    assert @response.body =~ /2 results/

    get :receive, :phone => u.phone, :text => "lookup joe smith", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    assert @response.body =~ /1 result/

    # no results
    get :receive, :phone => u.phone, :text => "lookup will_not_find", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /0 results/

    # lookup users
    get :receive, :phone => u.phone, :text => "lookup users joe", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /2 results/

    # lookup groups
    get :receive, :phone => u.phone, :text => "lookup groups joe", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /0 results/

    get :receive, :phone => u.phone, :text => "lookup groups all", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /1 results/

    # register
    # empty
    NEW_PHONE = '6175101234'
    UNREG_PHONE = '6175551111'
    get :receive, :phone => NEW_PHONE, :text => "register"
    assert_response :success
    assert @response.body =~ /errors/
    assert @response.body =~ /invalid register command/i

    # improperly formatted
    get :receive, :phone => NEW_PHONE, :text => "register joe password"
    assert_response :success
    assert @response.body =~ /errors/
    assert @response.body =~ /invalid register command/i

    # user not registered -> see operator
    get :receive, :phone => NEW_PHONE, :text => "register joexx:password"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /errors/
    assert @response.body =~ /see the operator/

    # user registered -> no password
    get :receive, :phone => NEW_PHONE, :text => "register #{u.login_name}:ppassword"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /errors/
    assert @response.body =~ /invalid password/i

    # user registered
    get :receive, :phone => NEW_PHONE, :text => "register #{u.login_name}:#{u.password}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent validation code/i

    db_u = User.find_by_login_name(u.login_name)
    assert db_u
    verify_code = db_u.sms_validation_sent

    # the phone is now this phone, not validated
    assert !db_u.sms_validated?
    assert_equal NEW_PHONE,db_u.phone
    assert_not_equal "",db_u.sms_validation_sent

    # a user who has not been validated cannot send a message
    get :receive, :phone => u.phone, :text => "Send joe: test", :time=>'2011-09-21+00:01:10s'
    #assert_equal "",@response.body
    assert_response :success
    assert @response.body =~ /errors/i
    assert @response.body =~ /not registered/i

    # or be able to lookup
    get :receive, :phone => u.phone, :text => "Send joe,joe_jones,jake: test", :time=>'2011-09-21+00:01:10s'
    #assert_equal "",@response.body
    assert_response :success
    assert @response.body =~ /errors/i
    assert @response.body =~ /not registered/i

    # verify
    # empty
    get :receive, :phone => NEW_PHONE, :text => ''
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /errors/i
    assert @response.body =~ /blank text/i


    # invalid
    get :receive, :phone => NEW_PHONE, :text => "#{verify_code}999"
    assert_response :success
    #assert_equal "", @response.body
    assert @response.body =~ /errors/
    assert @response.body =~ /unable to verify/i

    get :receive, :phone => NEW_PHONE, :text => verify_code
    assert_response :success
    assert @response.body =~ /has been registered/i

    db_u = User.find_by_login_name(u.login_name)
    assert db_u.sms_validated?
    assert_equal NEW_PHONE,db_u.phone

    # can remove
    get :receive, :phone => NEW_PHONE, :text => "remove #{u.login_name}:#{u.password}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /removed user/i
    db_u.reload
    assert !db_u.sms_validated?

    # can also use change to register
    NEW_PHONE2 = '6175101234'
    get :receive, :phone => NEW_PHONE2, :text => "change #{u.login_name}:#{u.password}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent validation code/i

    # can get help
    get :receive, :phone => NEW_PHONE2, :text => "help"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /commands available/i

    # can join groups
    assert !users(:joe).groups.find_by_short_name('edr')

    g = Group.new(:name=>"ED Results", :short_name=>"edr", :org_id => orgs(:sample).id)
    g.save!
    get :receive, :phone => NEW_PHONE2, :text => "join #{g.short_name}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /added user(.*)to group/i
    assert users(:joe).groups.find_by_short_name('edr')

    # cannot join again
    get :receive, :phone => NEW_PHONE2, :text => "join #{g.short_name}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /already a member/i

    # can leave groups
    get :receive, :phone => NEW_PHONE2, :text => "leave #{g.short_name}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /removed user (.*) from group/i
    assert !users(:joe).groups.find_by_short_name('edr')

    # cannot leave again
    get :receive, :phone => NEW_PHONE2, :text => "leave #{g.short_name}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /not a member/i

    # invalid group name
    get :receive, :phone => NEW_PHONE2, :text => "join xxx"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /no group called/i

    # unregistered phone
    get :receive, :phone => UNREG_PHONE, :text => "join #{g.short_name}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /not registered/i

    get :receive, :phone => NEW_PHONE2, :text => "join #{g.short_name}"
    assert_response :success
    assert users(:joe).groups.find_by_short_name(g.short_name)

    get :receive, :phone => UNREG_PHONE, :text => "leave #{g.short_name}"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /not registered/i
    # still in the group
    assert users(:joe).groups.find_by_short_name(g.short_name)

    # get a list of my groups
    get :receive, :phone => NEW_PHONE2, :text => "groups"
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /2 groups/i

    # unknown command
    get :receive, :phone => NEW_PHONE, :text => "go frag yourself"
    assert_response :success
    assert @response.body =~ /errors/

    # system error message
    get :receive, :phone => NEW_PHONE, :text => "Error Invalid number"
    assert_response :success
    assert @response.body =~ /error message/i
  end

  test "receiving conversations" do
    joe = users(:joe)

    assert_equal 1,joe.paged_msgs.count
    # joe tries to respond to the old message from jake -> cannot because old
    get :receive, :phone => joe.phone, :text => "jake sorry it took a while", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /error/

    # joe sends a message to jake
    get :receive, :phone => joe.phone, :text => "Send jake: test", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent to/
    assert @response.body =~ /confirmation sent/i

    # jake replies, and it goes to joe
    jake = users(:jake)
    get :receive, :phone => jake.phone, :text => "got it", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent message to joe/i

    # jake sends himself a quick reminder
    get :receive, :phone => jake.phone, :text => "send jake: reminder", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sender one of the recipients/i

    # jake replies again, send it to joe again
    # note: this is a 1 response - could be a confirmation code, but should not matter here since jake should be validated
    get :receive, :phone => jake.phone, :text => "1", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent message to joe/i

    # joe replies to jake (even though he has 2 message, both from jake)
    get :receive, :phone => joe.phone, :text => "got ya back", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent message to jake/i

    # joe jones replies -> error
    get :receive, :phone => users(:joe_jones).phone, :text => "trying to get in on this", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /error/i
    assert @response.body =~ /unknown command/i

    # joe jones sends a message to everyone
    get :receive, :phone => users(:joe_jones).phone, :text => "send joe,jake: whats up guys", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent to 2/i

    # jake replies -> needs to specify which conversation he is replying to
    get :receive, :phone => jake.phone, :text => "big jj", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /errors/i
    assert @response.body =~ /please use send/i

    # joe can send a reply directly back
    get :receive, :phone => joe.phone, :text => "send joe_jones:big jj", :time=>'2011-09-21+00:01:10s'
    assert_response :success
    #assert_equal "",@response.body
    assert @response.body =~ /sent to/i

    # extra
    # a phone with multiple users, one of whom is not valid, needs a username and password to respond

  end

  test "multiple users sharing a phone" do
    # todo: register, and validate appropriately, even if others not validated
    # todo: respond to conversation appropriately
    # what about looking up, this might require logging in if not properly validated - fine if everyone is validated, otherwise would require password
    # todo: remove - works, since uses username:password
    # the alternative to allowing multiple users to share a phone would be to require an individual phone
  end
end
