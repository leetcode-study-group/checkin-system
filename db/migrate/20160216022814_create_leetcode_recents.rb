class CreateLeetcodeRecents < ActiveRecord::Migration
  def change
    create_table :leetcode_recents do |t|
      t.integer :no
      t.references :user, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
