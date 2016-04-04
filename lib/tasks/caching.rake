namespace :caching do
  desc "Calculating advantage and disadvantage"
  task advantage: :environment do
    players = Hash.new
    Kill.where("attacker_guid != ''").select(:attacker_guid).distinct.each do |attacker|
      id = attacker.attacker_guid
      player = Hash.new

      killers = Kill.where(target_guid: id).group(:attacker_guid).count
      killers.delete(nil)
      killers.delete(id)

      killers = Hash[killers.collect do |k, v|
        recent = Kill.where("( attacker_guid = ? AND target_guid = ? ) OR ( attacker_guid = ? AND target_guid = ? )", id, k, k, id).last(Rails.application.config.ad_trend_len).count{ |p| p.attacker_guid == k }
        [k, {
          :total => (v.to_f / Kill.where(attacker_guid: id, target_guid: k).count),
          :recent => (recent.to_f / (Rails.application.config.ad_trend_len - recent))
        }]
      end]

      player[:nemesis] = Kill.where(attacker_guid: killers.sort_by{ |key, value| -(value[:recent] - value[:total]) }.first[0]).last.attacker_name

      killed = Kill.where(attacker_guid: id).group(:target_guid).count
      killed.delete(id)

      killed = Hash[killed.collect do |k, v|
        kills = Kill.where("( attacker_guid = ? AND target_guid = ? ) OR ( attacker_guid = ? AND target_guid = ? )", id, k, k, id).last(Rails.application.config.ad_trend_len).count{ |p| p.target_guid == k }
        [k, {
          :total => (v.to_f / Kill.where(target_guid: id, attacker_guid: k).count),
          :recent => (kills.to_f / (Rails.application.config.ad_trend_len - kills))
        }]
      end]

      player[:dominating] = Kill.where(target_guid: killed.sort_by{ |key, value| -(value[:recent] - value[:total]) }.first[0]).last.target_name

      players[id] = player
    end

    File.open(Rails.application.config.ad_trend_file, 'w'){ |f| f.write players.to_yaml }
  end
end
