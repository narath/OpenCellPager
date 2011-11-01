class Backend < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name

  validates_presence_of :backend_type

  has_many :router_rules, :order=>"position ASC", :dependent=>:destroy
  has_many :outbounds, :order=>"created_at ASC", :dependent=>:nullify
end
