
local myname, ns = ...


-- Add usable items that combine or shatter, like enchanting essences
ns.reagent_data = ns.reagent_data..[[
10938:3 10939:1
10939:1 10938:3
10998:3 11082:1
11082:1 10998:3
11134:3 11135:1
11135:1 11134:3
11174:3 11175:1
11175:1 11174:3
16202:3 16203:1
16203:1 16202:3
22447:3 22446:1
22446:1 22447:3
34056:3 34055:1
34055:1 34056:3
52718:3 52719:1
52719:1 52718:3
34052:1 34053:3
52721:1 52720:3
74247:1 74252:3
]]


local function GetComponentPrices(str)
	local cost = 0
	for id,qty2 in str:gmatch("(%d+):(%d+)") do
		local price = ns.GetPrice(tonumber(id))
		if not price then return end
		cost = cost + price*tonumber(qty2)
	end
	return cost
end


ns.combineprices = setmetatable({}, {__index = function(t,i)
	t[i] = false -- Prevent overflow while we try to calculate a price

	local str = ns.reagent_data:match("\n("..i.."[^\n]+)")
	if not str then return end

	local qty, rest = str:match(i..":([%d.]+) (.+)")
	if not qty then return end

	local cost = GetComponentPrices(rest)
	if not cost then return end

	t[i] = cost / tonumber(qty)
	return cost / tonumber(qty)
end})


ns.RegisterEvent("AUCTION_ITEM_LIST_UPDATE", function()
	wipe(ns.combineprices)
end)
