class AddFromToMsg < ActiveRecord::Migration
  def self.up
    add_column :msgs, :from, :string
  end

  def self.down
    remove_column :msgs, :from
  end
end
