# fp-vantage-example

A minimal reference resource showing how to call the [Vantage FiveM](../../) exports from your own server scripts.

It registers three test commands so you can see activity reach your Vantage dashboard without writing any code first:

| Command | What it does |
| --- | --- |
| `/arrest` | Records a single `arrest` event under the `police` tag. |
| `/fine <amount>` | Records a `fine_issued` event with a numeric value (for `sum` leaderboards). |
| `/duty` | Toggles a timed `duty` session under the `police` tag on and off. |

## Using it

1. Make sure `fp-vantage` is installed, configured, and started (see the [main README](../../)).
2. Copy the `fp-vantage-example` folder into your server's `resources/` directory.
3. Add `ensure fp-vantage-example` to your `server.cfg`, below `ensure fp-vantage`.
4. Join your server and run the commands above. With a panel subscribed to the `police` tag, the activity appears on your dashboard after the next batch flush.

Once you understand the calls, delete this resource and put the same `exports['fp-vantage']:...` calls into the scripts that already handle arrests, fines, and duty on your server.
