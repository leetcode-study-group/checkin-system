class CreateLeetcodeSubmissions < ActiveRecord::Migration
  def change
    create_table :leetcode_submissions do |t|
      t.datetime :submit_time
      t.string :path
      t.string :status
      t.string :detail_path
      t.string :runtime
      t.string :lang
      t.references :leetcode, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
