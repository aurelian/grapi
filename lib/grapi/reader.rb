require 'curl'

module Grapi

  class Error < StandardError;end

  class Reader

    VERSION = File.read(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "VERSION"))).strip

    def initialize(verbose= false)
      @client = ::Curl::Easy.new do | easy |
        easy.headers= {
          "User-Agent"      => "Grapi::Reader /#{Grapi::Reader::VERSION} +gzip",
          "Accept-Encoding" => "gzip, deflate",
          "GData-Version"   => 2
        }
        easy.follow_location= true
        easy.verbose= true if verbose
      end
      @token= nil
    end

    def login(username, password)
      post "https://www.google.com/accounts/ClientLogin", {
        "Email" => username,
        "Passwd" => password,
        "source" => @client.headers["User-Agent"],
        "service" => "reader",
        "accountType" => "HOSTED_OR_GOOGLE"
      }
      if @client.body_str.uncompress =~ /^SID=(.*)\n/
        @client.headers['Cookie']= "SID=#{$1}"
      else
        # TODO: can we handle Error=CaptchaRequired?
        raise Error.new("Authentication failed with: #{@client.body_str.uncompress}")
      end
      self
    end

    def unsubscribe(feed_url)
      edit_subscription "feed/#{feed_url}", "unsubscribe"
    end

    def subscribe(feed_url, label= "test")
      edit_subscription "feed/#{feed_url}", "subscribe", {"a" => "user/-/label/#{label}"}
    end

    def mark_as_read(entry_ids)
      ids = Array(entry_ids).map{|e|e.to_s}
      while ids.size>0
        ids_to_post= ids.slice!(0,250)
        post_with_token "http://www.google.com/reader/api/0/edit-tag", {"i" => ids_to_post, "a" => "user/-/state/com.google/read"}
        raise Grapi::Error.new("Failed to mark as read!\n#{@client.body_str}") if @client.response_code == 400
      end
      self
    end

    # options:
    #   :continuation (default: nil) -> continuation string
    #   :dump_data (default: false) -> whether to write the response to a file in /tmp or not
    #   :output (default: atom) -> desired output (atom|json)
    #   :items (default: 1000) -> amount of items to fetch
    #   :label (default: nil) -> get only the items in label, by default fetch all items
    def reading_list(options={})
      options= {:continuation => nil, :output => "atom", :dump_data => false, :items => 1000, :label => nil}.update(options)

      base= if options[:label].nil?
              "user/-/state/com.google/reading-list"
            else
              "user/-/label/#{options[:label]}"
            end

      if options[:output] == "atom"
        get "http://www.google.com/reader/atom/#{base}?xt=user/-/state/com.google/read&ck=#{Time.now.to_i*1000}&n=#{options[:items]}&c=#{options[:continuation]}"
      else
        get "http://www.google.com/reader/api/0/stream/contents/#{base}?output=#{options[:output]}&xt=user/-/state/com.google/read&ck=#{Time.now.to_i*1000}&n=#{options[:items]}&c=#{options[:continuation]}"
      end
      response= @client.body_str.uncompress
      File.open("/tmp/#{Time.now.to_i}-reading_list.#{options[:output]}", "w"){|f|f<<response} if options[:dump_data]
      response
    end

    protected
      def get(url)
        make_request(url){|c| c.http_get }
      end

      def post(url, params)
        post_data= params.inject([]) do |memo, current|
          memo<< if current[1].kind_of? Array
            current[1].map{|it| ::Curl::PostField.content(current[0], it)}
          else
            ::Curl::PostField.content(current[0], current[1])
          end
        end
        make_request(url){|c| c.http_post(*post_data)}
      end

      def post_with_token(url, params)
        request_token if @token.nil?
        params["T"]= @token
        post url, params
      end

    private
      def edit_subscription(feed_url, action, params={})
        post_with_token "http://www.google.com/reader/api/0/subscription/edit", { "s" => "feed/#{feed_url}", "ac" => action }.update(params)
        response= @client.body_str.uncompress
        unless response == "OK"
          $stderr<< "WARN: [#{__FILE__}:#{__LINE__}] ~> response is not OK. probably token has expired!\n#{response}\n\n"
        end
      end

      def request_token
        get "http://www.google.com/reader/api/0/token"
        @token= @client.body_str.uncompress
      end

      def make_request(url)
        @client.url= url
        yield @client
        @client.perform
        self
      end
  end
end
