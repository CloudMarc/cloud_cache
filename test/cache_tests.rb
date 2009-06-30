require 'test/unit'
require '../lib/cloud_cache'

#
# You'll need make a cloudcache.yml file in this directory that contains:
# amazon:
#    access_key: ACCESS_KEY
#    secret_key: SECRET
#
class CacheTests < Test::Unit::TestCase

    #def initialize(*params)
    #    super(*params)
    #end

    def test_for_truth
        assert true
    end

    def setup
        puts("Setting up cache...")
        props = nil
        begin
            props = YAML::load(File.read('cloudcache.yml'))
        rescue
            raise "Couldn't find cloudcache.yml file. " + $!.message
        end
        @cache = ActiveSupport::Cache::CloudCache.new(props['access_key'], props['secret_key'])
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

        sleep(1)

        response = @cache.get("s1")
        assert_equal(to_put, response)

    end

    def test_not_exists
        assert_nil @cache.get("does_not_exist")
    end

    def test_delete
        to_put = "I am a testing string. Take me apart and put me back together again."
        @cache.put("s1", to_put, 0)

        sleep(1)

        response = @cache.get("s1")
        assert_equal(to_put, response)

        @cache.delete("s1");

        response = @cache.get("s1")
        assert_nil(response)
    end

    def test_expiry
        to_put = "I am a testing string. Take me apart and put me back together again."
        @cache.put("s1", to_put, 2);

        sleep(4)

        response = @cache.get("s1")
        assert_nil(response)
    end

    def test_list_keys
        @cache.put("k1", "v2")
        sleep 1
        keys = @cache.list_keys
        puts("PRINTING KEYS:")
        for key in keys
            puts key
        end
        haskey = keys.index("k1")
        assert_not_nil(haskey)
    end

    def test_counters
        val = 0
        key = "counter1"
        @cache.put(key, val, 50000, true)
        10.times do
            val = @cache.increment(key)
        end
        assert_equal(10, val)

        # get as normal int now
        get_val = @cache.get_i(key)
        assert_equal(10, get_val)

        10.times do
            val = @cache.decrement(key)
        end
        assert_equal(0, val)

        # One more to make sure it stays at 0
        val = @cache.decrement(key)
        assert_equal(0, val)

    end

    def test_flush
        x = @cache.flush
        assert_equal('[]', x)
    end

    def test_stats
        x = @cache.stats
        puts x
    end

    def test_get_multi_raw
        @cache.put("m1", "v1", 500, true)
        @cache.put("m2", "v2", 500, true)

        kz = Array["m1", "m2", "m3"]
        vz = @cache.get_multi(kz, true)

        assert_equal("v1", vz["m1"]);
        assert_equal("v2", vz["m2"]);
        assert_nil(vz["m3"]);
    end

    def test_get_multi
        @cache.put("m1", "v1", 500, false)
        @cache.put("m2", "v2", 500, false)

        kz = Array["m1", "m2", "m3"]
        vz = @cache.get_multi(kz)

        assert_equal("v1", vz["m1"]);
        assert_equal("v2", vz["m2"]);
        assert_nil(vz["m3"]);
    end




end
