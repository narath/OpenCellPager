ProcessResult = Struct.new(:n_processed, :n_err, :msgs, :err_msgs)

class Roster < ActiveRecord::Base
  belongs_to :org
  belongs_to :call_role, :class_name => 'User', :foreign_key => 'role_id'
  belongs_to :call_assignment, :class_name => 'User', :foreign_key => 'assignment_id'


  def in_org?(org)
    return self.org && org && (self.org.id == org.id)
  end

  # this processes the schedule by going thru the roster and updating any elements that have not been processed
  # for the current day
  # returns: ProcessResult
  def self.process_schedule
    result = ProcessResult.new()
    result.n_processed = 0
    result.n_err = 0
    result.msgs = []
    result.err_msgs = []
    roster_today = Roster.find_all_by_start_date(Date.today)
    if !roster_today
      return result
    end

    roster_today.each do |roster|
      if !roster.processed
                            
        if !roster.call_role
          result.err_msgs << "No call role for roster id #{roster.id}"
          result.n_err += 1
          next
        end

        #note: there might not be a call_assignment (i.e. the call roster might be blank that day)

        #TODO: determine if we need to check to make sure the new assignment is to a valid user
        #for now, we just let the assignment go through

        begin
          roster.call_role.forward_to = roster.call_assignment
          roster.processed = true
          roster.processed_at = Time.now
          roster.call_role.save!
          roster.save!
          result.n_processed += 1
          result.msgs << "#{roster.call_role.name} => #{roster.call_assignment ? roster.call_assignment.name : '(none)'}"
        rescue Exception => e
          # note the exception and keep going
          result.err_msgs << "Error processing #{roster.call_role.name} assignment on #{roster.start_date} - Error #{e.message}"
          result.n_err += 1
        end
      end

    end
    return result
  end
end
