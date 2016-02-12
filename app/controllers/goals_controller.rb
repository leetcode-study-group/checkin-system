
class GoalsController < SlacksController
  protect_from_forgery
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :authenticate

  def create
    args = slack_params
    text = args[:text]
    return already_existed args if /\A(register|signup)\z/ =~ text

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

    #binding.pry
    @response = ''
    @action = :show
    task.split(/\s*;\s*/).each {|t| parse_task t} if task
    case @action
    when :show
      tasks = list_tasks
      render json: {text: @response + "\n#{@period} goal:\n#{tasks.empty? ? 'empty' : tasks}"}
    when :report
      render json: {text: @response + "REPORT PLACEHOLDER"}
    when :help
      render json: {text: USAGE}
    end
  end

  private
  def already_existed args
    slack = Slack.find_by_slack_id args[:user_id]
    email = slack.leetcode.email
    render json: {text: "User @#{slack.slack_name} already attached to Leetcode account #{email}"}
  end

  def parse_task task
    # 1, 2-3, 7
    if /\A(\d+(-\d+)?)(\s*,\s*(\d+(-\d+)?))*\z/ =~ task
      split_problems(task).each {|p| new_leetcode_task p, type: 'leetcode_problem'}

    # 3'
    elsif /\A(?<points>\d+)'\z/ =~ task
      old_point = current_goals.select {|t| t.task_type == 'leetcode_point'}[0]
      old_point = new_leetcode_task points, type: 'leetcode_point' unless old_point
      old_point.update(task: points)

    # #23
    elsif /\A#(?<completed>\d+)\z/ =~ task
      question = find_leetcode_by_no completed
      question = new_leetcode_task completed, type: 'leetcode_problem' unless question
      question.progress = (question.progress.to_i + 1).to_s
      question.save
      @response += "You have completed leetcode problem ##{completed}\n"

    # -17
    elsif /\A-(?<to_del>\d+)\z/ =~ task
      question = find_leetcode_by_no to_del
      if question and /0(%)?/ =~ question.progress
        question.delete
        @response += "You cancelled leetcode problem ##{to_del}\n"
      end

    # same as @Bob
    elsif /\Asame\s+as\s+@(?<other>[^\s]+)(:\s*)?\z/ =~ task
      msg = ''
      catch :not_found do
        msg = "Did not find user #{other}"

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
        end
      end
      @response += msg

    elsif /\A(report|progress|status)\z/ =~ task
      @action = :report

    elsif /\Areset\z/ =~ task
      current_goals.each do |g|
        if /0(%)?/ =~ g.progress
          g.delete
        elsif g.task_type == 'leetcode_point'
          g.update(task: '0')
        end
      end
      @response = "You've reset your #{@period} goals\n"

    elsif /\Ashow\z/ =~ task or !task
      @action = :show

    elsif /\Ahelp\z/ =~ task
      @action = :help

    else
      Goal.new(
        period: @period,
        task_type: 'normal',
        task: task,
        user_id: @user.id
      ).save
      # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX: add cron job to remind you complete at end of the day

    end
  end

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

  def new_leetcode_task problem, type: 'normal'
    goal = Goal.new(
      period: @period,
      task_type: type,
      task: problem.to_s,
      user_id: @user.id,
    )
    goal.save
    goal
  end

  def current_goals user: @user
    start_time = eval("Time.zone.now.beginning_of_#{@period.remove_ly}")
    Goal.where('created_at >= ? and user_id = ? and period = ?', start_time, user.id, @period)
  end

  def list_tasks
    goals = current_goals
    problems, others = goals.partition {|t| t.task_type == 'leetcode_problem'}
    point, normals = others.partition {|t| t.task_type == 'leetcode_point'}
    point = point[0]

    ((problems.empty? and !point) ? "" : "Leetcode: #{format_leetcodes problems, point}\n") +
      (normals.empty? ? "" : format_normals(normals))
  end

  def format_leetcodes problems, point
    sum = 0
    completed = 0
    problems_str = problems.map do |p|
      question = LeetcodeProblem.find_by_no(p.task.to_i)
      sum += question.point
      completed += question.point if p.done?
      "##{p.task}(#{question.difficulty})" + (p.done? ? "[DONE]" : "")
    end .join("\n")

    point = new_leetcode_task sum.to_s, type: 'leetcode_point' unless point
    point.task = sum if sum > point.task.to_i
    point.progress = completed
    point.save
    "{\n#{problems_str}\n} (#{point.progress}/#{point.task} pts)"
  end

  def format_normals normals
    normals.map {|g| g.task + (g.done? ? "[#{g.progress}]" : "")} .join("\n")
  end

  def find_leetcode_by_no no
    current_goals.select {|g| g.task_type == 'leetcode_problem' and g.task == no}[0]
  end

end

USAGE = "
Usage:
### Leetcode
NO ARGUMENTS => show your current goals
1, 2-3, 7    => set daily goal as leetcode problem #1, #2, #3 and #7
3'           => set daily goal to 3 points
#23          => finished leetcode problem #23
-7           => cancel leetcode problem #7
same as @Bob => copy Bob's daily goal

### Normal
whatever => set daily goal to 'whatever'

### Misc
report       => show today's progress
report week  => show current week's progress (valid for month, year)
signup       => to attch your leetcode account
help         => display this message

NTOE:
1. put [week|month|year] as the first word to set weekly/monthly/annual goals
2. you can set multiple goals in one command, separate them with ';'
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
