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

ActiveRecord::Schema.define(version: 20160207072918) do

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority"

  create_table "leetcodes", force: :cascade do |t|
    t.string   "email"
    t.string   "username"
    t.string   "password"
    t.integer  "slack_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "leetcodes", ["slack_id"], name: "index_leetcodes_on_slack_id"

  create_table "slacks", force: :cascade do |t|
    t.string   "slack_name"
    t.string   "slack_id"
    t.integer  "user_id"
    t.integer  "token_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "slacks", ["token_id"], name: "index_slacks_on_token_id"
  add_index "slacks", ["user_id"], name: "index_slacks_on_user_id"

  create_table "temp_tokens", force: :cascade do |t|
    t.string   "token"
    t.integer  "user_id"
    t.integer  "slack_id"
    t.integer  "leetcode_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "temp_tokens", ["leetcode_id"], name: "index_temp_tokens_on_leetcode_id"
  add_index "temp_tokens", ["slack_id"], name: "index_temp_tokens_on_slack_id"
  add_index "temp_tokens", ["user_id"], name: "index_temp_tokens_on_user_id"

  create_table "tokens", force: :cascade do |t|
    t.string   "token"
    t.string   "team_id"
    t.string   "team_domain"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",            null: false
    t.string   "crypted_password"
    t.string   "salt"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true

end
