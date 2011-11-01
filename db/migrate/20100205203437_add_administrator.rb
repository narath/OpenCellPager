require 'util'

class AddAdministrator < ActiveRecord::Migration
  def self.up

    unless Org.count>0
        sample_org = Org.new(:name  => "Sample Organization", :username=>'orguser', :password=>'orgpwd')
        sample_org.save!
    
        admin_member = User.new(:name  => "System Administrator", :login_name=> "admin", :password => "admin1234", :admin=>1)
        admin_member.org = sample_org
        admin_member.save!

        user_member = User.new(:name  => "Sample User",  :login_name  => "user", :password => "user1234", :admin=>0)
        user_member.org = sample_org
        user_member.save!
    end

  end

  def self.down
    User.destroy_all
    Org.destroy_all
  end
end
