
class GoalsController < SlacksController
  protect_from_forgery
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :authenticate

  def create
    args = slack_params
    text = args[:text]
    case text
    when /\A(register|signup)\z/
      return already_existed args
    end
    render json: {text: "not handled yet"}.to_json
  end

  private
  def already_existed args
    slack = Slack.find_by_slack_id args[:user_id]
    email = slack.leetcode.email
    render json: {text: "User #{slack.slack_name} already attached to Leetcode account #{email}"}.to_json
  end
end
