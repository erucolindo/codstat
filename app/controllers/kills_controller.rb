class KillsController < ApplicationController
  KD_TREND_LEN = 100
  HS_TREND_LEN = 50
  AD_TREND_LEN = 30

  def index
    @players = Hash.new
    Kill.where("attacker_guid != ''").select(:attacker_guid).distinct.each do |attacker|
      player = Hash.new
      player[:id] = attacker.attacker_guid
      player[:name] = Kill.where(attacker_guid: player[:id]).last.attacker_name
      player[:kills] = Kill.where(attacker_guid: player[:id]).count
      player[:deaths] = Kill.where(target_guid: player[:id]).count
      player[:kd] = (player[:kills].to_f / player[:deaths])

      kd_recent = Kill.where("attacker_guid = ? OR target_guid = ?", player[:id], player[:id]).last(KD_TREND_LEN)
      player[:kd_trend] = (kd_recent.count{ |k| k.attacker_guid == player[:id] }.to_f / kd_recent.count{ |k| k.target_guid == player[:id] }) > player[:kd]
      player[:headshots] = (Kill.where(attacker_guid: player[:id], damage_type: "MOD_HEAD_SHOT").count.to_f / player[:kills])

      hs_recent = Kill.where(attacker_guid: player[:id]).last(HS_TREND_LEN)
      player[:headshots_trend] = (hs_recent.count{ |k| k.damage_type == "MOD_HEAD_SHOT" }.to_f / hs_recent.count) > player[:headshots]
      player[:fav_gun] = Kill.where(attacker_guid: player[:id]).group(:weapon).count.sort_by{ |k, v| -v }.first[0]

      player[:longest_kill] = Kill.where("attacker_guid = ? AND weapon NOT IN (?)", player[:id], getWeapon("Grenade")).maximum("range")
      player[:longest_kill] = 0 unless player[:longest_kill]
      player[:longest_killstreak] = Kill.where(target_guid: player[:id]).maximum("target_killstreak")
      player[:longest_killstreak] = 0 unless player[:longest_killstreak]

      @players[player[:id]] = player
    end

    @players.each do |player_id, player|
      killers = Kill.where(target_guid: player[:id]).group(:attacker_guid).count
      killers.delete(nil)

      killers = Hash[killers.collect do |k, v|
        recent = Kill.where("( attacker_guid = ? AND target_guid = ? ) OR ( attacker_guid = ? AND target_guid = ? )", player[:id], k, k, player[:id]).last(AD_TREND_LEN).count{ |p| p.attacker_guid == k }
        [k, {
          :total => (v.to_f / Kill.where(attacker_guid: player[:id], target_guid: k).count),
          :recent => (recent.to_f / (AD_TREND_LEN - recent))
        }]
      end]

      player[:nemesis] = Kill.where(attacker_guid: killers.sort_by{ |key, value| -(value[:recent] - value[:total]) }.first[0]).last.attacker_name

      killed = Kill.where(attacker_guid: player[:id]).group(:target_guid).count

      killed = Hash[killed.collect do |k, v| 
        kills = Kill.where("( attacker_guid = ? AND target_guid = ? ) OR ( attacker_guid = ? AND target_guid = ? )", player[:id], k, k, player[:id]).last(AD_TREND_LEN).count{ |p| p.target_guid == k }
        [k, {
          :total => (v.to_f / Kill.where(target_guid: player[:id], attacker_guid: k).count),
          :recent => (kills.to_f / (AD_TREND_LEN - kills))
        }]
      end]

      player[:dominating] = Kill.where(target_guid: killed.sort_by{ |key, value| -(value[:recent] - value[:total]) }.first[0]).last.target_name
    end

    @players = @players.values

    sort = case params[:sort]
    when "kills"
      :kills
    when "deaths"
      :deaths
    when "kd"
      :kd
    when "hs"
      :headshots
    when "ks"
      :longest_killstreak
    when "range"
      :longest_kill
    when "adv"
      :dominating
    when "dis"
      :nemesis
    when "weapon"
      :fav_gun
    else
      :name
    end

    if [:name, :dominating, :nemesis, :fav_gun].include? sort
      @players.sort_by!{ |player| player[sort].gsub(/\^\d/, '').downcase }
    else
      @players.sort_by!{ |player| -player[sort] }
    end

    @title = "Leaderboard"
  end

  def show
    @player = Hash.new
    @player[:name] = Kill.where(attacker_guid: params[:id]).last.attacker_name
    @player[:kills] = Kill.where(attacker_guid: params[:id]).count
    @player[:deaths] = Kill.where(target_guid: params[:id]).count
    @player[:kd] = (@player[:kills].to_f / @player[:deaths])
    @player[:headshots] = ((Kill.where(attacker_guid: params[:id], damage_type: "MOD_HEAD_SHOT").count.to_f / @player[:kills]) * 100)
    @player[:kill_per_team] = Kill.where(attacker_guid: params[:id]).group(:attacker_team).count
    @player[:teamkills] = Kill.where(attacker_guid: params[:id], attacker_team: "allies", target_team: "allies").count + Kill.where(attacker_guid: params[:id], attacker_team: "axis", target_team: "axis").count
    @player[:teamkilled] = Kill.where(target_guid: params[:id], attacker_team: "allies", target_team: "allies").count + Kill.where(target_guid: params[:id], attacker_team: "axis", target_team: "axis").count
    @player[:grenade_kills] = Kill.where(attacker_guid: params[:id], damage_type: "MOD_GRENADE_SPLASH").count
    @player[:grenade_deaths] = Kill.where(target_guid: params[:id], damage_type: "MOD_GRENADE_SPLASH").count
    @player[:name_changes] = Kill.where(attacker_guid: params[:id]).select(:attacker_name).distinct.count
    @player[:melee_kills] = Kill.where(attacker_guid: params[:id], damage_type: "MOD_MELEE").count
    @player[:melee_deaths] = Kill.where(target_guid: params[:id], damage_type: "MOD_MELEE").count
    @player[:hit_bias] = ((Kill.where("target_guid = ? AND damage_location LIKE 'right%'", params[:id]).count - Kill.where("target_guid = ? AND damage_location LIKE 'left%'", params[:id]).count).to_f / @player[:deaths]).round(3)
    @player[:longest_range] = Kill.where("attacker_guid = ? AND weapon NOT IN (?)", params[:id], getWeapon("Grenade")).maximum("range")
    @player[:longest_killstreak] = Kill.where(target_guid: params[:id]).maximum("target_killstreak")
    ranges = Kill.where("attacker_guid = ? AND range != '' AND weapon NOT IN (?)", params[:id], getWeapon("Grenade"))
    ranges.count == 0 ? @player[:average_range] = 'N/A' : @player[:average_range] = ranges.sum("range") / ranges.count 

    @player[:killstreaks] = [["Killing Spree", 5, 9], ["Rampage", 10, 14], ["Dominating", 15, 19], ["Unstoppable", 20, 24], ["GODLIKE", 25, 100]].collect{ |k| [k[0], Kill.where("target_guid = ? AND target_killstreak BETWEEN ? AND ?", params[:id], k[1], k[2]).count] }
    @player[:killstreaks].delete_if{ |k| k[1] == 0 }

    @player[:matchups] = Kill.where(attacker_guid: params[:id]).group(:target_guid).count
    @player[:matchups].delete(params[:id].to_i)
    @player[:matchups] = @player[:matchups].map{ |k, v| { :name => Kill.where(target_guid: k).last.target_name, :kd => (v.to_f / Kill.where(attacker_guid: k, target_guid: params[:id]).count) } }.sort_by{ |k| -k[:kd] }

    @player[:killed_by] = Kill.where("target_guid = ? AND damage_type != 'MOD_SUICIDE'", params[:id]).group(:attacker_guid).count.map{ |k, v| { :name => Kill.where(attacker_guid: k).last.attacker_name, :kills => v, :percentage => ((v.to_f / @player[:deaths]) * 100) } }.sort_by{ |player| -player[:kills] }
    @player[:killed] = Kill.where("attacker_guid = ? AND target_guid != ? AND damage_type != 'MOD_SUICIDE'",  params[:id], params[:id]).group(:target_guid).count.map{ |k, v| { :name => Kill.where(target_guid: k).last.target_name, :kills => v, :percentage => ((v.to_f / @player[:kills]) * 100) } }.sort_by{ |player| -player[:kills] }

    @player[:killed_with_gun] = Kill.where(attacker_guid: params[:id]).group(:weapon).count.map{ |k, v| { :name => k, :kills => v, :percentage => ((v.to_f / @player[:kills]) * 100).to_i } }.sort_by{ |gun| -gun[:kills] }
    @player[:killed_with_gun].each{ |kill| kill[:divergence] = kill[:percentage] - ((Kill.where(weapon: kill[:name]).count.to_f / Kill.count) * 100).to_i }
    @player[:killed_by_gun] = Kill.where(target_guid: params[:id]).group(:weapon).count.map{ |k, v| { :name => k, :kills => v, :percentage => ((v.to_f / @player[:deaths]) * 100).to_i } }.sort_by{ |gun| -gun[:kills] }
    @player[:killed_by_gun].each{ |kill| kill[:divergence] = kill[:percentage] - ((Kill.where(weapon: kill[:name]).count.to_f / Kill.count) * 100).to_i }

    @player[:killed_with_guntype] = sortWeapons(Kill.where(attacker_guid: params[:id]).group(:weapon).count).map{ |k, v| { :name => k, :kills => v, :percentage => ((v.to_f / @player[:kills]) * 100).to_i } }.sort_by{ |gun| -gun[:kills] } 
    @player[:killed_with_guntype].each{ |kill| kill[:divergence] = kill[:percentage] - ((Kill.where(weapon: getWeapon(kill[:name])).count.to_f / Kill.count) * 100).to_i }
    @player[:killed_by_guntype] = sortWeapons(Kill.where(target_guid: params[:id]).group(:weapon).count).map{ |k, v| { :name => k, :kills => v, :percentage => ((v.to_f / @player[:deaths]) * 100).to_i } }.sort_by{ |gun| -gun[:kills] } 
    @player[:killed_by_guntype].each{ |kill| kill[:divergence] = kill[:percentage] - ((Kill.where(weapon: getWeapon(kill[:name])).count.to_f / Kill.count) * 100).to_i }

    @player[:killed_with_damage] = Kill.where(attacker_guid: params[:id]).group(:damage_location).count.map{ |k, v| { :name => k, :kills => v, :percentage => ((v.to_f / @player[:kills]) * 100).to_i } }.sort_by{ |damage| -damage[:kills] }
    @player[:killed_with_damage].each{ |kill| kill[:divergence] = kill[:percentage] - ((Kill.where(damage_location: kill[:name]).count.to_f / Kill.count) * 100).to_i }
    @player[:killed_by_damage] = Kill.where(target_guid: params[:id]).group(:damage_location).count.map{ |k, v| { :name => k, :kills => v, :percentage => ((v.to_f / @player[:deaths]) * 100).to_i } }.sort_by{ |damage| -damage[:kills] }
    @player[:killed_by_damage].each{ |kill| kill[:divergence] = kill[:percentage] - ((Kill.where(damage_location: kill[:name]).count.to_f / Kill.count) * 100).to_i }

    @title = @player[:name]
  end

  def weapons
    @weapons = Hash.new
    @weapons[:kills] = Kill.group(:weapon).count.map{ |k, v| { :weapon => k, :kills => v, :percentage => ((v.to_f / Kill.count) * 100).to_i } }
    @weapons[:kills].each do |w|
      top = Kill.where(weapon: w[:weapon]).group(:attacker_guid).count.sort_by{ |k, v| -v }.first
      w[:top_fragger_name] = Kill.where(attacker_guid: top[0]).last.attacker_name
      w[:top_fragger_kills] = top[1]
      w[:top_fragger_percentage] = ((w[:top_fragger_kills].to_f / w[:kills]) * 100).to_i
      ranges = Kill.where("weapon = ? AND range != ''", w[:weapon])
      if ranges.count == 0
        w[:average_range] = 'N/A'
        w[:longest_range] = 'N/A'
        w[:longest_name] = 'N/A'
      else
        w[:average_range] = ranges.sum("range") / ranges.count
        w[:longest_range] = ranges.maximum("range")
        w[:longest_name] = Kill.where(attacker_guid: ranges.order(range: :desc).first.attacker_guid).last.attacker_name
      end
    end

    @weapons[:kills_by_type] = sortWeapons(Kill.group(:weapon).count).map{ |k, v| { :weapon => k, :kills => v, :percentage => ((v.to_f / Kill.count) * 100).to_i } }
    @weapons[:kills_by_type].each do |t|
      top = Kill.where(weapon: getWeapon(t[:weapon])).group(:attacker_guid).count.sort_by{ |k, v| -v }.first
      t[:top_fragger_name] = Kill.where(attacker_guid: top[0]).last.attacker_name
      t[:top_fragger_kills] = top[1]
      t[:top_fragger_percentage] = ((t[:top_fragger_kills].to_f / t[:kills]) * 100).to_i
      ranges = Kill.where("weapon IN (?) AND range != ''", getWeapon(t[:weapon]))
      if ranges.count == 0
        t[:average_range] = 'N/A'
        t[:longest_range] = 'N/A'
        t[:longest_name] = 'N/A'
      else
        t[:average_range] = ranges.sum("range") / ranges.count
        t[:longest_range] = ranges.maximum("range")
        t[:longest_name] = Kill.where(attacker_guid: ranges.order(range: :desc).first.attacker_guid).last.attacker_name
      end
    end

    sort = case params[:sort]
    when "name"
      :weapon
    when "fragger"
      :top_fragger_kills
    when "avg"
      :average_range
    when "max"
      :longest_range
    else
      :kills
    end

    if sort == :weapon
      @weapons[:kills].sort_by!{ |weapon| weapon[:weapon].gsub(/\^\d/, '').downcase }
      @weapons[:kills_by_type].sort_by!{ |weapon| weapon[:weapon].gsub(/\^\d/, '').downcase }
    else
      @weapons[:kills].sort_by!{ |weapon| weapon[sort].is_a?(Integer) ? -weapon[sort] : 0 }
      @weapons[:kills_by_type].sort_by!{ |weapon| weapon[sort].is_a?(Integer) ? -weapon[sort] : 0 }
    end

    @title = "Weapons"
  end

  def weapon
    @players = Hash.new
    weapon = Kill.where(weapon: params[:id])
    @players[:kills] = weapon.group(:attacker_guid).count.map{ |k, v| { :name => Kill.where(attacker_guid: k).last.attacker_name, :kills => v } }
    @players[:kills].each{ |k| k[:percentage] = ((k[:kills].to_f / weapon.count) * 100).to_i }
    @players[:kills].sort_by!{ |k| -k[:kills] }
    @players[:deaths] = weapon.group(:target_guid).count.map{ |k, v| { :name => Kill.where(target_guid: k).last.target_name, :kills => v } }
    @players[:deaths].each{ |k| k[:percentage] = ((k[:kills].to_f / weapon.count) * 100).to_i }
    @players[:deaths].sort_by!{ |k| -k[:kills] }


    @title = params[:id]
  end

  def type
    @players = Hash.new
    type = Kill.where(weapon: getWeapon(params[:id]))
    @players[:kills] = type.group(:attacker_guid).count.map{ |k, v| { :name => Kill.where(attacker_guid: k).last.attacker_name, :kills => v } }
    @players[:kills].each{ |k| k[:percentage] = ((k[:kills].to_f / type.count) * 100).to_i }
    @players[:kills].sort_by!{ |k| -k[:kills] }
    @players[:deaths] = type.group(:target_guid).count.map{ |k, v| { :name => Kill.where(target_guid: k).last.target_name, :kills => v } }
    @players[:deaths].each{ |k| k[:percentage] = ((k[:kills].to_f / type.count) * 100).to_i }
    @players[:deaths].sort_by!{ |k| -k[:kills] }

    @title = params[:id]
  end

  def raw
    @kills = Kill.where("target_guid LIKE ? AND target_id LIKE ? AND target_team LIKE ? AND target_name LIKE ? AND attacker_guid LIKE ? AND attacker_id LIKE ? AND attacker_team LIKE ? AND attacker_name LIKE ? AND weapon LIKE ? AND damage LIKE ? AND damage_type LIKE ? AND damage_location LIKE ?", 
      params[:target_guid].presence || "%",
      params[:target_id].presence || "%",
      "%" + (params[:target_team].presence || "") + "%",
      "%" + (params[:target_name].presence || "") + "%",
      params[:attacker_guid].presence || "%",
      params[:attacker_id].presence || "%",
      "%" + (params[:attacker_team].presence || "") + "%",
      "%" + (params[:attacker_name].presence || "") + "%",
      "%" + (params[:weapon].presence || "") + "%",
      params[:damage].presence || "%",
      "%" + (params[:damage_type].presence || "") + "%",
      "%" + (params[:damage_location].presence || "") + "%"
      ).last(1000)

    @title = "RAW"
  end

  def export
    @kills = Kill.all
    
    send_data @kills.as_csv
  end

  private
  def sortWeapons(weapons)
    weapon_types = Hash.new
    weapons.each do |weapon, value|
      type = case weapon
      when "thompson_mp", "greasegun_mp", "sten_mp", "PPS42_mp", "ppsh_mp", "mp40_mp"
        "SMG"
      when "mp44_mp", "bren_mp", "bar_mp"
        "Machine Gun"
      when "SVT40_mp", "g43_mp", "m1carbine_mp", "m1garand_mp"
        "Rifle"
      when "mosin_nagant_mp", "kar98k_mp", "enfield_mp"
        "Bolt Action"
      when "mosin_nagant_sniper_mp", "springfield_mp", "kar98k_sniper_mp", "enfield_scope_mp"
        "Sniper"
      when "frag_grenade_german_mp", "frag_grenade_american_mp", "frag_grenade_russian_mp", "frag_grenade_british_mp"
        "Grenade"
      when "shotgun_mp"
        "Shotgun"
      when "mg42_bipod_stand_mp", "30cal_stand_mp"
        "Mounted"
      when "luger_mp", "webley_mp", "TT30_mp", "colt_mp"
        "Pistol"
      else
        nil
      end

      if type
        weapon_types[type] ? weapon_types[type] = weapon_types[type] + value : weapon_types[type] = value
      end
    end
    return weapon_types
  end

  def getWeapon(type)
    return case type
    when "SMG"
      ["thompson_mp", "greasegun_mp", "sten_mp", "PPS42_mp", "ppsh_mp", "mp40_mp"]
    when "Machine Gun"
      ["mp44_mp", "bren_mp", "bar_mp"]
    when "Rifle"
      ["SVT40_mp", "g43_mp", "m1carbine_mp", "m1garand_mp"]
    when "Bolt Action"
      ["mosin_nagant_mp", "kar98k_mp", "enfield_mp"]
    when "Sniper"
      ["mosin_nagant_sniper_mp", "springfield_mp", "kar98k_sniper_mp", "enfield_scope_mp"]
    when "Grenade"
      ["frag_grenade_german_mp", "frag_grenade_american_mp", "frag_grenade_russian_mp", "frag_grenade_british_mp"]
    when "Shotgun"
      "shotgun_mp"
    when "Mounted"
      ["mg42_bipod_stand_mp", "30cal_stand_mp"]
    when "Pistol"
      ["luger_mp", "webley_mp", "TT30_mp", "colt_mp"]
    end
  end
end
