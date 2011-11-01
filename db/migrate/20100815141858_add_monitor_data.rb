class AddMonitorData < ActiveRecord::Migration
  def self.up
    add_column :orgs, :monitor_minutes, :integer
    add_column :orgs, :monitor_unsent_pages, :integer
    add_column :orgs, :monitor_last_panic, :datetime
    add_column :orgs, :monitor_on, :boolean, :default=>true
    add_column :orgs, :monitor_last_check, :datetime
    add_column :orgs, :monitor_is_panicking, :boolean, :default=>false
    add_column :orgs, :monitor_check_in_minutes, :integer
  end

  def self.down
    remove_column :orgs, :monitor_minutes
    remove_column :orgs, :monitor_unsent_pages
    remove_column :orgs, :monitor_last_panic
    remove_column :orgs, :monitor_on
    remove_column :orgs, :monitor_last_check
    remove_column :orgs, :monitor_is_panicking
    remove_column :orgs, :monitor_check_in_minutes
  end
end
