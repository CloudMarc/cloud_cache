require 'test/unit'
require '../lib/cloud_cache'
require 'my_class'
#
# You'll need make a cloudcache.yml file in this directory that contains:
# amazon:
#    access_key: ACCESS_KEY
#    secret_key: SECRET
#
class CacheTests < Test::Unit::TestCase

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
        @cache.put("s1", to_put)

        sleep(1)

        response = @cache.get("s1")
        assert_equal(to_put, response)

    end

    def test_not_exists
        assert_nil @cache.get("does_not_exist")
    end

    def test_delete
        to_put = "I am a testing string. Take me apart and put me back together again."
        @cache.put("s1", to_put)

        sleep(1)

        response = @cache.get("s1")
        assert_equal(to_put, response)

        @cache.delete("s1")

        response = @cache.get("s1")
        assert_nil(response)
    end

    def test_expiry
        to_put = "I am a testing string. Take me apart and put me back together again."
        @cache.put("s1", to_put, :ttl=>2);
        sleep(4)
        response = @cache.get("s1")
        assert_nil(response)

        @cache.write("s1", to_put, :expires_in=>2);
        sleep(4)
        response = @cache.get("s1")
        assert_nil(response)
    end

    def test_list_keys
        @cache.put("k1", "v2", :expires_in=>15)
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
        key = "counter1" # should add a test for a key with a slash
        @cache.put(key, val, :ttl=>50000, :raw=>true)
        10.times do
            val = @cache.increment(key)
            puts 'val=' + val.to_s
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
        @cache.remove("m1") rescue false
        @cache.remove("m2") rescue false
        @cache.remove("m3") rescue false
        @cache.remove("m4") rescue false

        @cache.put("m1", "v1", :ttl=>500, :raw=>true)
        @cache.put("m2", "v2", :ttl=>500, :raw=>true)

        kz = Array["m1", "m2", "m3"]
        vz = @cache.get_multi(kz, :raw=>true)

        assert_equal("v1", vz["m1"])
        assert_equal("v2", vz["m2"])
        assert_nil(vz["m3"])


    end

    def test_get_multi

        kz = []
        vz = @cache.get_multi(kz)
        assert vz.size == 0

        kz = ["nothere"]
        vz = @cache.get_multi(kz)
        assert vz.size == 0

        @cache.remove("m1") rescue false
        @cache.remove("m2") rescue false
        @cache.remove("m3") rescue false
        @cache.remove("m4") rescue false

        @cache.put("m1", "v1", :ttl=>500, :raw=>false)
        @cache.put("m2", "v2", :ttl=>500, :raw=>false)
        @cache.put("m4", MyClass.new("Travis", 10), :ttl=>500, :raw=>false)

        kz = ["m1", "m2", "m3", "m4"]
        vz = @cache.get_multi(kz)

        assert_equal("v1", vz["m1"]);
        assert_equal("v2", vz["m2"]);
        assert_nil(vz["m3"]);
        assert_equal("Travis", vz["m4"].name)
        assert_equal(10, vz["m4"].age)

        @cache.put("m3", MyClass.new("Leroy", 3), :ttl=>500, :raw=>false)

        kz = ["m1", "m2", "m3", "m4"]
        vz = @cache.get_multi(kz)

        assert_equal("v1", vz["m1"]);
        assert_equal("v2", vz["m2"]);
        assert_equal("Leroy", vz["m3"].name)
        assert_equal(3, vz["m3"].age)
        assert_equal("Travis", vz["m4"].name)
        assert_equal(10, vz["m4"].age)


    end

    def test_big
        s = random_string(100000)
        @cache.put("s1", s)

        s2 = @cache.get("s1")

        assert_equal(s, s2)
    end

    def random_string(length=10)
        chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
        password = ''
        length.times { password << chars[rand(chars.size)] }
        password
    end

    def test_usage
        usage = @cache.usage
        assert_kind_of(Numeric, usage)
    end


    def test_set_if_not_found
        key = "sinf"
        @cache.delete(key)

        assert_raise Net::HTTPServerException do
            @cache.increment(key, 1)
        end

        val = 3
        ret = @cache.increment(key, 1, :set_if_not_found=>val)
        assert ret == val
        ret = @cache.get(key)
        assert ret == val
        ret = @cache.increment(key, 1, :set_if_not_found=>val)
        assert ret == val + 1

    end

    def test_failing_data
        fname = "fail_message.txt"
        return if !File.exists?(fname)
        file = File.new fname
        result = file.read # JSON.parse(file.read)
        file.close
        puts result.inspect
        @cache.put("bigolmsg", result)
    end

    def test_bad_md5
        @cache.put("md5val", "BAhvOhFQZXJmTG9nRW50cnkPOhBAZW50cnlfZGF0ZVU6DURhdGVUaW1lWwhV
Og1SYXRpb25hbFsHbCsJN5Fzjkoz+wBsKwgAIJ20BgBVOwhbB2n0aR1pAxkV
IzoPQGZyb21fbm9kZW86DEFkYXB0ZXIJOhBAYXR0cmlidXRlc3sYSSIJbmFt
ZQY6DWVuY29kaW5nIgpVVEYtOFsGSSILVFI1MzAxBjsMQBFJIgx1cGRhdGVk
BjsMQBFbBkkiGDIwMDktMDktMTZUMDY6NDM6MTAGOwwiDVVTLUFTQ0lJSSIT
bGFzdF9jb25uZWN0ZWQGOwxAEVsGSSIYMjAwOS0wOS0xNlQwNjo0MzowOQY7
DEAXSSIOY29ubmVjdGVkBjsMQBFbBkkiGDIwMDktMDktMDFUMTA6MDY6MjYG
OwxAEUkiD25ldHdvcmtfaWQGOwxAEVsGSSIpMWY5MTQzNGMtOTZkZi0xMWRl
LWExOWItMDAxZWMyYjRhYjQ5BjsMQBFJIgdpZAY7DEARSSIpMWNiZmVjMGUt
OTZkZi0xMWRlLWExOWItMDAxZWMyYjRhYjQ5BjsMQBFJIgtzdGF0dXMGOwxA
EVsGSSIIbmV3BjsMQBFJIgxjcmVhdGVkBjsMQBFbBkkiGDIwMDktMDktMDFU
MTA6MDY6MjcGOwxAEUkiGHBsYXN0ZXJfbmV0d29ya3NfaWQGOwxAEVsGSSIL
VFI1MzAxBjsMQBFJIgp3YW5pcAY7DEARWwZJIg4xMjcuMC4wLjEGOwxAEUki
CG1hYwY7DEARWwZJIhEwMDI0RThUUjUzMDEGOwxAEUkiDmxhc3Rfc2VlbgY7
DEARWwZJIhgyMDA5LTA5LTE2VDA2OjQzOjA5BjsMQBdJIhRkZXZpY2VfcGFz
c3dvcmQGOwxAEVsGSSIVMTExMTIyMjIzMzMzNDQ0NAY7DEARSSIKc3d2ZXIG
OwxAEVsGSSILMC4wLjM1BjsMQBFJIhRuYW1lX29uX2FkYXB0ZXIGOwxAEVsG
SSILVFI1MzAxBjsMQBFJIhJyb2xsb3V0X3BoYXNlBjsMQBFbBkkiGTA5MjIz
MzcyMDM2ODU0Nzc1ODA5BjsMQBFJIg5sYXN0X3BlcmYGOwxAEVsGSSIYMjAw
OS0wOS0xNlQwNjo0MzowOQY7DEAXSSIUdGltZV9zaW5jZV9ib290BjsMQBFb
BkkiGTA5MjIzMzcyMDM2ODU0Nzc1ODMwBjsMQBdJIhhTZGItaXRlbS1pZGVu
dGlmaWVyBjsMQBFbBkkiKTFjYmZlYzBlLTk2ZGYtMTFkZS1hMTliLTAwMWVj
MmI0YWI0OQY7DEAROhBAbmV3X3JlY29yZEY6DEBlcnJvcnNvOiZTaW1wbGVS
ZWNvcmQ6OlNpbXBsZVJlY29yZF9lcnJvcnMGOw5bADoLQGRpcnR5ewpJIhNs
YXN0X2Nvbm5lY3RlZAY7DEAXSSIYMjAwOS0wOS0xNlQwNjo0MTozNQY7DEAR
SSIObGFzdF9zZWVuBjsMQBd1OglUaW1lDQZiG4BGJZCsSSIObGFzdF9wZXJm
BjsMQBdJIhgyMDA5LTA5LTE2VDA2OjQxOjM1BjsMQBFJIhR0aW1lX3NpbmNl
X2Jvb3QGOwxAF0kiGTA5MjIzMzcyMDM2ODU0Nzc1ODMwBjsMQBE6DHVwZGF0
ZWRJIhgyMDA5LTA5LTEzVDA1OjM1OjMwBjsMQBE6DUBuZXR3b3JrbzoMTmV0
d29yawk7C3sPSSINcGFzc3dvcmQGOwxAEVsGSSItMTQ1Yzg0NDIxNTgwZTZl
MGU1NGY0YmI2MTBjOTdjMzg3MTRkODZhMQY7DEARSSIMY3JlYXRlZAY7DEAR
WwZJIhgyMDA5LTA5LTAxVDEwOjA2OjMxBjsMQBFJIgdpZAY7DEARSSIpMWY5
MTQzNGMtOTZkZi0xMWRlLWExOWItMDAxZWMyYjRhYjQ5BjsMQBFJIg1vd25l
cl9pZAY7DEARWwZJIik4Y2RiMTJlMC1mODgxLTExZGQtYTBmMS0wMDE2ZWE1
ZTcxYzYGOwxAEUkiDHVwZGF0ZWQGOwxAEVsGSSIYMjAwOS0wOS0xMVQwMjo1
NDowMwY7DEARSSIJbmFtZQY7DEARWwZJIhVQTE4gVFI1MyBOZXR3b3JrBjsM
QBFJIhNwbGFpbl9wYXNzd29yZAY7DEARWwZJIg0xMjM0NTY3OAY7DEARSSIJ
Z3dpcAY7DEARWwZJIg4xMjcuMC4wLjEGOwxAEUkiCmd3bWFjBjsMQBFbBkki
ETAwMjRFOFRSNTM5OQY7DEARSSIKd2FuaXAGOwxAEVsGSSIOMTI3LjAuMC4x
BjsMQBE7DUY7Dm87DwY7DlsAOxB7ADoOQGFkYXB0ZXJzMDoPQHBlcmZfZGF0
YTA6EUB0aHJvdWdocHV0czA6F0ByZXF1ZXN0X2FzX3N0cmluZ0kiAjYEUGFy
YW1ldGVyczoKbWFjPTAwMjRFOFRSNTMwMQptYWNfY2NvPWNjb19tYWMKbnVt
c3Rhcz01Cmd3aXA9MTI3LjAuMC4xCmd3bWFjPTAwMjRFOFRSNTM5OQpzd3Zl
cj0wLjAuMzUKdGltZT0yMgpzdGFfbWFjXzA9MDAyNEU4VFI1MzAwCnN0YV9u
YW1lXzA9VFI1MzAwCnN0YV9tYWNfMT0wMDI0RThUUjUzMDEKc3RhX25hbWVf
MT1UUjUzMDEKc3RhX21hY18yPTAwMjRFOFRSNTMwMgpzdGFfbmFtZV8yPVRS
NTMwMgpzdGFfbWFjXzM9MDAyNEU4VFI1MzAzCnN0YV9uYW1lXzM9VFI1MzAz
CnN0YV9tYWNfND0wMDI0RThUUjUzMDQKc3RhX25hbWVfND1UUjUzMDQKc3Jj
X21hY18wPTAwMjRFOFRSNTMwMApkc3RfbWFjXzA9MDAyNEU4VFI1MzAxCnJh
dGVfZndkXzA9MjEKcmF0ZV9yZXZfMD0yMQpzcmNfbWFjXzE9MDAyNEU4VFI1
MzAwCmRzdF9tYWNfMT0wMDI0RThUUjUzMDIKcmF0ZV9md2RfMT0xNgpyYXRl
X3Jldl8xPTQKc3JjX21hY18yPTAwMjRFOFRSNTMwMApkc3RfbWFjXzI9MDAy
NEU4VFI1MzAzCnJhdGVfZndkXzI9MTgKcmF0ZV9yZXZfMj01CnNyY19tYWNf
Mz0wMDI0RThUUjUzMDAKZHN0X21hY18zPTAwMjRFOFRSNTMwNApyYXRlX2Z3
ZF8zPTcKcmF0ZV9yZXZfMz04CnNyY19tYWNfND0wMDI0RThUUjUzMDEKZHN0
X21hY180PTAwMjRFOFRSNTMwMgpyYXRlX2Z3ZF80PTYKcmF0ZV9yZXZfND0y
MgpzcmNfbWFjXzU9MDAyNEU4VFI1MzAxCmRzdF9tYWNfNT0wMDI0RThUUjUz
MDMKcmF0ZV9md2RfNT0yNwpyYXRlX3Jldl81PTI2CnNyY19tYWNfNj0wMDI0
RThUUjUzMDEKZHN0X21hY182PTAwMjRFOFRSNTMwNApyYXRlX2Z3ZF82PTgK
cmF0ZV9yZXZfNj0zMQpzcmNfbWFjXzc9MDAyNEU4VFI1MzAyCmRzdF9tYWNf
Nz0wMDI0RThUUjUzMDMKcmF0ZV9md2RfNz0xMQpyYXRlX3Jldl83PTYKc3Jj
X21hY184PTAwMjRFOFRSNTMwMgpkc3RfbWFjXzg9MDAyNEU4VFI1MzA0CnJh
dGVfZndkXzg9NQpyYXRlX3Jldl84PTIyCnNyY19tYWNfOT0wMDI0RThUUjUz
MDMKZHN0X21hY185PTAwMjRFOFRSNTMwNApyYXRlX2Z3ZF85PTIwCnJhdGVf
cmV2Xzk9MTcKY29udHJvbGxlcj1uYXBpL3YxCmFjdGlvbj1wZXJmCgY7DEAX
OhhAcmVzcG9uc2VfYXNfc3RyaW5nSSJZPD94bWwgdmVyc2lvbj0iMS4wIiBl
bmNvZGluZz0iVVRGLTgiPz4KPHJlc3BvbnNlPgogIDxtc2c+Y29udGludWU8
L21zZz4KPC9yZXNwb25zZT4KBjsMQBc6E0BlcnJvcl9tZXNzYWdlMDoMQGFj
dGlvbkkiCXBlcmYGOwxAFw==", :raw=>true)
    end


end
