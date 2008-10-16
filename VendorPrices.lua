
local prices = [[
2894 50 12 -- Rhapsody Malt
1179 125 6 -- Ice Cold Milk
17196 50 12 -- Holiday Spirits
2596 120 30 -- Skin of Dwarven Stout
159 25 1 -- Refreshing Spring Water
4536 25 1 -- Shiny Red Apple
6260 50 12 -- Blue Dye
4342 2500 625 -- Purple Dye
2604 50 12 -- Red Dye
2324 25 6 -- Bleach
2325 1000 250 -- Black Dye
2605 100 25 -- Green Dye
10290 2500 625 -- Pink Dye
4341 500 125 -- Yellow Dye
6261 1000 250 -- Orange Dye
4340 350 87 -- Gray Dye
4289 50 12 -- Salt
8343 2000 500 -- Heavy Silken Thread
14341 5000 1250 -- Rune Thread
4291 500 125 -- Silken Thread
2320 10 2 -- Coarse Thread
2321 100 25 -- Fine Thread
3857 500 125 -- Coal
2880 100 25 -- Weak Flux
3466 2000 500 -- Strong Flux
18567 150000 37500 -- Elemental Flux
2928 20 5 -- Dust of Decay
2930 50 12 -- Essence of Pain
8923 200 50 -- Essence of Agony
8924 100 25 -- Dust of Deterioration
5173 100 25 -- Deathweed
8925 2500 125 -- Crystal Vial
18256 30000 1500 -- Imbued Vial
3371 20 1 -- Empty Vial
3372 200 10 -- Leaded Vial
3713 160 40 -- Soothing Spices
2665 20 5 -- Stormwind Seasoning Herbs
2678 10 0 -- Mild Spices
17194 10 0 -- Holiday Spices
2692 40 10 -- Hot Spices
4470 38 9 -- Simple Wood
11291 4500 1125 -- Star Wood
6530 100 25 -- Nightcrawlers
4399 200 50 -- Wooden Stock
4400 2000 500 -- Heavy Stock
10647 2000 500 -- Engineer's Ink
10648 500 125 -- Blank Parchment
6217 124 24 -- Copper Rod
]]


FRC_VendorSellPrices = setmetatable({}, {
	__index = function(t,i)
		local v = string.match(prices, i.." %d+ (%d+)")
		if v then
			t[i] = tonumber(v)
			return tonumber(v)
		else
			t[i] = false
			return
		end
	end,
})


FRC_VendorBuyPrices = setmetatable({}, {
	__index = function(t,i)
		local v = string.match(prices, i.." (%d+) %d+")
		if v then
			t[i] = tonumber(v)
			return tonumber(v)
		else
			t[i] = false
			return
		end
	end,
})
