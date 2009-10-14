require 'rubygems'
require 'active_support'
require 'net/http'
require 'base64'
require 'right_http_connection'

$:.unshift(File.dirname(__FILE__))

begin
    require 'digest/hmac'
    USE_EMBEDDED_HMAC = false
rescue
    puts "HMAC, not found in standard lib." + $!.message
    require 'hmac-sha1'
    USE_EMBEDDED_HMAC = true
end


class CloudCache < ActiveSupport::Cache::Store

    DEFAULT_TTL = 0
    DEFAULT_HOST = "cloudcache.ws"
    DEFAULT_PORT = "80"
    DEFAULT_PROTOCOL = "http"

    attr_accessor :secret_key, :pipeline

    def initialize(access_key, secret_key, options={})
        @access_key = access_key
        @secret_key = secret_key

        @server = options[:host] || DEFAULT_HOST
        @port = options[:port] || DEFAULT_PORT
        @protocol = options[:protocol] || DEFAULT_PROTOCOL

        @default_ttl = options[:default_ttl] || DEFAULT_TTL
        @pipeline = options[:pipeline] || true

        puts 'Creating new CloudCache [default_ttl=' + @default_ttl.to_s + ', persistent_conn=' + @pipeline.to_s + ']'

        if @pipeline
            @http_conn = Rightscale::HttpConnection.new()
        end

    end

    def run_http(http_method, command_name, command_path, body=nil, parameters=nil, extra_headers=nil)
        ts = generate_timestamp(Time.now.gmtime)
        # puts 'timestamp = ' + ts
        sig = generate_signature("CloudCache", command_name, ts, @secret_key)
        # puts "My signature = " + sig
        url = @protocol + "://" + @server + "/" + command_path # todo: append port if non standard
         puts url

        user_agent = "CloudCache Ruby Client"
        headers = {'User-Agent' => user_agent, 'signature' => sig, 'timestamp' => ts, 'akey' => @access_key}

        if !extra_headers.nil?
            extra_headers.each_pair do |k, v|
                headers[k] = v
            end
        end

        if @pipeline

        end


        uri = URI.parse(url)
        #puts 'body=' + body.to_s
        if (http_method == :put)
            req = Net::HTTP::Put.new(uri.path)
            req.body = body unless body.nil?
            #puts 'BODY SIZE=' + req.body.length.to_s
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
            if !parameters.nil?
                req.set_form_data(parameters)
            end
        end
        headers.each_pair do |k, v|
            req[k] = v
        end
        # req.each_header do |k, v|
        # puts 'header ' + k + '=' + v
        #end
        if @pipeline
            req_params =  { :request  => req,
        :server   => @server,
        :port     => @port,
        :protocol => @protocol }
            res = @http_conn.request(req_params)
        else
            res = Net::HTTP.start(uri.host, uri.port) do |http|
                http.request(req)
            end
        end

#        puts 'response body=' + res.body
        case res
            when Net::HTTPSuccess
                #puts 'response body=' + res.body
                res.body
            else
                res.error!
        end

    end

    def auth()
        command_name = "auth"
        command_path = "auth"
        run_http(:get, command_name, command_path)
    end

    def put(key, val, options={})
        seconds_to_store = options[:expires_in] || options[:ttl]
        raw = options[:raw]
        #puts 'putting ' + val.to_s + ' to key=' + key
        seconds_to_store = 0 if seconds_to_store.nil?
        if raw
            data = val.to_s
        else
            data = (Marshal.dump(val))
            #data = Base64.encode64(data)
        end
        #puts 'putting=' + data.to_s
        extra_headers = seconds_to_store > 0 ? {"ttl"=>seconds_to_store} : nil
        run_http(:put, "PUT", key, data, nil, extra_headers)
    end

    def get_multi(keys, options={})
        return {} if keys.size == 0
        raw = options[:raw]
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
        val = ""
        count = 0
        body.each_line do |line|
            #print 'LINE=' + line
            if line == "END\r\n"
                # puts 'ENDED!!!'
                break
            end
            if line =~ /^VALUE (.+) (.+)/ then # (key) (bytes)
                if !curr_key.nil?
                    values[curr_key] = raw ? val.strip : Marshal.load(val.strip)
                end
                curr_key, data_length = $1, $2
                val = ""
                #raise CloudCacheError, "Unexpected response #{line.inspect}"
            else
                # data block
                val += line
            end
            count += 1
        end
        if !val.nil? && val != ""
            values[curr_key] = raw ? val.strip : Marshal.load((val.strip))
        end
        #puts 'values=' + values.inspect
        values
    end

    def get(key, options={})
        raw = options[:raw]
        begin
            data = run_http(:get, "GET", key)
        rescue Net::HTTPServerException
            # puts $!.message
            return nil if $!.message.include? "404"
            raise $!
        end
        #puts 'data1=' + data.to_s
        if raw
            return data
        else
            #data = Base64.decode64(data)
            return Marshal.load((data))
        end
    end

    # returns the value as an int.
    def get_i(key)
        val = get(key, :raw=>true)
        return nil if val.nil?
        return val.to_i
    end

    def list_keys
        body = run_http(:get, "listkeys", "listkeys")
        # puts "list_keys=" + body
        keys = ActiveSupport::JSON.decode body # body[1..-2].split(',').collect! {|n| n.to_i}
        keys
    end

    def stats
        body = run_http(:get, "myusage", "myusage")
        #keys = ActiveSupport::JSON.decode body # body[1..-2].split(',').collect! {|n| n.to_i}
        #puts 'body=' + body
        body.to_i
    end

    def usage
        return stats
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
        put(name, value, options)
    end

    def delete(name, options = nil)
        super
        begin
            run_http(:delete, "DELETE", name)
        rescue Net::HTTPServerException => ex
            puts 'CAUGHT ' + ex.response.inspect
            case ex.response
                when Net::HTTPNotFound
                    return false
                else
                    raise ex
            end
        end
        true
    end

    def remove(name, options=nil)
        delete(name, options)
    end

    def delete_matched(matcher, options = nil)
        super
        raise "delete_matched not yet supported by CloudCache"
    end

    def exist?(key, options = nil)
        exists?(key, options)
    end

    def exists?(key, options = nil)
        x = get(key, :raw=>true)
        return !x.nil?
    end

    def fetch(key, options = {})
        if (options != {})
            raise "Options on fetch() not yet supported by this library"
        end
        v = get(key)
        v
    end

    def increment(key, val=1, options={})
        headers = {"val"=>val}
        if options[:set_if_not_found]
            headers["x-cc-set-if-not-found"] = options[:set_if_not_found]
        end
        ret = run_http(:post, "POST", key + "/incr", nil, headers)
        ret.to_i
    end

    def decrement(key, val=1, options={})
        headers = {"val"=>val}
        if options[:set_if_not_found]
            headers["x-cc-set-if-not-found"] = options[:set_if_not_found]
        end
        ret = run_http(:post, "POST", key + "/decr", nil, headers)
        ret.to_i
    end

    def silence!
        super
    end

    def shutdown
        close
    end

    def close
        # close http connection if it exists.
        if @http_conn
            @http_conn.finish
        end
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


# Backwards compatability
module ActiveSupport
    module Cache
        class CloudCache < ::CloudCache
        end
    end
end
