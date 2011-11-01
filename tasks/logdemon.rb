#!/usr/bin ruby
require 'rubygems'
require 'daemons'

#options = {
#  :app_name   => "my_app",
#  :ARGV       => ARGV,
#  :dir_mode   => :script,
#  :dir        => 'pids',
#  :multiple   => false,
#  :ontop      => false,
#  :mode       => :exec,
##  :backtrace  => true,
## when running in exec mode cannot use backtracing unfortunately
#  :monitor    => true
#}
#
#options = { :mode => :exec,
#            :dir_mode => :script,
#            :dir => "pids"}
#Daemons.run('logserver.rb')), options)
Daemons.run('logserver.rb')
