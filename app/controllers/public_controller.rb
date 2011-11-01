class PublicController < ApplicationController

  layout 'application'

  def index
    redirect_to(:controller => 'orgs', :action => 'show')  if @org
    
  end

  def help
  end
  
  def page_not_found
    respond_to do |type| 
      type.html { render :template => "public/error_404", :layout => 'application', :status => 404 } 
      type.all  { render :nothing => true, :status => 404 } 
    end
  end
  
  def oops
    @error_message = flash[:oops]
  end

  def inauthenticity
  end

  def boom
    raise "boom!"
  end
  
end
