require 'rubygems'
require 'active_support'
require 'net/http'
require 'base64'

$:.unshift(File.dirname(__FILE__))

begin
    require 'digest/hmac'
    USE_EMBEDDED_HMAC = false
rescue
    puts "HMAC, not found in standard lib." + $!.message
    require 'hmac-sha1'
    USE_EMBEDDED_HMAC = true
end



module ActiveSupport
    module Cache

        class CloudCache < Store


            attr_accessor :secret_key

            def initialize(access_key, secret_key)
                puts 'Creating new CloudCache'
                @access_key = access_key
                @secret_key = secret_key

            end

            def run_http(http_method, command_name, command_path, body=nil, parameters=nil, extra_headers=nil)
                ts = generate_timestamp(Time.now.gmtime)
                # puts 'timestamp = ' + ts
                sig = generate_signature("CloudCache", command_name, ts, @secret_key)
                # puts "My signature = " + sig
                url = "http://cloudcache.ws/" + command_path
                # puts url

                user_agent = "CloudCache Ruby Client"
                headers = {'User-Agent' => user_agent, 'signature' => sig, 'timestamp' => ts, 'akey' => @access_key}

                if !extra_headers.nil?
                    extra_headers.each_pair do |k, v|
                        headers[k] = v
                    end
                end


                uri = URI.parse(url)
                #puts 'body=' + body.to_s
                if (http_method == :put)
                    req = Net::HTTP::Put.new(uri.path)
                    req.body = body unless body.nil?
                elsif (http_method == :post)
                    req = Net::HTTP::Post.new(uri.path)
                    if !parameters.nil?
                        req.set_form_data(parameters)
                    end
                elsif (http_method == :delete)
                    req = Net::HTTP::Delete.new(uri.path)
                    if !parameters.nil?
                        req.set_form_data(parameters)
                    end
                else
                    req = Net::HTTP::Get.new(uri.path)
                end
                headers.each_pair do |k, v|
                    req[k] = v
                end
                # req.each_header do |k, v|
                # puts 'header ' + k + '=' + v
                #end
                res = Net::HTTP.start(uri.host, uri.port) do |http|
                    http.request(req)
                end
                case res
                    when Net::HTTPSuccess
                        # puts 'response body=' + res.body
                        res.body
                    else
                        res.error!
                end

            end

            def auth()
                command_name =  "auth"
                command_path = "auth"
                run_http(:get, command_name, command_path)
            end

            def put(key, val, seconds_to_store=0, raw=false)
                seconds_to_store = 0 if seconds_to_store.nil?
                if raw
                    data = val.to_s
                else
                    data = (Marshal.dump(val))
                end
                #puts 'putting=' + data.to_s
                extra_headers = seconds_to_store > 0 ? {"ttl"=>seconds_to_store} : nil
                run_http(:put, "PUT", key, data, nil, extra_headers)
            end


            def get_multi(keys, raw=false)
                kj = keys.to_json
                #puts "keys.to_json = " + kj
                extra_headers = {"keys" => kj }
                #puts "get_multi, extra_headers keys =  " + extra_headers.keys.to_s
                #puts "get_multi, extra_headers vals = " + extra_headers.values.to_s
                body = run_http(:get, "GET", "getmulti", nil, nil, extra_headers)
                #puts 'body=' + body.to_s
                # todo: should try to stream the body in
                #vals = ActiveSupport::JSON.decode body
                # New response format is:
                # VALUE <key>  <bytes> \r\n
                # <data block>\r\n
                # VALUE <key>  <bytes> \r\n
                # <data block>\r\n
                # END
                values = {}
                curr_key = nil
                data_length = 0
                body.each_line do |line|
                    break if line == "END\r\n"
                    if line =~ /^VALUE (.+) (.+)/ then # (key) (bytes)
                        curr_key, data_length = $1, $2
                        #raise CloudCacheError, "Unexpected response #{line.inspect}"
                    else
                        # data block
                        values[curr_key] = raw ? line.strip : Marshal.load(line.strip)
                    end
                end
                #puts 'values=' + values.inspect
                values
            end

            def get(key, raw=false)
                begin
                    data = run_http(:get, "GET", key)
                rescue Net::HTTPServerException
                    # puts $!.message
                    return nil if $!.message.include? "404"
                    raise $!
                end
                # puts 'data=' + data.to_s
                if raw
                    return data
                else
                    return Marshal.load((data))
                end
            end

            # returns the value as an int.
            def get_i(key)
                val = get(key, true)
                return nil if val.nil?
                return val.to_i
            end

            def list_keys
                body = run_http(:get, "listkeys", "listkeys")
                keys = ActiveSupport::JSON.decode body # body[1..-2].split(',').collect! {|n| n.to_i}
                keys
            end

            def stats
                body = run_http(:get, "mystats", "mystats")
                #keys = ActiveSupport::JSON.decode body # body[1..-2].split(',').collect! {|n| n.to_i}
                body
            end


            def flush
                body = run_http(:get, "flush", "flush")
                body.strip
            end

            def clear
                flush
            end

            def read(name, options={})
                super
                ret = get(name)
                return ret
            end

            def write(name, value, options={})
                super
                put(name, value, options[:expires_in], options[:raw])
            end

            def delete(name, options = nil)
                super
                run_http(:delete, "DELETE", name)
            end

            def delete_matched(matcher, options = nil)
                super
                raise "delete_matched not yet supported by CloudCache"
            end

            def exist?(key, options = nil)
                x = get(key, true)
                return !x.nil?
            end

            def fetch(key, options = {})
                if (options != {})
                    raise "Options on fetch() not yet supported by this library"
                end
                v = get(key)
                v
            end

            def increment(key, val=1)
                ret = run_http(:post, "POST", key + "/incr", nil, {"val"=>val})
                ret.to_i
            end

            def decrement(key, val=1)
                ret = run_http(:post, "POST", key + "/decr", nil, {"val"=>val})
                ret.to_i
            end

            def silence!
                super
            end

            def shutdown

            end


            def generate_timestamp(gmtime)
                return gmtime.strftime("%Y-%m-%dT%H:%M:%SZ")
            end

            def generate_signature(service, operation, timestamp, secret_access_key)
                if USE_EMBEDDED_HMAC
                    my_sha_hmac = HMAC::SHA1.digest(secret_access_key, service + operation + timestamp)
                else
                    my_sha_hmac = Digest::HMAC.digest(service + operation + timestamp, secret_access_key, Digest::SHA1)
                end
                my_b64_hmac_digest = Base64.encode64(my_sha_hmac).strip
                return my_b64_hmac_digest
            end

            class CloudCacheError < RuntimeError

            end
        end
    end
end
