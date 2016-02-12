class Goal < ActiveRecord::Base
  belongs_to :user
  validates :user_id, presence: true
  validates :task, presence: true
  validates :task_type, presence: true
  validates_uniqueness_of :task, scope: [:user_id, :task_type]

  after_initialize :set_default

  def set_default
    self.progress ||= case self.task_type
                      when 'leetcode_problem', 'leetcode_point'
                        '0'
                      else
                        '0%'
                      end
    self.tries ||= 0
  end

  def done?
    case self.task_type
    when 'leetcode_problem'
      # progress as AC number
      self.progress.to_i > 0

    when 'leetcode_point'
      # progress as current point, task as goal point
      self.progress.to_i > self.task.to_i

    when /100%/, /done/i
      true
    else
      false
    end
  end

end
