class LeetcodeProblem < ActiveRecord::Base
  validates :no, uniqueness: true, presence: true

  def point
    case self.difficulty
    when /easy/i
      1
    when /medium/i
      3
    when /hard/i
      5
    else
      0
    end
  end
end
