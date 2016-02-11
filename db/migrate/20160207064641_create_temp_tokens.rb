class CreateTempTokens < ActiveRecord::Migration
  def change
    create_table :temp_tokens do |t|
      t.string :token
      t.references :user, index: true, foreign_key: true
      t.references :slack, index: true, foreign_key: true
      t.references :leetcode, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
