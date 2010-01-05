require 'rubygems'
require 'mongrel'
require 'net/http'

# SimpleProxy
#
# A simple web proxy that supports GET/POST
# with basic authentication
class SimpleProxy < Mongrel::HttpHandler
  def process(request, response)
    res = fetch(request.params['REQUEST_URI'])

    response.start(200) do |header, out|
      header['Content-Type'] = "text/html"
      out << res.body
    end
  end

  private
  def fetch(uri)
    response = Net::HTTP.get_response(URI.parse(uri))
  end

  
end

# Create and start the proxy server
proxy_server = Mongrel::HttpServer.new("localhost", "3001")
proxy_server.register("/", SimpleProxy.new)
proxy_server.run.join

