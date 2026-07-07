local queue = {}

-- Open sessions tracked per player so we can auto-close them on disconnect or
-- resource stop. Keyed by player source; each entry holds the identifier
-- captured at start_session time (the player may be gone by the time we need
-- to close it) plus the set of open sessions for that player.
--   openSessions[source] = {
--     identifier = "...",
--     sessions   = { [sessionType.."|"..tag] = { session_type = ..., tag = ... } },
--   }
local openSessions = {}

local function sessionKey(sessionType, tag)
    return sessionType .. "|" .. (tag or "")
end

-- API key comes from a server convar, not config, so it stays out of git and an
-- unset key (dev servers) disables pushing entirely.
local function getApiKey()
    return GetConvar("vantage_api_key", "")
end

local function getApiBaseUrl()
    return GetConvar("vantage_api_url", Config.ApiBaseUrl)
end

local function getIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if Config.IdentifierType == "discord" and string.sub(id, 1, 8) == "discord:" then
            return string.sub(id, 9)
        elseif Config.IdentifierType == "steam" and string.sub(id, 1, 6) == "steam:" then
            return string.sub(id, 7)
        end
    end
    return nil
end

local function getDisplayName(source)
    return GetPlayerName(source) or "Unknown"
end

local function flushQueue()
    if #queue == 0 then return end

    local apiKey = getApiKey()
    if apiKey == "" then
        -- No key (dev server): drop the queue so it can't grow unbounded, and
        -- never touch the API.
        queue = {}
        return
    end

    local payload = json.encode({ events = queue })
    queue = {}

    PerformHttpRequest(getApiBaseUrl() .. "/events/batch", function(status, _, headers)
        if status ~= 200 and status ~= 204 then
            print("[vantage] batch flush failed, status: " .. tostring(status))
        end
    end, "POST", payload, {
        ["Content-Type"] = "application/json",
        ["X-Api-Key"] = apiKey,
    })
end

-- Enqueue a session_end directly from a stored identifier. Used for auto-close,
-- where the player may already be disconnected and getIdentifier would fail.
local function enqueueSessionEnd(identifier, sessionType, tag)
    queue[#queue + 1] = {
        type         = "session_end",
        session_type = sessionType,
        tag          = tag or "",
        entity_id    = identifier,
        occurred_at  = os.time(),
    }
end

-- ── Exports ──────────────────────────────────────────────────────────────────

exports("push_event", function(source, eventType, tag, value, metadata)
    local identifier = getIdentifier(source)
    if not identifier then return end

    queue[#queue + 1] = {
        type         = "point",
        event_type   = eventType,
        tag          = tag or "",
        entity_id    = identifier,
        display_name = getDisplayName(source),
        value        = value,
        metadata     = metadata,
        occurred_at  = os.time(),
    }
end)

exports("start_session", function(source, sessionType, tag)
    local identifier = getIdentifier(source)
    if not identifier then return end

    queue[#queue + 1] = {
        type         = "session_start",
        session_type = sessionType,
        tag          = tag or "",
        entity_id    = identifier,
        display_name = getDisplayName(source),
        occurred_at  = os.time(),
    }

    -- Track the open session so it can be auto-closed later.
    local entry = openSessions[source]
    if not entry then
        entry = { identifier = identifier, sessions = {} }
        openSessions[source] = entry
    end
    entry.identifier = identifier
    entry.sessions[sessionKey(sessionType, tag)] = {
        session_type = sessionType,
        tag          = tag or "",
    }
end)

exports("end_session", function(source, sessionType, tag)
    local identifier = getIdentifier(source)
    if not identifier then return end

    enqueueSessionEnd(identifier, sessionType, tag)

    -- Stop tracking this session.
    local entry = openSessions[source]
    if entry then
        entry.sessions[sessionKey(sessionType, tag)] = nil
        if next(entry.sessions) == nil then
            openSessions[source] = nil
        end
    end
end)

-- ── Lifecycle hooks ───────────────────────────────────────────────────────────

-- End every open session for a player who disconnects.
AddEventHandler("playerDropped", function()
    local src = source
    local entry = openSessions[src]
    if not entry then return end

    for _, session in pairs(entry.sessions) do
        enqueueSessionEnd(entry.identifier, session.session_type, session.tag)
    end
    openSessions[src] = nil
end)

-- On shutdown/restart, close every tracked open session and flush best-effort.
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, entry in pairs(openSessions) do
        for _, session in pairs(entry.sessions) do
            enqueueSessionEnd(entry.identifier, session.session_type, session.tag)
        end
    end
    openSessions = {}
    flushQueue()
end)

-- Announce on start whether data pushing is active, so a missing key on a dev
-- server is obvious in the console rather than silently swallowed.
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local apiKey = getApiKey()
    if apiKey == "" then
        print("[vantage] vantage_api_key convar not set. Data pushing DISABLED (dev mode).")
        return
    end
    print("[vantage] enabled, pushing to " .. getApiBaseUrl())

    -- Close any sessions left open by the previous run. A fresh start means the
    -- resource has no in-memory session state, so nobody is on duty yet and every
    -- still-open session in the backend is an orphan (crash / forced restart /
    -- lost shutdown flush). This is what prevents duty time surviving a restart.
    PerformHttpRequest(getApiBaseUrl() .. "/sessions/reset", function(status)
        if status == 200 or status == 204 then
            print("[vantage] cleared stale open sessions from the previous run")
        else
            print("[vantage] session reset failed, status: " .. tostring(status))
        end
    end, "POST", "", {
        ["Content-Type"] = "application/json",
        ["X-Api-Key"] = apiKey,
    })
end)

-- ── Batch flush timer ─────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(Config.BatchFlushInterval * 1000)
        flushQueue()
    end
end)
