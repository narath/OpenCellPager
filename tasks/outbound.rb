#!/usr/bin/env ruby
require 'rubygems'
require 'active_record'
require 'yaml'

require 'serialport'
require 'rubygsm'

MAX_MSG_LEN = 160
USB_MODEM_STATUS_QUEUED = 0
USB_MODEM_STATUS_SENT = 1
USB_MODEM_STATUS_FAILED = -1

require File.join(File.dirname(__FILE__), "/outlog")
require File.join(File.dirname(__FILE__), "/outgsmlog")
require File.join(File.dirname(__FILE__), "/../app/models/outbound")

#require 'pp'

def config_filename
  return File.expand_path(File.join(File.dirname(__FILE__), "/../config/database.yml"))
end


def log_event(event, message)
  OutLogger.instance.log(event+" "+message)
end

#-----------------------------------------------------------------------------
# modem_receive method
# Note: this is called from the modem thread, so it is important that this be
# thread safe
#--
class Receiver
  def modem_receive(msg)
    begin
      begin
        # todo: test to see if log_event is thread safe
        log_event "modem_receive", "From #{msg.sender} at #{msg.sent}: #{msg.text}"
      rescue Exception => e
        log_event "modem_receive", "Exception #{e.inspect}"
      end
    rescue Exception => e
      # just ignore this one, probably error writing to the log file
    end
                   

  end
end


#-----------------------------------------------------------------------------
# init_modem
#--
def init_modem
  modem = nil # existential
  begin
    modem = Gsm::Modem.new('/dev/ttyS0', :error) # :error, :warn, :debug, :traffic
    log_event "init_modem", "modem instantiated"
  rescue Exception => exc
    log_event "Gsm::Modem", "error instantiating modem: #{exc.message}"
    if exc.message.blank? || (exc.message == 'SIGHUP') ||( exc.message == 'SIGTERM')
      log_event "init_modem", "Terminating"
      raise
    end
    delay = 10
    log_event "init_modem", "sleeping for #{delay} seconds"
    sleep(delay)
    # note a terminate signal can arrive here, and will not be caught but will escalate up
    retry
  end

  return modem
end

#-----------------------------------------------------------------------------
# init_db_connection
#--
def init_db_connection
  db_config_list = File.open( config_filename ) { |yf| YAML::load( yf ) }

  if db_config_list['production']
    db_config = db_config_list['production']
  else
    db_config = {
            :adapter => "mysql",
            :host  => "localhost",
            :username => "root",
            :password => "",
            :database => "ocp_development"
    }
  end

  ActiveRecord::Base.establish_connection(db_config)
  log_event "ActiveRecord::Base", "establish_connection to #{db_config[:database]}"
end

#-----------------------------------------------------------------------------
# is_recoverable
# some errors are recoverable - they just need the modem to wait until a valid state is available again
#--
def is_recoverable(e)
  (([512, 513, 515].member?(e.code)) or (e.kind_of?(Gsm::TimeoutError)))
end

#-----------------------------------------------------------------------------
# handle_outbound
#--
def handle_outbound(modem, outbound)

  phone = outbound.phone
  phone = '+' + phone if phone =~ /^[^0]/ # add a plus if the number doesn't look local (might not travel well)

  max_num_tries = 5
  num_tries = 0
  begin
    modem.send_sms!( Gsm::Outgoing.new(modem, phone, outbound.text))
    sleep 1
    outbound.status = USB_MODEM_STATUS_SENT
    outbound.status_string = "Message sent"
    log_event "handle_outbound", "sent message to #{phone}"
  rescue Gsm::Error => e
    if is_recoverable(e) and (num_tries<max_num_tries)
      log_event "handle_outbound", "Retry #{num_tries} after FAIL sending to #{phone} code: #{e.code} status: #{e.to_s}"
      num_tries = num_tries + 1
      sleep 2

      i_wait = 0
      i_max_wait = 5
      begin
        i_wait = i_wait + 1
        log_event "handle_outbound", "Waiting for network #{i_wait}"
        modem.wait_for_network
      rescue Gsm::Error, RuntimeError => wait_e
        if i_wait>=i_max_wait
          log_event "handle_outbound", "Could not wait for network anymore!"
          raise
        end
        sleep 2
        retry
      end
      # now the network should be available
      retry
    end
    # otherwise fail
    outbound.status = USB_MODEM_STATUS_FAILED # assume all errors fatal
    outbound.error_code = e.code
    outbound.status_string = e.to_s
    log_event "handle_outbound", "FAIL sending to #{phone} code: #{e.code} status: #{e.to_s}"
  end

  outbound.save
#pp outbound

end

#-----------------------------------------------------------------------------
# send_pending_outbounds
#--
def send_pending_outbounds(modem)
  Outbound.find(:all, :conditions => ["status=?", USB_MODEM_STATUS_QUEUED], :order=>"created_at").each { |outbound|
    handle_outbound(modem, outbound)
  }
end

#-----------------------------------------------------------------------------
# main
#--

log_event "main", "Outbound starting..."
begin
  # todo: could make receiving an option
  #rcv = Receiver.new
  modem = init_modem
  init_db_connection
  # modem.receive(rcv.method(:modem_receive))
  # at this time receiving is too volatile (it crashes with CME 515 errors)
  
  more = true
  while more
    begin
      sleep(2) #10
      send_pending_outbounds(modem)
      # log_event "handle_outbound","alive"
    rescue Exception => exc
      log_event "outbound loop", "Exception: #{exc.message}"
      if exc.message.blank? || (exc.message == 'SIGHUP') ||( exc.message == 'SIGTERM')
        log_event "outbound loop", "Terminating: #{exc.message}"
        more = false
      end
    end
  end
ensure
  log_event "main", "Outbound ended."
end




 