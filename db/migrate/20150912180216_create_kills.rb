class CreateKills < ActiveRecord::Migration
  def change
    create_table :kills do |t|
      t.integer :target_guid
      t.integer :target_id
      t.string :target_team
      t.string :target_name
      t.integer :attacker_guid
      t.integer :attacker_id
      t.string :attacker_team
      t.string :attacker_name
      t.string :weapon
      t.integer :damage
      t.string :damage_type
      t.string :damage_location

      t.timestamps null: false
    end
  end
end
