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
      killers.delete(player[:id])

      killers = Hash[killers.collect do |k, v|
        recent = Kill.where("( attacker_guid = ? AND target_guid = ? ) OR ( attacker_guid = ? AND target_guid = ? )", player[:id], k, k, player[:id]).last(AD_TREND_LEN).count{ |p| p.attacker_guid == k }
        [k, {
          :total => (v.to_f / Kill.where(attacker_guid: player[:id], target_guid: k).count),
          :recent => (recent.to_f / (AD_TREND_LEN - recent))
        }]
      end]

      player[:nemesis] = Kill.where(attacker_guid: killers.sort_by{ |key, value| -(value[:recent] - value[:total]) }.first[0]).last.attacker_name

      killed = Kill.where(attacker_guid: player[:id]).group(:target_guid).count
      killed.delete(player[:id])

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
    @player[:name_changes] = Kill.where(attacker_guid: params[:id]).select(:attacker_name).uniq.collect{ |a| a.attacker_name }
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

    
    @charts = Hash.new
    n = (@player[:kills] + @player[:deaths]) - [1000, @player[:kills] + @player[:deaths]].min
    @charts[:kd] = Kill.where("attacker_guid = ? OR target_guid = ?", params[:id], params[:id]).last(1000).each_slice(KD_TREND_LEN).to_a.collect do |kills| 
      [n = n + 100, (kills.count{ |k| k.attacker_guid == params[:id].to_i }.to_f / kills.count{ |k| k.target_guid == params[:id].to_i }).round(2)]
    end

    @charts[:range] = Kill.where(attacker_guid: params[:id]).group(:range).count
    @charts[:range].delete(nil)

    @charts[:range_hs] = Kill.where(attacker_guid: params[:id], damage_type: "MOD_HEAD_SHOT").group(:range).count
    @charts[:range_hs].delete(nil)

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
    weapon = Kill.where(weapon: params[:id])

    @charts = Hash.new
    @charts[:range] = weapon.group(:range).count
    @charts[:range].delete(nil)
    @charts[:range_hs] = weapon.where(damage_type: "MOD_HEAD_SHOT").group(:range).count
    @charts[:range_hs].delete(nil)
    @charts[:kills] = Hash[weapon.group(:attacker_guid).count.map{ |k, v| [ pretty_name(Kill.where(attacker_guid: k).last.attacker_name), v ] }.sort_by{ |v| v[0] }]
    @charts[:deaths] = Hash[weapon.group(:target_guid).count.map{ |k, v| [ pretty_name(Kill.where(target_guid: k).last.target_name), v ] }.sort_by{ |v| v[0] }]

    @charts[:kills_percent] = Hash.new
    Kill.where("attacker_guid != ''").select(:attacker_guid).distinct.each do |player|
      id = player.attacker_guid
      name = pretty_name(Kill.where(attacker_guid: id).last.attacker_name)
      @charts[:kills_percent][name] = ((Kill.where(attacker_guid: id, weapon: params[:id]).count.to_f / Kill.where(attacker_guid: id).count) * 100).round(1)
    end
    @charts[:kills_percent] = Hash[@charts[:kills_percent].sort_by{ |k, v| -v }]

    @title = params[:id]
  end

  def type
    type = Kill.where(weapon: getWeapon(params[:id]))

    @charts = Hash.new
    @charts[:range] = type.group(:range).count
    @charts[:range].delete(nil)
    @charts[:range_hs] = type.where(damage_type: "MOD_HEAD_SHOT").group(:range).count
    @charts[:range_hs].delete(nil)
    @charts[:kills] = Hash[type.group(:attacker_guid).count.map{ |k, v| [ pretty_name(Kill.where(attacker_guid: k).last.attacker_name), v ] }.sort_by{ |v| v[0] }]
    @charts[:deaths] = Hash[type.group(:target_guid).count.map{ |k, v| [ pretty_name(Kill.where(target_guid: k).last.target_name), v ] }.sort_by{ |v| v[0] }]

    @charts[:kills_percent] = Hash.new
    Kill.where("attacker_guid != ''").select(:attacker_guid).distinct.each do |player|
      id = player.attacker_guid
      name = pretty_name(Kill.where(attacker_guid: id).last.attacker_name)
      @charts[:kills_percent][name] = ((Kill.where(attacker_guid: id, weapon: getWeapon(params[:id])).count.to_f / Kill.where(attacker_guid: id).count) * 100).round(1)
    end
    @charts[:kills_percent] = Hash[@charts[:kills_percent].sort_by{ |k, v| -v }]

    @title = params[:id]
  end

  def charts
    @charts = Hash.new
    @charts[:kills] = Hash[Kill.where("attacker_guid != ''").group(:attacker_guid).count.map{ |k, v| [pretty_name(Kill.where(:attacker_guid => k).last.attacker_name), v] }.sort_by{ |v| v[0] }]
    @charts[:deaths] = Hash[Kill.where("target_guid != ''").group(:target_guid).count.map{ |k, v| [pretty_name(Kill.where(:target_guid => k).last.target_name), v] }.sort_by{ |v| v[0] }]

    @charts[:ranges_avg] = Hash.new
    @charts[:ranges_long] = Hash.new
    @charts[:kd] = Hash.new
    @charts[:headshots] = Hash.new
    @charts[:headshoted] = Hash.new

    Kill.where("attacker_guid != ''").select(:attacker_guid).distinct.each do |player|
      id = player.attacker_guid
      name = pretty_name(Kill.where(attacker_guid: id).last.attacker_name)
      range = Kill.where("attacker_guid = ? AND weapon NOT IN (?)", id, getWeapon("Grenade")).maximum("range")
      range ? @charts[:ranges_long][name] = range : @charts[:ranges_long][name] = 0
      ranges = Kill.where("attacker_guid = ? AND range != '' AND weapon NOT IN (?)", id, getWeapon("Grenade"))
      ranges.count == 0 ? @charts[:ranges_avg][name] = 0 : @charts[:ranges_avg][name] = ranges.sum("range") / ranges.count 
      @charts[:kd][name] = (Kill.where(attacker_guid: id).count.to_f / Kill.where(target_guid: id).count).round(2)
      @charts[:headshots][name] = ((Kill.where(attacker_guid: id, damage_type: "MOD_HEAD_SHOT").count.to_f / Kill.where(attacker_guid: id).count) * 100).round(1)
      @charts[:headshoted][name] = ((Kill.where(target_guid: id, damage_type: "MOD_HEAD_SHOT").count.to_f / Kill.where(target_guid: id).count) * 100).round(1)
    end

    @charts[:kd] = Hash[@charts[:kd].sort_by{ |k, v| -v }]
    @charts[:headshots] = Hash[@charts[:headshots].sort_by{ |k, v| -v }]
    @charts[:ranges_long] = Hash[@charts[:ranges_long].sort_by{ |k, v| -v }]

    @title = "Charts"
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

  def pretty_name(name)
    if name == ''
      "Environment"
    else
      name.gsub(/\^\d/, '')
    end
  end
end
