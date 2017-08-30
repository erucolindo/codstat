namespace :import do
  desc "Imports and clears the CoD2 logfile"
  task logs: :environment do
    lines = Array.new
    File.open('/usr/games/cod2/main/games_mp.log', 'r+') do |file|
      file.each do |line|
        lines.push line
      end
      file.truncate(0) 
    end
    
    lines.each do |line|
      data = line.sub(/\s*\d+:\d\d\s/, '').strip.split(";")
      if data[0] == "K"
        if data.length > 12
          Kill.create(target_guid: data[1], target_id: data[2], target_team: data[3], target_name: data[4], attacker_guid: data[5], attacker_id: data[6], attacker_team: data[7], attacker_name: data[8], weapon: data[9], damage: data[10], damage_type: data[11], damage_location: data[12], range: data[13], target_killstreak: data[14], attacker_killstreak: data[15])
        else
          Kill.create(target_guid: data[1], target_id: data[2], target_team: data[3], target_name: data[4], attacker_guid: data[5], attacker_id: data[6], attacker_team: data[7], attacker_name: data[8], weapon: data[9], damage: data[10], damage_type: data[11], damage_location: data[12])
        end
      end
    end
  end

  desc "Removes whitespace from database"
  task update: :environment do
    Kill.all.each{ |kill| kill.update(damage_location: kill.damage_location.strip) }
  end

  desc "Remove Instagib kills"
  task instagib: :environment do
    Kill.where(damage: 10000).each{ |kill| kill.destroy }
  end
  
  desc "Attempt to fix unauthenticaded users"
  tast fix_guid: :environment do
    Kill.where(attacker_guid: 0).select(:attacker_name).distinct.each do |attacker|
      candidate = Kill.where("attacker_guid != 0 AND attacker_name = ?", attacker.attacker_name).first.attacker_guid
      if candidate
        new_guid = candidate.attacker_guid
        Kill.where(attacker_guid: 0, attacker_name: attacker.attacker_name).each do |kill|
          kill.update(attacker_guid: new_guid)
        end
      end
    end
    Kill.where(target_guid: 0).select(:target_name).distinct.each do |target|
      candidate = Kill.where("target_guid != 0 AND target_name = ?", attacker.target_name).first.target_guid
      if candidate
        new_guid = candidate.target_guid
        Kill.where(target_guid: 0, target_name: attacker.target_name).each do |kill|
          kill.update(target_guid: new_guid)
        end
      end
    end
  end

end
