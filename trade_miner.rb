#!/usr/bin/env ruby

require './wowhead'


def process_list(data)
	new_data = data.reject {|d| !d.has_key?("creates")}
	return if new_data.nil?
	new_data.map do |d|
		vals = []
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
pages.each {|page| all_data += process_list(wh.get(page, "spells"))}

enchants = wh.get("/spells=11.333", "spells")
scrolls = wh.get("/items=0.6&filter=na=Enchant")
scrolls = scrolls.select {|i| i["name"] =~ /^\dScroll of / || i["name"] =~ /^\dEnchant /}
scrolls.map! {|i| [i["name"].gsub(/^\d(Scroll of )?/, '').gsub(/Bracers/, "Bracer"), i["id"], i["level"]]}
enchants = enchants.reject {|e| e["reagents"].nil?}.map {|e| [e["name"][1..-1].gsub(/Bracers/, "Bracer"), e["reagents"].map {|r| r.join(":")}.join(" ")]} #.reject {|name,reagents| !scrolls.assoc(name)}
all_data += scrolls.map {|s| (s + [enchants.assoc(s[0])]).flatten}.reject {|s| s.last.nil?}.map {|name,id,lvl,name2,reagents| ["#{id}:1", "38682:1", reagents]}
all_data.reject! {|a,b| BLACKLIST.include?(a.split(":").first.to_i)}


File.open("data.lua", "w") do |f|
	f << %Q|
TEK_REAGENT_COST_DATA = [[
#{all_data.sort.map {|v| v.join(" ")}.join("\n")}
]]
|
end
