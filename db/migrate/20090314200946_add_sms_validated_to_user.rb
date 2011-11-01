class AddSmsValidatedToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :sms_validated, :integer
  end

  def self.down
    remove_column :users, :sms_validated
  end
end
