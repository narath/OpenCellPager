class CreateSchema < ActiveRecord::Migration
  
  def self.up
    
    create_table :users do |t|
      t.string   "name",     :null => false
      t.string   "unique_name"
      t.string   "phone"
      t.string   "password"
      t.integer  "admin",   :default => 0
      t.integer  "org_id",  :null => false
      t.timestamps
    end

    create_table :orgs do |t|
      t.string   "name",     :null => false
      t.string   :username
      t.string   :password
      t.decimal  :balance, :decimal, :precision => 8, :scale => 2, :default => 0
      t.timestamps
    end

    create_table :groups do |t|
      t.string   "name",     :null => false
      t.string   "unique_name"
      t.integer  "org_id",  :null => false
      t.timestamps
    end

    create_table :groups_users, :id=>false do |t|
      t.integer  "group_id"
      t.integer  "user_id"
    end
    
    create_table :msgs do |t|
      t.text     "text",     :null => false
      t.integer  "org_id",  :null => false
      t.integer  "recipient_id",    :null => false
      t.string   "recipient_type"
      t.timestamps
    end

    create_table :pages do |t|
      t.integer  "msg_id", :null => false
      t.integer  "user_id", :null => false
      t.integer  "org_id",  :null => false
      t.integer  "status",   :default => STATUS_PENDING
      t.string   "gateway_uid"
      t.string   "gateway_status_string"
      t.timestamps
    end
    
  end

  def self.down
    drop_table :users
    drop_table :orgs
    drop_table :groups
    drop_table :groups_users
    drop_table :msgs
    drop_table :pages
  end
  
end
