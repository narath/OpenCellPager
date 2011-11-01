# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'util'

class ApplicationController < ActionController::Base

  include ExceptionNotifiable
  local_addresses.clear
  #local_addresses.clear # always send email notifications instead of displaying the error
  
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '62888d0fef6268d3d3121f7d5b28e1ce'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  
  before_filter :require_user_session
  before_filter :check_back
  
  rescue_from ActiveRecord::RecordNotFound, ActionController::UnknownController, 
              ActionController::UnknownAction, ActionController::RoutingError, :with => :redirect_if_not_found
  
  rescue_from ActionController::InvalidAuthenticityToken, :with => :redirect_if_inauthentic

  
  protected
  
  def require_user_session
    # if the user_id is valid, then the User is returned in @user
    @user = User.find_user_for_session(session[:user_id], request.remote_ip)
    @org = @user.org
  end
	
  def require_admin
     authorization_error_redirect("Authorization (admin) required") unless @user.admin?
  end

  def require_member
     authorization_error_redirect("Authorization (member) required") unless @user.registered?
  end
  
  def require_user
     authorization_error_redirect("Authorization (user) required") if @user.stranger?
  end


  def authorization_error_redirect(defect='')

    # user is logged in
    if @user.registered?
      log_event("authorization_error", "user: #{@user.id} | uri: '#{request.request_uri}'")
      flash[:oops] = "Permission denied. You cannot access the requested page. #{defect}"
      respond_to do |format| 
        format.html { redirect_to :controller => 'public', :action => 'oops' }
        format.js { render(:update) { |p| p.redirect_to :controller => 'public', :action => 'oops' } }
      end
    else
      flash[:notice] = "Login is required to access the requested page."
      respond_to do |format| 
        format.html { redirect_to :controller => 'users', :action => 'login', :back => request.request_uri }
        format.js { render(:update) { |p| p.redirect_to :controller => 'users', :action => 'login' } }
      end
    end
    
    false  # Want to short-circuit the filters
  end

  def user_error(error_message)
    flash[:oops] = error_message
    redirect_to :controller => 'public', :action => 'oops'
    true # so caller can say 'and return'
  end
  
  def expected_post_not_get
    user_error("I expected a post not a get request.")
  end
  
  def redirect_if_inauthentic
    require_user_session
    redirect_to :controller => 'public', :action => 'inauthenticity'
  end

  def redirect_if_not_found
    redirect_to :controller => 'public', :action => 'page_not_found'
  end

	
  def id_param
    params[:id].to_i
  end

  def check_back
    @back = params[:back]
    return true
  end

  #-----------------------------------------------------------------------------
  # redirect to stored back link, or to specified default if no back link stored
  #--
  def redirect_back_or_to(params)
    if @back.blank?
      redirect_to(params)
    else
      redirect_to(@back)
    end
  end


end
