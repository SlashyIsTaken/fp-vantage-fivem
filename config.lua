Config = {}

-- The instance API key is NOT stored here! It's read from a server convar so it
-- never lands in version control, and a dev server without it stays silent.
-- In server.cfg:
--   set vantage_api_key "vntg_your_key_here"
-- Leave it unset on dev/local servers to disable all data pushing.

-- Ingest API base URL, including the /v1 suffix. Default when vantage_api_url is unset.
Config.ApiBaseUrl  = "https://vantage-ingest.flarepoint.nl/v1"

-- "discord" or "steam". Must match the identifier type set on your Vantage instance.
Config.IdentifierType = "discord"

-- Seconds between batch flushes to the API
Config.BatchFlushInterval = 10
