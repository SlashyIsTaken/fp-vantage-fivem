-- standalone.playtime — one open "playtime" session per connected player.
--
-- Framework-agnostic. Sessions are tracked in main.lua's registry, so the global
-- playerDropped / onResourceStop handlers already auto-close them; this module
-- only opens them and stops opening new ones when disabled.

local TAG = "server"
local SESSION = "playtime"
local joinHandler = nil

RegisterModule("standalone.playtime", {
    requires = nil,
    onEnable = function()
        -- Backfill players already connected when the module is switched on.
        for _, src in ipairs(GetPlayers()) do
            Vantage.startSession(tonumber(src), SESSION, TAG)
        end
        joinHandler = AddEventHandler("playerJoining", function()
            Vantage.startSession(source, SESSION, TAG)
        end)
    end,
    onDisable = function()
        if joinHandler then
            RemoveEventHandler(joinHandler)
            joinHandler = nil
        end
        for _, src in ipairs(GetPlayers()) do
            Vantage.endSession(tonumber(src), SESSION, TAG)
        end
    end,
})
