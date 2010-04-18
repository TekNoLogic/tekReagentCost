#!/usr/bin/env ruby

require 'wowhead'


def process_list(data)
	new_data = data.reject {|d| !d.has_key?("creates")}
	new_data.map do |d|
		vals = []
		vals << "#{d["creates"][0]}:#{(d["creates"][1] + d["creates"][2])/2}"
		vals << d["reagents"].map {|r| "#{r[0]}:#{r[1]}"}
		vals
	end
end


wh = Wowhead.new
all_data = []
pages = [
	"/spells=11.171", # Alchemy
	"/spells=11.164", # Blacksmith
	"/spells=11.333", # Enchanting
	"/spells=11.202", # Engineering
	"/spells=11.773", # Inscription
	"/spells=11.755", # Jewelcrafting
	"/spells=11.165", # Leatherworking
	"/spells=11.186", # Mining
	"/spells=11.197", # Tailoring
]
pages.each {|page| all_data += process_list(wh.get(page, "spells"))}

enchants = wh.get("/spells=11.333", "spells")
scrolls = wh.get("/items=0.6&filter=na=Scroll+of")
scrolls.map! {|i| [i["name"][11..-1], i["id"], i["level"]]}
weapon_scrolls = scrolls.select {|i| i[0] =~ /Enchant( 2H)? Weapon/}
enchants = enchants.reject {|e| e["reagents"].nil?}.map {|e| [e["name"][1..-1], e["reagents"].map {|r| r.join(":")}.join(" ")]} #.reject {|name,reagents| !scrolls.assoc(name)}
all_data += scrolls.map {|s| (s + [enchants.assoc(s[0])]).flatten}.reject {|s| s.last.nil?}.map {|name,id,lvl,name2,reagents| ["#{id}:1", "#{weapon_scrolls.assoc(name) ? "43146" : "43145"}:1", reagents]}


File.open("data.lua", "w") do |f|
	f << %Q|
TEK_REAGENT_COST_DATA = [[
#{all_data.sort.map {|v| v.join(" ")}.join("\n")}
]]
|
end
