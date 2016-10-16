
local myname, ns = ...


local PRIMAL_SPIRIT = 120945
local BLOOD_OF_SARGERAS = 124124
local PRIMAL_TRADES = {
  [108996] = 1/5,  -- Alchemical Catalyst
  [113261] = 1/15, -- Sorcerous Fire
  [113262] = 1/15, -- Sorcerous Water
  [113263] = 1/15, -- Sorcerous Earth
  [113264] = 1/15, -- Sorcerous Air
  [118472] = 1/25, -- Savage Blood
  [127759] = 1/25, -- Felblight
}
local BLOOD_TRADES = {
  [123918] = 10, -- Leystone Ore
  [123919] =  5, -- Felslate
  [124101] = 10, -- Aethril
  [124102] = 10, -- Dreamleaf
  [124103] = 10, -- Foxflower
  [124104] = 10, -- Fjarnskaggl
  [124105] =  3, -- Starlight Rose
  [124107] = 10, -- Cursed Queenfish
  [124108] = 10, -- Mossgill Perch
  [124109] = 10, -- Highmountain Salmon
  [124110] = 10, -- Stormray
  [124111] = 10, -- Runescale Koi
  [124112] = 10, -- Black Barracuda
  [124113] = 10, -- Stonehide Leather
  [124115] = 10, -- Stormscale
  [124117] = 10, -- Lean Shank
  [124118] = 10, -- Fatty Bearsteak
  [124119] = 10, -- Big Gamy Ribs
  [124120] = 10, -- Leyblood
  [124121] = 10, -- Wildfowl Egg
  [124437] = 10, -- Shal'dorei Silk
  [124438] = 20, -- Unbroken Claw
  [124439] = 20, -- Unbroken Tooth
  [124440] = 10, -- Arkhana
  [124441] =  3, -- Leylight Shard
}


local function GetBestTrade(trades)
  local best = 0
  for item_id,count in pairs(trades) do
    local price = GetAuctionBuyout and GetAuctionBuyout(item_id)
    if price then best = math.max(best, price * count) end
  end

  return best
end


ns.bop_values = setmetatable({}, {
  __index = function(t,i)
    local v = false

    if i == PRIMAL_SPIRIT then
      v = GetBestTrade(PRIMAL_TRADES)
    elseif i == BLOOD_OF_SARGERAS then
      v = GetBestTrade(BLOOD_TRADES)
    end

    t[i] = v
    return v
  end
})


local wiper = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
wiper:SetScript("OnEvent", function()
	wipe(ns.bop_values)
end)
