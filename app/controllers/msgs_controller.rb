class MsgsController < ApplicationController
  layout 'application', :except => [:ajax_get_address]

  before_filter :find_msg, :except=>[:new, :create, :browse, :sweep, :address, :ajax_get_address, :refresh_all]
  before_filter :init_msg, :only=>[:new, :create]

  before_filter :require_user
  before_filter :require_admin, :only=>[:sweep, :browse, :refresh_all]

  def sweep
    @sweep_status = Msg.sweep
  end

  def browse
    #@org.refresh_pending_pages
    @msgs = @org.msgs.paginate(:all, :order => "updated_at desc", :page => params[:page], :per_page => 24)
  end

  def show
    @msg.refresh_status
  end

  def ajax_update_msg_status
    @msg.refresh_status
    render :partial=>'update_msg_status'
  end

  def refresh_all
    @org.refresh_pending_msgs
    flash[:notice] = "Refreshed!"
    redirect_to :controller=>'msgs', :action=>'browse', :back=>@back
  end

  def new
    @msg.from = get_from()
    @msg.from = @user.login_name if @msg.from.blank? && @user.registered?
  end

  def create
    expected_post_not_get && return unless request.post?
    @msg.attributes = (params[:msg])
    @recipient_name = params[:recipient_name]
    @msg.recipient = @org.find_recipient_by_name(@recipient_name)

    set_from(@msg.from)
    @msg.save!
    @msg.send_pages

    # we've just tried to send some pages
    # this could be a good time to check if we are sending messages successfully
    run_msg_monitor

    redirect_to :controller=>'msgs', :action => 'show', :id=>@msg, :back=>@back
  rescue ActiveRecord::RecordInvalid
    render :action => :new
  end

  def address
    #	@all = @org.recipients
  end

  def ajax_get_address
    if request.xhr?
      if params['search_for'].strip.length > 0
        @all = @org.find_users_or_groups_by_keywords(params['search_for'])
      end
      render :partial => "addresses", :object=>@all
    else
      redirect_to :controller => "public_controller", :action => :index
    end
  end

  #######
  protected
  #######

  def get_from()
    session[:from] || ""
  end

  def set_from(new_val)
    session[:from] = new_val
  end

  def find_msg
    @msg = Msg.find_by_id(id_param) || raise(ActiveRecord::RecordNotFound)
    raise(ActiveRecord::RecordNotFound) unless @msg.in_org?(@org)
  end

  def init_msg
    @msg = Msg.new_msg_for_org(@org)
  end

  def run_msg_monitor
    url = url_for(:controller=>:admin)
    panic_email_data = {:host => (request.env["HTTP_X_FORWARDED_HOST"] || request.env["HTTP_HOST"]),
                        :rails_root => Pathname.new(RAILS_ROOT).cleanpath.to_s,
                        :admin_url => url}
    @org.check_monitor_sending_messages(panic_email_data)
  end

end
