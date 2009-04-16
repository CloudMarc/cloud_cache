require 'test/unit'
require '../lib/cloudcache'

#
# You'll need make a cloudcache.yml file in this directory that contains:
# amazon:
#    access_key: ACCESS_KEY
#    secret_key: SECRET
#
class CacheTests < Test::Unit::TestCase

  def test_for_truth
    assert true
  end

  def setup
    puts("Setting up cache...")
    props = nil
    begin
      props = YAML::load(File.read('cloudcache.yml'))
    rescue
      puts "Couldn't find cloudcache.yml file. " + $!.message
      return
    end
    @cache = ActiveSupport::Cache::CloudCache.new("cloudcache-ruby-tests", props['amazon']['access_key'], props['amazon']['secret_key'])
  end


  def teardown
    @cache.shutdown unless @cache.nil?
  end

  def test_auth
    @cache.auth()
  end

  def test_bad_auth

    temp = @cache.secret_key
    @cache.secret_key = "badkey"

    assert_raise Net::HTTPServerException do
      test_basic_ops
    end

    @cache.secret_key = temp
  end

  def test_basic_ops
    to_put = "I am a testing string. Take me apart and put me back together again."
    @cache.put("s1", to_put, 0);

    sleep(5)

    response = @cache.get("s1")
    assert_equal(to_put, response)

  end

  def test_not_exists
    assert_nil @cache.get("does_not_exist")
  end

  def test_delete
    to_put = "I am a testing string. Take me apart and put me back together again."
    @cache.put("s1", to_put, 0)

    sleep(5)

    response = @cache.get("s1")
    assert_equal(to_put, response)

    @cache.delete("s1");

    response = @cache.get("s1")
    assert_nil(response)
  end

  def test_expiry
    to_put = "I am a testing string. Take me apart and put me back together again."
    @cache.put("s1", to_put, 5);

    sleep(10)

    response = @cache.get("s1")
    assert_nil(response)
  end

  def test_list_keys
    keys = @cache.list_keys
    puts("PRINTING KEYS:")
    for key in keys
      puts key
    end
  end

  def test_counters
    val = 0;
    key = "counter1";
    @cache.put(key, val, 50000);
    10.times do
      val = @cache.increment(key)
    end
    assert_equal(10, val)

    10.times do
      val = @cache.decrement(key)
    end
    assert_equal(0, val);

    # One more to make sure it stays at 0
    val = @cache.decrement(key);
    assert_equal(0, val);


  end


end