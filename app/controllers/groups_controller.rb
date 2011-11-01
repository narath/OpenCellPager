class GroupsController < ApplicationController
  layout 'application'

  before_filter :find_group, :except=>[:new, :create, :browse]
  before_filter :init_group, :only=>[:new, :create]
  before_filter :find_member, :only=>[:add_member]
  
  before_filter :require_user
  before_filter :require_admin, :except=>[:show, :browse]
  
  def browse
    @groups = @org.groups.paginate(:all, :order => "name", :page => params[:page], :per_page => 24)
  end
  
  def show
  end
  
  def edit
  end

  def new
  end

  def update
    expected_post_not_get && return unless request.post?
    @group.update_attributes!(params[:group])
    redirect_back_or_to :controller=>'orgs', :action => 'show'
  rescue ActiveRecord::RecordInvalid 
    render :action => :edit
  end

  def create
    expected_post_not_get && return unless request.post?
    @group.attributes = (params[:group])
    @group.save!
    redirect_back_or_to :controller=>'groups', :action => 'show', :id=>@group
  rescue ActiveRecord::RecordInvalid 
    render :action => :new 
  end

  def delete
    expected_post_not_get && return unless request.delete?
    @group.destroy
    flash[:notice] = "Group Deleted"
    redirect_to :controller => 'groups', :action => 'browse'
  end
  
  def add_member

    if !@group.users.find(:first, :conditions=>['users.id=?', @member.id])
      @member.groups << @group
      flash[:notice] = "User added to group added"
    else
      flash[:notice] = "User was already in the group"
    end

	  redirect_back_or_to :controller=>'groups', :action => 'show', :id => @group

  end
  
  def ajax_add_member

		if params['search_for'].strip.length > 0
			terms = params['search_for'].split.collect do |word|
				"%#{word.downcase}%"
		  end
			@members = @org.users.find(:all, 
				:conditions => [ ( ["(LOWER(name) LIKE ?)"] * terms.size ).join(" AND "),
				* terms.flatten ] )
		end
		render :partial => "members", :object=>@members

  end
  
  #######
  protected
  #######
  
  def find_group
    @group = Group.find_by_id(id_param) || raise(ActiveRecord::RecordNotFound)
    raise(ActiveRecord::RecordNotFound) unless @group.in_org?(@org)
  end

  def find_member
    @member = User.find_by_id(params[:member_id]) || raise(ActiveRecord::RecordNotFound)
    raise(ActiveRecord::RecordNotFound) unless @member.in_org?(@org)
  end
  
  def init_group
    @group = Group.new
    @group.org = @org
  end
  
end
