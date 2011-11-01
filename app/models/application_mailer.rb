class ApplicationMailer < ActionMailer::Base
  def test_msg(recipient)
    recipients recipient
    from       ExceptionNotifier.sender_address
    subject    "Test message from OCP server"
    body       "This is just a test message."
  end

  def panic_email(info)
    recipients ExceptionNotifier.exception_recipients
    from       ExceptionNotifier.sender_address
    subject    "Unable to send pages"
    body       info
  end
end
