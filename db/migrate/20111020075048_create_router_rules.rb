class CreateRouterRules < ActiveRecord::Migration
  def self.up
    create_table :router_rules do |t|
      t.string :pattern
      t.integer :position
      t.integer :backend_id
      t.string :comment

      t.timestamps
    end
  end

  def self.down
    drop_table :router_rules
  end
end
