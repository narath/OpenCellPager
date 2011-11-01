class ChangeSentIdToString < ActiveRecord::Migration
  def self.up
    # the gateways sometimes return guids, and so we will store this as a string
    change_column :outbounds,:sent_id,:string, :limit=>200
  end

  def self.down
    change_column :outbounds, :sent_id, :integer
  end
end
