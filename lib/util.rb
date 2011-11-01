require 'net/http'
require 'uri'


#-----------------------------------------------------------------------------
#
#--
def log_gateway_error(category, message)

  #logger.error "Gateway error #{category} : #{message}"

  log_event(category, message)

end

def log_gateway_event(category, message)

  #logger.error "Gateway error #{category} : #{message}"

  log_event(category, message)

end

#-----------------------------------------------------------------------------
#
#--
def log_event(category, message)

  # convert all newlines to '\'
  clean_message = message.gsub(/\r\n/, '\n').tr("\n\r", '\\')

  f = File.open(File.expand_path(File.dirname(__FILE__) + "/../log/event.log"), "a")
  f.puts(Time.now.strftime("%Y-%m-%d %H:%M:%S") + "|#{category}|" + clean_message)
  f.close

end


#-----------------------------------------------------------------------------
# so we can call TextHelper mthods from controllers
# e.g. text_help.pluralize or text_help.strip_tags
#--

def text_help
  Helper.instance
end

class Helper
  include Singleton
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::SanitizeHelper
end

#-----------------------------------------------------------------------------
# returns default if opt not specified
def default_if_not_specified(opt,default_opt)
  opt ? opt : default_opt
end

# returns a has of key value pairs
# option1=val1,option2=val2 -> [[option1,val1],[option2,val2]] -> {option1=>val1,etc}
def extract_options(option_str)
  opt_ar = option_str.split(",").collect {|kv| kv.split("=",2) }
  opt_ar.inject({}) { |m, e| m[e[0].strip] = e[1].strip; m }
end

# for csv files, you need to escape commas, by using quotations
def escape_for_csv(str)
  str.include?(',') ? add_double_quotes(str) : str
end

def add_double_quotes(str)
  str.index('"')==0 ? str : "\"#{str}\"" 
end

def is_true?(val)
  val.match(/(true|t|yes|y|1)$/i) != nil if val
end

# todo: refactor utility methods into OCP module

module OCP
  def self.standardize_unique_name(name)
    # downcase, strip and conflate whitespace
    name.blank? ? '' : name.gsub(/\s+/, ' ').downcase.strip
  end

  def self.is_msg_too_long?(msg)
    msg && msg.length>(MAX_MSG_PAYLOAD-MAX_FROM_LEN)
  end

  def self.truncate_msg_if_too_long(msg)
    # truncate the message if too long
    if self.is_msg_too_long?(msg)
      msg[0..(MAX_MSG_PAYLOAD-MAX_FROM_LEN-TRUNCATE_MSG.length-1)]+TRUNCATE_MSG
    else
      msg
    end
  end



end