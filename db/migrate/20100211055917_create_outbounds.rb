class CreateOutbounds < ActiveRecord::Migration
  def self.up
    create_table :outbounds do |t|
      t.integer  "page_id",   :null => false
      t.string   "phone",     :null => false
      t.text     "text",     :null => false
      t.integer  "status",   :default => 0
      t.integer  "error_code",   :default => 0
      t.string   "status_string"
      t.timestamps
    end
  end

  def self.down
    drop_table :outbounds
  end
end
