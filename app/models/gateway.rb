require 'rubygems'

module Gateway

  #######
  # Gateway::Session
  #######
  class Session
    cattr_accessor :subclasses; self.subclasses = {}

    def self.inherited(klass)
      k_s = klass.to_s.gsub('Gateway::', '')
      super_s = self.to_s.gsub('Gateway::', '')

      key = k_s.gsub(Regexp.new(Regexp.new(super_s)), '').underscore.to_sym

      # self in this context is always Session
      self.subclasses[key] = klass
      Rails.logger.info "GATEWAY: registered #{k_s} as #{key}"
    end

    def self.create(type, config=nil)
      return self.subclasses[type.to_sym].new(process_config(config)) if self.subclasses[type.to_sym]
      raise "No such type #{type}"
    end

    # Subclasses should define this to give the user the default structure of expected options
    def self.default_config_str
      return ''
    end

    # Takes a (saved) outbound object - has phone and text
    # saves the sent_id, sent_at in the outbound object
    # Returns the outbound object
    # Throws Gateway::Error on failure
    # phone and msg are snapshotted - can subsequently change without accecting the outgoing sms
    def send_page(outbound)
      raise "Not implemented"
    end

    # Takes a msg_id cookie returned by a prior call to send_page
    # Returns a Gateway::Status object
    # Throws Gateway::Error on failure
    def check_page_status(sent_id)
      raise "Not implemented"
    end

    # Throws Gateway::Error on failure
    def balance
      raise "Not implemented"
    end

    protected

    # todo: refactor out - will save lots of constant setting
    def config_or_default(config,key,default)
      (config && config[key] ? config[key] : default)
    end

    # Note: key is a string key. The user will enter string key, the app settings will use a symbol
    # todo: consider refactoring so all app settings use string keys as well
    def config_or_app_settings(config,key,app)
      app_value = (app && app[key.to_sym] ? app[key.to_sym] : nil)
      config_or_default(config,key,app_value)
    end

    def check_config(field_name, val)
      raise "Invalid configuration - missing field: #{field_name}" if !val
      raise "Invalid configuration - missing field: #{field_name}" if val && val==""
    end

    def self.process_config(str)
      if str
        YAML.load(str)
      else
        nil
      end
    end

    def log_an_event(str_class, str_msg)
      Rails.logger.info("GATEWAY EVENT #{self.class} #{str_class}: #{str_msg}")
    end

    def log_an_error(str_class, str_msg)
      Rails.logger.error("GATEWAY ERROR #{self.class} #{str_class}: #{str_msg}")
    end

  end

#######
# Gateway::MessageStatus
#######
  class MessageStatus

    attr_reader :code, :message

    def initialize(code,msg)
      @code = code
      @message = msg
    end

    def state
    end
  end


#######
# Gateway::Error
#######
  class Error < StandardError

    attr_reader :code, :message

    def initialize (code, msg)
      @code = code
      @message = msg
    end
  end

############################################################################
# Gateway::TestSession
#######
  class TestSession < Session
    attr_accessor :events # an array of events in the test session

    def initialize(config)
      @events = []
      log_an_event "TestSession", "Created config=#{config}"
    end

    def self.log(msg)
      log_an_event "TestSession", msg
    end

    # The test gateway is simple, it usually just succeeds, unless you use special messages
    # fail: fails
    # error: throws a gateway error
    def send_page(outbound)
      begin
        # the page needs to have an id
        outbound.status = STATUS_PENDING
        outbound.save!

        case outbound.text
          when /fail/i
            outbound.status = STATUS_FAILED
            outbound.save!
          when /error(.*)/i
            raise Error.new(00, $1)
          else
            # succeed by default
            outbound.status = STATUS_DELIVERED
            outbound.sent_id = 999
            outbound.sent_at = Time.zone.now
            outbound.save!
        end
      rescue Error => e
        log_an_error "TestSession.send_page", "Error #{e.inspect}"
        # try to save it to the outbound message
        outbound.status = STATUS_FAILED
        outbound.status_string = "Error:#{e.message} (#{e.code})"
        outbound.save
        raise
      end
      @events.push(["send_page", outbound])
      return outbound
    end

    # Takes a single message id returned by previous call to send_message
    # Returns a Gateway::Status object
    # Throws Gateway::Error on failure
    def check_page_status (sent_id)
      # since this is automatically updated with a server call, this just returns the page status
      ob = Outbound.find_by_sent_id(sent_id)
      return ob ? MessageStatus.new(ob.status, ob.status_string) : nil
    end

    # designed to allow the receiving system to send back messages
    # to the number which has paged it (which does not have a user)
    def send_raw(to, msg, dlr_url='')
      log_an_event("Gateway::TestSession", "send raw #{[to, msg, dlr_url].join(' ')} ")
      @events.push(["send_raw", {:to=>to, :msg=>msg, :dlr_url=>dlr_url}])

      wait_for_response = false
      status = "sent"
      status_string = "TestSession"
      [wait_for_response, status, status_string]
    end

    def balance
      -1
    end
  end

######## ############################################################################
# Gateway::ClickatellSession
#######
  require 'clickatell'

  class ClickatellSession < Session
    attr_reader :username,:password, :api_id, :api

    def initialize (config)
      @api = nil
      @api_id = config_or_default(config,'api_id',CLICKATELL_API_ID)
      @username = config_or_default(config,'username',CLICKATELL_USERNAME)
      @password = config_or_default(config,'password',CLICKATELL_PASSWORD)
      @from = config_or_default(config,'from',CLICKATELL_FROM)

      check_config 'api_id',@api_id
      check_config 'username', @username
      check_config 'password', @password
    end

    def self.default_config_str
      <<-END
# all optional: specify values here if you want to override the system defaults
password: Your password
username: Your username
api_id: Your api id
      END
    end

    def send_page(outbound)
      check_api
      begin
        options = {}
        options[:from] = @from if @from && (@from!='')

        log_an_event "Clickatell.send_page:","#{outbound.phone} #{outbound.text} #{options.inspect}"

        message_id = @api.send_message(outbound.phone, outbound.text,options)
        outbound.sent_id = message_id
        outbound.sent_at = Time.zone.now
        outbound.save
        log_an_event("Clickatell.send_page", "message_id: #{message_id.inspect}")
        return message_id
      rescue Clickatell::API::Error => e
        log_an_error "Clickatell.send_page", "Error code #{e.code}: #{e.message}"
        raise Gateway::Error.new(e.code, e.message)
      end
    end


    # Takes a single message id returned by previous call to send_message
    # Returns a Gateway::Status object
    # Throws Gateway::Error on failure
    def check_page_status (msg_id)
      check_api
      begin
        status_code = @api.message_status(msg_id)
        log_an_event("Clickatell.check_page_status", "msg_id=#{msg_id} status_code: #{status_code}")
        return status_code.nil? ? nil : Gateway::ClickatellMessageStatus.new(status_code)
      rescue Clickatell::API::Error => e
        log_an_error "Clickatell.check_page_status", "Error code #{e.code}: #{e.message}"
        raise Gateway::Error.new(e.code, e.message)
      end
    end

    # Throws Gateway::Error on failure
    def balance
      check_api
      begin
        bal = @api.account_balance
        log_an_event("Clickatell.balance", "account_balance: #{bal}")
        return bal
      rescue Clickatell::API::Error => e
        log_an_error "Clickatell.balance", "Error code #{e.code}: #{e.message}"
        raise Gateway::Error.new(e.code, e.message)
      end
    end

  protected
    # authenticates to the api, and returns the api if not already created
    def check_api
      return @api if @api
      begin
        log_an_event "ClickatellSession","authenticating"
        @api = Clickatell::API.authenticate(@api_id, @username, @password)
        log_an_event "ClickatellSession","authenticated"
      rescue Clickatell::API::Error => e
        log_an_error "ClickatellSession", "Error initializing - code #{e.code}: #{e.message}"
        raise Gateway::Error.new(e.code, e.message)
      end
      return @api
    end
  end


#######
# Gateway::ClickatellMessageStatus
#######
  class ClickatellMessageStatus < MessageStatus

    PENDING_CODES = [1, 2, 3, 8, 11]
    # note: 1 is actually an error or unknown but these are all going thru in tanzania, so just added to pending again
    FAILED_CODES = [5, 6, 7, 9, 10, 12]
    SUCCESS_CODES = [4]

    def initialize (code)
      @code = code
      s_code = ''
      s_code = sprintf('%.3d',code) if code
      @message = "#{Clickatell::API::MessageStatus[s_code]} (#{code})"
    end

    def state
      return SUCCESS_CODES.include?(@code) ? STATUS_DELIVERED :
          PENDING_CODES.include?(@code) ? STATUS_PENDING :
              STATUS_FAILED;
    end
  end


############################################################################
  require 'open-uri'
  class KannelSession < Session
    attr_reader :server, :port, :username, :password, :dlr_mask, :dlr_url,
                :receive_url, :admin_port

    def initialize (config)
      @server = config_or_default(config,"server", KANNEL_CONFIG_SERVER)
      @port = config_or_default(config,"port", KANNEL_CONFIG_PORT)
      @username = config_or_default(config,"username", KANNEL_CONFIG_USERNAME)
      @password = config_or_default(config,"password", KANNEL_CONFIG_PASSWORD)
      @dlr_mask = config_or_default(config,"dlr_mask", KANNEL_CONFIG_DLR_MASK)
      @dlr_url = config_or_default(config,"dlr_url", KANNEL_CONFIG_DLR_URL)
      @receive_url = config_or_default(config,"receive_url", KANNEL_CONFIG_RECEIVE_URL)
      @admin_port = config_or_default(config,"admin_port", KANNEL_CONFIG_ADMIN_PORT)

      check_config "server", @server
      check_config "port", @port
      check_config "username", @username
      check_config "password", @password
      check_config "dlr_mask", @dlr_mask
      check_config "dlr_url", @dlr_url if @dlr_mask && @dlr_mask.to_i>0
      check_config "receive-url", @receive_url
      # admin port is optional
    end

    def self.default_config_str
      <<-END
#optional: use these to override the system default settings
server: http://10.10.10.10
port: 12000
#admin_port
username: username
password: password
dlr_url: dlr_url
dlr_mask: 31
receive_url: rcv
      END
    end

    def send_page(outbound)
      begin
        log_an_event("send_page","#{outbound.phone} #{outbound.text}")

        # needs to have an id
        outbound.status = STATUS_PENDING
        outbound.save!

        to = outbound.phone
        msg = outbound.text
        dlr_url = "#{@dlr_url}?id=#{outbound.id}&status=%d&answer=%A"

        waiting_for, gateway_status, gateway_string = send_raw(to, msg, dlr_url)
        outbound.status = gateway_status
        outbound.status_string = gateway_string
        outbound.sent_id = outbound.id
        outbound.sent_at = Time.zone.now
        outbound.save!

        return outbound.sent_id
      rescue Error => e
        log_an_error "KannelSession.send_page", "Error #{e.inspect}"
        raise
      end
    end

    # Takes a single message id returned by previous call to send_message
    # Returns a Gateway::Status object
    # Throws Gateway::Error on failure
    def check_page_status (msg_id)
      # since this is automatically updated with a server call, this just returns the page status
      out = Outbound.find_by_id(msg_id)
      return out ? KannelMessageStatus.new(out.status, out.status_string) : nil
    end

    # currently only supported by this gateway to allow for the receiving of messages
    # returns waiting_for_response, gateway_status, gateway_string
    def send_raw(to, msg, dlr_url='')
      raise "To should not be a user in send_raw" if to.instance_of?(User)

      log_an_event("send_raw","#{to} #{msg} #{dlr_url}")

      gateway_status = nil
      gateway_string = nil

      # could limit message here
      # msg = msg[0..MSG_MAX_LEN]

      # todo: ensure the page has valid characters
      # todo: ensure the to is only numbers
      url = "http://#{@server}:#{@port}/cgi-bin/sendsms?"+
          "username=#{@username}&password=#{@password}"
      wait_for_response = false
      if (@dlr_mask && @dlr_mask.to_i>0 && @dlr_url && dlr_url)
        url = url + "&dlr-mask=#{@dlr_mask}&dlr-url=#{URI::escape(dlr_url)}"
        wait_for_response = true
      end
      url = url + "&to=#{URI::escape(to)}&text=#{URI::escape(msg)}"
      log_an_event "send_raw url", url
      open(url) do |f|
        # status will give us a message
        # read the status as well

        # it could fail here
        # but it cannot succeed immediately since this is just queued
        # from Kannel user guide, return codes are:
        #200: 0: Accepted for delivery
        #202: 0: Accepted for delivery
        #The message has been accepted and is delivered onward to a SMSC driver.
        #Note that this status does not ensure that the intended recipient receives the message.
        #202	3: Queued for later delivery
        #4xx	(varies)
        #503	Temporal failure, try again later.
        # it returns an array ["202","Accepted"]
        f_status_code = f.status
        f_status_code = f.status[0] if f.status.is_a?(Array)
        if not ["200", "202"].member?(f.status[0])
          gateway_status = STATUS_FAILED
          gateway_string = f.status.to_s
          log_an_error("send_raw", "FAILED to send #{url}\n#{f.status.inspect}")
        else
          gateway_string = f.read

          # 2 modes for the kannel server
          # either we wait for a delivery receipt, or we just send it to the server and assume this has been sent
          if wait_for_response
            gateway_status = STATUS_PENDING
          else
            gateway_status = STATUS_DELIVERED
          end
          log_an_event("send_page", "SUCCESS #{url} #{gateway_string}")
        end
      end
      [wait_for_response, gateway_status, gateway_string]
    end

    def balance
      -1
    end
  end

#######
# Gateway::KannelMessageStatus
#######
  class KannelMessageStatus < MessageStatus
    def initialize (code, status_string)
      @code = code
      @message = status_string
    end

    def state
      return @code
    end
  end

############################################################################
  require 'rest-client'

  class TropoSession < Session
    def initialize (config)
      @token = config_or_app_settings(config,'token',APP_SETTINGS[:tropo])
      @assume_north_america = config_or_app_settings(config,'assume_north_america',APP_SETTINGS[:tropo])

      check_config('token',@token)
      # optional: assume_north_america
    end

    def send_page(outbound)
      begin
        # the outbound.needs to have an id
        outbound.status = STATUS_PENDING
        outbound.save!

        msg = outbound.text
        gateway_status, gateway_string = send_raw(outbound.phone, msg)
        outbound.status = gateway_status
        outbound.status_string = gateway_string
        outbound.sent_id = outbound.id
        outbound.sent_at = Time.zone.now
        outbound.save!

        return outbound.id
      rescue Error => e
        log_an_error "TropoSession.send_page", "Error #{e.inspect}"
        raise
      end
    end

    # Takes a single message id returned by previous call to send_message
    # Returns a Gateway::Status object
    # Throws Gateway::Error on failure
    def check_page_status (msg_id)
      # since this is automatically updated with a server call, this just returns the page status
      ob = Outbound.find_by_id(msg_id)
      return ob ? TropoMessageStatus.new(ob.status, ob.status_string) : nil
    end

    # returns waiting_for_response, gateway_status, gateway_string
    def send_raw(to, msg)
      raise "To should not be a user in send_raw" if to.instance_of?(User)

      gateway_status = nil
      gateway_string = nil

      # could limit message here
      # msg = msg[0..MSG_MAX_LEN]

      # todo: ensure the page has valid characters
      # todo: ensure the to is only numbers

      # set up a client to talk to the Tropo REST API
      # todo.optimize: might be worth caching this, or at least profiling
      # send an sms
      phone = format_phone(to)
      result = RestClient.get('https://api.tropo.com/1.0/sessions',
                              {:params => {
                                  :action => 'create',
                                  :token => @token,
                                  :to => to,
                                  :msg => msg}
                              }
      )
      Rails.logger.debug("#{result.inspect}")

      # todo: standard message format when sent from page
      # todo: review how Tropo returns sms send information

      gateway_status = STATUS_PENDING
      [false, gateway_status, gateway_string]
    end

    # Throws Gateway::Error on failure
    def balance
      # can probably get this using the rest client
      -1
    end

    protected

    def format_phone(phone)
      if @assume_north_america
        phone = '1' + phone if phone && phone.length==9 && phone[0..0]!='1'
      end
      phone
    end
  end


#######
  class TropoMessageStatus < MessageStatus
    def initialize (code, status_string)
      @code = code
      @message = status_string
    end

    def state
      return @code
    end
  end

# NOT ACTIVELY SUPPORTED NOW

############################################################################
#  require 'twilio-ruby'
#
#  TWILIO_TIMEOUT = 'twilio-timeout'
#  TWILIO_DEFAULT_TIMEOUT = 3 # in seconds
#
#  class TwilioSession < Session
#    def initialize (org)
#      @org = org
#      @config = get_config(@org)
#    end
#
#    # Takes single mobile number (string) & message string
#    # Returns a message id on success, which can be used with check_page_status
#    # Throws Gateway::Error on failure
#    def send_page(page)
#      begin
#        # the page needs to have an id
#        page.status = STATUS_PENDING
#        page.save!
#
#        msg = "#{page.msg.from} #{page.msg.text}"
#        gateway_status, gateway_string = send_raw(page.user.phone, msg)
#        page.status = gateway_status
#        page.gateway_status_string = gateway_string
#        page.gateway_uid = page.id
#        page.save!
#
#        return page.id
#      rescue Error => e
#        log_an_error "send_page", "Error #{e.inspect}"
#        raise
#      end
#    end
#
#    # Takes a single message id returned by previous call to send_message
#    # Returns a Gateway::Status object
#    # Throws Gateway::Error on failure
#    def check_page_status (msg_id)
#      # since this is automatically updated with a server call, this just returns the page status
#      p = Page.find_by_id(msg_id)
#      return p ? TwilioMessageStatus.new(p.status, p.gateway_status_string) : nil
#    end
#
#    # returns waiting_for_response, gateway_status, gateway_string
#    def send_raw(to, msg, dlr_url='')
#      raise "To should not be a user in send_raw" if to.instance_of?(User)
#
#      gateway_status = nil
#      gateway_string = nil
#
#      # could limit message here
#      # msg = msg[0..MSG_MAX_LEN]
#
#      # toodo: ensure the page has valid characters
#      # toodo: ensure the to is only numbers
#
#      # set up a client to talk to the Twilio REST API
#      # toodo.optimize: might be worth caching this, or at least profiling
#      client = Twilio::REST::Client.new @config[:account_sid], @config[:auth_token]
#
#      # send an sms
#      result = client.account.sms.messages.create(
#          :from => @config[:from_number],
#          :to => to,
#          :body => msg,
#          :timeout => @config[:timeout],
#          :status_callback => @config[:receive_url]
#      )
#      Rails.logger.debug("#{result.inspect}")
#
#      # toodo: standard message format when sent from page
#      # toodo: review how twilio returns sms send information
#
#      gateway_status = STATUS_PENDING
#      [false, gateway_status, gateway_string]
#    end
#
#    # Throws Gateway::Error on failure
#    def balance
#      # can probably get this using the rest client
#      return 0
#    end
#
#    protected
#    # Standard twilio options would be
#    # twilio-from-number=161755511,
#    # twilio-account-sid=233123123123,
#    # twilio-auth-token=1231312312,
#    # twilio-receive-url=https://www.yoursite.com/twilio
#    # optional
#    # twilio-timeout=3
#    def get_config(org)
#      result = {}
#      opts = extract_options(org.gateway_config)
#      if !(result[:from_number] = opts["twilio-from-number"])
#        raise "No twilio-from-number specified"
#      end
#      if !(result[:account_sid] = opts["twilio-account-sid"])
#        raise "No twilio-account-sid specified"
#      end
#      if !(result[:auth_token] = opts["twilio-auth-token"])
#        raise "No twilio-auth-token specified"
#      end
#      if !(result[:receive_url] = opts["twilio-receive-url"])
#        raise "No twilio-receive-url specified"
#      end
#      result[:timeout] = (opts[TWILIO_TIMEOUT] ? opts[TWILIO_TIMEOUT] : TWILIO_DEFAULT_TIMEOUT)
#      result
#    end
#  end
#
#
########
#  class TwilioMessageStatus < MessageStatus
#    def initialize (code, status_string)
#      @code = code
#      @message = status_string
#    end
#
#    def state
#      return @code
#    end
#  end



####################################################################################
# Gateway::UsbModemSession
#######
#  USB_MODEM_STATUS_QUEUED = 0
#  USB_MODEM_STATUS_SENT = 1
#  USB_MODEM_STATUS_FAILED = -1
#
#  class UsbModemSession < Session
#
#    def initialize (config)
#      log_an_event("UsbModem initialize", "stub")
#    end
#
#
#    # Takes single mobile number (string) & message string
#    # Returns a message id on success, which can be used with check_page_status
#    # Throws Gateway::Error on failure
#    def send_page(page)
#      outbound = Outbound.new()
#      outbound.phone = page.user.phone
#      outbound.text = page.msg.text
#      outbound.status = USB_MODEM_STATUS_QUEUED
#      outbound.error_code = 0
#      outbound.status_string = 'Queued on server'
#      outbound.page = page # this is so the outbound record can be destroyed if page is destroyed
#      outbound.save!
#      log_an_event("UsbModem send_page", "queued message for phone: #{outbound.phone} outbound id: #{outbound.id}")
#      return outbound.id
#    end
#
#
#    # Takes a single message id returned by previous call to send_page
#    # Returns a Gateway::Status object
#    # Throws Gateway::Error on failure
#    def check_page_status (msg_id)
#
#      outbound = Outbound.find_by_id(msg_id)
#
#      if outbound
#        log_an_event("UsbModem check_page_status", "check status outbound id: #{outbound.id} phone: #{outbound.phone} status: #{outbound.id}")
#        return Gateway::UsbModemMessageStatus.new(outbound.status, outbound.status_string)
#      else
#        log_an_event("UsbModem check_page_status", "outbound record not found with id: #{msg_id}")
#        return Gateway::UsbModemMessageStatus.new(USB_MODEM_STATUS_FAILED, "outbound page record not found")
#      end
#
#    end
#
#    # Throws Gateway::Error on failure
#    def balance
#      return 0 # is there a way to find this from usb modem api?
#    end
#
#  end
#
#
########
## Gateway::UsbModemMessageStatus
########
#  class UsbModemMessageStatus < MessageStatus
#
#    PENDING_CODES = [USB_MODEM_STATUS_QUEUED]
#    FAILED_CODES = [USB_MODEM_STATUS_FAILED]
#    SUCCESS_CODES = [USB_MODEM_STATUS_SENT]
#
#    def initialize (code, status_string)
#      @code = code
#      @message = status_string
#    end
#
#    def state
#      return SUCCESS_CODES.include?(@code) ? STATUS_DELIVERED :
#          PENDING_CODES.include?(@code) ? STATUS_PENDING :
#              STATUS_FAILED;
#    end
#  end




end
