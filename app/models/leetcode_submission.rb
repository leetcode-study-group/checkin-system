class LeetcodeSubmission < ActiveRecord::Base
  belongs_to :leetcode

  def update_goal
    question = LeetcodeProblem.find_by_path self.path
    return unless question
    user = User.find_by_email(Leetcode.find(self.leetcode_id).email) # TODO make leetcode belongs to user
    return unless user
    problem_goal = Goal.find_by_user_id_and_task_type_and_task(user.id, 'leetcode_problem', question.no)
    problem_goal ||= Goal.create(
      period: :daily,
      task_type: 'leetcode_problem',
      task: question.no,
      user_id: user.id,
      created_at: self.submit_time,
      updated_at: self.submit_time
    )
    problem_goal.add 1, field: :tries
    problem_goal.completed(rollback: false) if self.status =~ /\Aaccepted\z/i
  end
end
