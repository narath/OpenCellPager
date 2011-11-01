require File.dirname(__FILE__) + '/../test_helper'

module TestHelper
  # returns the created msg
  def simple_create_msg(org, from, to, text)
    m = Msg.new(:from=>from, :text=>text)
    m.org = org
    m.recipient = to
    m.save!

    p = Page.new()
    p.org = org
    p.msg = m
    p.user = to
    p.save!

    return m
  end

end

class UserTest < ActiveSupport::TestCase
  include TestHelper

  def setup
    @joe = users(:joe)
    @admin = users(:admin)
    @org = orgs(:sample)
  end

  def test_empty_user
    user = User.new
    assert !user.valid?
    assert user.errors.invalid?(:name)
  end

  def test_add_user
    # blank name not valid
    user = User.new(:name => "", :password=>'secret')
    assert !user.valid?
    assert user.errors.invalid?(:name)
    user.name = "Joe2"

    # org must be specified
    assert_raise ActiveRecord::RecordInvalid do
      user.save!
    end
    user.org = @org

    # login_name must be >3
    assert_raise ActiveRecord::RecordInvalid do
      user.save!
    end
    assert_equal "", user.login_name
    user.login_name = "joe2"
    assert user.save!

    # duplicate name not valid
    user = User.new(:name => "Joe2", :password=>'secret', :login_name=>'joe2')
    user.org = @org
    assert !user.valid?
    assert user.errors.invalid?(:unique_name)
    assert user.errors.invalid?(:login_name)
    user.login_name = 'joe22'

    # name can contain accents, commas, dashes, 
    user.name = "Mr. René Üteñsîl-Butterdißh, Woolworth & Cie"
    assert user.valid?
    assert user.save!

    # name can contain extra spaces, but they are suppressed before save
    #user.name = "    my   dumb   name  "
    #assert user.valid?
    #assert user.save
    #user.name.should.equal "my dumb name"
  end

  def test_forbidden_name
    user = User.new(:name => FROM_SYSTEM_NAME, :password=>'secret', :login_name=>FROM_SYSTEM_NAME)
    user.org = @org
    assert !user.valid?
    assert user.errors.invalid?(:name)
    assert user.errors.invalid?(:login_name)
    assert_raises ActiveRecord::RecordInvalid do
      user.save!
    end
  end

  def test_phone
    user = User.new(:name => "Joe Phone", :password=>'secret', :login_name => 'joe_phone')
    user.org = @org

    # no phone # by default
    assert !user.phone
    assert user.valid?

    # can save without a phone #
    user.save!

    # updates phone correctly
    user.phone = "+416-555-1212"
    assert user.phone
    assert_equal '4165551212', user.phone
    user.save!

    # retrieve phone correctly
    userFind = User.find_by_name(user.name)
    assert userFind
    assert userFind.phone==user.phone

    # todo: phone number logic - i.e. org could have default country code, know area code etc
  end

  def test_admin
    # by default user is not admin
    user = User.new(:name => "Admin2")
    assert user.admin==0

    # there should always be at least one admin in the org
    admin = User.find_by_admin(1)
    assert admin, "No administrative user defined in your database"
  end

  def test_add_user_with_same_name_as_group

    group = Group.new(:name => "Duplicate")
    group.org = @org
    assert group.save, group.errors.full_messages

    # user valid if name is same as group
    user = User.new(:name => "Duplicate", :password=>'secret', :login_name=>'duplicate')
    user.org = @org
    assert !user.valid?

    # rename group
    group.name = "xDuplicate"
    assert group.save, group.errors.full_messages

    # can save once name is unique
    assert user.valid?, user.errors.full_messages
    assert user.save, user.errors.full_messages
  end

  def test_sms_validation
    #assert !@joe.sms_validated?
    @joe.reset_sms_validation!
    assert !@joe.sms_validated?

    # simulate getting the wrong code back
    @joe.sms_validation_received = @joe.sms_validation_sent+'1'
    assert_raise ActiveRecord::RecordInvalid do
      @joe.save!
    end

    # simulate getting the correct code
    assert !@joe.sms_validated?
    @joe.sms_validation_received = @joe.sms_validation_sent
    @joe.save!
    assert @joe.sms_validated?

    @joe.phone = "16175551111"
    assert !@joe.sms_validated?
    # can still save
    @joe.save!
  end

  def test_generate_username
    assert_raises RuntimeError do
      User.generate_username("")
    end
    assert_equal "dross",User.generate_username("Dr. Douglas Ross")
    assert_equal "iman",User.generate_username("Iman")
    assert_equal "gabas",User.generate_username("G. Abas MD (Diabetes)")

    # now create a user with the generated username
    # and try to generate another
    u = User.new(:name=>'Dr Douglas Ross',:login_name=>"dross", :password => 'erreruns')
    u.org_id = orgs(:sample).id
    u.save!
    assert_equal "dross1",User.generate_username("Dr. Douglas Ross")
  end

  def test_generate_password
    p1 = User.generate_password('user')
    assert_not_equal "password", p1 # theoretically possible but should be rare
    assert_not_equal p1, User.generate_password('user') # theoretically possible but again should be rare
  end

  def test_recent_msgs

    # all msgs for joe should pickup the fixture msg
    assert_equal 1, @org.msgs.count
    assert_equal 1, @org.pages.count
    assert_equal 1, @joe.pages.count
    assert_equal 1, @joe.paged_msgs.count

    # recent msgs should pickup none
    assert_equal 0, @joe.recent_msgs.count

    # save a new message for joe
    simple_create_msg(@org, 'jake', @joe, 'hello world')
    assert_equal 2, @joe.pages.count
    assert_equal 2, @joe.paged_msgs.count

    # now recent msgs should pick it up
    assert_equal 1, @joe.recent_msgs.count

    # and once more
    assert_difference '@joe.recent_msgs.count', 1, 'Should have another recent msg' do
      simple_create_msg(@org, 'jake', @joe, 'hello world')
    end
  end

  test "can create system user" do
    assert !User.find_by_name(FROM_SYSTEM_NAME)

    u = User.create_system_user(orgs(:sample))
    assert u, "Could not create system user"

    assert_raises RuntimeError do
      User.create_system_user(orgs(:sample))
    end
  end
end
