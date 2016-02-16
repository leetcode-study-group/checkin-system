class Receiver < ActiveRecord::Base
  def send_to_slack json
    uri = URI.parse(receiver.url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if URI::HTTPS === uri

    request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json'})
    request.body = json.to_json

    http.request(request)
  end
end
