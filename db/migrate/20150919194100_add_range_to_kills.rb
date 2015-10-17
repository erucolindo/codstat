class AddRangeToKills < ActiveRecord::Migration
  def change
    change_table :kills do |t|
      t.integer :range
      t.integer :target_killstreak
      t.integer :attacker_killstreak
    end
  end
end
