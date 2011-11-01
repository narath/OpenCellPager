class CreateBackends < ActiveRecord::Migration
  def self.up
    create_table :backends do |t|
      t.string :name, :null=>false, :limit=>50
      t.string :config
      t.integer :balance, :default=>0
      t.integer :total_sent, :default=>0
      t.integer :total_received, :default=>0

      t.timestamps
    end
    add_index(:backends,:name,:unique=>true)
  end

  def self.down
    drop_table :backends
  end
end
