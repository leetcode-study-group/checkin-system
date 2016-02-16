class Goal < ActiveRecord::Base
  belongs_to :user
  validates :user_id, presence: true
  validates :task, presence: true
  validates :task_type, presence: true
  validates_uniqueness_of :task, scope: [:user_id, :period, :task_type], if: lambda {|o| o.task_type != 'leetcode_point'}

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

  def completed progress=nil, rollback: true
    case self.task_type
    when 'leetcode_point'
      raise "Can't complete a leetcode point"
    when 'leetcode_problem'
      Goal.add_rollback(self.user_id, self.period, self.id, -1) if rollback
      progress ||= 1
      add progress # progress as AC number
      if self.progress == '1'
        question = LeetcodeProblem.find_by_no self.task
        self.point_goal.update_points(question.point, rollback: rollback)
      end
    else
      progress ||= '100'
      self.progress = progress # overwrite for normals
      self.save
    end
  end

  ####### static queries
  def self.point_goal time, user_id, period, created_at: time
    p_goal = Goal.where(
      created_at: time.period_range(period),
      period: period,
      task_type: 'leetcode_point',
      user_id: user_id
    )[0]
    p_goal ? p_goal : Goal.create(
      period: period,
      task_type: 'leetcode_point',
      user_id: user_id,
      created_at: created_at,
    )
  end

  def self.leetcode_problems time, user_id, period
    Goal.goals_of_type time, user_id, period, 'leetcode_problem'
  end

  def self.normal_goals time, user_id, period
    Goal.goals_of_type time, user_id, period, 'normal'
  end

  def self.add_rollback user_id, period, task_id, progress
    rollback = Goal.where(task_type: 'rollback', user_id: user_id, period: period, task: task_id)[0]
    if rollback
      rollback.add progress
      rollback
    else
      Goal.create(task_type: 'rollback', user_id: user_id, period: period, task: task_id,
        progress: progress
      )
    end
  end

  def self.rollback
    Goal.where(task_type: 'rollback').each do |r|
      Goal.find(r.task).add r.progress
      r.delete
    end
  end

  ####### method versions
  def point_goal period: self.period
    Goal.point_goal self.created_at, self.user_id, period
  end

  def leetcode_problems period: self.period
    Goal.leetcode_problems self.created_at, self.user_id, period
  end

  def normal_goals period: self.period
    Goal.normal_goals self.created_at, self.user_id, period
  end

  def add num_str, field: :progress
    eval("self.#{field} = (self.#{field}.to_i + num_str.to_i).to_s")
    self.save
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

  def update_points point, rollback: true
    [:daily, :weekly, :monthly, :annual].each do |period|
      goal = point_goal(period: period)
      goal.add point
      Goal.add_rollback(goal.user_id, goal.period, goal.id, "-#{point}") if rollback
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
