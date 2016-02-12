class CreateGoals < ActiveRecord::Migration
  def change
    create_table :goals do |t|
      t.string :period
      t.string :task_type
      t.string :task
      t.integer :tries
      t.string :progress
      t.references :user, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
