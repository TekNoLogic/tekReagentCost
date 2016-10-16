
local myname, ns = ...


-- Lookup one of the reagents and figure out its price
-- Returns:
--  price - the reagent's cost, if unable to calculate this will be nil
--  is_bop - boolean indicating that the reagent is bop and cannot be crafted,
--           therefore no price can be given for it
local function GetRecipeReagentCost(recipe_id, reagent_index)
	local link = C_TradeSkillUI.GetRecipeReagentItemLink(recipe_id, reagent_index)
	if not link then return end

	local itemid = ns.ids[link]
	if ns.bound_reagents[itemid] then return nil, true end

	local price = ns.GetPrice(itemid)
	if not price then return end

	local _, _, count = C_TradeSkillUI.GetRecipeReagentInfo(recipe_id, reagent_index)
	return price * count
end


-- Calculate the price to craft a recipe and cache its result for future use
-- Returns:
--   cost - the total cost to make the recipe
--   incomplete - a boolean indicating that we couldn't get the cost for at
--                least one reagent
function ns.GetRecipeCost(recipe_id)
	local cost, incomplete = 0
	local num = C_TradeSkillUI.GetRecipeNumReagents(recipe_id)
	if not num then return 0, true end

	local has_bound_reagents
	for i=1,num do
		local price, is_bop = GetRecipeReagentCost(recipe_id, i)
		if is_bop then
			has_bound_reagents = true
		elseif price then
			cost = cost + price
		else
			incomplete = true
		end
	end

	if incomplete then return cost, true end

	local link = C_TradeSkillUI.GetRecipeItemLink(recipe_id)
	local itemid = link and ns.ids[link]
	if itemid then
		ns.has_bound_reagents[itemid] = has_bound_reagents
		ns.combineprices[itemid] = cost / (ns.GetNumMade(recipe_id, itemid) or 1)
	end

	ns.combineprices["recipe:"..recipe_id] = cost

	return cost
end
