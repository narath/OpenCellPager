require 'test_helper'

class OutboundTest < ActiveSupport::TestCase
  test "send correctly" do
    o = Outbound.post(orgs(:sample),pages(:page_to_joe),'16175551111','test message')
    assert o

    # handle test yourself
    o = Outbound.post(orgs(:sample),pages(:page_to_joe),'16175551111','test message') do |outbound|
      assert_equal backends(:one).name, outbound.backend.name
      outbound.status_string = "I handled this"
      true
    end
    assert_equal "I handled this",o.status_string

    o = Outbound.post(orgs(:sample),pages(:page_to_joe),'2666175551111','test message') do |outbound|
      assert_not_equal backends(:one).name, outbound.backend.name
      false
    end
    assert_not_equal "I handled this",o.status_string
  end

  test "call refresh correctly" do
    assert_equal STATUS_DELIVERED,outbounds(:one).request_refresh
  end

  test "sent_direct works appropriately" do
    Outbound.create!(
        :page_id => nil,
        :phone => '1617',
        :text => 'direct'
    )
    assert_equal 1,Outbound.sent_direct.count
    assert_not_equal Outbound.sent_direct.count, Outbound.all.count
  end
end
