class AddRawFlagToMsg < ActiveRecord::Migration
  def self.up
    add_column :msgs, :raw, :integer, :default=>0
    execute "update msgs set raw = 0"
  end

  def self.down
    remove_column :users, :raw
  end
end
