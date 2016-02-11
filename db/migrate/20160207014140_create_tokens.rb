class CreateTokens < ActiveRecord::Migration
  def change
    create_table :tokens do |t|
      t.string :token
      t.string :team_id
      t.string :team_domain

      t.timestamps null: false
    end
  end
end
