# some basic testing utilities

# Adds a number users at once to the system
# num = the number of users to add
# args can be:
# name = the name of the user, will always append # to it
#   note: this will be the username as well, and will fail if it already exists
#   if not specified = Test User01
# login_name = testuser01
#   note: these numbers are not always sequential
# password (default "password"}
# phone => phone number to use (default = +123456789 = the test number
# validated => is this validated (default true)
# group_name => if specified all the users added here are added to this particular group_name
#
# returns an array of the users added
#
# How to use this in a test environment
# RAILS_ENV=production ruby script/console
# > require 'lib/test_util.rb'
# true
# > add_x_users(20,:name=>"Server",:phone=>"16179531665",:group=>"20 server users")

def add_x_users(num, *args)

  puts "Adding #{num} users, params=#{args.inspect}"

  org = Org.find(:first)

  name = "Test User"
  login_name = "testuser"
  password = "password"
  phone = "+123456789"
  validated = true
  group_name = nil

  if args.length==1
    params = args[0]
    name = params[:name] if params[:name]
    login_name = params[:username] if params[:username]
    password = params[:password] if params[:password]
    phone = params[:phone] if params[:phone]
    validated = params[:validated] if params[:validated]
    group_name = params[:group]
  end

  if group_name and Group.find_by_name(:first,group_name)
    raise "The group #{group_name} already exists!"
  end
  
  # find the first unique test user name
  next_avail_user_num = 0
  found = true
  while found do
    next_avail_user_num = next_avail_user_num + 1
    found = User.find_by_login_name(login_name+next_avail_user_num.to_s) != nil    
    print "."
  end

  puts "found next #{login_name} #{next_avail_user_num}"

  users = []
  num.times do |i|
    u = User.new
    u.org = org
    u.name = name + (next_avail_user_num+i).to_s
    u.login_name = login_name + (next_avail_user_num+i).to_s
    u.password = password
    u.phone = phone
    u.save!
    u.force_sms_validation!(validated)
    users << u
    puts "Added user #{u.inspect}"
  end

  if group_name
    # now create the group_name from this
    group = Group.new
    group.org = org
    group.name = group_name
    group.save!
    puts "Added group #{group.inspect}"
    users.each do |u|
      u.groups << group
    end
    puts "Added all users to groups"
  end

  users
end

def test_util_loaded?
  puts "I am loaded"
end