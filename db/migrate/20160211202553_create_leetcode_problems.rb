class CreateLeetcodeProblems < ActiveRecord::Migration
  def change
    create_table :leetcode_problems do |t|
      t.integer :no
      t.string :title
      t.string :difficulty
      t.string :path

      t.timestamps null: false
    end

    require File.expand_path('../../../bin/collect/leetcode_problems.rb', __FILE__)
  end
end
