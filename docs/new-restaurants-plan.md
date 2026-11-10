# Opening new restaurants

Phase 2 of the plan for keeping players playing once they max out. It needs Bakery Levels (`bakery-level-plan.md`).

### Rules (the user's choices)
- **When it's allowed:** only when the restaurant is at the max Bakery Level and has
  2 employees hired. The button is in the Cookbook, behind a Yes/No confirmation.
- **What starts over:** the new restaurant gets its own coins, Bakery Level, recipes,
  upgrades, decor and Inventory, employees, garden, stash, expansion, paint, name, pantry and
  goals.
- **What stays with the player:** Stars, passes, Receipts, daily streak, boosts, referrals,
  `TutorialDone` and `StarterPackClaimed`. Pass items are given again in each new restaurant
  through `applyExclusiveItems`.
- **Bonus:** every restaurant after the first gets +20% customers all the time, added in
  `rushPower` from `Config.Prestige.CustomerBonus = 0.2`. *Assumption: this doesn't grow with
  each restaurant opened (a third one doesn't get +40%). It's one Config value if the user
  wants it to.*
- **How many:** there's no limit. The managed restaurant always shows. The most recently
  opened unmanaged restaurants fill whatever plots are free, newest first.
- **Unmanaged restaurants are just for show.** They run on an in-memory copy of that
  restaurant's save, so nothing they do is saved, they earn nothing, and their pantry never
  runs dry. 3 AI workers (Cashier, Baker, Stocker) run them: the 2 hired employees, plus a
  temporary hire for the missing job.
- **Switching:** the owner sees a "Manage this bakery" prompt at an unmanaged restaurant's
  door. It shows the same Yes/No card as Bake Together. Yes makes that restaurant the managed
  one, and the old one turns into a showpiece on the spot. The HUD coin balance switches to
  the new restaurant's coins.
- **Plots running out:** when someone new joins and no plot is free, the oldest unmanaged
  showpiece is removed to make room. A real player always gets a plot first.

### Save format (`PlayerData.luau`)
- Keep today's flat `data` as the **managed** restaurant, so the roughly 5,000 lines that
  read `data.Coins`, `data.Placed` and so on don't change.
- Add a `BAKERY_FIELDS` list naming every per-restaurant field. Add `data.Restaurants`, a
  list of saved copies of those fields for the restaurants not being managed, each with an
  `Opened` time. Add `data.Managed`, the index of the restaurant being managed, and
  `data.Prestiges`, how many have been opened.
- `PlayerData.SwapRestaurant(player, index)` stores the managed restaurant's fields into
  `Restaurants` and loads the chosen one into the flat fields. `PlayerData.OpenRestaurant(player)`
  stores the current restaurant and loads a fresh `clean({})` copy of the per-restaurant
  fields, keeping all the player-wide fields.
- `clean()` cleans each saved restaurant with the same per-field cleaners.
- DataStore size: each restaurant adds a few KB. The 4 MB limit allows hundreds, but
  `Restaurants` should be capped at, say, 50, dropping the oldest.

### Server (`BakerySystem.server.luau`, probably a new ModuleScript `Restaurants` because of the register limit)
- **Refactor `claimPlot(player)` (line 4575):** move the build steps into
  `buildRestaurant(plot, owner, data, showcase)`. When `showcase` is true:
  - set `plot.showcase = true` and `plot.showOwner = player`, but don't set `playerPlots`;
  - give the plot a deep copy of the data, kept in `plot.data`;
  - `earn()`, `syncStats`, goals, deliveries and saving all do nothing for a showcase plot;
  - its door prompt reads "Manage this bakery", and only its owner sees it.
- **Look up a plot's data in one place.** There are 15 `PlayerData.Get(plot.owner)` /
  `PlayerData.Get(owner)` lookups. Each goes through a new `plotData(plot)`, which returns
  `plot.data` for a showcase plot. All of them must be checked so a showcase plot never
  writes to the real save.
- **Employees:** `runEmployee` loops over 3 slots for a showcase plot. Slot 3 is a temporary
  hire with a random look from `Config.Wardrobe` and the missing job.
- **Pantry:** a showcase plot's `plot.data.Pantry` is refilled whenever the Baker uses it.
- **Switching:** a `ManageRestaurant` remote reuses the Bake Together request card. On Yes, it
  releases both plots, swaps the save, then builds the managed restaurant on the plot the
  player is standing at and the old one as a showcase.
- **Opening:** an `OpenRestaurant` remote checks max level and 2 employees, then calls
  `OpenRestaurant`. The old restaurant becomes a showcase if a plot is free. The new one is
  built where the player is.
- **Showcases on join/leave:** after each `claimPlot` and `releasePlot`, a
  `refreshShowcases()` hands free plots to the newest unmanaged restaurants of the players in
  the server. A new player always takes a showcase's plot first. When the owner leaves, their
  showcases are released.

### Client
- The Cookbook gets an "Open a new restaurant" row: locked text until the restaurant is ready,
  then a Yes/No confirmation explaining what starts over.
- The owner's "Manage this bakery" door prompt is handled the same way as "Ask to Bake
  Together" (the door prompt's client filter is in `BakeryClient`).
- The HUD shows "Restaurant 2 · +20% customers" under the coin balance.
