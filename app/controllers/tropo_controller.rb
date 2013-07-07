require 'tropo-webapi-ruby'

class TropoController < GatewayController

  # Process an SMS message request from Tropo
  def sms
    # receive message

    # Generate Tropo response
    @tropo = Tropo::Generator.new

    if params[:session] && params[:session][:parameters]
      values = params[:session][:parameters]
      request_token = values[:token]
      # todo: validate my application token

      # send message
      request_to = values[:to]
      request_msg = values[:msg]

      @tropo.call(:to => format_phone(request_to), :network => "SMS")
      @tropo.say(:value => request_msg)
    else
      # here we process particulars commands
      # in the future this will update a message response based on the number
      values = params[:session]
      text = values['initialText']
      phone = values['from']['id']
      # could confirm from SMS and is TEXT
      receive_time = values['timestamp']

      # here we handle this differently than than the traditional gateway since with tropo
      # we are in conversation mode
      @result = handle_received_msg("tropo",phone,text,receive_time)
    end

    tropo_message = @tropo.response

    respond_to do |format|
      format.html  { redirect_to root_path }
      format.json  { render :json => tropo_message }
    end
  end

  protected

  def format_phone(p)
    # todo: check the org config to determine if assuming north america
    # make sure has +1 ONLY if 9 numbers only (else already has area code)
    p = '+1'+p if p && p.length==10 && p[0..0]!='1'
    p = '+'+p if p && p[0..0]!='+'
    p
  end

  ##########
  # Override the default gateway controller to use tropos conversation mode

  def reply_to_sender(phone_number, msg)
    Rails.logger.debug('TropoController::reply_to_sender')
    #get_system_org.create_gateway!.send_raw(phone_number, msg)
    @tropo.say(msg)
  end

  def reply_to_user(user, msg)
    Rails.logger.debug('TropoController::reply_to_user')
    #user.org.send_msg(FROM_SYSTEM_NAME, user.name, msg)
    @tropo.say(msg)
  end


end
