class CreateLeetcodeProgresses < ActiveRecord::Migration
  def change
    create_table :leetcode_progresses do |t|
      t.integer :ac
      t.integer :submissions
      t.references :leetcode, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
