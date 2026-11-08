# Plan: The Sweet Stash (back storage room, Stash Shelves, treat-marked cases)

## Context
The user wants more room for treats in Sweetopia. Today the Stocker only takes batches from the oven, and when every case is full it stands at the oven holding the tray ("Cases are full!"). Cases take any mix of treats.

What they asked for:
- A new Shop upgrade, **The Sweet Stash**, opens a storage room through a door in the back wall.
- In the room, a **whiteboard** station sells **Stash Shelves**. These work like the Tall Display Case (12 treats) but look different, and they can only be placed in this room.
- The whiteboard's **Customize store shelves** mode: tapping a display case in the store opens a list of unlocked treats. The chosen treat is the only one the Stocker puts in that case. Unmarked cases are first come, first served.
- When no case has room, the Stocker puts treats on the stash shelves. As a spot frees up, it brings them to the case.

The user's answers:
- **Name:** The Sweet Stash.
- **Prices:** 5,000 coins for the room, 300 per shelf.
- **Marks:** only the Stocker follows them. A player can still hand-stock any case with any treat.
- **Customers:** never use the stash shelves.
- **Door:** a fixed spot between the oven and the Delivery Counter. When it's bought, anything in the doorway goes to the Inventory (counters move to a free spot), with a message.
- **Showing marks:** treat tags float over marked cases only while customizing. Otherwise the case's E prompt says "Cupcakes only · 3/12 treats".

## Before starting
- **Other sessions:** another session just committed floor tiles and case colours (580971b). Check that `git status` is clean, that Studio is in Edit mode, and that each script's Studio Source matches `git show HEAD:<file>` (checksum) before syncing anything.
- **Script room:** measure the free local-variable room in `BakeryClient` (insert dummy locals at the Bake Together request card's `do` block) and in `BakerySystem`, compiling with `loadstring` in Edit mode. Each script gets **one** new top-level local, a `stash` table of functions. Everything else goes in functions or in fields on existing tables (`panels`, the plot table).
- **Syncing:** use `tools/studio_patch.py` with `execute_luau` in Edit mode, plus a final checksum and `loadstring` check. HTTP to localhost is blocked.
- **Commits:** one file per commit, pushed after each one (SSH remote).

## Geometry (floor space: +Z is the front door, −Z is the back)
These are starting numbers. Measure them in Edit mode before fixing them in `Layout`.
- **Door:** x 6..11, 9 studs tall, in the back wall at `bounds.MinZ`. The default layout has a free gap from x 4.6 (oven) to x 12.7 (Delivery Counter).
- **Room inside:** x −3..21 (24 wide), 14 deep. It runs from `bounds.MinZ − 1` (behind the back wall's 1-stud thickness) back to `bounds.MinZ − 15`, and moves back with every expansion.
  - At the largest size the room's outer wall is at z ≈ −59. The park only keeps clear to z −47, so plants have to go (step 10).
- **Kept clear:**
  - **Bakery side of the door:** x 5..12, from the back wall 3 forward, the full wall height, so no wall piece hangs over the door or its sign.
  - **Room side of the door:** the same width, 3 deep.
  - **Whiteboard:** its spot on the room's right wall, plus 3 clear in front of it.
- **Stocker:** `PATH_SETTINGS.AgentRadius` is 1.2 (BakerySystem ~2122), so a 5-wide door is enough for pathfinding. Customers only walk to case stands, seats and the register, so they never route into the room.

## Steps (each a single-file commit, pushed)

### 1. `docs/sweet-stash-plan.md`
A copy of this plan, like the other plans in `docs/`.

### 2. Config (`src/ReplicatedStorage/Config.luau`)
- **The room:** `Config.Stash = { Name = "The Sweet Stash", Coins = 5000, Description = "A storage room through a back door, …" }`.
- **The shelf item:** `StashShelf` ("Stash Shelf", `Coins = 300`, `Charm = 0`, `Room = "Stash"`).
  - It gets 12 slots, 4 shelves of 3, from a new local helper next to `displayCase` (~409). The helper builds wooden uprights, open plank shelves and little crates, with no glass. Its first part is the base, because a case's first part holds its prompt.
  - The comment explains that `Room` items only go in that room and are bought at its whiteboard.

### 3. Layout (`src/ReplicatedStorage/Layout.luau`)
- **Constants:** `Layout.Stash` holds the room rect, `Depth`, `DoorMinX`/`DoorMaxX`/`DoorHeight` and the whiteboard rect.
- **`Layout.StashBounds(level)`:** the room's inside rect at that expansion level.
- **`Layout.BoundsFor(item, level)`:** the room's bounds for an item with `Room`, otherwise `Layout.Bounds(level)`.
- **`Layout.StashThings(level)`:** fixed things for the two doorway zones and the whiteboard, built with `describe` so `Check` treats them like stations.
- **Saved cells:** `Layout.CleanEntry` (226) checks against a new `Layout.Farthest`, which is `Largest` plus the room at the largest level, so saved shelf cells are accepted.
- **`ItemThing` (262):** passes `item.Room` through to the thing.
- **`Check`'s inside test (331):** a `Room` piece outside the room says "Stash Shelves go in The Sweet Stash". Other pieces outside the bakery keep "Keep it inside your bakery".

### 4. PlayerData (`src/ServerScriptService/PlayerData.luau`)
- **New field:** `Stash = saved.Stash == true`, next to `LuxuryOven` (~329), with a comment. It's set before `cleanLayout` runs (381).
- **`cleanLayout` (126):**
  - Each piece is checked against `Layout.BoundsFor(item, data.Expansion)`.
  - `Room` pieces are dropped (left in the inventory) unless `data.Stash` is true.
  - A placed display case keeps `Treat` when it's a whole number from 1 to `#Config.Recipes` and the item has `Slots` and no `Room`.

### 5. `tools/build_stash.luau` (new), run once in Edit mode
- **What it builds:** `ServerStorage.StashRoom`, a template model pivoted at the room's front-centre on the floor, in floor-space axes. It contains:
  - a `Floor` whose top is level with the bakery floor,
  - left, right and back walls 14 tall, with trim matching the bakery's,
  - a warm `PointLight`, and no roof (the bakery has none),
  - the door frame, with an open door swung against the room's inside wall,
  - a "The Sweet Stash" sign over the door on the bakery side,
  - a `Whiteboard` model (frame, white board, a SurfaceGui with marker doodles and "Stash list", and a `Board.Prompt` with ActionText "Use Whiteboard" and distance 8).
- **How it's built:** colours come from the bakery's walls. Parts are anchored. Only walls and floor collide.
- **How it's checked:** clone it into one plot in Edit mode and take screenshots.

### 6. BakerySystem: the room (`src/ServerScriptService/BakerySystem.server.luau`)
New top-level `stash` table, defined before the Place and Purchase remotes.
- **`stash.place(plot, data)`:** called after every `applyExpansion` (claimPlot ~3871, Expand ~1535, releasePlot ~3939).
  - With `data.Stash`, it clones the template into `plot.model` the first time, `PivotTo`s it to the level's spot, and cuts the door. Otherwise it removes the room.
- **Cutting the door:** `setUpPlot` (~4324) makes two parked clones of `Walls.BackWall`, named `BackWallRight` and `BackWallTop`, and adds them to `plot.paintParts.Back` (~4402) so wall paint covers them.
  - After `applyExpansion` resets `BackWall` to full width, cutting the door shrinks `BackWall` to the part left of the door. It then sizes `BackWallRight` (right of the door) and `BackWallTop` (the lintel, door top to wall top), parented into `Walls`.
  - `TrimBack` stays whole. Without the room, the two clones are parked again.
- **Whiteboard prompt:** set active when the room is placed, owner only (no `CoBake`), using `canUse`. It fires `openPanelEvent` with `"Whiteboard"`. The client already watches prompts with `plotsFolder.DescendantAdded`.
- **Buying the room:** `purchaseEvent "Stash"`, next to "LuxuryOven" (~1520).
  1. Refuse if already owned. Otherwise `buy(Config.Stash.Coins)` and set `data.Stash = true`.
  2. `stash.clearDoorway`: placed floor and back-wall pieces that clash with the doorway things go through `storePlaced` (stock goes to the tray), and stations that clash move to `freeStationSpot`.
  3. `stash.place`, `refreshEmployees`, `syncStats`.
  4. Notify "The Sweet Stash is open! It's through the back door", plus "Moved the X to your Inventory" for each piece moved.
- **`layoutThings` (668):** adds `Layout.StashThings(data.Expansion)` when `data.Stash`, so pieces, stations and `freeStationSpot` keep the doorway clear.
- **Place remote (~1244–1336):** "New" and "Move" check items against `Layout.BoundsFor(item, data.Expansion)`. Stations keep `plotBounds`. "Move" keeps `Treat` as it keeps `Paint`. "Store" and "Sell" drop it.
- **Expand (~1535):** Room pieces' `Z` drops by the step's `Back` (as `moveWallPieces` does at 1340) before they're rebuilt, so shelves and their stock ride back with the room.

### 7. BakerySystem: shelves
- **Prompts:** `buildPlaced` (1137) already calls `addCase` for `Slots` items. For `Room` items, the prompt reads "Stock Shelf" and a second prompt, "Take Treats" (key F, `CoBake` attribute), calls `stash.take(plot, player, key)`.
- **Taking treats:** `stash.take` moves treats from the shelf onto the player's own tray, up to `trayCapacity`. With a hotbar box selected it takes only that treat; otherwise the priciest go first, mirroring `stockCase` (1073). Then `refreshCase` and `syncStats`.
- **Things that skip `Room` items:** `pickStockedCase` (2167, customers), `sellWhileAway` (4032, offline sales), `findCaseWithRoom` (317, guide hint), and `placedCaseCount` (269, "keep one display case").
- **Guide hint:** when the cases are full but a stash shelf has room, it says "Your cases are full! The Stocker can put extras in The Sweet Stash".

### 8. BakerySystem: marks and the Stocker
- **Setting a mark:** a new Place action, "Treat" `(key, recipeIndex or nil)`. It's the owner's own plot only. The piece must have `Slots` and no `Room`, and the index must be from 1 to `RecipesUnlocked`. It sets `data.Placed[key].Treat`, then `refreshCase` and `syncStats`.
- **Case prompt text:** `refreshCase` (1052) sets ObjectText to "Cupcakes only · 3/12 treats" (via `treatWord`) for a marked case, "3/12 treats" otherwise, and "Stash · 3/12 treats" for a shelf.
- **Which cases take a treat:** `stash.accepts(data, key, recipe)` is true when the piece isn't a `Room` item and its `Treat` is nil or equal to the recipe.
- **Room counts:** `caseRoom(plot, data, recipe)` (3463) counts only cases that accept the recipe. `caseWithRoom(plot, data, from, recipe)` (3472) picks the nearest case marked for that recipe, then the nearest unmarked one. New `stash.shelfRoom` and `stash.shelfWithRoom` do the same for shelves.
- **The Stocker branch of `runEmployee` (3539–3593):**
  1. **Not carrying, with a ready oven whose treat has case room:** take `min(oven.count, caseRoom(r) + shelfRoom)`. This is today's path. `oven.recipe` is the recipe table, so its index comes from `table.find(Config.Recipes, oven.recipe)`, as at 3549.
  2. **Not carrying, otherwise:** if a shelf holds a treat `r` with `caseRoom(r) > 0`, say "Restocking", walk to the nearest such shelf's stand, recheck, and take `min(count of r there, caseRoom(r))` off it. Then `refreshCase` the shelf.
  3. **Not carrying, still nothing:** if an oven is ready and `shelfRoom > 0`, take `min(count, shelfRoom)`.
  4. **Carrying:** go to the nearest accepting case with room. Failing that, go to the nearest shelf with room (saying "Taking N to the stash"). Failing both, say "Shelves are full!" if it owns the stash, or "Cases are full!" if not, then `helperGoHome`. Recheck the target on arrival, as today.
  - The comment above `runEmployee` is updated to describe this.

### 9. BakeryClient (`src/StarterPlayer/StarterPlayerScripts/BakeryClient.client.luau`)
New top-level `stash` table. It's split into a few commits.
- **a. Shop:** `panels.Shop` (572) gets a "The Sweet Stash" row after the upgrades. It has a Buy button (5,000 coins; fires `purchaseEvent("Stash")`) and shows "Owned" once bought. `state.Stash` comes from `syncStats` (add `Stash = data.Stash` there, server ~793; that's part of step 6's commit).
- **b. Whiteboard menu:** `panels.Whiteboard`, titled "The Sweet Stash".
  - **Stash Shelf row:** "Holds 12 treats for the Stocker. Only fits in here. You have N to place", with a 300 Buy button (`purchaseEvent("Item", "StashShelf")`) and Place (`startPlacing("StashShelf")`) when one is spare.
  - **"Customize store shelves" row:** "Choose which treat the Stocker puts in each display case", with a Start button.
  - **Decorate menu:** its Floor tab (~1186) skips `Room` items. The Inventory tab still lists them. `saleText` (1061) leaves shelves out of the last-case count.
- **c. Placing shelves:**
  - **Bounds:** `myBounds()` (2297) returns `Layout.BoundsFor(item, state.Expansion)` when the held item has `Room`, so `refreshHeld`, `moveHeldTo`, `rotateHeld` and the starting spot all use the room.
  - **Grid:** `showGrid` (2340) is redrawn when the held piece switches between the room and the bakery (`stash.gridRoom`).
  - **`allThings` (~2301):** adds `Layout.StashThings` when `state.Stash`.
  - **Pointer:** `surfacePointAt` (2737) also hits `plot.StashRoom.Floor`.
  - **Back wall pieces:** `WALL_NAMES` (2230) adds `BackWallRight` and `BackWallTop`, looked up with `FindFirstChild`.
- **d. Customize mode:** a sub-mode of decorate mode, like `tiling`.
  - **Starting and stopping:** `stash.startMarking()` closes the menu, stops tiling, and sets `stash.marking = true` before `setDecorating(true)`. `setDecorating(false)` clears it and removes the tags (next to the tiling reset, ~2710).
  - **The bar and banner:** `refreshBar` (2551) shows only Done, with the banner "Tap a display case to choose its treat". `showGrid` draws no grid while marking.
  - **Input:** the `RenderStepped` hover (3012), `InputBegan` (3043) and `TouchTap` (3096) each get an `elseif stash.marking` branch next to `tiling.style`. Hover outlines only store cases. A click or tap runs `pieceOnRay`, and a store case opens `panels.CaseTreat` for that key. `setPanel` doesn't end decorate mode, so the mode carries on behind it.
  - **`panels.CaseTreat`:** titled "<Case name>: which treat?". It has an "Any treat" row, then one row per unlocked recipe, each with a `showTreat` ViewportFrame parented into the row that `addRow` returns. The current choice shows "✓ Chosen", the others "Choose". Choosing fires `placeEvent("Treat", key, index)` and `setPanel(nil)`.
  - **Tags:** `stash.refreshTags(plot)` puts a BillboardGui over each marked case, with a ViewportFrame of the treat and its name. It's rebuilt on each State sync while marking and removed when Done is pressed.

### 10. `tools/build_greenery.luau` and the live park
- **The builder:** `BAKERY_BOX` (~40) is kept, and a second keep-clear box covers the room at the largest level plus 4 studs, so a future re-run keeps it clear. A re-run reshuffles the seeded park, so it isn't re-run.
- **The live place:** in Edit mode, delete only the `Town.Greenery` plants inside each plot's new box. Behind Plots 2–6 that's a few trees and bushes in z −64..−44.
- **Townsfolk:** check that the boxes stay clear of their ways out (`setUpTown` exits, `WAY_HALF` 7).

### 11. Docs
- **README:** The Sweet Stash, Stash Shelves, and customizing store shelves.
- **`docs/roadmap.md`:** a Sweet Stash row covering what the test covered, plus the new script-room figures.

## Verification (Studio, throwaway save, no DataStore writes)
- **Test setup:** use the fresh-save patch from memory. Set `BakerySystem.Enabled = false`, add a `TEST_Patch_DELETE` that fakes `Load`/`Get`/`CanSave`/`Save`, and add a `TEST_Bridge_DELETE` to set coins. Inject `RecipesUnlocked ≥ 3`, a few cases, and `Employees = { NewEmployee({}, "Stocker"), NewEmployee({}, "Baker") }`. Afterwards delete the patch and bridge and re-enable BakerySystem. Nothing touches the user's real save.
- **Room, door and whiteboard:** buy The Sweet Stash with a piece deliberately in the doorway.
  - The room and door appear, and the piece goes to the Inventory with a message.
  - Screenshots of the door from the bakery, the room, the whiteboard and the sign.
  - Walk through the door. The whiteboard prompt opens its menu.
- **Shelves:** buy a Stash Shelf and place it.
  - Placing it in the bakery is refused with "Stash Shelves go in The Sweet Stash".
  - A rug or table in the room is refused.
  - Nothing can be placed or hung in the doorway.
  - Paint the back wall: all three back-wall pieces change colour.
- **Marks:** Customize mode, with real clicks.
  - Tags show, and the popup lists the unlocked treats with pictures.
  - Mark a case for Cookies. The prompt reads "Cookies only · n/6".
  - Hand-stocking that case with Cupcakes still works.
  - Pressing Done removes the tags.
- **Stocker:**
  - A cupcake batch skips the cookie-marked case and fills unmarked cases.
  - When the cases are full, it goes to the shelf ("Taking N to the stash").
  - After a customer buys from a case, it restocks that case from the shelf.
  - With shelves full, it says "Shelves are full!".
  - Customers never walk into the room. Logs from the bridge.
- **Shelf prompts:** the second prompt, "Take Treats", fills the tray up to its limit.
- **Expansion and leaving:**
  - Expand once. The room, the shelves and their stock move back with the wall, and the door is re-cut.
  - Release the plot: the room goes and the back wall is whole again.
- **Save round-trip:** run `PlayerData`'s clean on a saved copy with `Stash`, a shelf entry, a marked case and a bad `Treat`. It should keep the valid ones and drop the bad one. Also check a save without `Stash` drops the shelf entry to the inventory.
- **Script room:** both scripts still compile, and the new script-room figures are recorded.

## Not covered (say so in the roadmap)
- **Phones:** tapping cases in Customize mode on a real phone (Studio's simulator doesn't turn clicks into taps).
- **Co-bakers:** using "Take Treats".
- **The real save:** the user's own save loading with The Sweet Stash after a real rejoin.
