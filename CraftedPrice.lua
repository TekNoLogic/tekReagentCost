
local myname, ns = ...


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
