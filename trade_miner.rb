#!/usr/bin/env ruby

require './wowhead'


def process_list(data)
	new_data = data.reject {|d| !d.has_key?("creates")}
	return if new_data.nil?
	new_data.map do |d|
		vals = []
		vals << d["creates"][0]
		vals << "#{d["creates"][0]}:#{[(d["creates"][1] + d["creates"][2])/2, 1].max}"
		vals << d["reagents"].map {|r| "#{r[0]}:#{r[1]}"} unless d["reagents"].nil?
		vals
	end
end

BLACKLIST = [
 	35622, 35623, 35624, 35625, 35627, 36860, # Eternals
 	36919, 36922, 36925, 36928, 36931, 36934, # Wrath epic gems
]

wh = Wowhead.new
all_data = []
pages = []
[
	"/spells=11.171", # Alchemy
	"/spells=11.164", # Blacksmith
	"/spells=11.333", # Enchanting
	"/spells=11.202", # Engineering
	"/spells=11.773", # Inscription
	"/spells=11.755", # Jewelcrafting
	"/spells=11.165", # Leatherworking
	"/spells=11.186", # Mining
	"/spells=11.197", # Tailoring
].each do |page|
	pages << page
	pages << "#{page}?filter=minrs=200"
	pages << "#{page}?filter=minrs=400"
	pages << "#{page}?filter=minrs=600"
end
pages.each {|page| all_data += process_list(wh.get(page, "listviewspells"))}

enchants  = wh.get("/spells=11.333", "listviewspells")
enchants += wh.get("/spells=11.333?filter=minrs=200", "listviewspells")
enchants += wh.get("/spells=11.333?filter=minrs=400", "listviewspells")
enchants += wh.get("/spells=11.333?filter=minrs=600", "listviewspells")
scrolls = wh.get("/items=0.6&filter=na=Enchant", "listviewitems")
scrolls.reject! {|i| i["sourcemore"].nil? || i["sourcemore"].empty?}
scrolls.select! {|i| i["sourcemore"].first["c"] == 11}
scrolls.select! {|i| i["sourcemore"].first["s"] == 333}
all_data += scrolls.map do |i|
	spellid = i["sourcemore"].first["ti"]
	reagents = enchants.find {|e| e["id"] == spellid}["reagents"]
	[i["id"], "#{i["id"]}:1", "38682:1"] + reagents.map {|v| v.join ":"}
end

all_data.reject! {|a| BLACKLIST.include?(a.first)}


File.open("data.lua", "w") do |f|
	f << %Q|
local myname, ns = ...
ns.reagent_data = [[
#{all_data.uniq.sort.map {|v| v.drop(1).join(" ")}.join("\n")}
]]
|
end
