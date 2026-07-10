-- Module registry + config-poll loop.
--
-- Library modules (modules/*.lua) register themselves here under a stable id.
-- Nothing runs until the panel enables a module: this loop polls the backend for
-- the instance's enabled-module list and wires each emitter on/off to match
-- (true standby). The manifest that produces that list lives in the backend's
-- app/modules.py; the `id`s must agree with the ones registered here.

local registered = {}   -- id -> { requires, onEnable, onDisable }
local active = {}       -- id -> true (currently wired)
local pollInterval = 30 -- seconds; overridden by the backend response

-- Called at file load by each module in modules/*.lua.
function RegisterModule(id, def)
    registered[id] = def
end

-- A module with a `requires` only runs when that FiveM resource is started.
local function canEnable(def)
    if not def.requires then return true end
    return GetResourceState(def.requires) == "started"
end

local function enableModule(id)
    if active[id] then return end
    local def = registered[id]
    if not def then
        print("[vantage] panel enabled unknown module '" .. id .. "'; update this resource")
        return
    end
    if not canEnable(def) then
        print("[vantage] module '" .. id .. "' needs resource '" .. tostring(def.requires)
            .. "' (not started); skipping")
        return
    end
    active[id] = true
    if def.onEnable then def.onEnable() end
    print("[vantage] module enabled: " .. id)
end

local function disableModule(id)
    if not active[id] then return end
    active[id] = nil
    local def = registered[id]
    if def and def.onDisable then def.onDisable() end
    print("[vantage] module disabled: " .. id)
end

-- Reconcile the active set against the backend's enabled list.
local function syncModules(enabledList)
    local want = {}
    for _, m in ipairs(enabledList) do
        want[m.id] = true
    end
    for _, m in ipairs(enabledList) do
        if not active[m.id] then enableModule(m.id) end
    end
    for id in pairs(active) do
        if not want[id] then disableModule(id) end
    end
end

CreateThread(function()
    while true do
        local apiKey = Vantage.getApiKey()
        if apiKey ~= "" then
            PerformHttpRequest(Vantage.getApiBaseUrl() .. "/modules", function(status, body)
                if status ~= 200 or not body then return end
                local ok, data = pcall(json.decode, body)
                if not ok or type(data) ~= "table" then return end
                if data.poll_interval then pollInterval = data.poll_interval end
                syncModules(data.enabled_modules or {})
            end, "GET", "", { ["X-Api-Key"] = apiKey })
        end
        Wait(pollInterval * 1000)
    end
end)
