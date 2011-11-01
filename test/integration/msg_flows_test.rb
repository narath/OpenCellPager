require 'test_helper'

class MsgFlowsTest < ActionController::IntegrationTest
  fixtures :all

  def setup
    @org = orgs(:sample)
    @joe = users(:joe)
    @jake = users(:jake)
  end

  test "send successful message" do
    # the backend for @joe should go thru test
    assert_equal 'test',RouterRule.find_matching_rule(@joe.phone).backend.backend_type
    msg = @org.send_msg(@jake,@joe,'test message')
    assert_equal STATUS_DELIVERED, msg.pages[0].outbounds[0].status
  end

  test "send fail" do
    msg = @org.send_msg(@jake,@joe,'fail test message')
    assert_equal STATUS_FAILED, msg.pages[0].outbounds[0].status
  end

  test "send error" do
    # sending the page no longer raises Gateway::Error since this is most likely going to be delayed job
    # instead, from the test I would expect the message to be failure
    msg = @org.send_msg(@jake,@joe,'error test message')
    assert_equal STATUS_FAILED,msg.pages[0].outbounds[0].status
    assert msg.pages[0].outbounds[0].status_string =~ /error/i
  end
end
