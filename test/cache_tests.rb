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


    def test_get_multi_raw
        @cache.put("m1", "v1", 500, true)
        @cache.put("m2", "v2", 500, true)

        kz = Array["m1", "m2", "m3"]
        vz = @cache.get_multi(kz)

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
