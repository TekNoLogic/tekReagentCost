
local myname, ns = ...

local ids = LibStub("tekIDmemo")

local orig = GetReagentCost
function GetReagentCost(item)
	local recipe_id = tonumber(item:match("^recipe:(%d+)$"))
	if recipe_id then
		ns.GetRecipeCost(recipe_id)
		if ns.combineprices[item] then return ns.combineprices[item] end
	else
		local id = ids[item]
		if id and ns.combineprices[id] then return ns.combineprices[id] end
	end
	if orig then return orig(item) end
end


function HasBoundReagents(id)
	return ns.has_bound_reagents[id]
end
