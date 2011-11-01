require 'test_helper'
require 'login_test_helper'

class BackendsControllerTest < ActionController::TestCase
  include LoginTestHelper

  test "should get index only if administator" do
    get_requires_admin :index
    assert_not_nil assigns(:backends)
  end

  test "should get new" do
    get_requires_admin :new
    assert_response :success
  end

  test "should create backend" do
    # cannot post without being admin
    assert_no_difference('Backend.count') do
      post :create, :backend => { :name=>"Tester", :backend_type=>'test' }
    end

    # can if admin
    assert_difference 'Backend.count',1,"Admin can create a backend session" do
      params = {:backend => { :name=>"New one", :backend_type=>'test' }}
      post :create, params, admin_session
    end
    assert_redirected_to backend_path(assigns(:backend))
  end

  test "should show backend" do
    get_requires_admin :show, :id => backends(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get_requires_admin :edit, :id => backends(:one).to_param
    assert_response :success
  end

  test "should destroy backend" do
    assert_no_difference('Backend.count') do
      delete :destroy, :id => backends(:one).to_param
    end

    assert_difference('Backend.count', -1) do
      params = {:id => backends(:one).to_param}
      delete :destroy, params, admin_session
    end

    assert_redirected_to backends_path
  end

  test "should update backend" do
    # can only update if admin
    put :update, :id => backends(:one).to_param, :backend => { }
    assert_redirected_to :action=>'login'

    put_params = {:id => backends(:one).to_param, :backend => { }}

    put :update, put_params, user_session
    assert_redirected_to :action=>'oops'

    put :update, put_params, admin_session
    assert_redirected_to backend_path(assigns(:backend))
  end
end
