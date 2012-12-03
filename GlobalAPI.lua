
local myname, ns = ...

local ids = LibStub("tekIDmemo")

local orig = GetReagentCost
function GetReagentCost(item)
	local id = ids[item]
	if id and ns.combineprices[id] then return ns.combineprices[id] end
	if orig then return orig(item) end
end
