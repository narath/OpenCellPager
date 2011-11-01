require 'test_helper'

class UsersControllerTest < ActionController::TestCase

  def setup
    @joe = users(:joe)
    @admin = users(:admin)
    @org = orgs(:sample)
  end

  #-----------------------------------------------------------------------------
  #
  #--
  def test_login
    post :login, :login_name => @joe.login_name, :password => @joe.password
    assert_response :redirect, flash[:error]
    assert_redirected_to :controller => 'orgs', :action => 'show'
    assert_equal @joe.id, session[:user_id]
  end

  #-----------------------------------------------------------------------------
  #
  #--
  def test_login_bad_password
    post :login, :login_name => @joe.login_name, :password => 'bogus'
    assert_template "login"
  end

  def test_system_user_cannot_login
    u = @org.system_user
    assert u, "System user does not exist"

    post :login, :login_name => u.login_name, :password => u.password
    assert_template "login"
    assert flash[:error] =~ /incorrect/i
  end

end
