require 'test_helper'
require 'login_test_helper'

class RouterRulesControllerTest < ActionController::TestCase
  include LoginTestHelper

  test "should get index only if administator" do
    get_requires_admin :index
    assert_not_nil assigns(:router_rules)
  end

  test "should get new" do
    get_requires_admin :new
    assert_response :success
  end

  NEW_PATTERN = '011'
  test "should create rule" do
    # cannot post without being admin
    params = {:router_rule => { :pattern=> NEW_PATTERN, :backend_id=>backends(:one).id }}
    assert_no_difference('RouterRule.count') do
      post :create, params
    end

    # can if admin
    assert_difference 'RouterRule.count',1,"Admin can create a rule" do
      post :create, params, admin_session
    end
    assert_redirected_to router_rule_path(assigns(:router_rule))
  end

  test "should show rule" do
    get_requires_admin :show, :id => router_rules(:use_one_for_america).to_param
    assert_response :success
  end

  test "should get edit" do
    get_requires_admin :edit, :id => router_rules(:use_one_for_america).to_param
    assert_response :success
  end

  test "should destroy rule" do
    assert_no_difference('RouterRule.count') do
      delete :destroy, :id => router_rules(:use_one_for_america).to_param
    end

    assert_difference('RouterRule.count', -1) do
      params = {:id => router_rules(:use_one_for_america).to_param}
      delete :destroy, params, admin_session
    end

    assert_redirected_to router_rules_path
  end

  test "should update rule" do
    # can only update if admin
    put_params = {:id => router_rules(:use_one_for_america).to_param, :router_rule => { :comment => 'hello world'}}

    put :update, put_params
    assert_redirected_to :action=>'login'

    put :update, put_params, user_session
    assert_redirected_to :action=>'oops'

    put :update, put_params, admin_session
    assert_redirected_to router_rule_path(assigns(:router_rule))
  end
end
