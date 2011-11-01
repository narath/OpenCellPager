class IpsController < ApplicationController
  layout 'application'
  
  before_filter :find_ip, :except=>[:new, :create, :browse]
  before_filter :init_ip, :only=>[:new, :create]

  before_filter :require_user
  before_filter :require_admin, :except=>[:browse]

  def browse
    @ips = @org.ips.paginate(:all, :order => "address", :page => params[:page], :per_page => 24)
  end

  def edit
  end

  def new
  end

  def update
    expected_post_not_get && return unless request.post?
    @ip.update_attributes!(params[:ip])
    redirect_back_or_to :controller=>'ips', :action => 'browse'
  rescue ActiveRecord::RecordInvalid 
    render :action => :edit
  end

  def create
    expected_post_not_get && return unless request.post?
    @ip.attributes = (params[:ip])
    @ip.save!
    redirect_back_or_to :controller=>'ips', :action => 'browse'
  rescue ActiveRecord::RecordInvalid 
    render :action => :new 
  end

  def delete
    expected_post_not_get and return unless request.delete? || request.post?
    @ip.destroy
    flash[:notice] = "Address Removed"
    redirect_back_or_to :controller => 'ips', :action => 'browse'
  end
  
  #######
  protected
  #######
  
  def find_ip
    @ip = Ip.find_by_id(id_param) || raise(ActiveRecord::RecordNotFound)
    raise(ActiveRecord::RecordNotFound) unless @ip.in_org?(@org)
  end

  
  def init_ip
    @ip = Ip.new
    @ip.org = @org
  end
  
end
