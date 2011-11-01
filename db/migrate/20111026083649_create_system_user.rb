require 'util'

class CreateSystemUser < ActiveRecord::Migration
  def self.up
    # for all organizations, create a system user
    Org.all.each do |org|
      org.system_user
    end
  end

  def self.down
    # remove the system user
    Org.all.each do |org|
      u = org.users.find_by_name(FROM_SYSTEM_NAME)
      u.destroy if u
    end
  end
end
