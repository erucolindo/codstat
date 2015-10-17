# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150919194100) do

  create_table "kills", force: :cascade do |t|
    t.integer  "target_guid"
    t.integer  "target_id"
    t.string   "target_team"
    t.string   "target_name"
    t.integer  "attacker_guid"
    t.integer  "attacker_id"
    t.string   "attacker_team"
    t.string   "attacker_name"
    t.string   "weapon"
    t.integer  "damage"
    t.string   "damage_type"
    t.string   "damage_location"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.integer  "range"
    t.integer  "target_killstreak"
    t.integer  "attacker_killstreak"
  end

end
