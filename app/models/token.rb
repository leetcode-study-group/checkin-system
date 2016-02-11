class Token < ActiveRecord::Base
  has_many :slacks

  validates :token, presence: true, uniqueness: true
  validates :team_id, presence: true
  validates :team_domain, presence: true
end
