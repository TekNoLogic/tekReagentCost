
local myname, ns = ...


local prices = [[
159 25 1 -- Refreshing Spring Water
1179 125 6 -- Ice Cold Milk
2320 10 2 -- Coarse Thread
2321 100 25 -- Fine Thread
2324 25 6 -- Bleach
2325 1000 250 -- Black Dye
2596 120 30 -- Skin of Dwarven Stout
2604 50 12 -- Red Dye
2605 100 25 -- Green Dye
2665 20 5 -- Stormwind Seasoning Herbs
2678 10 0 -- Mild Spices
2692 40 10 -- Hot Spices
2880 100 25 -- Weak Flux
2894 50 12 -- Rhapsody Malt
2928 20 5 -- Dust of Decay
2930 50 12 -- Essence of Pain
3371 20 1 -- Empty Vial
3372 200 10 -- Leaded Vial
3466 2000 500 -- Strong Flux
3713 160 40 -- Soothing Spices
3857 500 125 -- Coal
4289 50 12 -- Salt
4291 500 125 -- Silken Thread
4340 350 87 -- Gray Dye
4341 500 125 -- Yellow Dye
4342 2500 625 -- Purple Dye
4399 200 50 -- Wooden Stock
4400 2000 500 -- Heavy Stock
4470 38 9 -- Simple Wood
4536 25 1 -- Shiny Red Apple
5173 100 25 -- Deathweed
6217 124 24 -- Copper Rod
6260 50 12 -- Blue Dye
6261 1000 250 -- Orange Dye
6530 100 25 -- Nightcrawlers
8343 2000 500 -- Heavy Silken Thread
8923 200 50 -- Essence of Agony
8924 100 25 -- Dust of Deterioration
8925 2500 125 -- Crystal Vial
10290 2500 625 -- Pink Dye
10647 2000 500 -- Engineer's Ink
10648 125  -- Common Parchment
10648 500 125 -- Blank Parchment
11291 4500 1125 -- Star Wood
14341 5000 1250 -- Rune Thread
17194 10 0 -- Holiday Spices
17196 50 12 -- Holiday Spirits
18256 30000 1500 -- Imbued Vial
18567 150000 37500 -- Elemental Flux
38426 30000 -- Eternium Thread
39354 15   -- Light Parchment
39501 1250 -- Heavy Parchment
39502 5000 -- Resilient Parchment
39684 9000 -- Hair Trigger
40411 10000 -- Enchanted Vial
40533 50000 -- Walnut Stock
44500 15000000 -- Goblin-machined Piston (for Mechano-hog)
44501 10000000 -- Goblin-machined Piston (for Mechano-hog)
44999 30000000 -- Salvaged Iron Golem Parts (for Mechano-hog)
52188 3750 -- Jeweler's Setting
]]


ns.vendor = setmetatable({}, {
	__index = function(t,i)
		local v = string.match(prices, i.." (%d+)")
		if v then
			t[i] = tonumber(v)
			return tonumber(v)
		else
			t[i] = false
			return
		end
	end,
})
