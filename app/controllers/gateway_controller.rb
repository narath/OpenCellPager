class GatewayController < ApplicationController

  protected

  REPLY_PHONE_NOT_REGISTERED = 'Sorry, your phone is not registered. To register, call the hospital operator.'
  REPLY_PHONE_NOT_VALIDATED = 'Sorry, your phone has not been validated. To register this phone to your account, send register username:password, and you will receive a validation code.'
  REPLY_SEND_UNEXPECTED_FORMAT = 'Invalid send command. The format is send <name>: <msg> e.g. send John Smith: important message. You can use their username or their full name. Use lookup <name> to look someone up'
  REPLY_SEND_TO_USERS_NOT_FOUND = 'Could not find the following names: %s. Use lookup <name> to find the correct address'

  REPLY_LOOKUP_UNEXPECTED_FORMAT = 'Invalid lookup command. The format is lookup <keywords>'

  REPLY_ERROR_INVALID_PASSWORD = 'Invalid password. This attempt has been logged!'

  REPLY_REGISTER_UNEXPECTED_FORMAT = 'Invalid register command. The format is register <username>:<password>'
  REPLY_REGISTER_UNKNOWN_LOGIN_NAME = 'You appear to be trying to register a new account in the system. In order to do so, please go and see the operator so they can verify your identity, and activate your phone.'
  REPLY_REGISTER_NOW_VALIDATE_PHONE = 'In order to make sure I can reach you, I am sending a verification code. Just text it back to me. Your code is %s'

  REPLY_VERIFY_INVALID = 'Sorry, a verification code should be a number'
  REPLY_VERIFY_SUCCESS = 'Great %s, this phone has been registered! Happy paging.'
  REPLY_VERIFY_WRONG_CODE = 'Sorry, that code was not correct for that phone number'
  REPLY_VERIFY_DO_NOT_RECOGNIZE_PHONE_AND_CODE = 'Sorry, I do not recognize this phone number or code. I am unable to verify your registration.'

  REPLY_CONVERSATION_MUST_ADDRESS = '%s have all sent you messages. Please use send user:msg to reply to the correct person.'

  REPLY_REMOVE_UNEXPECTED_FORMAT = 'Invalid remove command. The format is remove <username>:<password>'
  REPLY_ERROR_UNKNOWN_LOGIN_NAME = 'Invalid login name.'
  REPLY_REMOVED_SUCCESSFULLY = 'This phone has been removed successfully. To reactivate this phone, just use register username:password.'

  REPLY_JOIN_UNEXPECTED_FORMAT = 'Invalid join command. The format is join <groupname>'
  REPLY_JOINED_SUCCESSFULLY = 'Welcome to the %s group. To leave the group, just text "leave %s"' # Group.name, Group.short_name
  REPLY_JOIN_GROUP_NOT_FOUND = 'Sorry, there is no group called %s'
  REPLY_JOIN_MULTIPLE_GROUPS = 'There were multiple groups with a similar name, please be more specific or use the (short_name). Groups: %s'
  REPLY_JOIN_ALREADY_A_MEMBER = 'You are already a member of the group %s'

  REPLY_LEAVE_UNEXPECTED_FORMAT = 'Invalid leave command. The format is leave <groupname>'
  REPLY_LEFT_SUCCESSFULLY = 'You successfully left the %s group. To join again, just text "join %s"' # Group.name, Group.short_name
  REPLY_LEAVE_MULTIPLE_GROUPS = 'There were multiple groups with a similar name, please be more specific or use the (short_name). Groups: %s'
  REPLY_LEAVE_NOT_A_MEMBER = 'You are not a member of the group %s'

  REPLY_YOUR_GROUP_LIST = '%d groups:%s'

  REPLY_HELP = "Commands available:\n"+
      "send user_or_group: your message\n"+
      "lookup keyword\n"+
      "register username:password (register your phone)\n"+
      "remove username:password"

  REPLY_MSG_SENT = "Msg sent to %d users/groups"

  ERR_MSG = "There were errors!\n"

  def handle_received_msg(gateway_name, phone, text, receive_time)
    log_event("receive", "#{gateway_name} #{receive_time} #{phone} #{text})")

    phone = User.clean_phone(phone) if phone
    return ERR_MSG + 'No phone number specified' if !phone
    return ERR_MSG + 'Blank text, nothing to do' if !text || text.strip==''

    result = ''
    error = false

    # todo: catch an exceptions, send user a generic error message
    # and send the other one through exception notifier

    case
      when text =~ /error/i
        log_event("receive", "Error message!")
        # possible error messages:
        # 16175551111 Error Invalid Number. (if a land line)
        result = "Error message possibly from SMS provider"
      when text =~ /cmd_time_msg/im
        # cmd_time_msg is a msg with only this in the body
        # it always just finds the last msg with this command and adds the difference to the msg text
        begin
          dt_received = DateTime.now
          msg = Msg.find_by_text('cmd_time_msg', :last)
          if msg
            dt_sent = msg.created_at.to_datetime
            dt_diff_sec = (dt_received - dt_sent)*60*60*24
            # add this to the message
            msg.text = msg.text + " #{dt_received.to_s} sec=#{dt_diff_sec.to_i}"
            msg.save!
            result = "Received cmd_time_msg : #{msg.text}"
          end
        rescue Exception => ex
          log_event("receive", "Exception #{ex.message}")
          raise
        end
      when text =~ /^\s*send(.*)/im
        result, error = process_send(gateway_name, phone, $1.strip)
      when text =~ /^\s*lookup(.*)/im
        result, error = process_lookup(gateway_name, phone, $1.strip)
      when (text =~ /^\s*register(.*)/im) || (text =~ /^\s*change(.*)/im)
        result, error = process_register(gateway_name, phone, $1.strip)
      when text =~ /^\s*remove(.*)/im
        result, error = process_remove(gateway_name, phone, $1.strip)
      when text =~ /^\s*help(.*)/im
        result, error = process_help(gateway_name, phone, $1.strip)
      when text =~/^\s*join(.*)/im
        result, error = process_join(gateway_name, phone, $1.strip)
      when text =~/^\s*leave(.*)/im
        result, error = process_leave(gateway_name, phone, $1.strip)
      when text =~/^\s*groups(.*)/im
        result, error = process_groups(gateway_name, phone, $1.strip)
      else
        result, error = process_conversation(gateway_name, phone, text)
    end
    result = ERR_MSG + result if error
    result
  end

  def process_send(gateway_name, phone, send_body)
    return_error = true
    return_no_error = false

    if !send_body || send_body==""
      return reply_to_sender_with_error(phone, REPLY_SEND_UNEXPECTED_FORMAT)
    end

    if !(send_body =~ /(.*?):(.*)/)
        return reply_to_sender_with_error(phone, REPLY_SEND_UNEXPECTED_FORMAT)
    end

    send_to = $1
    send_msg = $2

    # todo: handle multiple users registered to the same phone
    if !(from_user = is_sender_registered?(phone))
      return reply_to_sender_with_error(phone, REPLY_PHONE_NOT_REGISTERED)
    end

    # must be validated to send
    if (!from_user.sms_validated?)
      return reply_to_sender_with_error(phone, REPLY_PHONE_NOT_VALIDATED)
    end

    if !send_to
      result = REPLY_SEND_UNEXPECTED_FORMAT
      result = reply_to_user(from_user, result)
      return result, return_error
    end

    # support sending to multiple users, when comma seperated
    to_user_names = send_to.strip.split(',')

    send_to_users = []
    names_not_found = []
    to_user_names.each do |name|
      send_to_user = from_user.org.find_recipient_by_name(name)
      if send_to_user
        send_to_users << send_to_user
      else
        names_not_found << name if !send_to_user
      end
    end

    if names_not_found.length>0
      result = sprintf(REPLY_SEND_TO_USERS_NOT_FOUND, names_not_found.join(','))
      reply_to_user(from_user, result)
      return result, return_error
    end

    send_msg.strip! if send_msg
    did_truncate = OCP::is_msg_too_long?(send_msg)

    # todo: can check for invalid words here

    send_to_users.each do |send_to|
      msg = safe_send_msg(from_user.org,from_user,send_to, send_msg)
    end

    # only necessary to send a reply confirmation if the user was not in one of the groups/user list
    user_is_a_recipient = send_to_users.detect() do |user_or_group|
      case
        when user_or_group.instance_of?(User)
          from_user.id == user_or_group.id
        when user_or_group.instance_of?(Group)
          user_or_group.users.find_by_id(from_user.id)
        else
          Rails.logger.error "Unexpected send_to: not user or group in process_send\n#{user_or_group.inspect}"
          false
      end
    end

    result = sprintf(REPLY_MSG_SENT, send_to_users.length)
    result += " TRUNCATED" if did_truncate

    reply_to_user(from_user, result) if !user_is_a_recipient
    result += ' '+(!user_is_a_recipient ? "CONFIRMATION SENT" : "Unconfirmed since sender one of the recipients")

    return result, return_no_error
  end

  MAX_LOOKUP_SIZE = 140

  def process_lookup(gateway_name, phone, lookup_body)
    lookup_body.strip!
    if lookup_body==""
      return reply_to_sender_with_error(phone, REPLY_LOOKUP_UNEXPECTED_FORMAT)
    end

    if !(from_user = is_sender_registered?(phone))
      return reply_to_sender_with_error(phone, REPLY_PHONE_NOT_REGISTERED)
    end

    opts = nil # = default = search all
    if lookup_body=~/^\s*user[s]*\s(.*)/
      opts = [:users]
      lookup_body = $1
    elsif lookup_body=~/^\s*group[s]*\s(.*)/
      opts = [:groups]
      lookup_body = $1
    end

    # todo: consider allowing lookup groups to search for anything

    if lookup_body==""
      return reply_to_sender_with_error(phone, REPLY_LOOKUP_UNEXPECTED_FORMAT)
    end

    all = from_user.org.find_users_or_groups_by_keywords(lookup_body, opts)
    all_names = all.collect { |item| (item.instance_of?(Group) ? "#{item.name} (#{item.short_name})" : "#{item.name} (#{item.login_name})") }.sort.join(",")

    send_msg = "#{all.count} results\n#{all_names[0..MAX_LOOKUP_SIZE]}"

    reply_to_user(from_user, send_msg)

    return send_msg, false
  end


  def process_register(gateway_name, phone, register_body)
    register_body.strip!
    if register_body==""
      return reply_to_sender_with_error(phone, REPLY_REGISTER_UNEXPECTED_FORMAT)
    end

    if !(register_body=~/(.*?):(.*)/im)
      return reply_to_sender_with_error(phone, REPLY_REGISTER_UNEXPECTED_FORMAT)
    end

    from_login_name = $1
    from_msg = $2

    # may support override in the future = override confirmation
    #override = false
    #if from_msg=~/(.*)\s+override/
    #  from_password = $1
    #  override = true
    #else
    #  from_password = from_msg
    #end

    if !(from_user = get_system_org.users.find_by_login_name(from_login_name))
      return reply_to_sender_with_error(phone, REPLY_REGISTER_UNKNOWN_LOGIN_NAME)
    end

    if !(from_user.valid_password?(from_msg.strip))
      log_event("SECURITY", "Invalid PASSWORD for user #{from_user.id} #{from_user.login_name}")
      # todo.security : lockout the user after a certain number of failed password attempts
      return reply_to_sender_with_error(phone, REPLY_ERROR_INVALID_PASSWORD)
    end

    # now need to verify that I can reach this number
    # by sending a validation code
    # necessary because we might not be able to connect to all of the networks

    from_user.phone = phone
    # this will reset the sms_validation
    from_user.reset_sms_validation!("Okay #{from_user.login_name[0..MAX_FROM_LEN-1]}. " +REPLY_REGISTER_NOW_VALIDATE_PHONE)
    from_user.save!
    logger.debug("Register: send verification #{from_user.inspect}")
    # we do not reset sms_validated - since the old phone might still be valid
    return "Sent validation code to user #{from_user.name}", false
  end

  # Conversations are implicit responses to previous messages
  # Conversations with the server are also included in this, and
  # so this handler also handles (and actually these receive priority):
  # verification
  def process_conversation(gateway_name, phone, msg_body)
    msg_body.strip! if msg_body

    if !msg_body || msg_body==''
      return process_help(gateway_name,phone,msg_body)
    end

    from_users = get_system_org.users.find_all_by_phone(phone)

    # if this is the format of a validation code
    # and there is a user requiring validation
    # this takes priority
    might_be_conf_code = (msg_body =~ /the code is (\d+)/ || msg_body =~ /^\s*(\d+)/)
    if might_be_conf_code
      conf_code = $1
      logger.info("Attempting to verify phone #{phone} with code #{msg_body}")
      validating_user = from_users.detect { |user| !user.sms_validated? && user.sms_validation_sent==msg_body }
      # note: even if multiple users are using a phone, and one user is not validated, but this user does return correctly, then this validation will succeed
      # note: if this is an incorrect validation code, then the response
      # if there is no message should reflect an invalid validation code
      # not an invalid conversation piece.
      return process_validation(gateway_name,validating_user,conf_code) if validating_user
    end

    # only validated users can be in conversations
    from_users.reject! {|user| !user.sms_validated?}

    # if we reach here, it might be a conversation response
    # find recent messages sent to the users
    # if there is only one recent message -> reply to this
    # if there are multiple messages and only one user -> user must address
    # if there are multiple users on the phone -> user must identify themselves -> overcome by just asking to address the message
    num_senders = 0
    msgs = from_users.collect() do |user|
      user_msgs = user.recent_msgs(APP_SETTINGS[:conversations_timeout])

      # ignore system messages
      user_msgs.reject! {|m| m.from==OCP::standardize_unique_name(FROM_SYSTEM_NAME)}

      # ignore messages from self
      user_msgs.reject! {|m| m.from==user.login_name}

      # remove duplicates from the from addresses
      senders = user_msgs.inject([]) do |all_from,m|
        std_name = OCP::standardize_unique_name(m.from)
        (all_from.include?(std_name) ? all_from : all_from.push(std_name))
      end

      num_senders += senders.count
      #puts "\nSENDERS:***\n"+senders.inspect
      (senders.length>0 ? [user,senders] : nil )
    end.compact
    #puts "\nCOMBINED MSGS ***\n"+msgs.inspect

    if (num_senders==1)
      from_user = msgs[0][0]
      org = from_user.org
      prev_sender = msgs[0][1][0]
      to_user = org.find_recipient_by_name(prev_sender)
      if to_user
        msg = safe_send_msg(org, from_user, to_user,msg_body)
        result = "Sent message to #{to_user.login_name}"
        reply_to_sender(phone,result)
        return result,false
      else
        logger.debug "Could not find user who sent the last message: from = #{prev_sender}"
        must_address = true
      end
    else
      must_address = num_senders>1
      # if no messages then something else
    end

    case
      when might_be_conf_code
        return reply_to_sender_with_error(phone, REPLY_VERIFY_DO_NOT_RECOGNIZE_PHONE_AND_CODE)
      when must_address
        all_senders = msgs.collect {|m| m[1].join(',')}
        return reply_to_sender_with_error(phone, sprintf(REPLY_CONVERSATION_MUST_ADDRESS,all_senders.join(',')))
      else
        # no command do nothing
        log_event("receive", "Unknown request: #{msg_body}")
        result = "Unknown command #{msg_body}"
        error = true
        return result,error
    end
end

  def process_remove(gateway_name, phone, body)
    body.strip!
    if body==""
      return reply_to_sender_with_error(phone, REPLY_REMOVE_UNEXPECTED_FORMAT)
    end

    if !(body=~/(.*?):(.*)/im)
      return reply_to_sender_with_error(phone, REPLY_REMOVE_UNEXPECTED_FORMAT)
    end

    from_login_name = $1
    from_msg = $2

    # may support override in the future = override confirmation
    #override = false
    #if from_msg=~/(.*)\s+override/
    #  from_password = $1
    #  override = true
    #else
    #  from_password = from_msg
    #end

    if !(from_user = get_system_org.users.find_by_login_name(from_login_name))
      return reply_to_sender_with_error(phone, REPLY_ERROR_UNKNOWN_LOGIN_NAME)
    end

    if !(from_user.valid_password?(from_msg.strip))
      log_event("SECURITY", "Invalid PASSWORD for user #{from_user.id} #{from_user.login_name}")
      # todo.security : lockout the user after a certain number of failed password attempts
      return reply_to_sender_with_error(phone, REPLY_ERROR_INVALID_PASSWORD)
    end

    # now need to verify that I can reach this number
    # by sending a validation code
    # necessary because we might not be able to connect to all of the networks

    from_user.sms_validated = DB_FALSE
    from_user.save!
    reply_to_sender(phone, REPLY_REMOVED_SUCCESSFULLY)
    logger.debug("Removed user phone #{from_user.inspect}")
    return "Removed user phone #{from_user.name}", false
  end

  def process_help(gateway_name, phone, body)
    reply_to_sender(phone, REPLY_HELP)
    return REPLY_HELP, false
  end

  def process_join(gateway_name, phone, body)
    body.strip!
    if body==""
      return reply_to_sender_with_error(phone, REPLY_JOIN_UNEXPECTED_FORMAT)
    end

    if !(from_user = is_sender_registered?(phone))
      return reply_to_sender_with_error(phone, REPLY_PHONE_NOT_REGISTERED)
    end

    search_for = OCP::standardize_unique_name(body)

    g_arr = Group.find(:all, :conditions=>["unique_name=:search OR short_name=:search", {:search=>search_for}])

    if g_arr.length==0
      return reply_to_sender_with_error(phone, sprintf(REPLY_JOIN_GROUP_NOT_FOUND, search_for))
      # to consider: could do automatic lookup of groups based on this as a keyword
    end

    if g_arr.length>1
      g_list = g_arr.collect { |item| "#{item.name} (#{item.short_name}" }
      return reply_to_sender_with_error(phone, sprintf(REPLY_JOIN_MULTIPLE_GROUPS, g_list))
    end

    g = g_arr[0]

    if g.users.find_by_id(from_user.id)
      return reply_to_sender_with_error(phone, sprintf(REPLY_JOIN_ALREADY_A_MEMBER, search_for))
    end

    g.users << from_user
    reply_to_sender(phone, sprintf(REPLY_JOINED_SUCCESSFULLY, g.name, g.short_name))

    result = "Added user #{from_user.name} (#{from_user.id}) to group #{g.name} (#{g.id}"
    logger.debug(result)
    return result, false
  end

  def process_leave(gateway_name, phone, body)
    body.strip!
    if body==""
      return reply_to_sender_with_error(phone, REPLY_LEAVE_UNEXPECTED_FORMAT)
    end

    if !(from_user = is_sender_registered?(phone))
      return reply_to_sender_with_error(phone, REPLY_PHONE_NOT_REGISTERED)
    end

    search_for = OCP::standardize_unique_name(body)

    g_arr = from_user.groups.find(:all, :conditions=>["unique_name=:search OR short_name=:search", {:search=>search_for}])

    if g_arr.length==0
      return reply_to_sender_with_error(phone, sprintf(REPLY_LEAVE_NOT_A_MEMBER, search_for))
    end

    if g_arr.length>1
      g_list = g_arr.collect { |item| "#{item.name} (#{item.short_name}" }
      return reply_to_sender_with_error(phone, sprintf(REPLY_LEAVE_MULTIPLE_GROUPS, g_list))
    end

    g = g_arr[0]

    from_user.groups.delete(g)
    reply_to_sender(phone, sprintf(REPLY_LEFT_SUCCESSFULLY, g.name, g.short_name))

    result = "Removed user #{from_user.name} (#{from_user.id}) from group #{g.name} (#{g.id}"
    logger.debug(result)
    return result, false
  end

# if the user just sends groups = show personal groups
# use lookup to search for other groups
  def process_groups(gateway_name, phone, body)
    if !(from_user = is_sender_registered?(phone))
      return reply_to_sender_with_error(phone, REPLY_PHONE_NOT_REGISTERED)
    end
    groups = from_user.groups.collect { |g| g.name }.sort
    result = sprintf(REPLY_YOUR_GROUP_LIST, groups.length, groups.join(','))
    reply_to_sender(phone, result)
    return result, false
  end

 def process_validation(gateway_name,user,conf_code)
     user.sms_validation_received = conf_code
     raise "Unexpected error: user should be validated" if !user.sms_validated?

     user.save!
     result = sprintf(REPLY_VERIFY_SUCCESS, user.name)
     reply_to_user(user, result)
     logger.info "Successfully validated user #{user.login_name} with phone #{user.phone}"
     return result, false
 end

# ----------
# returns the user if they are found within an organization
  def is_sender_registered?(phone_number)
    phone_number = phone_number.gsub(/\+1/, '').gsub(/\D+/, '')
    get_system_org.users.find_by_phone(phone_number)
  end

# Sends a reply back to the phone number
  def reply_to_sender(phone_number, msg)
    msg = msg[0..MAX_MSG_PAYLOAD-1]
    org = get_system_org
    org.send_direct(org.system_user, phone_number, msg)
  end

# sends the reply to the user, and returns [msg,true]
# true = error has occurred
  def reply_to_sender_with_error(phone_number, msg)
    reply_to_sender(phone_number, msg)
    msg = "" if Rails.env=='production' # do not show error messages in UI in production
    return msg, true
  end

  def reply_to_user(user, msg)
    # or could allow a maximum multi message in the future
    user.org.send_msg(user.org.system_user, user.name, OCP::truncate_msg_if_too_long(msg))
  end

  def safe_send_msg(org,from,to,text)
    text.strip! if text
    text = OCP::truncate_msg_if_too_long(text)
    org.send_msg(from.login_name[0..MAX_FROM_LEN-1], to, text)
    # todo: better from msg attribution
  end


  def get_system_org
    org = Org.find(:first)
    # todo: could search through organizations to find registered user here
    # or cell modem numbers could be registered to a particular organization
    raise "could not find system organization" if !org
    org
  end

end
