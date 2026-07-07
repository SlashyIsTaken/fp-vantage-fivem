# Vantage for FiveM

The official FiveM resource for [Vantage](https://vantage.flarepoint.nl), Flarepoint's activity tracking and leaderboard platform. Drop it into your server, call a few exports from your existing scripts, and player activity (arrests, reports handled, on-duty time, anything you want to count) shows up on your Vantage dashboard.

> **You need a Vantage instance to use this.** This resource only collects activity on your FiveM server and ships it to Vantage. The dashboards, leaderboards, and panels all live in Vantage itself. Create an instance and get your API key at **[vantage.flarepoint.nl](https://vantage.flarepoint.nl)**.

## What it does

Other resources on your server call Vantage's exports to report two kinds of activity:

- **Events:** discrete things that happen once, such as an arrest, a report handled, or a kill.
- **Sessions:** timed activity with a start and an end, such as on-duty time.

The resource buffers these in memory, batches them, and sends them to the Vantage API on an interval. Members are created automatically the first time they are seen, so there is no player list to maintain.

---

## Quickstart

New to this? Follow these steps in order and you will have activity flowing to your dashboard in a few minutes. Every step is explained in more detail further down.

1. **Create your Vantage instance.** Go to [vantage.flarepoint.nl](https://vantage.flarepoint.nl), create an instance, and copy the **API key** it gives you. The key is shown once, so save it somewhere safe. You can rotate it later if you lose it.

2. **Pick your identifier type.** Vantage identifies players by **Discord** or **Steam**. Choose one when you set up your instance and remember which, because the resource has to be told the same one.

3. **Install the resource.** Copy this folder into your server's `resources/` directory and name it exactly **`fp-vantage`**. The name matters: your scripts call `exports['fp-vantage']`, so a different folder name will break those calls.

4. **Set your config.** Open `config.lua` and set `Config.IdentifierType` to `"discord"` or `"steam"` to match step 2. Leave everything else at its default for now.

5. **Add it to `server.cfg`:**

   ```cfg
   set vantage_api_key "vntg_your_key_here"
   ensure fp-vantage
   ```

   Use `set`, not `sets`. `sets` would replicate your secret key to every connected client. Put `ensure fp-vantage` above any resource that calls its exports so it starts first.

6. **Start the server** (or run `ensure fp-vantage` from the console). Watch the console: `[vantage] enabled, pushing to ...` means it works. `data pushing DISABLED` means the key is not set (see [Troubleshooting](#troubleshooting)).

7. **Send your first event.** Add an export call like the ones in [Exports](#exports) to one of your scripts, or drop the ready-made [example resource](examples/fp-vantage-example) into your server to try the flow with test commands.

That is the whole setup. Everything below is reference detail for when you want to go further.

---

## Requirements

- A Vantage instance and its **API key**. Create one at [vantage.flarepoint.nl](https://vantage.flarepoint.nl); the key is shown once on creation and can be rotated later.
- Players identified by **Discord** or **Steam**, whichever your instance is configured for.
- FiveM server artifacts recent enough to support `PerformHttpRequest` and server exports (any modern build is fine).

---

## Configuration

The **API key is a server convar**, not a config value. That keeps it out of version control, and a server without it pushes nothing. Set it in `server.cfg`:

| Convar | Description |
| --- | --- |
| `vantage_api_key` | Your instance API key from the Vantage dashboard. **Required to push data.** Unset means the resource stays silent (dev mode). Use `set`, never `sets`. |
| `vantage_api_url` | *Optional.* Overrides `Config.ApiBaseUrl` for this server, for example to point a dev server at a dev backend. Include the `/v1` suffix. |

The rest live in `config.lua`:

| Setting | Description |
| --- | --- |
| `Config.ApiBaseUrl` | Default ingest URL, **including the `/v1` suffix**. As of July 2026: `https://vantage-ingest.flarepoint.nl/v1`. Overridden by `vantage_api_url` when that convar is set. |
| `Config.IdentifierType` | `"discord"` or `"steam"`. **Must match** the identifier type set on your Vantage instance. |
| `Config.BatchFlushInterval` | Seconds between batch uploads. Events are buffered and sent in bulk to avoid hammering the API. Lower is more real-time, higher means fewer requests. `10` is a good default. |

> **Dev vs prod:** the resource is committed with no key in it. Production servers set `vantage_api_key` in their (uncommitted) `server.cfg`; developers running a local server simply leave it unset, so their server never pushes into your production instance.

> **Identifier note:** if a player has no identifier of the configured type (for example `IdentifierType = "discord"` but the player has not linked Discord), events for that player are silently skipped. Make sure your server enforces the identifier you track.

---

## Exports

All exports are **server-side** and take the player's server id (`source`) as the first argument. Call them from a server script. For a complete working script, see the [example resource](examples/fp-vantage-example).

### `push_event(source, eventType, tag, value?, metadata?)`

Record a discrete event.

- `eventType` *(string)*: the event name, for example `"arrest"`. This must match the **event type** you configure on a Vantage leaderboard.
- `tag` *(string)*: a grouping tag, for example a department name. Use `""` if unused. Panels subscribe to tags.
- `value` *(number, optional)*: a numeric amount for `sum` leaderboards, for example a fine amount. Omit it for simple counts.
- `metadata` *(table, optional)*: arbitrary extra data stored with the event.

```lua
-- Count an arrest for a police officer
exports['fp-vantage']:push_event(source, "arrest", "police")

-- A fine of $500 (for a "sum" leaderboard), with metadata
exports['fp-vantage']:push_event(source, "fine_issued", "police", 500, { reason = "speeding" })
```

### `start_session(source, sessionType, tag)`

Begin a timed session, for example going on duty.

```lua
exports['fp-vantage']:start_session(source, "duty", "police")
```

### `end_session(source, sessionType, tag)`

End a timed session. The `sessionType` and `tag` must match the `start_session` call.

```lua
exports['fp-vantage']:end_session(source, "duty", "police")
```

Session duration is measured by Vantage from the start and end timestamps. It feeds `duration_sum` leaderboards and the Active Duty view.

### Tracking multiple duty types

To track separate duties (police, staff, ambulance, and so on), vary the **tag** and keep `sessionType` as `"duty"`:

```lua
exports['fp-vantage']:start_session(source, "duty", "police")
exports['fp-vantage']:start_session(source, "duty", "staff")
exports['fp-vantage']:start_session(source, "duty", "ambulance")
```

The **tag is what separates duties everywhere**:

- The **Active Duty view** filters open sessions by a panel's subscribed tags only. It ignores `sessionType`, so the tag is what splits police vs. staff vs. ambulance in the live list.
- **Duration leaderboards** filter by both `sessionType` (matched to the leaderboard's event type) and the panel's subscribed tags.

Set it up like this:

1. Create one panel per duty, each subscribing to its tag (for example a Police panel with tag `police`).
2. On each panel, add a `duration_sum` leaderboard with event type `duty` to rank time on duty.

Two things to watch for:

- A panel with **no** subscribed tags shows **all** open sessions for the instance. Always give a department panel its tag, or the Active Duty view will not separate the duties.
- A player can be on more than one duty at once (for example police and ambulance). Each is tracked and auto-closed independently.

---

## Automatic session closing

You do not have to manually close every session. Vantage handles the common failure cases:

- **Player disconnects:** `playerDropped` auto-ends every open session that player had.
- **Resource or server stop:** `onResourceStop` closes all tracked open sessions and does a best-effort final flush.
- **Hard crash:** if the server dies without a clean stop, the final flush cannot run. As a safety net, the Vantage backend automatically closes any session left open for more than 24 hours.

Because closing on stop relies on an outbound HTTP request that may not finish during shutdown, treat the 24h backend cleanup as the guarantee and the on-stop flush as best-effort.

---

## How data flows

1. Your scripts call `push_event`, `start_session`, or `end_session`.
2. The resource buffers each call in an in-memory queue.
3. Every `Config.BatchFlushInterval` seconds (and on resource stop), the queue is POSTed to `POST {ApiBaseUrl}/events/batch` with your API key.
4. The Vantage backend creates members on first sight and records the events.

This means data appears in the dashboard with up to `BatchFlushInterval` seconds of delay.

---

## Troubleshooting

**Nothing shows up in the dashboard**

- Check the startup log. `data pushing DISABLED` means `vantage_api_key` is not set. Add it to `server.cfg` and restart.
- Confirm the ingest URL ends with `/v1` (`Config.ApiBaseUrl`, or `vantage_api_url` if you override it).
- Confirm `vantage_api_key` is correct. Rotate it in the dashboard if you are unsure.
- Confirm `Config.IdentifierType` matches your instance's identifier type.
- Confirm players actually have that identifier (Discord linked, or Steam running).
- Remember the flush delay. Wait at least `BatchFlushInterval` seconds.

**Server console shows `[vantage] batch flush failed, status: 401`**

- The API key is wrong or was rotated. Update the `vantage_api_key` convar and restart.

**`status: 0` or a timeout**

- The server cannot reach `ApiBaseUrl`. Check the URL, DNS, and that the API is up.

**Events show under the wrong leaderboard, or not at all**

- The `eventType` (or `sessionType`) string must exactly match what the leaderboard or requirement is configured to read, and the panel must subscribe to the `tag` you send.

---

## License

MIT. See [LICENSE](LICENSE).
