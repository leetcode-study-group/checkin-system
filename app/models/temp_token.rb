class TempToken < ActiveRecord::Base
  include Tokenable
  after_create :sweep

  belongs_to :user
  belongs_to :slack
  belongs_to :leetcode

  def sweep(utime: 3.minutes, ctime: 15.minutes)
    if utime.is_a? String
      utime = utime.split.reduce do |count, unit|
        count.to_i.send(unit)
      end
    end
    TempToken.delete_all "updated_at < '#{utime.ago.to_s(:db)}' OR created_at < '#{ctime.ago.to_s(:db)}'"
  end
  handle_asynchronously :sweep, run_at: Proc.new {4.minutes.from_now}

end
