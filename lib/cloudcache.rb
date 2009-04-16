require 'rubygems'
require 'active_support'
require 'net/http'
require 'hmac-sha1'
require 'base64'
require 'json'

module ActiveSupport
  module Cache

    class CloudCache < Store

      attr_accessor :secret_key

      def initialize(bucket_name, access_key, secret_key)
        puts 'Creating new CloudCache'
        @access_key = access_key
        @secret_key = secret_key

      end

      def run_http(http_method, command_name, command_path, body=nil, parameters=nil, extra_headers=nil)
        ts = generate_timestamp(Time.now.gmtime)
        puts 'timestamp = ' + ts
        sig = generate_signature("CloudCache", command_name, ts, @secret_key)
        puts "My signature = " + sig
        url = "http://cloudcache.ws/" + command_path
        puts url

        user_agent = "CloudCache Ruby Client"
        headers = {'User-Agent' => user_agent, 'signature' => sig, 'timestamp' => ts, 'akey' => @access_key}

        if !extra_headers.nil?
          extra_headers.each_pair do |k, v|
            headers[k] = v
          end
        end


        uri = URI.parse(url)
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
        req.each_header do |k, v|
          puts 'header ' + k + '=' + v
        end
        res = Net::HTTP.start(uri.host, uri.port) do |http|
          http.request(req)
        end
        case res
        when Net::HTTPSuccess
          puts 'response body=' + res.body
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

      def put(key, val, seconds_to_store=0)
#        seconds_to_store = seconds_to_store > 0 ? seconds_to_store : 9999999
        puts 'seconds=' + seconds_to_store.to_s
        data = Marshal.dump(val)
        val_to_put = data #(Time.now+seconds_to_store).to_i.to_s + "::" + data
        extra_headers = seconds_to_store > 0 ? {"ttl"=>seconds_to_store} : nil
        run_http(:put, "PUT", key, val_to_put, nil, extra_headers)
      end


      def get(key)

        begin
          cache_entry = run_http(:get, "GET", key)
        rescue Net::HTTPServerException
          puts $!.message
          return nil if $!.message.include? "404"
        end
        puts 'cache_entry=' + cache_entry
=begin
        index = cache_entry.index('::')
        puts 'index=' + index.to_s
        expires = cache_entry[0..index].to_i
        puts 'expires in get=' + expires.to_s
        expires2 = (expires - Time.now.to_i)
        data = cache_entry[(index+2)...cache_entry.length]
=end

        data = cache_entry
        return Marshal.load(data)

=begin
 if expires2 > 0
          return Marshal.load(data)
        else
          puts 'expired=' + key + ' about ' + expires2.to_s + ' ago... now=' + Time.now.to_s
        end
=end

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

      def read(name, options = nil)
        #        puts 'read from localcache'
        super
        ret = get(name)
#        puts 'ret.frozen=' + ret.frozen?.to_s
        return ret
      end

      def write(name, value, options = nil)
        super
        put(name, value, options.nil? ? nil : options[:expires_in])
#        puts 'write.frozen=' + value.frozen?.to_s
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
        x = get(key)
        r = true
        if (x == nil)
          r = false
        end
        r
      end

      def fetch(key , options = {})
        if (options != {})
          raise "Options on fetch() not yet supported by this library"
        end
        v = get(key)
        v
      end

      def increment(key,val=1)
        ret = run_http(:post, "POST", key + "/incr", nil, {"val"=>val})
        ret.to_i
      end

      def decrement(key,val=1)
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
        my_sha_hmac = HMAC::SHA1.digest(secret_access_key, service + operation + timestamp)
        my_b64_hmac_digest = Base64.encode64(my_sha_hmac).strip
        return my_b64_hmac_digest
      end
    end
  end
end
