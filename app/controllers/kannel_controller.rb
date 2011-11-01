require 'util'

class KannelController < GatewayController
  helper ApplicationHelper

  def index
  end

  def deliveryreport
    Rails.logger.info("deliveryreport params: #{params.inspect}'")
    sent_id = params['id'].to_i
    status = params['status'].to_i
    answer = params['answer']

    sent = Outbound.find_by_id(sent_id)
    if sent
      # update status
      if KANNEL_SUCCESS.member?(status)
        sent.status = STATUS_DELIVERED
      elsif status==KANNEL_QUEUED_ON_SMSC
        sent.status = STATUS_PENDING
      else
        sent.status = STATUS_FAILED
      end

      sent.status_string = "#{status} #{answer}"
      sent.save!

      sent.page.msg.update_status if sent.page_id && sent.page && sent.page.msg_id && sent.page.msg
    else
      Rails.logger.debug("deliveryreport ERROR: could not find sent id #{params['id']}")
    end

    render(:layout=>false)
  end

  def receive
    Rails.logger.debug("receive params: #{params.inspect}")

    # here we process particulars commands
    # in the future this will update a message response based on the number
    text = params["text"]
    phone = params["phone"]
    receive_time = params["time"]

    @result = handle_received_msg("kannel",phone,text,receive_time)
    render(:layout=>false)
  end
end
