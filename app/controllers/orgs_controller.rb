require 'csv'

class OrgsController < ApplicationController

  layout "application"

  before_filter :require_user
  before_filter :require_admin, :except=>[:show]

  def show

  end

  def edit
  end

  def update
    expected_post_not_get && return unless request.post?
    @org.update_attributes!(params[:org])
    redirect_back_or_to :controller=>'orgs', :action => 'show'
  rescue ActiveRecord::RecordInvalid
    render :action => :edit
  end

  def balance

    @org.refresh_balance

  end

  def import

  end

  def import_file
     return if not request.post?
     @show_hint = false

     @parsed_file=CSV::Reader.parse(params[:dump][:file])

     # read the first line to ensure the correct format
     col_username = -1  # optional
     col_password = -1  # optional - else generates
     col_full_name = -1
     col_phone = -1
     col_validated = -1 # optional

    n=0
    n_added = 0
    @results = []
    @parsed_file.each  do |row|
      n += 1
      if n==1
        # read the row header to know which columns to read
        col_n = 0
        row.each do |col|
          col_name = col.to_s.downcase.strip
          case
            when col_name =~ /user/
              col_username = col_n
            when col_name =~ /password/
              col_password = col_n
            when col_name =~ /full/
              col_full_name = col_n
            when col_name =~ /phone/
              col_phone = col_n
            when col_name =~ /valid/
              col_validated = col_n
          end
          col_n += 1
        end
          # check that all required fields are specified
          if [col_full_name, col_phone].include?(-1)
            flash.now[:message] = "Invalid file format (Full Name=#{col_full_name} Phone=#{col_phone}"
            @show_hint = true
            return
          end
      else # a data column
        full_name = row[col_full_name]
        full_name.strip if full_name
        if !full_name or full_name==""
          @results << "#{n}. #{row.join(",")}: No name specified!\n"
          next
        end

        # if the user already exists then skip it
        if User.find_by_name(full_name)
          @results << "#{n}. #{row.join(",")}:\"#{full_name}\" already exists!\n"
          next
        end

        # is a phone number specified
        phone = row[col_phone]
        phone.gsub!(/\D+/, '') if phone
        if !phone or phone==""
          @results << "#{n-1}. #{row.join(",")}:No phone specified!\n"
          next
        end

        # is a login name specified
        username = ""
        if col_username != -1
          username = row[col_username]
          username = username.downcase.gsub(/[^\w_]/, '') if username

        end

        # if it is not specified -> generate
        if !username or username==""
          username = User.generate_username(full_name)
        end

        # if it exists -> fail (in the future could reassign username)
        if User.find_by_login_name(username)
          @results << "#{n-1}. #{row.join(",")}:Username #{username} already exists!\n"
          next
        end

        # is a password specified
        password = ""
        password = row[col_password] if col_password!=-1

        # if not -> generate
        if !password or password==""
          password = User.generate_password(username)
        end
        # if yes -> if not strong enough -> generate
        if !User.check_password_strength(password)
          @results << "#{n-1}. #{row.join(",")}:Password #{password} is not strong enough!\n"
          next
        end

        validated = false
        if col_validated!=-1 and row[col_validated] and row[col_validated].to_s=="1"
          validated = true
        end

        user = User.new
        user.org = @org
        user.login_name = username
        user.name = full_name
        user.password = password
        user.phone = phone
        if (validated)
          user.force_sms_validation!(true)
        end

        if user.save
          n_added += 1

          @results << "#{n-1}. #{row.join(",")}: added username=#{username} password=#{password} full_name=#{full_name} phone=#{phone} valid=#{validated}\n"

          GC.start if n%50==0
        end
      end
    end
    flash.now[:message]="CSV Import Completed,#{n_added} of #{n } new records added to data base"
  end

  def monitor

  end

  def monitor_update
    expected_post_not_get && return unless request.post?
    # update only the monitor params
    @org.monitor_on = params["org"]["monitor_on"]

    # if turning of panicking, then change the last check date to now
    # since we only want to keep checking from now on
    if (@org.monitor_is_panicking && !params["org"]["monitor_is_panicking"])
      @org.monitor_last_check = Time.zone.now
    end

    @org.monitor_is_panicking = params["org"]["monitor_is_panicking"]

    # update settings
    @org.monitor_minutes = params["org"]["monitor_minutes"]
    @org.monitor_unsent_pages = params["org"]["monitor_unsent_pages"]
    @org.monitor_check_in_minutes = params["org"]["monitor_check_in_minutes"]

    @org.save!
    flash[:notice] = "Monitor settings updated successfully."

    render(:template => "admin/monitor")
  end


#######
protected
#######



end
