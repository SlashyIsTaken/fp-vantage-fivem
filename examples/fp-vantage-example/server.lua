-- Example integration for the Vantage FiveM resource.
--
-- A standalone resource that shows how to call fp-vantage's exports from your
-- own server scripts. It is not required by fp-vantage; it exists purely as a
-- reference. Copy the export calls into your real scripts, or run this as-is to
-- try the flow with the test commands below.
--
-- fp-vantage must be installed and started first (see the dependency in
-- fxmanifest.lua). The tags used here ("police") assume a panel subscribed to
-- that tag on your Vantage instance.

-- Who is currently on duty, so /duty can toggle rather than only start.
local onDuty = {}

local function notify(source, text)
    TriggerClientEvent("chat:addMessage", source, { args = { "Vantage", text } })
end

-- /arrest : record one arrest event.
RegisterCommand("arrest", function(source)
    if source == 0 then return end -- the console has no player identifier

    -- push_event(source, eventType, tag): "arrest" is the event type a
    -- leaderboard reads; "police" is the tag a panel subscribes to.
    exports['fp-vantage']:push_event(source, "arrest", "police")
    notify(source, "Arrest recorded.")
end, false)

-- /fine <amount> : record a fine and attach its dollar amount.
RegisterCommand("fine", function(source, args)
    if source == 0 then return end

    local amount = tonumber(args[1]) or 0
    -- The 4th argument is a numeric value (used by "sum" leaderboards); the 5th
    -- is free-form metadata stored alongside the event.
    exports['fp-vantage']:push_event(source, "fine_issued", "police", amount, { reason = "example" })
    notify(source, ("Fine of $%d recorded."):format(amount))
end, false)

-- /duty : toggle a timed police duty session on and off.
RegisterCommand("duty", function(source)
    if source == 0 then return end

    if onDuty[source] then
        -- sessionType and tag must match the start_session call.
        exports['fp-vantage']:end_session(source, "duty", "police")
        onDuty[source] = nil
        notify(source, "Off duty.")
    else
        exports['fp-vantage']:start_session(source, "duty", "police")
        onDuty[source] = true
        notify(source, "On duty.")
    end
end, false)
