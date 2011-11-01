require 'test_helper'

class GroupTest < ActiveSupport::TestCase

  def setup
    @org = orgs(:sample)
    @joe = users(:joe)
  end
  
  def test_add
    group = Group.new()
    assert !group.valid?
    
    # must specify a name
    assert group.errors.invalid?(:unique_name), group.errors.full_messages

    group.name = "Test01"
    group.org = @org
    assert group.valid?
    assert group.save!,"Unable to save group"
    
    # name must be unique
    newgroup = Group.new(:name => "Test01", :org => @org)
    assert !newgroup.valid?
    assert newgroup.errors.invalid?(:unique_name)
    
    assert_raise ActiveRecord::RecordInvalid do
      newgroup.save!
    end
    
    # can add a user to the group
    assert group.users.size==0,"Expecting no users in this group!"
    
    user1 = User.new(:name => "Josephine", :password=>'secret', :login_name=>'josephine')
    user1.org = @org
    group.users << user1
    assert_equal 1, group.users.size, "Expecting 1 user in this group!"
    
    # cannot add the same user to the group
    assert_raise ActiveRecord::RecordInvalid do
      group.users << user1
    end
    
    # can add x users to the group
    total_users = 100
    total_users.times do |i|
      userX = User.new(:name => "User " +i.to_s, :org => @org, :password=>'secret', :login_name=>'user_'+i.to_s)
      userX.org = @org
      group.users << userX
    end
    assert_equal group.users.size,total_users+1,"Not able to add #{total_users} users"
  end

  def test_short_name
    g = groups(:all_users)
    assert g.short_name && g.short_name!=""

    g2 = orgs(:sample).groups.new(:name => "Test02")
    g2.save!

    # cannot add a duplicate short name
    g2.short_name = g.short_name
    assert_raises ActiveRecord::RecordInvalid do
      g2.save!
    end

    # cannot add a duplicate of a users login name
    g2.short_name = users(:joe).login_name
    assert_raises ActiveRecord::RecordInvalid do
      g2.save!
    end


    # cannot add a duplicate of a users name
    g2.short_name = users(:joe).unique_name
    assert_raises ActiveRecord::RecordInvalid do
      g2.save!
    end

    # but we can save something unique
    g2.short_name = "group2"
    g2.save!
  end

  def test_forbidden_name
    g = orgs(:sample).groups.new(:name => FROM_SYSTEM_NAME, :short_name=> FROM_SYSTEM_NAME)
    assert !g.valid?
    assert g.errors.invalid?(:name)
    assert g.errors.invalid?(:short_name)
    assert_raises ActiveRecord::RecordInvalid do
      g.save!
    end
  end
  
end
