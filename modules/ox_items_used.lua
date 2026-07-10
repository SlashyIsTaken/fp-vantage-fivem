-- ox.items_used — one "item_used" point event per item a player consumes.
--
-- Requires ox_inventory. The item name rides along as metadata so a future
-- leaderboard could split by item; the leaderboard itself just counts events.
-- Signature verified against ox_inventory docs:
--   ox_inventory:usedItem(playerId, name, slotId, metadata)

local TAG = "items"
local EVENT = "item_used"
local usedHandler = nil

RegisterModule("ox.items_used", {
    requires = "ox_inventory",
    onEnable = function()
        usedHandler = AddEventHandler("ox_inventory:usedItem", function(playerId, name)
            Vantage.pushEvent(playerId, EVENT, TAG, nil, { item = name })
        end)
    end,
    onDisable = function()
        if usedHandler then
            RemoveEventHandler(usedHandler)
            usedHandler = nil
        end
    end,
})
