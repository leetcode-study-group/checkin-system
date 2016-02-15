class CreateReceivers < ActiveRecord::Migration
  def change
    create_table :receivers do |t|
      t.string :team_id
      t.string :channel_name
      t.string :url

      t.timestamps null: false
    end
  end
end
