require 'test_helper'

class PageTest < ActiveSupport::TestCase

  def setup
    @org = orgs(:sample)
    @joe = users(:joe)
    @msg = msgs(:msg_to_joe)
  end

  def test_add
    page = Page.new()
    
    # must have msg
    page.user = @joe
    page.org = @org
    page.msg = nil
    assert_raise ActiveRecord::StatementInvalid do
      page.save!
    end

    # must have user
    page.user = nil
    page.org = @org
    page.msg = @msg
    assert_raise ActiveRecord::StatementInvalid do
      page.save!
    end

    # must have org
    page.user = @joe
    page.org = nil
    page.msg = @msg
    assert_raise ActiveRecord::StatementInvalid do
      page.save!
    end
      
    page.user = @joe
    page.org = @org
    page.msg = @msg
    assert page.save
  end
  
end
