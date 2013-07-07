# Be sure to restart your server when you modify this file

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.16' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
  # See Rails::Configuration for more options.

  # Skip frameworks you're not going to use. To use Rails without a database
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Specify gems that this application depends on. 
  # They can then be installed with "rake gems:install" on new installations.
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "aws-s3", :lib => "aws/s3"

  #config.gem 'mislav-will_paginate', :version => '~> 2.3.2', :lib => 'will_paginate', :source => 'http://gems.github.com'
  #config.gem 'clickatell', :source=>'git://github.com/lukeredpath/clickatell.git'
  #config.gem 'twilio-ruby'
  ##config.gem 'tropo-webapi-ruby' # not needed, only the restclient
  #config.gem 'rest-client'

  
  # Only load the plugins named here, in the order given. By default, all plugins 
  # in vendor/plugins are loaded in alphabetical order.
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Make Time.zone default to the specified zone, and make Active Record store time values
  # in the database in UTC, and return them converted to the specified local zone.
  # Run "rake -D time" for a list of tasks for finding time zone names. Uncomment to use default local time.
  config.time_zone = 'UTC'

  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random, 
  # no regular words or you'll be exposed to dictionary attacks.
  config.action_controller.session = {
    :session_key => '_lifeline_session',
    :secret      => '077fb50e7cd51d3b1ed271b50a49592dd9985946439b79050a448b47b24ae777a3b4db7d7490c7cfa4caeb9fc23915270157b573d83ffc4ce51e4618ecc82620'
  }

  # Use the database for sessions instead of the cookie-based default,
  # which shouldn't be used to store highly confidential information
  # (create the session table with "rake db:sessions:create")
  # config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  APP_VERSION = '0.6.8'

  DB_TRUE = 1
  DB_FALSE = 0
  
  MIN_USER_NAME_LEN = 3
  MAX_USER_NAME_LEN = 60

  MIN_PASSWORD_LEN = 6
  MAX_PASSWORD_LEN = 60
  
  MAX_FROM_LEN = 20
  MAX_MSG_LEN = 160
  MAX_MSG_PAYLOAD = MAX_MSG_LEN - MAX_FROM_LEN - 2 # max len less overhead for delimiting text and from fields
  TRUNCATE_MSG = "(more)"

  STATUS_FAILED = -1
  STATUS_PENDING = 0
  STATUS_DELIVERED = 1
  STATUS_PARTIAL = 2
  STATUS_UNKNOWN = 3 # status unknown due to gateway error

  USER_STATUS_DO_NOT_PAGE = 0
  USER_STATUS_ACTIVE = 1

  DEFAULT_MONITOR_MINUTES = 5
  DEFAULT_MONITOR_UNSENT_PAGES = 5
  DEFAULT_MONITOR_CHECK_IN_MINUTES = 5

  DEFAULT_CONVERSATION_TIMEOUT = 10
  FROM_SYSTEM_NAME = 'System'

  FORBIDDEN_NAMES = ['system']
  # add in standardized format

end

#-----------------------------------------------------------------------------
# CronTask
#
# RAILS_ENV=production /opt/local/bin/ruby /home/www/om/current/script/runner CronTask.delete_old_db_sessions
# RAILS_ENV=development ruby script/runner CronTask.send_alive_msg
#
#--
class Session < ActiveRecord::Base; end; 

class CronTask
  
  def self.log_task(msg)
    f = File.open(File.expand_path(File.dirname(__FILE__) + "/../log/task.log"), "a")
    f.puts(Time.now.strftime("%Y-%m-%d %H:%M:%S") + " CronTask " + msg)
    f.close
  end

  # clean out old sessions
  def self.delete_old_db_sessions
    begin
      Session.destroy_all(['updated_at <= ?', (Time.now.to_i - 1.day)])
      log_task("delete_old_db_sessions success")
    rescue Exception => exc
      log_task("delete_old_db_sessions FAILURE: #{exc.message}")
    end
  end

  def self.process_schedule
    begin
      results = Roster.process_schedule
      log_task("process_schedule : n=#{results.n_processed} errors=#{results.n_err}")
    rescue Exception => e
      log_task("process_schedule FAILURE: #{e.message}")
    end
  end

  def self.send_alive_msg
    begin
      # get all the administrators
      admins = User.find_all_by_admin_and_send_alive(DB_TRUE,true)
      Rails.logger.info "CRONTASK Sending alive msg to #{admins.count} admins"
      return if !admins or admins.length==0

      # create the system summary
      count_all = Outbound.count
      count_all_yesterday = Outbound.count(:conditions=>"DateDiff(NOW(),updated_at)<=1")
      count_all_this_week = Outbound.count(:conditions=>"DateDiff(NOW(),updated_at)<8")

      # Todo: improve the way in which we can tell when messages were delivered
      # refresh the status of all messages
      org = Org.find(:first)
      # todo: specify the default org for the system

      org.refresh_pending_msgs

      count_delivered_all = Outbound.count(:conditions=>"status=#{STATUS_DELIVERED}")
      count_delivered_yesterday = Outbound.count(:conditions=>"status=#{STATUS_DELIVERED} and DateDiff(NOW(),created_at)<2")
      count_delivered_this_week = Outbound.count(:conditions=>"status=#{STATUS_DELIVERED} and DateDiff(NOW(),created_at)<8")

      count_failed_all = Outbound.count(:conditions=>"status<>#{STATUS_DELIVERED} and DateDiff(NOW(),updated_at)<2")
      count_failed_yesterday = Outbound.count(:conditions=>"status<>#{STATUS_DELIVERED} and DateDiff(NOW(),created_at)<2")
      count_failed_this_week = Outbound.count(:conditions=>"status<>#{STATUS_DELIVERED} and DateDiff(NOW(),created_at)<8")

      # Refresh the status of all the messages
      text = "Good morning. Your OpenCellPager server is alive and has sent #{count_all} total pages, yesterday=#{count_all_yesterday},last week=#{count_all_this_week}, failed yesterday=#{count_failed_yesterday}"
              #"delivered=#{count_delivered_all},1d=#{count_delivered_yesterday},7d=#{count_delivered_this_week}, "+
              #"failed=#{count_failed_all},1d=#{count_failed_yesterday},7d=#{count_failed_this_week}. "+
              #"Send us your feedback if you are having problems!"

      # send messages to all the administrators that have phones
      # in the future might prefer email messages here
      msg = Msg.new
      msg.text = text[0..MAX_MSG_PAYLOAD]
      msg.from = "System Message"
      i = 0
      admins.each do |user|
        next if !user.phone
        msg.org = user.org
        msg.recipient = user
        msg.save!
        msg.send_pages
        i += 1
      end
      Rails.logger.info("CRONTASK send_alive_msg: sent to #{i} users")

    rescue Exception => e
      Rails.logger.info("CRONTASK send_alive_msg FAILURE: #{e.message}")
    end
  end

  def self.daily_tasks
    delete_old_db_sessions
    process_schedule
    send_alive_msg
  end
  
end

ExceptionNotifier.exception_recipients = %w(support@email.com)
ExceptionNotifier.sender_address = "from.support@email.com"
ExceptionNotifier.email_prefix = "[OCP]"

