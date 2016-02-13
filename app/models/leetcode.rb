class Leetcode < ActiveRecord::Base
  belongs_to :slack

  validates :email, uniqueness: true
  validates :password, length: {minimum: 3}
end
