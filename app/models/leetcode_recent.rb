class LeetcodeRecent < ActiveRecord::Base
  belongs_to :user
  validates :no, presence: true
  validates :user_id, presence: true
end
