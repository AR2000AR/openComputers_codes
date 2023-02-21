local transposer = require("component").transposer
assert(transposer, "This library require a transposer")

local CONVERTION_RATE  = 100
local COIN_BRONZE      = 1
local ID_COIN_BRONZE   = "ordinarycoins:coinbronze"
local COIN_SILVER      = COIN_BRONZE * CONVERTION_RATE
local ID_COIN_SILVER   = "ordinarycoins:coinsilver"
local COIN_GOLD        = COIN_SILVER * CONVERTION_RATE
local ID_COIN_GOLD     = "ordinarycoins:coingold"
local COIN_PLATINUM    = COIN_GOLD * CONVERTION_RATE
local ID_COIN_PLATINUM = "ordinarycoins:coinplatinum"

local coin             = {}

---count the coins
---@param side side
---@return number
---@return number
---@return number
---@return number
function coin.getCoin(side)
  local bronze, silver, gold, platinum = 0, 0, 0, 0
  local stack = nil
  for stack in transposer.getAllStacks(side) do
    if (stack) then
      if (stack.name == ID_COIN_BRONZE) then bronze = bronze + stack.size end
      if (stack.name == ID_COIN_SILVER) then silver = silver + stack.size end
      if (stack.name == ID_COIN_GOLD) then gold = gold + stack.size end
      if (stack.name == ID_COIN_PLATINUM) then platinum = platinum + stack.size end
    end
  end
  return math.floor(bronze), math.floor(silver), math.floor(gold), math.floor(platinum)
end

---get the total value of coins
---@param bronze number
---@param silver number
---@param gold number
---@param platinum number
---@return number
function coin.getValue(bronze, silver, gold, platinum)
  bronze = bronze or 0
  silver = silver or 0
  gold = gold or 0
  platinum = platinum or 0
  return (bronze * COIN_BRONZE) + (silver * COIN_SILVER) + (gold * COIN_GOLD) + (platinum * COIN_PLATINUM)
end

---find how much space is left for each kind of coins
---@param side side
---@return number
---@return number
---@return number
---@return number
---@return number
function coin.getEmptySpace(side)
  local bronze, silver, gold, platinum, air = 0, 0, 0, 0, 0
  local stack = nil
  for stack in transposer.getAllStacks(side) do
    if (stack.name) then
      if (stack.size < stack.maxSize) then
        if (stack.name == ID_COIN_BRONZE) then bronze = bronze + stack.maxSize - stack.size end
        if (stack.name == ID_COIN_SILVER) then silver = silver + stack.maxSize - stack.size end
        if (stack.name == ID_COIN_GOLD) then gold = gold + stack.maxSize - stack.size end
        if (stack.name == ID_COIN_PLATINUM) then platinum = platinum + stack.maxSize - stack.size end
        if (stack.name == "minecraft:air") then air = air + 1 end
      end
    else
      air = air + 1
    end
  end
  return math.floor(bronze), math.floor(silver), math.floor(gold), math.floor(platinum), air
end

---find the first stack containing the item
---@param side side
---@param name string
---@return number|boolean
function coin.findFirstStack(side, name)
  local i = 1
  for stack in transposer.getAllStacks(side) do
    if (stack.name and (name == nil or stack.name == name)) then return i end
    i = i + 1
  end
  return false
end

---move a certain value of coins
---@param amount number
---@param from side
---@param to side
---@return number|boolean
---@return number|nil
---@return number|nil
---@return number|nil
function coin.moveCoin(amount, from, to)
  if (coin.getValue(coin.getCoin(from)) >= amount) then
    local bronze, silver, gold, platinum = coin.getCoin(from)

    local need_platinum = math.floor((amount) / COIN_PLATINUM)
    amount = amount - (need_platinum * COIN_PLATINUM)
    local need_gold = math.floor((amount) / COIN_GOLD)
    amount = amount - (need_gold * COIN_GOLD)
    local need_silver = math.floor((amount) / COIN_SILVER)
    amount = amount - (need_silver * COIN_SILVER)
    local need_bronze = math.floor((amount) / COIN_BRONZE)

    if (need_platinum > platinum) then
      need_gold = need_gold + ((need_platinum - platinum) * CONVERTION_RATE)
      need_platinum = platinum
    end
    if (need_gold > gold) then
      need_silver = need_silver + ((need_gold - gold) * CONVERTION_RATE)
      need_gold = gold
    end
    if (need_silver > silver) then
      need_bronze = need_bronze + ((need_silver - silver) * CONVERTION_RATE)
      need_silver = silver
    end
    if (need_bronze > bronze) then
      need_bronze = bronze
    end

    local moved_bronze, moved_silver, moved_gold, moved_platinum = 0, 0, 0, 0
    while (moved_bronze < need_bronze) do
      local moved_coin = transposer.transferItem(from, to, need_bronze, coin.findFirstStack(from, ID_COIN_BRONZE) --[[@as number]])
      if (moved_coin == 0) then
        break
      else
        moved_bronze = moved_bronze + moved_coin
      end
    end
    while (moved_silver < need_silver) do
      local moved_coin = transposer.transferItem(from, to, need_silver, coin.findFirstStack(from, ID_COIN_SILVER) --[[@as number]])
      if (moved_coin == 0) then
        break
      else
        moved_silver = moved_silver + moved_coin
      end
    end
    while (moved_gold < need_gold) do
      local moved_coin = transposer.transferItem(from, to, need_gold, coin.findFirstStack(from, ID_COIN_GOLD) --[[@as number]])
      if (moved_coin == 0) then
        break
      else
        moved_gold = moved_gold + moved_coin
      end
    end
    while (moved_platinum < need_platinum) do
      local moved_coin = transposer.transferItem(from, to, need_platinum, coin.findFirstStack(from, ID_COIN_PLATINUM) --[[@as number]])
      if (moved_coin == 0) then
        break
      else
        moved_platinum = moved_platinum + moved_coin
      end
    end

    return moved_bronze, moved_silver, moved_gold, moved_platinum
  else
    return false
  end
end

return coin
