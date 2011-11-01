require 'test_helper'

class AdminControllerTest < ActionController::TestCase
  test "access page without user" do
    get :index
    assert_redirected_to :action => "login"
    assert_equal "Login is required to access the requested page.",flash[:notice]
  end
end
