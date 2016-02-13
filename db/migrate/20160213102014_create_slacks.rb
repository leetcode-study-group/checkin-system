class CreateSlacks < ActiveRecord::Migration
  def change
    create_table :slacks do |t|
      t.string :slack_name
      t.string :slack_id
      t.string :team_id
      t.references :user, index: true, foreign_key: true
      t.references :token, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
