#!/usr/bin ruby

# include the period in new ext
# e.g. change_ext("/home/file.txt",".log")
def change_ext(filename,new_ext)
  filename.gsub(File.extname(filename),new_ext)
end

def log_event(category, message)
  # convert all newlines to '\'
  clean_message = message.gsub(/\r\n/, '\n').tr("\n\r", '\\')
  message = Time.now.strftime("%Y-%m-%d %H:%M:%S") + "|#{category}|" + clean_message
  filename = File.expand_path(File.dirname(__FILE__) + "/../log/" + change_ext(File.basename(__FILE__),".log"))
  f = File.open(filename, "a")
  f.puts(message)
  f.close
  return true
  #pp message
end


loop do
  begin
  msg = "I'm alive"
  log_event("Message",msg)
  #puts "hello world"
  sleep(2)
  rescue Exception => exc
    log_event "Message", "I'm killed!"
    raise
  end
end
