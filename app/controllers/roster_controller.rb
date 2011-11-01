SimpleRole = Struct.new(:id, :start_date, :call_role_name, :call_assignment_name)

class RosterController < ApplicationController
  layout 'application'

  before_filter :find_item, :except=>[:new, :create, :browse, :update, :process_schedule, :ajax_get_names]
  before_filter :init_item, :only=>[:new, :create]

  before_filter :require_user
  before_filter :require_admin, :except=>[:browse]

  def browse
    @roster = @org.rosters.paginate(:all, :order => "start_date", :page => params[:page], :per_page => 24)
    #TODO: add :condition=>"DATE(start_date) >= DATE(NOW())"
  end

  def new
    @simple = SimpleRole.new()
    @simple.id = @roster.id
    @simple.start_date = Time.now.localtime.strftime('%d %b %Y')
  end

  def create
    expected_post_not_get && return unless request.post?

    call_role = User.find_by_name(params[:simple][:call_role_name])
    call_assignment = User.find_by_name(params[:simple][:call_assignment_name])

    do_redirect = false
    error_msg = []

    start_date = Date.parse(params[:simple][:start_date])
    if !start_date
      error_msg << "Invalid date"
      do_redirect = true
    end

    if (!call_role)
      error_msg << "Call role does not specify a user"
      do_redirect = true
    end

    if (!call_assignment)
      error_msg << "Call assignment does not specify a user"
      do_redirect = true
    end

    if do_redirect
      flash[:notice] = error_msg.join("\n")
      render :action => :new
      return
    end

    @roster = Roster.new()
    @roster.org = @org
    @roster.start_date = start_date
    @roster.call_role = call_role
    @roster.call_assignment = call_assignment
    @roster.save!
    redirect_back_or_to :controller=>'roster', :action => 'browse'
  rescue ActiveRecord::RecordInvalid
    render :action => :new
  end

  def edit
    @simple = SimpleRole.new()
    @simple.id = @roster.id
    @simple.start_date = @roster.start_date
    @simple.call_role_name = @roster.call_role.name if @roster.call_role
    @simple.call_assignment_name = @roster.call_assignment.name if @roster.call_assignment
  end

  def update
    expected_post_not_get && return unless request.post?

    call_role = User.find_by_name(params[:simple][:call_role_name])
    call_assignment = User.find_by_name(params[:simple][:call_assignment_name])

    do_redirect = false
    error_msg = []

    start_date = Date.parse(params[:simple][:start_date])
    if !start_date
      error_msg << "Invalid date"
      do_redirect = true
    end

    if (!call_role)
      error_msg << "Call role does not specify a user"
      do_redirect = true
    end

    if (!call_assignment)
      error_msg << "Call assignment does not specify a user"
      do_redirect = true
    end


    if do_redirect
      flash[:notice] = error_msg.join("\n")
      render :action => :edit, :id => @roster
      return
    end

    @roster = Roster.find_by_id(params[:simple][:id])
    if !@roster
      flash[:notice] = "Could not find item with id #{id_param}"
      redirect_to :controller=>'roster', :action => 'browse'
      return
    end

    @roster.start_date = start_date
    @roster.call_role = call_role
    @roster.call_assignment = call_assignment
    @roster.save!
    flash[:notice] = "Updated roster item"
    redirect_to  :controller=>'roster', :action => 'browse'
  rescue ActiveRecord::RecordInvalid
    render :action => :edit
  end

  def delete
    expected_post_not_get && return unless request.delete? || request.post?
    @roster.destroy
    flash[:notice] = "Assignment removed"
    redirect_back_or_to :controller => "roster", :action => "browse"
  end

  def delete_all
    expected_post_not_get && return unless request.delete? || request.post?
    Roster.destroy_all
    flash[:notice] = "All assignments removed"
    redirect_back_or_to :controller => "roster", :action => "browse"
  end

  def process_schedule
    expected_post_not_get && return unless request.post?
    @result = Roster.process_schedule
  end


  def ajax_get_names
    if request.xhr?
      if params['search_for'].strip.length > 2
        terms = params['search_for'].split.collect do |word|
          "%#{word.downcase}%"
        end
        users = @org.users.find(:all,
                                :conditions => [ ( ["(LOWER(name) LIKE ?)"] * terms.size ).join(" AND "),
                                                 * terms.flatten ] )
        groups = @org.groups.find(:all,
                                  :conditions => [ ( ["(LOWER(name) LIKE ?)"] * terms.size ).join(" AND "),
                                                   * terms.flatten ] )
        @all = Array.new
        users.each { |user| @all << user }
        groups.each { |group| @all << group }
        @all = @all.sort_by { |obj| obj.name.downcase }
      end
      @text_id = params['text_id']
      render :partial => "names", :locals => { :all => @all, :text_id => @text_id }
    else
      render :text => ""
    end
  end

  #######
  protected
  #######
  def init_item
    @roster = Roster.new()
    @roster.org = @org
  end

  def find_item
    @roster = Roster.find_by_id(id_param) || raise(ActiveRecord::RecordNotFound)
    raise(ActiveRecord::RecordNotFound) unless @roster.in_org?(@org)
  end

end
