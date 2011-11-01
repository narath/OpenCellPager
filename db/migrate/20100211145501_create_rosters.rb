class CreateRosters < ActiveRecord::Migration
  def self.up
    create_table :rosters do |t|
      t.integer "org_id"
      t.date  "start_date"
      t.integer "role_id"
      t.integer "assignment_id"
      t.boolean "processed"
      t.datetime "processed_at"
      t.timestamps
    end
  end

  def self.down
    drop_table :rosters
  end
end
