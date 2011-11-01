require 'test_helper'

class UtilTest < ActiveSupport::TestCase
  def setup
    @org = orgs(:sample)
  end

  test "default_if_not_specified" do
    assert_equal nil,default_if_not_specified(nil,nil)
    assert_equal "default",default_if_not_specified(nil,"default")
    assert_equal "overridden",default_if_not_specified("overridden","default")
  end

  test "extract_options" do
      s1 = "kannel-server=http://127.0.0.1,kannel-port=13013,kannel-username=tester,kannel-password=foobar,"+
            "dlr-url=http://127.0.0.1/kannel/deliveryreport,dlr-mask=31,"+
            "receive-url=http://127.0.0.1/kannel/receive"
    ar = extract_options(s1)
    assert_equal "http://127.0.0.1", ar["kannel-server"]
    assert_equal "13013",ar["kannel-port"]
    assert_equal "tester",ar["kannel-username"]
    assert_equal "foobar", ar["kannel-password"]
    assert_equal "http://127.0.0.1/kannel/deliveryreport", ar["dlr-url"]
    assert_equal "31",ar["dlr-mask"]
    assert_equal "http://127.0.0.1/kannel/receive",ar["receive-url"]
  end

  test "escape_for_csv" do
    assert_equal "",escape_for_csv("")
    assert_equal "hello",escape_for_csv("hello")
    assert_equal "\"hello,world\"",escape_for_csv("hello,world")
    assert_equal "\"hello,world\"",escape_for_csv("\"hello,world\"")
  end

  test "add_double_quotes" do
    assert_equal "\"\"",add_double_quotes("")
    assert_equal "\"hello world\"",add_double_quotes("hello world")
    assert_equal "\"hello world\"",add_double_quotes("\"hello world\"") 
  end

  test "truncate msg" do
    assert_equal "", OCP::truncate_msg_if_too_long("")

    msg = ""
    100.times { msg += "A" }
    assert_equal msg, OCP::truncate_msg_if_too_long(msg)

    msg = ""
    (MAX_MSG_PAYLOAD-MAX_FROM_LEN).times { msg += "A" }
    assert_equal msg, OCP::truncate_msg_if_too_long(msg)

    msg += "A"
    assert_equal MAX_MSG_PAYLOAD-MAX_FROM_LEN, OCP::truncate_msg_if_too_long(msg).length

  end
end

