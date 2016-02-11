class CreateLeetcodes < ActiveRecord::Migration
  def change
    create_table :leetcodes do |t|
      t.string :email
      t.string :username
      t.string :password
      t.references :slack, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
