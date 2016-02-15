# coding: utf-8

class GoalsController < SlacksController
  protect_from_forgery
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :authenticate

  def create
    args = slack_params
    text = args[:text]

    slack = Slack.find_by_slack_id args[:user_id]
    @user = User.find(slack.user_id)

    /\A(?<time>day|week(ly)?|month(ly)?|year(ly)?|annual)?\s*(?<task>.*)\z/ =~ text
    @period = case time
             when /week(ly)?/
               :weekly
             when /month(ly)?/
               :monthly
             when /year(ly)?|annual/
               :annual
             else
               :daily
             end

    @response = ''
    @broadcast = ''
    @action = :show
    task.split(/\s*;\s*/).each {|t| parse_task t} if task

    unless @broadcast.empty?
      send_to_slack({text: @broadcast, attachments: goals_sumary})
      @action = :report
    end

    case @action
    when :show
      tasks = list_tasks
      render json: {text: @response + "#{@period}: #{tasks.empty? ? 'empty' : tasks}"}
    when :report
      render nothing: true
    when :help
      render json: {text: USAGE}
    end
  end

  private

  def parse_task task
    # 1, 2-3, 7
    if /\A(\d+(-\d+)?)(\s*,\s*(\d+(-\d+)?))*\z/ =~ task
      split_problems(task).each {|p| new_task p, type: 'leetcode_problem'}
      @broadcast = "#{@slack_name} updated the #{@period} goal!"

    # 3'
    elsif /\A(?<points>\d+)('|\u2019)\z/ =~ task # the Slack may auto transfer ' to ’
      old_point = current_goals.select {|t| t.task_type == 'leetcode_point'}[0]
      old_point = new_task points, type: 'leetcode_point' unless old_point
      old_point.update(task: points)
      @broadcast = "#{@slack_name} updated the #{@period} goal!"

    # #23
    elsif /\A#(?<completed>\d+)\z/ =~ task
      question = find_leetcode_by_no completed
      question = new_task completed, type: 'leetcode_problem' unless question
      question.completed
      @broadcast = "#{@slack_name} just completed ##{completed}!"

    elsif /\Adone\s+(?<normal>.+)\z/ =~ task
      normals = Goal.normal_goals(Time.zone.now, @user.id, @period)
      if normals.empty?
        @response = "You don't have normal tasks in your #{@period} goals.\n"
        return
      end

      candidates = normals.select {|g| g.task.index normal}
      if candidates.length == 1
        candidates[0].completed
        @response += "You've completed task: #{candidates[0].task}\n"
      else
        candidates = normals if candidates.empty?
        @response = "Your task words are ambiguous, please be more specific.\n"
      end

    # -17
    elsif /\A-(?<to_del>\d+)\z/ =~ task
      question = find_leetcode_by_no to_del
      if question and /0(%)?/ =~ question.progress
        question.delete
        @response += "You cancelled leetcode problem ##{to_del}\n"
        @broadcast = ""
      end

    # copy @Bob
    elsif /\A(same\s+as|copy)\s+@(?<other>[^\s]+)(:\s*)?\z/ =~ task
      msg = ''
      catch :not_found do
        msg = "Copy #{other} failed...\n"
        @broadcast = ""

        slack = Slack.find_by_slack_name other
        throw :not_found unless slack

        him = User.find slack.user_id
        throw :not_found unless him

        my_goals = current_goals
        his_goals = current_goals user: him
        his_goals.each do |g|
          if g.task_type == 'leetcode_point' and
            point = my_goals.select {|g| g.task_type == 'leetcode_point'}[0]
            point.update(task: g.task)
          else
            Goal.new(
              period: g.period,
              task_type: g.task_type,
              task: g.task,
              user_id: @user.id
            ).save
          end
          msg = "You copied #{other}'s goals\n"
          @broadcast = "#{@slack_name} copied #{other}'s #{@period} goals!"
        end
      end
      @response += msg

    elsif /\A(report|progress|status)\z/ =~ task
      @action = :report
      @broadcast = "#{@slack_name} shared #{@period} goals."

    elsif /\Areset\z/ =~ task
      current_goals.each do |g|
        if /0(%)?/ =~ g.progress
          g.delete
        elsif g.task_type == 'leetcode_point'
          g.update(task: '0')
        end
      end
      @response = "You've reset your #{@period} goals\n"
      @broadcast = ""

    elsif /\Ashow\z/ =~ task or !task
      @action = :show
      @broadcast = ""

    elsif /\A:\s*(?<normal>.*)\z/ =~ task
      Goal.new(
        period: @period,
        task_type: 'normal',
        task: normal,
        user_id: @user.id
      ).save
      # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX: add cron job to remind you complete at end of the day
      @broadcast = "#{@slack_name} updated the #{@period} goal!"

    else
      @action = :help
      @broadcast = ""

    end
  end

  # "7, 1-3, 3, 8" => [1, 2, 3, 7, 8]
  def split_problems str
    str.gsub('-', '..').split(/\s*,\s*/).map {|e| eval(e)} .reduce([]) do |nos, e|
      case e
      when Range
        nos += e.to_a
      else
        nos.push e
      end
    end .sort.uniq
  end

  def new_task problem, period: @period, type: 'normal'
    Goal.create(task: problem.to_s, period: period, task_type: type, user_id: @user.id)
  end

  def current_goals user: @user, period: @period, task_type: nil
    start_time = eval("Time.now.beginning_of_#{period.remove_ly}")
    goals = Goal.where('created_at >= ? and user_id = ? and period = ?', start_time, user.id, period)
    task_type ? goals.select {|g| g.task_type == task_type} : goals
  end

  # => "{ 1(M) | 7(E) } (0/4) ; os homework"
  def list_tasks user: @user
    "#{format_leetcodes(user:user)}; #{format_normals(user:user)}"
  end

  def format_leetcodes user: @user
    problems = Goal.leetcode_problems Time.zone.now, user.id, @period
    return "" if problems.empty?
    point = problems[0].point_goal
    problems_str = problems.map do |p|
      question = LeetcodeProblem.find_by_no(p.task.to_i)
      "#{p.task}(#{question.difficulty[0]})" + (p.done? ? "\u2705" : "")
    end .join(" | ")

    point = Goal.new(task: '0', progress: '0') unless point
    "{ #{problems_str} } (#{point.progress}/#{point.task})"
  end

  def format_normals user: @user
    normals = Goal.normal_goals Time.zone.now, user.id, @period
    return "" if normals.empty?
    normals.select {|g| !g.done?
    } .map {|g| g.task + (g.progress[0] != '0' ? "[#{g.progress}]" : "")} .join("; ")
  end

  def find_leetcode_by_no no
    current_goals.select {|g| g.task_type == 'leetcode_problem' and g.task == no}[0]
  end

  def update_points no
    question = LeetcodeProblem.find_by_no(no)
    return unless question
    point = question.point
    [:daily, :weekly, :monthly, :annual].each do |period|
      pt = current_goals(period: period, task_type: 'leetcode_point')[0]
      pt = new_task '0', period: period, type: 'leetcode_point' unless pt
      pt.progress = (pt.progress.to_i + point).to_s
      pt.save
    end
  end

  def goals_sumary
    members = Slack.where('team_id = ?', @team_id)
    sumary = members.map do |m|
      next unless m.user_id
      user = User.find m.user_id
      tasks = list_tasks(user: user)
      tasks =~ /\A\s*;\s*\z/ ? nil : "#{m.slack_name}: #{list_tasks(user: user)}"
    end .compact.join("\n")
    [{text: sumary}]
  end

end

USAGE = "
------------------------------------------------------------------------------
Usage:
### Leetcode
NO ARGUMENTS => show your current goals
1, 2-3, 7    => set daily goal as leetcode problem #1, #2, #3 and #7
3'           => set daily goal to 3 points
#23          => finished leetcode problem #23
-7           => cancel leetcode problem #7
copy @Bob => copy Bob's daily goal
done algo      => complete a normal task which contains word 'algo'

:whatever => set daily goal to 'whatever'

report       => show today's progress

NOTE: put [week|month|year] as the first word to set weekly/monthly/annual goals
------------------------------------------------------------------------------
"

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
