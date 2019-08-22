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

ActiveRecord::Schema.define(version: 0) do

  create_table "list_data", id: :integer, force: :cascade, options: "ENGINE=MyISAM DEFAULT CHARSET=latin1" do |t|
    t.integer "list_id", null: false
    t.integer "track_id", null: false
    t.boolean "is_active"
    t.integer "ordering", null: false
    t.boolean "is_playing"
    t.text "comments"
    t.index ["list_id", "ordering"], name: "ordering_ix1", unique: true
    t.index ["track_id", "list_id"], name: "list_data_ix0"
  end

  create_table "lists", primary_key: "list_id", id: :integer, default: nil, force: :cascade, options: "ENGINE=MyISAM DEFAULT CHARSET=latin1" do |t|
    t.string "name", limit: 50
    t.date "start_time"
    t.date "end_time"
    t.string "command", limit: 1024
    t.string "ctrl"
  end

  create_table "tracks", primary_key: "track_id", id: :integer, force: :cascade, options: "ENGINE=MyISAM DEFAULT CHARSET=latin1" do |t|
    t.string "name", limit: 45
    t.string "path"
    t.string "artist", limit: 45
    t.string "album", limit: 45
    t.integer "track"
  end

end
