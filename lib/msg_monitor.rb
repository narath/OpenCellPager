# A class this is used to monitor messages
class MsgMonitor
  attr_accessor :panic_after_minutes, :panic_after_unsent_msgs

  DEFAULT_PANIC_AFTER_MINUTES = 5
  DEFAULT_PANIC_AFTER_UNSENT_MSGS = 5

  def initialize(*params)
    @panic_after_minutes = params[:panic_after_minutes] ? params[:panic_after_minutes] : DEFAULT_PANIC_AFTER_MINUTES
    @panic_after_unsent_messages = params[:panic_after_unsent_msgs] ? params[:panice_after_unsent_msgs] : DEFAULT_PANIC_AFTER_UNSENT_MSGS
  end

  

end