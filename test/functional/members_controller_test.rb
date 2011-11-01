require 'test_helper'

class MembersControllerTest < ActionController::TestCase
  test "browse" do
    get :browse
    assert_redirected_to :controller=>"users", :action=>"login", :back=>"/members/browse"
    assert_equal "Login is required to access the requested page.",flash[:notice]

    get :browse, {}, { :user_id => users(:admin).id }
    assert_response :success
    assert_template "browse"
  end

  # ruby -I test test/functional/members_controller_test.rb -n test_admin_can_assign_admin_users
  test "admin can assign admin users" do
    get :edit, { :id=>users(:joe).id },{:user_id => users(:admin).id}
    assert_response :success
    assert_template "edit"
    assert_tag :tag=>"input", :attributes=>{ :type=>"checkbox", :id=>"member_admin"}
  end

  test "users cannot assign admin users" do
    get :edit, { :id=>users(:joe).id },{:user_id => users(:joe).id}
    assert_response :success
    assert_template "edit"
    assert_no_tag :tag=>"input", :attributes=>{ :type=>"checkbox", :id=>"member_admin"}
  end

  test "admin cannot change own admin status" do
    get :edit, { :id=>users(:admin).id },{:user_id => users(:admin).id}
    assert_response :success
    assert_template "edit"
    assert_no_tag :tag=>"input", :attributes=>{ :type=>"checkbox", :id=>"member_admin"}
  end

  #todo: "when user is created, validation is automatically sent"

end
