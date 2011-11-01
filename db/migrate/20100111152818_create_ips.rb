class CreateIps < ActiveRecord::Migration
  def self.up
    create_table :ips do |t|
      t.string   "address"
      t.integer  "org_id",  :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :ips
  end
end
