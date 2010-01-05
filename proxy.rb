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
    res = fetch(params['REQUEST_URI'])

    response.start(200) do |header, out|
      # Set the content type based on the HTTP_ACCEPT parameter
      header['Content-Type'] = params['HTTP_ACCEPT'].split(',').first
      out << res.body
    end
  end

  private
  def fetch(uri, limit = 10)
    response = Net::HTTP.get_response(URI.parse(uri))

    case response
      when Net::HTTPSuccess then response
      when Net::HTTPRedirection then fetch(response['location'], limit - 1)
      when Net::HTTPUnauthorized then fetch_authorized(uri)
    else
      response.error!
    end
  end

  def fetch_authorized(uri)
    url = URI.parse(uri)
    login = @credentials[url.host]

    unless login.nil?
    # This will change later, when posts are supported
      req = Net::HTTP::Get.new(url.path, {"User-Agent" => "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.A.B.C Safari/525.13"})
      req.basic_auth login['user'], login['pass']
      response = Net::HTTP.start(url.host, url.port) { |http|
        http.request(req)
      }

      # Technically this should case response for errors
    end
  end
end

# Create and start the proxy server
proxy_server = Mongrel::HttpServer.new("localhost", "3001")
proxy_server.register("/", SimpleProxy.new)
proxy_server.run.join

