class SlacksController < ApplicationController

  protected
  def slack_params
    params.permit(
      :token,
      :team_id, :team_domain,
      :user_id, :user_name,
      :channel_id, :channel_name,
      :timestamp,
      :text,
      :trigger_word,
      :service_id, :bot_id, :bot_name
    )
  end

  def authenticate
    args = slack_params
    @token = Token.find_by_token_and_team_id_and_team_domain(
      args[:token], args[:team_id], args[:team_domain]
    )
    return render plain: 'Authenticate failed' unless @token

    @team_id = args[:team_id]
    @slack_id = args[:user_id]
    @slack = Slack.find_by_slack_id_and_token_id(
      @slack_id, @token.id
    )
    @slack_name = args[:user_name]

    new_slack
    attach_leetcode
  end

  def new_slack
    unless @slack
      @slack = Slack.new(
        slack_id: @slack_id,
        slack_name: @slack_name,
        team_id: @team_id,
        token_id: @token.id
      )
      @slack.save
    end
  end

  def attach_leetcode
    @leetcode = Leetcode.find_by_slack_id @slack.id
    unless @leetcode
      @leetcode = Leetcode.new
      temp_token = TempToken.create(slack_id: @slack.id)
      render json: {text: "It seems that you didn't attach your Leetcode account.
Please click the following link to sign up in 5 minutes.
<http://#{default_url_options[:host]}:3000/leetcodes/new?temp_token=#{temp_token.token}>"}.to_json
    end
  end

  # via Incoming webhook
  def send_to_slack json
    receiver = Receiver.find_by_team_id @team_id
    return false unless receiver

    uri = URI.parse(receiver.url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if URI::HTTPS === uri

    request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json'})
    request.body = json.to_json

    http.request(request)
  end

end
