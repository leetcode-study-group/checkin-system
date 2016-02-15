class Goal < ActiveRecord::Base
  belongs_to :user
  validates :user_id, presence: true
  validates :task, presence: true
  validates :task_type, presence: true
  validates_uniqueness_of :task, scope: [:user_id, :period, :task_type]

  after_initialize :set_default

  def done?
    case self.task_type
    when 'leetcode_problem'
      # progress as AC number
      self.progress.to_i > 0
    when 'leetcode_point'
      # progress as current point, task as goal point
      self.progress.to_i > self.task.to_i
    else
      # progress as percentage
      self.progress =~ /100/ or self.progress =~ /done/i
    end
  end

  def completed progress: nil
    case self.task_type
    when 'leetcode_point'
      add progress # progress as problem point
    when 'leetcode_problem'
      add 1        # progress as AC number
    else
      self.progress = progress # overwrite for normals
    end
    self.save
  end

  ####### static queries
  def self.point_goal time, user_id, period
    p_goal = Goal.where(
      created_at: time.period_range(period),
      period: period,
      task_type: 'leetcode_point',
      user_id: user_id
    )[0]
    p_goal ? p_goal : Goal.create(
      period: period,
      task_type: 'leetcode_point',
      user_id: user_id
    )
  end

  def self.leetcode_problems time, user_id, period
    Goal.goals_of_type time, user_id, period, 'leetcode_problem'
  end

  def self.normal_goals time, user_id, period
    Goal.goals_of_type time, user_id, period, 'normal'
  end

  ####### method versions
  def point_goal period
    Goal.point_goal self.created_at, self.user_id, period
  end

  def leetcode_problems period
    Goal.leetcode_problems self.created_at, self.user_id, period
  end

  def normal_goals period
    Goal.normal_goals self.created_at, self.user_id, period
  end

  protected

  def self.goals_of_type time, user_id, period, type
    Goal.where(
      created_at: time.period_range(period),
      task_type: type,
      user_id: user_id
    )
  end

  def set_default
    self.task ||= '0'
    self.progress ||= '0'
    self.tries ||= 0
  end

  def add num_str
    self.progress = (self.progress.to_i + num.to_i).to_s
  end

  def update_points point
    [:daily, :weekly, :monthly, :annual].each do |period|
      point_goal(period: period).completed point
    end
  end

end

class Time
  def period_range period
    eval(
      ['beginning', 'end'].map { |t|
        "self.#{t}_of_#{period.remove_ly}"
      } .join('..')
    )
  end
end

class String
  def remove_ly
    self.to_sym.remove_ly
  end
end

class Symbol
  def remove_ly
    case self
    when :daily
      'day'
    when :weekly
      'week'
    when :monthly
      'month'
    when :annual
      'year'
    else
      self
    end
  end
end
