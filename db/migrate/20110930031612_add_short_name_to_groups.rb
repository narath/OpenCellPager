class AddShortNameToGroups < ActiveRecord::Migration
  def self.up
    add_column :groups, :short_name, :string

    # add a short name to all the groups
    count = 1
    Group.all.each do |group|
      group.short_name = "group_#{count}"
      group.save
    end
  end

  def self.down
    remove_column :groups, :short_name
  end
end
