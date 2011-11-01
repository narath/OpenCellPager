#!/usr/bin/env ruby
# vim: noet

#-----------------------------------------------------------------------------
#  our basic logger
#--
require 'singleton'
require 'logger'

class OutLogger
  attr_accessor :log
  include Singleton

  def initialize(filename = default_log_filename)
    @log = Logger.new(filename)
    @log.level = Logger::WARN
  end

  def log_num_level(message,level=:debug)
    @log.add(convert_num_category_to_logger_level(level),message)
  end

  def log(message,level=Logger::ERROR)
    @log.add(level,message)
  end

  def convert_num_category_to_logger_level(num)
    convert_algo = {
            :file => Logger::ERROR,
            :traffic => Logger::ERROR,
            :debug => Logger::DEBUG,
            :warn => Logger::WARN,
            :error => Logger::ERROR
    }
    default_logger_level = Logger::ERROR

    if (convert_algo.has_key?(num))
      return convert_algo[num]
    else
      return default_logger_level
    end
  end

  def default_log_filename
    File.expand_path(File.join(File.dirname(__FILE__),"../log/outbound.log"))
  end
end

