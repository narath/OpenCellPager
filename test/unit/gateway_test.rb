require 'test_helper'

class GatewayTest < ActiveSupport::TestCase
  def assert_has_session(hash, key)
    assert hash.has_key?(key), "#{key} session not registered correctly"
  end

  test "submodules are registered correctly" do
    types = Gateway::Session.subclasses
    #assert_equal "", types
    assert_has_session(types, :test)
    assert Gateway::Session.create(:test, ''), "Could not create TestSession"
    # the rest are sort of optional
  end
end

class TestSessionTest < ActiveSupport::TestCase
  test "can create" do
    g = Gateway::Session.create :test
    assert_equal Gateway::TestSession, g.class
  end
end

class ClickatellSessionTest < ActiveSupport::TestCase
  test "can create" do
    g = Gateway::Session.create :clickatell,nil
    assert_equal Gateway::ClickatellSession, g.class

    # can override the options
    c = YAML.load(Gateway::ClickatellSession.default_config_str)
    c['username'] = 'me'
    c['password'] = 'something silly'
    c['api_id'] = 'aappii'
    g = Gateway::Session.create :clickatell,YAML.dump(c)
    assert g, "Could not create clickatell gateway"
    assert_equal c['username'],g.username
    assert_equal c['password'],g.password
    assert_equal c['api_id'],g.api_id
    # lazy api load
    assert !g.api

    # throw error if missing params
    check_missing_params('username','password','api_id')
  end

  def check_missing_params(*args)
    # the default options should be specified
    # so we just need to set it to blank to test that it is being picked up
    args.each do |key|
      assert_raises RuntimeError do
        g = Gateway::Session.create :clickatell,"#{key}: ''"
      end
    end
  end
end

class KannelSessionTest < ActiveSupport::TestCase
  test "kannel checks config settings correctly" do
    #not specifying any options should work
    g = Gateway::Session.create :kannel,nil
    assert_equal Gateway::KannelSession, g.class

    assert_equal KANNEL_CONFIG_SERVER, g.server
    assert_equal KANNEL_CONFIG_PORT, g.port
    assert_equal KANNEL_CONFIG_USERNAME, g.username
    assert_equal KANNEL_CONFIG_PASSWORD, g.password
    assert_equal KANNEL_CONFIG_DLR_URL, g.dlr_url
    assert_equal KANNEL_CONFIG_DLR_MASK, g.dlr_mask
    assert_equal KANNEL_CONFIG_RECEIVE_URL, g.receive_url

    # overridding options should work
    config = YAML.load(Gateway::KannelSession.default_config_str)
    assert config, "Default kannel settings not valid yaml"
    g = Gateway::Session.create :kannel,YAML.dump(config)
    assert_equal Gateway::KannelSession, g.class

    assert_equal config['server'], g.server
    assert_equal config['port'], g.port
    assert_equal config['username'], g.username
    assert_equal config['password'], g.password
    assert_equal config['dlr_url'], g.dlr_url
    assert_equal config['dlr_mask'], g.dlr_mask
    assert_equal config['receive_url'], g.receive_url

  end
end


class TropoSessionTest < ActiveSupport::TestCase
  test "can create" do
    # requires token
    assert_raises RuntimeError do
      g = Gateway::Session.create :tropo,nil
    end

    g = Gateway::Session.create :tropo,'token: hello world'
    assert_equal Gateway::TropoSession, g.class
  end
end

