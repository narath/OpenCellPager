require 'bundler/capistrano'
require 'delayed/recipes'

default_run_options[:pty] = true

set :user, 'opencellpager'
set :application, 'ocp'
set :repository,  "git@github.com:narath/OpenCellPager.git"

if ocp_server == "pilot"
  set :domain, 'pilot'
  set :deploy_to, "/var/www/#{application}"
  set :have_smsd_server, true
elsif ocp_server == "mylinode"
    set :domain, 'mylinode'
    set :deploy_to, "/var/www/#{application}"
    set :have_smsd_server, false
elsif ocp_server == "pilotlocal"
    set :domain, 'pilotlocal'
    set :deploy_to, "/var/www/#{application}"
    set :have_smsd_server, true
    set :config_dir, "../../config/production-pilot"
elsif ocp_server == "staging"
    set :domain, 'staging'
    set :deploy_to, "/var/www/#{application}"
    set :have_smsd_server, true
else
    raise Exception.new("Unknown ocp_server #{ocp_server}")
end

role :app, domain, :smsd_server => have_smsd_server
role :web, domain
role :db,  domain, :primary => true

# branch to checkout, by default is the master branch, but can be overridden using --set branch=other
set :branch, 'master'

# miscellaneous options 
set :deploy_via, :remote_cache 
set :scm, 'git'
set :scm_verbose, true 
set :use_sudo, false 


# task which causes Passenger to initiate a restart 
namespace :deploy do 
  task :restart do 
    run "touch #{current_path}/tmp/restart.txt" 
  end 
end 

# start smsd server before deploy and restart after
#before "deploy:update", "smsd:stop_smsd"
#after "deploy:update", "smsd:update_smsd"
#after "deploy:update", "smsd:start_smsd"

namespace :smsd do

  task :stop_smsd, :roles => :app, :only => {:smsd_server => true} do
    begin
      #run "cd /etc/init.d && #{sudo} ./ocpdaemon stop"

      # Kannel configuration is manual on the server for now, so we dont support starting and stopping it
      run "#{sudo} /etc/init.d/kannel stop"
    rescue Exception => error
      puts "*** SMSD ERROR: Couldn't stop smsd: #{error}"
    end
  end

  task :update_smsd, :roles => :app, :only => {:smsd_server => true} do
    #note: the server will need to be restarted for these to take effect
    run "#{sudo} cp #{current_path}/config/kannel/kannel.conf /etc/kannel/kannel.conf"
    run "#{sudo} cp #{current_path}/config/kannel/modems.conf /etc/kannel/modems.conf"
  end
  
  task :start_smsd, :roles => :app, :only => {:smsd_server => true} do
    begin
      #run "cd /etc/init.d && #{sudo} ./ocpdaemon start"
      run "#{sudo} /etc/init.d/kannel start"
    rescue Exception => error
      puts "*** SMSD ERROR: Couldn't start smsd: #{error}"
    end
  end
  
end

after "deploy:update_code", :update_config

desc "copy config .yml into the current release path"
task :update_config, :roles => :app do
  db_config = "#{deploy_to}/config/database.yml" 
  run "cp #{db_config} #{release_path}/config/database.yml" 

  mailer_config = "#{deploy_to}/config/mailer.yml"
  run "cp #{mailer_config} #{release_path}/config/mailer.yml"
  
  local_settings_config = "#{deploy_to}/config/local_settings.yml"
  run "cp #{local_settings_config} #{release_path}/config/local_settings.yml"  
end

# Delayed job hooks
after "deploy:stop",    "delayed_job:stop"
after "deploy:start",   "delayed_job:start"
after "deploy:restart", "delayed_job:restart"

namespace :nginx do
  desc "Update Nginx config and restart"
  task :update, :roles => :web do
    config_file = File.expand_path(File.join(File.basename(__FILE__),config_dir,'nginx.conf'))
    raise "File does not exist #{config_file}" if !File.exists?(config_file)
    upload config_file, 'nginx.conf'
    sudo "cp ~/nginx.conf /opt/nginx/conf/nginx.conf"
    sudo "/etc/init.d/nginx restart"
  end

  # sometimes needed if the above restart does not work
  # then just try starting it
  task :start, :roles => :web do
    sudo "/etc/init.d/nginx start"
  end

  task :watch do
    stream "tail -f /opt/nginx/logs/*.log"
  end
end

namespace :logs do
  task :watch do
    run "#{sudo} tail -f #{deploy_to}/shared/log/*"
  end

  task :watch_nginx do
    stream "tail -f /opt/nginx/logs/*.log"
  end
end

