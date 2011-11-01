require 'test_helper'

class RosterTest < ActiveSupport::TestCase

  def setup
    @org = orgs(:sample)
    @joe = users(:joe)
    @doc_on_call = users(:doc_on_call)
  end

  def test_add
    roster = Roster.new()

    roster.start_date = Time.now()
    roster.call_role = @doc_on_call
    roster.call_assignment = @joe
    roster.save
  end

  def test_delete

  end

end
