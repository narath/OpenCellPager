class UsersController < ApplicationController

  layout 'application'

  #-----------------------------------------------------------------------------
  # login 
  #-
  def login
    @orgs = Org.find(:all)
    user_error("No organizations in database!") and return if @orgs.size == 0
    
    # we are currently assuming there is only one org defined
    user_error("Multiple organizations in database. Not yet supported!") and return if @orgs.size > 1
    
    if !request.post? 
      session[:user_id] = nil 
      session[:original_uri] = @back # remember where they wre trying to go
      return
    end
      
    @login_name = params[:login_name]
    @password = params[:password]

    if FORBIDDEN_NAMES.include?(OCP::standardize_unique_name(@login_name))
      logger.info "UserController.login: ATTEMPT TO LOGIN AS FORBIDDEN NAME #{@login_name}"
      flash.now[:error] = "Incorrect login name or password"
    else
      user = User.find_by_login_name(  OCP::standardize_unique_name(@login_name) )
      user = nil if user && !user.valid_password?(@password)

      if user.nil?
        logger.info "UserController.login: FAILED LOGIN ATTEMPT FOR #{@login_name}"
        flash.now[:error] = "Incorrect login name or password"
      else
        session[:user_id] = user.id
        uri = session[:original_uri]
        session[:original_uri] = nil
        redirect_to(uri || {:controller => 'orgs', :action => 'show'})
      end
    end
  end

  #-----------------------------------------------------------------------------
  # logout 
  #--
  def logout 
    reset_session
    redirect_to(:controller => 'public', :action => 'index') 
  end

  #######
  protected
  #######
  
end
