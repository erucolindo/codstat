module KillsHelper
  def pretty_name(name)
    if name == ''
      "Environment"
    else
      name.gsub(/\^\d/, '')
    end
  end

  def pretty_location(name)
    name.split('_').map(&:capitalize).join(' ')
  end

  def pretty_gun(name)
    case name
    when "kar98k_sniper_mp"
      "Scoped Kar98k"
    when "shotgun_mp"
      "M1897 Trench Gun"
    when "g43_mp"
      "Gewehr 43"
    when "thompson_mp"
      "Thompson"
    when "kar98k_mp"
      "Kar98k"
    when "mp40_mp"
      "MP40"
    when "enfield_scope_mp"
      "Scoped Lee-Enfield"
    when "m1garand_mp"
      "M1 Garand"
    when "springfield_mp"
      "Springfield"
    when "enfield_mp"
      "Lee-Enfield"
    when "greasegun_mp"
      "Grease Gun"
    when "sten_mp"
      "Sten"
    when "mosin_nagant_mp"
      "Mosin-Nagant"
    when "m1carbine_mp"
      "M1A1 Carbine"
    when "mg42_bipod_stand_mp"
      "MG42"
    when "PPS42_mp"
      "PPS42"
    when "frag_grenade_german_mp"
      "Stielhandgranate"
    when "mp44_mp"
      "MP44"
    when "mosin_nagant_sniper_mp"
      "Scoped Mosin-Nagant"
    when "ppsh_mp"
      "PPSh"
    when "SVT40_mp"
      "Tokarev SVT-40"
    when "frag_grenade_british_mp"
      "Mills Bomb"
    when "frag_grenade_american_mp"
      "Mk 2 Grenade"
    when "bren_mp"
      "Bren LMG"
    when "bar_mp"
      "BAR"
    when "luger_mp"
      "Luger"
    when "TT30_mp"
      "TT-30"
    when "30cal_stand_mp"
      "Browning M1919"
    when "webley_mp"
      "Webley"
    when "frag_grenade_russian_mp"
      "RGD-33 Grenade"
    when "colt_mp"
      "M1911"
    else
      name.gsub(/_mp\z/, '')
    end
  end
end
