require 'test_helper'

class BackendTest < ActiveSupport::TestCase
  test "name must be unique" do
    one = backends(:one)
    b = Backend.new(:name=>one.name, :backend_type=>'test')
    assert_raises ActiveRecord::RecordInvalid do
      b.save!
    end
    b.name += " new"
    b.save!
  end

  test "must have name" do
    b = Backend.new(:backend_type=>'test')
    assert_raises ActiveRecord::RecordInvalid do
      b.save!
    end
    b.name = "has name"
    b.save!
  end

end
