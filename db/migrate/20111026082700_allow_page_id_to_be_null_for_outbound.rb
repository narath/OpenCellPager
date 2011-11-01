class AllowPageIdToBeNullForOutbound < ActiveRecord::Migration
  def self.up
    change_column :outbounds, :page_id, :integer, :null=>true
    # needed to be able to support sending direct messages
  end

  def self.down
    change_column :outbounds, :page_id, :null=>false
  end
end
