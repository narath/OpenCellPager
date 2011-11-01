require 'test_helper'

class RouterRuleTest < ActiveSupport::TestCase
  P_AMERICA = '16175105555'
  P_TANZANIA = '25555551111'
  P_LESOTHO = '26633331111'
  P_OTHER = '55511114444'
  P_MAGIC = '23999456'

  test "creating rules" do
    r = RouterRule.new()
    assert_raises ActiveRecord::RecordInvalid do
      r.save!
    end
    assert r.errors.invalid?(:pattern)
    assert r.errors.invalid?(:backend_id)

    # pattern that is already taken
    r.pattern = '*'
    assert_raises ActiveRecord::RecordInvalid do
      r.save!
    end

    r.pattern = '11'

    # backend must be specified
    assert_raises ActiveRecord::RecordInvalid do
      r.save!
    end

    # note: some of the regular expression patterns might be equivalent, but should not be exactly the same

    r.backend = backends(:one)
    r.save!
  end


  test "apply prefix rules appropriately" do
    r = router_rules(:use_one_for_america)
    assert r.match(P_AMERICA)
    # + in the number should not matter
    assert r.match('+'+P_AMERICA)

    assert !r.match(P_LESOTHO)

    rules = RouterRule.rules
    mr = rules.detect { |r| r.match(P_AMERICA) }
    assert_equal router_rules(:use_one_for_america),mr

    mr = rules.detect { |r| r.match(P_LESOTHO) }
    assert_equal router_rules(:use_two_for_tanzania_and_lesotho),mr

    mr = rules.detect { |r| r.match(P_MAGIC) }
    assert_equal router_rules(:use_two_for_regular_expression_for_magic_numbers),mr

    mr = rules.detect { |r| r.match(P_OTHER) }
    assert_equal router_rules(:use_one_as_default), mr
  end

  test "find_matching_rule" do
    assert_equal router_rules(:use_one_for_america),RouterRule.find_matching_rule(P_AMERICA)
  end
end
