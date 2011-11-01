class AddSentIdToOutbound < ActiveRecord::Migration
  def self.up
    add_column :outbounds,:sent_id, :integer
    add_column :outbounds,:sent_at, :datetime
  end

  def self.down
    remove_column :outbounds,:sent_id
    remove_column :outbounds,:sent_at
  end
end
