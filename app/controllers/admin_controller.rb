require 'net/http'

class AdminController < ApplicationController

  layout 'application'

  before_filter :require_admin

  def index
    @header = 'Admin'
  end

  def show_usage
    @header = 'Disk Usage'
    @lines = `df -h`
    render(:template => "admin/show_lines")
  end

  def show_rails_log
    @header = 'Rails Log'

    case ENV['RAILS_ENV']
      when 'development'
        @lines = `tail -200 log/development.log`
      when 'production'
        @lines = `tail -200 log/production.log`
      else
        @lines = "not defined for this environment"
    end

    render(:template => "admin/show_lines")
  end

  def show_event_log
    @header = 'Event Log'
    @lines = `tail -200 log/event.log`
    render(:template => "admin/show_lines")
  end


  # sudo tail -f /tmp/kannel.log /tmp/smsbox.log /tmp/modem.log /tmp/access.log
  def show_kannel_log
    @header = 'Kannel Log'
    @lines = `tail -200 log/kannel.log`
    render(:template => "admin/show_lines")
  end

  def show_modem_log
    @header = 'Modem Log'
    @lines = `tail -200 log/modem.log`
    render(:template => "admin/show_lines")
  end

  def show_smsbox_log
    @header = 'SmsBox Log'
    @lines = `tail -200 log/smsbox.log`
    render(:template => "admin/show_lines")
  end

  def kannel_admin
        @header = 'Kannel Admin'
  end

  def kannel_cmd
    # since the kannel specification is to be called from the local server
    # we need to take care of getting the data ourselves

    #todo: this should just create a kannel backend

    gateway = @org.create_gateway!
    if gateway.class!=Gateway::KannelSession
      flash[:error] = "The gateway of this system is not a Kannel gateway so no kannel commands are available!"
      redirect_to :action=>'kannel_admin'
      return
    end

    @cmd = params["cmd"]
    @kannel_url = "http://#{gateway.kannel_server}:#{gateway.kannel_admin_port}"
    @kannel_response = nil
    if @cmd=="restart"
      @kannel_response = Net::HTTP.get_response(gateway.kannel_server, "/restart?password=#{gateway.kannel_password}", gateway.kannel_admin_port)
    elsif @cmd=="status"
      @kannel_response = Net::HTTP.get_response(gateway.kannel_server, "/status", gateway.kannel_admin_port)
    else
      raise "Unknown command #{@cmd}"
    end

    @header = "Kannel Cmd #{@cmd}"

    # seems reasonable to show the kannel log at this stage too
    @lines = `tail -200 log/kannel.log`
  end


end
