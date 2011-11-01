module LoginTestHelper
  def get_requires_user(url,params=nil,session={})
    get :index
    assert_redirected_to :action => "login"
    assert flash[:notice] =~ /login is required/i

    get :index,nil,user_session.merge(session)
    assert_response :success
  end

  def get_requires_admin(url,params=nil,session={})
    get :index
    assert_redirected_to :action => "login"
    assert flash[:notice] =~ /login is required/i

    get :index,nil,user_session.merge(session)
    assert_redirected_to :action => "oops"

    get :index,nil,admin_session.merge(session)
    assert_response :success
  end

  def admin_session
    {:user_id=>users(:admin).id}
  end

  def user_session
    {:user_id=>users(:joe).id}
  end
end
