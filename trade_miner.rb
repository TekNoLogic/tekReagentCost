#! /c/ruby/bin/ruby

require 'net/http'
require 'rubygems'
require 'json'


def parse_list(raw_data)
	# Sanitize our data
	data = raw_data.gsub(/"/, "TOKEN1").gsub(/\\'/, "TOKEN2").gsub(/'/, '"').gsub(/([{,])([^{:,]+):/, '\1"\2":').gsub(/TOKEN2/, "'").gsub(/TOKEN1/, "'")
	JSON.parse(data)
end


def process_list(data)
	new_data = data.reject {|d| !d.has_key?("creates")}
	new_data.map do |d|
		vals = []
		vals << "#{d["creates"][0]}:#{(d["creates"][1] + d["creates"][2])/2}"
		vals << d["reagents"].map {|r| "#{r[0]}:#{r[1]}"}
		vals.join(" ")
	end
end


all_data = []
Net::HTTP.start("www.wowhead.com") do |http|
	pages = [
		"/?spells=11.171", # Alchemy
		"/?spells=11.164", # Blacksmith
		"/?spells=11.333", # Enchanting
		"/?spells=11.202", # Engineering
		"/?spells=11.773", # Inscription
		"/?spells=11.755", # Jewelcrafting
		"/?spells=11.165", # Leatherworking
		"/?spells=11.186", # Mining
		"/?spells=11.197", # Tailoring
	]
	pages.each do |page|
		res = http.get(page)
		data = parse_list($1) if res.body =~ /data: (.+)\}\);\n\/\/\]\]><\/script>/m
		all_data += process_list(data)
	end
end

File.open("data.lua", "w") do |f|
	f << %Q|
TEK_REAGENT_COST_DATA = [[
#{all_data.join("\n")}
]]
|
end
