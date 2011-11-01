class MembersController < ApplicationController
  layout 'application'

  before_filter :find_member, :except=>[:new, :create, :browse, :ajax_find_user, :export]
  before_filter :init_member, :only=>[:new, :create]
  before_filter :find_group, :only => [:add_to_group, :drop_from_group]

  before_filter :require_user
  before_filter :require_admin, :only=>[:create, :delete, :add_to_group, :drop_from_group, :export]
  before_filter :require_admin_or_self, :only=>[:update, :edit, :edit_password, :edit_status,
                                                :ajax_lookup_forward, :ajax_set_forward, :ajax_find_user,
                                                :send_conf, :update_conf, :messages]

  def messages
    @msgs = @member.msgs.paginate(:all, :order => "updated_at desc", :page => params[:page], :per_page => 24)
  end

  def pages
    @msgs = @member.paged_msgs.paginate(:all, :order => "updated_at desc", :page => params[:page], :per_page => 24)
  end

  def show
    @allow_edit = @user.admin? || @user.tis_himself?(@member)
  end

  def edit
  end

  def edit_status
    return if not request.post?

    @member.update_attributes(params[:member])

    if @member.save
      flash[:notice] = "Your status was changed"
      redirect_back_or_to(:controller=>'members', :action=>'show', :id=>@member)
      return
    end

  end

  def confirm

    @conf_msg = @member.conf_msg
    @conf_msg.refresh_raw_status if @conf_msg

  end

  def send_conf

    expected_post_not_get && return unless request.post?

    @member.reset_sms_validation!

    flash[:notice] = "Confirmation SMS sent"
    redirect_to(:controller=>'members', :action=>'confirm', :id=>@member)

  end

  def update_conf
    expected_post_not_get && return unless request.post?
    @member.update_attributes(params[:member])
    if @member.save
      flash[:notice] = "Conf status updated"
      redirect_back_or_to(:controller=>'members', :action=>'show', :id=>@member)
    else
      redirect_to(:controller=>'members', :action=>'confirm', :id=>@member)
    end
  end

  def force_conf
    expected_post_not_get && return unless request.post?
    @member.force_sms_validation!(params[:value].to_i==DB_TRUE)
    flash[:notice] = "Validation overridden. Phone #{@member.sms_validated? ? "validated" : "disabled"}"
    redirect_back_or_to(:controller=>'members', :action=>'show', :id=>@member)
  end

  def edit_password

    return if not request.post?

    unless (@user.admin? && !@user.tis_himself?(@member)) || @member.valid_password?(params[:old_password])
      @member.errors.add_to_base("Authentication with old password failed")
      return
    end

    @member.password = params[:new_password]
    @member.password_confirmation = params[:new_password_confirmation]

    if @member.save
      flash[:notice] = "Your password was changed"
      redirect_back_or_to(:controller=>'members', :action=>'show', :id=>@member)
      return
    end

  end

  def browse
    @members = @org.users.paginate(:all, :order => "name", :page => params[:page], :per_page => 24)
  end

  def update
    expected_post_not_get && return unless request.post?
    @member.update_attributes!(params[:member])
    if @member.need_conf?
      redirect_to :action => 'confirm', :id=>@member
    else
      redirect_back_or_to :controller=>'orgs', :action => 'show'
    end
  rescue ActiveRecord::RecordInvalid
    render :action => :edit
  end

  def create
    expected_post_not_get && return unless request.post?
    @member.attributes = (params[:member])
    @member.save!
    if @member.need_conf?
      redirect_to :action => 'confirm', :id=>@member, :back=>@back
    else
      redirect_back_or_to :controller=>'orgs', :action => 'show'
    end
  rescue ActiveRecord::RecordInvalid
    render :action => :new
  end

  def delete
    expected_post_not_get && return unless request.delete?
    @member.destroy
    flash[:notice] = "User Deleted"
    redirect_to :controller => 'members', :action => 'browse'
  end

  def export
    @members = @org.users.all(:order=>"name,phone")
    # from http://snippets.dzone.com/posts/show/2046
    response.headers['Content-Type'] = 'text/csv' # I've also seen this for CSV files: 'text/csv; charset=iso-8859-1; header=present'
    response.headers['Content-Disposition'] = 'attachment; filename=members.csv'
    render :layout=>false
  end

  def add_to_group

    if !@member.groups.find(:first, :conditions=>['groups.id=?', @group.id])
      @member.groups << @group
      flash[:notice] = "User added to group added"
    else
      flash[:notice] = "User was already in the group"
    end

    redirect_back_or_to :controller=>'members', :action => 'show', :id => @member

  end

  def drop_from_group

    if @member.groups.find(:first, :conditions=>['groups.id=?', @group.id])
      @member.groups.delete(@group)
      flash[:notice] = "User added to group added"
    else
      flash[:notice] = "User was not in the group"
    end

    redirect_back_or_to :controller=>'members', :action => 'show', :id => @member

  end

  def ajax_add_to_group

    if params['search_for'].strip.length > 0
      terms = params['search_for'].split.collect do |word|
        "%#{word.downcase}%"
      end
      @groups = @org.groups.find(:all,
                                 :conditions => [(["(LOWER(name) LIKE ?)"] * terms.size).join(" AND "),
                                                 * terms.flatten])
    end
    render :partial => "groups", :object=>@groups

  end

  def ajax_find_user
    if params['search_for'].strip.length > 0
      terms = params['search_for'].split.collect do |word|
        "%#{word.downcase}%"
      end
      @users = @org.users.find(:all,
                               :conditions => [(["(LOWER(name) LIKE ?)"] * terms.size).join(" AND "),
                                               * terms.flatten])
    end
    render :partial => "users", :object=>@users
  end

  def ajax_lookup_forward

    @key = params[:key].downcase.strip
    @limit = 50
    @results = []

    if @key.blank?
      @results = @org.users.find(:all, :conditions => ["users.id != ?", @member.id], :limit=>@limit)
    else
      terms = @key.split.collect { |word| "%#{word}%" }
      @results = @org.users.find(:all,
                                 :conditions => ["users.id != ? and " + (["(LOWER(name) LIKE ?)"] * terms.size).join(" AND "), @member.id, * terms.flatten],
                                 :limit=>@limit,
                                 :order => 'name')
    end

    render :update do |page|
      @member.forward_to = @results[0]
      page.replace_html("forwardees", :partial => "members/forwardees", :locals => {:results => @results, :member=>@member})
      page.replace_html('forwardee', :partial => "members/forwardee", :locals => {:member => @member})
      page["member_forward_id"].value = @results[0] ? @results[0].id : ''
    end

  end

  def ajax_set_forward
    render :update do |page|
      if params[:value].blank? || params[:value].to_i==0
        @member.forward_to = nil
        page.replace_html('forwardee', :partial => "members/forwardee", :locals => {:member => @member})
        page["member_forward_id"].value = 0
      elsif @member.forward_to = User.find_by_id(params[:value])
        page.replace_html('forwardee', :partial => "members/forwardee", :locals => {:member => @member})
        page["member_forward_id"].value = @member.forward_to.id
      end
    end
  end

  #######
  protected
  #######

  def find_group
    @group = Group.find_by_id(params[:group_id]) || raise(ActiveRecord::RecordNotFound)
    raise(ActiveRecord::RecordNotFound) unless @group.in_org?(@org)
  end

  def find_member
    @member = User.find_by_id(id_param) || raise(ActiveRecord::RecordNotFound)
    raise(ActiveRecord::RecordNotFound) unless @member.in_org?(@org)
  end

  def init_member
    @member = User.new
    @member.org = @org
  end

  def require_admin_or_self
    authorization_error_redirect("Authorization (self) required") unless @user.admin? || @user.tis_himself?(@member)
  end

end
