require 'rubygems'
require 'mongrel'
require 'net/http'

# SimpleProxy
#
# A simple web proxy that supports GET/POST
# with basic authentication
class SimpleProxy < Mongrel::HttpHandler
  def initialize
    @credentials = YAML::load(File.open('config.yml'))
  end

  def process(request, response)
    params = request.params
    res = fetch(params['REQUEST_URI'], params['REQUEST_METHOD'], post_data(request))

    response.start(200) do |header, out|
      header['Content-Type'] = params['HTTP_ACCEPT'].split(',').first
      out << res.body
    end
  end

  private
  def fetch(uri, request_method, post_data, limit = 10)
    url = URI.parse(uri)
    login = get_credentials(url.host)

    if login.nil?
      response = get_response(request_method, url, post_data)
    else
      response = get_auth_response(request_method, url, post_data, login)
    end

    case response
      when Net::HTTPSuccess then response
      when Net::HTTPRedirection then return fetch(response['location'], request_method, post_data, limit - 1)
    else
      response.error!
    end

    response
  end

  def get_credentials(host)
    # This was originally just a lookup into the hash but ran into issues with subdomains
    @credentials.each do |domain, login|
      return login if host.match(domain)
    end

    nil
  end

  def post_data(request)
    Mongrel::HttpRequest.query_parse(request.body.readlines.first)
  end

  def get_response(request_method, url, post_data)
    case request_method
      when "GET" then Net::HTTP.get_response(url)
      when "POST" then Net::HTTP.post_form(url, post_data)
    end
  end

  def get_auth_response(request_method, url, post_data, login)
    req = build_request_class(request_method, url.path, post_data)
    req.basic_auth login['user'], login['pass']
    response = Net::HTTP.start(url.host, url.port) { |http|
      http.request(req)
    }
  end

  def build_request_class(request_method, url, post_data)
    case request_method
      when "POST" then
        req = Net::HTTP::Post.new(url)
        req.set_form_data(post_data)
      when "GET" then req = Net::HTTP::Get.new(url)
    end

    req
  end
end

# Create and start the proxy server
proxy_server = Mongrel::HttpServer.new("localhost", "3001")
proxy_server.register("/", SimpleProxy.new)
proxy_server.run.join
