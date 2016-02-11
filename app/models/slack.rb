class Slack < ActiveRecord::Base
  belongs_to :user
  belongs_to :token
  has_one :leetcode

  validates :slack_id, presence: true, uniqueness: true
end
