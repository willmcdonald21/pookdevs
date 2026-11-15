# Plan: take treats out of cases, sit in chairs, bigger storage room, new furniture, éclair fix

## Context
You asked for five things:
1. **Display cases:** you can take treats that are already on display back out.
2. **Chairs:** players can sit in them, as customers do.
3. **Storage room:** expansions for The Sweet Stash once it's bought.
4. **New furniture:** new tables and chairs.
5. **The éclair:** it shows only its cream and toppings.

Your choices:
- **Storage room:** two upgrades that each make the room 10 studs wider.
- **Who sits:** anyone in the bakery, visitors included.
- **Furniture:** table sets with their chairs built in, plus a few chairs on their own.

What I found:
- **Chairs:** customers "sit" by being posed on a seat spot. Nothing uses Roblox's real `Seat`.
- **Cases:** Stash Shelves already have a working "Take Treats" (F) prompt, and its code works unchanged for display cases.
- **The éclair isn't too long.** It fits its slot with room to spare, and the Croissant and cakes are wider.
  - It's built from squashed balls, an ellipsoid 2.2 long and 0.6 tall. Roblox draws a Ball part with uneven sides as a round sphere the size of its smallest side, so the éclair body becomes a tiny bead hidden under the cream.
  - The same bug quietly shrinks the Croissant and every garden plant's leaves.
  - I'll confirm this in Studio before changing anything.
- **Script room:** both main scripts are at Luau's 200-local limit, so new code goes into existing tables (`seats`, `stash`) and inside existing functions. No new top-level locals.

## 1. Taking treats out of a display case
- **Prompt:** every display case gets the "Take Treats" (F) prompt that Stash Shelves have. It loads the case's treats onto your tray.
  - With a hotbar box selected, it takes only that treat.
  - Otherwise it takes the most valuable first, as much as your tray holds.
- **Who:** the owner and co-bakers, like the Stock prompt.
- **Messages:** "This case is empty" or "There are no éclairs in this case", worded for a case or a shelf.
- **Code:** in `BakerySystem`, drop the `if shelf then` gate around the TakePrompt clone in `addCase` (around line 1250). Word `stash.take`'s two messages by `case.shelf`.
- **Note:** a Stocker employee will refill an emptied case from the oven or shelves, as it does today.

## 2. Sitting in chairs
- **Prompt:** every free seat shows a "Sit" prompt to anyone in the bakery. The seat is a real Roblox `Seat`, so you get Roblox's own sit pose, and jumping gets you up as usual.
- **Sharing seats:**
  - A seat a player is in is skipped by customers.
  - A seat a customer is in hides its prompt.
  - Moving, storing or selling the piece stands the sitter up, because the seat goes with the model.
- **Server (`BakerySystem`, fields on the existing `seats` table):**
  - `seats.build(plot, key, model, origin, item)` is called from `buildPlaced` for items with `Seats`. For each seat it adds an invisible `Seat` part (`Seat1`, `Seat2`, …) in the model:
    - top at `At`, facing `Look`;
    - anchored, `CanCollide`/`CanTouch` off, so walking into it doesn't sit you down;
    - a ProximityPrompt "Sit" (hold 0, range 6) with the `Everyone` attribute.
  - Triggered: if the seat has no Occupant, no customer holds `plot.seated[id]`, and the player is near, then `seat:Sit(humanoid)`.
  - `seats.free` also skips seats whose `Seat.Occupant` is set.
  - `seats.sit` and the seat's Occupant signal set the prompt's `Active`.
- **Client (`BakeryClient`, inside `refreshPrompt`):** a prompt with `Everyone` shows to every player when it's `Active`.
- **Character rig:** I'll check the place's avatar type in Studio. Roblox's Seat works for R6 and R15.

## 3. A bigger storage room
- **Where to buy:** once The Sweet Stash is bought, its whiteboard menu shows "Bigger stash".
  - Step 1 makes the room 34 wide, from 24, for **400 coins**.
  - Step 2 makes it 44 wide for **1,000 coins**, then it shows "As big as it gets".
  - Each step uses a second "Sure?" tap.
- **How it grows:** the room grows to the right, away from the door.
  - The right wall, its trim, the right lamp and the whiteboard move out.
  - The floor, back wall and back trim get longer.
  - Shelves stay put.
  - The outside skins and trim colours follow.
  - Garden plants now under the room go to the Inventory, as when the stash is bought.
- **Space behind the bakeries:** I measured 20 free studs on the right behind every bakery. Plot 3 is the tightest at x 44, and the room's outer wall would reach 42. I'll recheck each plot's park plants in Studio and remove any in the way.
- **Code:**
  - `Config.Stash.Sizes = { { Coins = 400, Width = 10 }, { Coins = 1000, Width = 10 } }`.
  - `Layout`: `StashBounds(level, size)` widens `MaxX` by the bought widths. `StashThings`, `BoundsFor`, `GardenThings` and `Farthest` take the size, and `Farthest` covers the widest room.
  - `PlayerData`: save `StashSize` (0–2), added to `RESTAURANT_FIELDS` so each restaurant keeps its own. `cleanLayout` passes it to `BoundsFor`.
  - `BakerySystem`:
    - `stash.place` resizes the cloned room by the extra width. A new `stash.resize` field moves `RightWall`, `TrimRightWall`, the right `Lamp` and `Whiteboard`, and stretches `Floor`, `BackWall` and `TrimBackWall`.
    - A new purchase kind, "StashSize".
    - `exterior.apply`'s back-wall skip uses the room's real width.
    - Every `StashBounds`/`StashThings`/`BoundsFor` call passes `data.StashSize`.
    - `syncStats` sends `StashSize`.
  - `BakeryClient`:
    - The Whiteboard panel gets the row.
    - The grid, held-piece checks and `myBounds` pass `state.StashSize`.
  - `tools/build_greenery.luau`: `STASH_BOX` uses the widest room.

## 4. New tables and chairs
- **Line-up:** six new floor pieces, priced like today's cheaper decor (the Cafe Table is 25 coins).
- **Customers and players:** every seat works for both. Customers already pick any free seat.

| Piece | What it looks like | Seats | Price | Charm |
|---|---|---|---|---|
| Bistro Set | Small round marble-top table on a black iron stand, two curly iron chairs | 2 | 40 coins | 2 |
| Table for Four | Square oak table with four ladder-back chairs | 4 | 60 coins | 3 |
| Diner Booth | Two pink padded benches with high backs facing over a table | 4 | 80 coins | 3 |
| Window Bar | Long high counter with three round-top stools | 3 | 50 coins | 2 |
| Pastel Chair | A single painted wooden chair, colour picked when bought (free) | 1 | 10 coins | 1 |
| Heart Loveseat (deluxe) | Pink velvet two-seater with a heart-shaped back | 2 | 10 Stars | 6 |

- **Built like the current pieces:** boxes, discs and balls in `Config.Items`, each seat with `At` (seat top), `Look` and `From` (where a customer stands before sitting). The Pastel Chair has `Paint = true` parts, so it gets the colour list when bought.
- **Checks:** I'll check each piece in Studio with a screenshot and a real sit before committing.

## 5. Éclair (and other squashed balls)
- **The goal:** the whole éclair shows on the shelves, just like every other treat: its long choux body, the chocolate icing along its top, and the cream and toppings. Not just a blob of cream.
- **Confirm first:** in Studio Edit mode, build one éclair at full size into a temporary model, screenshot it, then delete it.
- **Fix:** in `ItemBuilder`, a `Ball` given a `Size` is built as a block with a `SpecialMesh` of type Sphere. That draws a true squashed ball of that size. Round balls with a `Diameter` are unchanged.
- **Effects:**
  - The éclair, Croissant and garden plants' leaves and flowers show at their intended shapes everywhere: cases, hotbar icons, trays, menus and the Treat Designer.
  - Garden plants will look fuller than they do now. Their footprints don't change, because those were already measured from `Size`.
- **If the screenshot shows something else**, I'll come back to you before changing anything.
- **Checking the goal:** I'll fill a Display Case and a Tall Display Case with éclairs beside cookies, cupcakes and croissants, and screenshot them from where a player stands in front of the case.
  - **Done** only when the whole éclair, body and icing, is as easy to see through the glass as its neighbours.
  - **If it still reads too small or hidden** (it's a thin treat), I'll tune it until it does. For example, set the slot's Y offset so it sits on the shelf rather than sinking, or size its parts up to match the other treats' visible bulk. Any such tweak touches only the éclair, and I'll show you the before and after screenshots.
  - I'll do the same check on the Stash Shelf, the carried tray and the hotbar icon.

## Files
- `src/ReplicatedStorage/Config.luau`: new furniture, `Config.Stash.Sizes`.
- `src/ReplicatedStorage/Layout.luau`: stash size in bounds and things.
- `src/ReplicatedStorage/ItemBuilder.luau`: squashed balls.
- `src/ServerScriptService/PlayerData.luau`: `StashSize`.
- `src/ServerScriptService/BakerySystem.server.luau`: take prompt, seats, stash size.
- `src/StarterPlayer/StarterPlayerScripts/BakeryClient.client.luau`: `Everyone` prompts, Whiteboard row, stash size on the grid.
- `tools/build_greenery.luau`: `STASH_BOX`.
- Docs: `docs/furniture-and-stash-plan.md` (this plan), README, roadmap.
- One commit per file, each pushed. Studio is synced with the checked patch method (old checksum, then new checksum, then `loadstring`) in Edit mode.

## Verification
1. **Before starting:** `git status` is clean and no other session is editing. Studio is in Edit mode, and its scripts match `HEAD`.
2. **Éclair first:**
   - Take the full-size screenshot before and after the ItemBuilder change.
   - Check a Display Case and a Tall Display Case of éclairs beside other treats, from the player's view in front of the glass. The whole éclair has to be clearly visible, like the others.
   - Check the Stash Shelf, tray, hotbar icon and a garden plant.
3. **Script room:** compile every changed script with `loadstring`. Both main scripts are full, so any "Out of local registers" error means moving code into a table or function.
4. **Fake-save playtest** (`TEST_Patch_DELETE` with a bridge, so the real save is untouched):
   - **Cases:** stock a case, press F to take treats back (with and without a hotbar box selected), and empty-case messages.
   - **Sitting:** place each new piece and screenshot it. Sit with the prompt and jump up. Check customers skip a seat you're in and the prompt hides while a customer sits. Move a chair while sitting.
   - **Storage room:** buy the stash, then both size steps. Screenshot inside and out, place a shelf in the new space, check the whiteboard moved, and check a garden plant behind goes to Inventory. Expand the bakery with a big stash.
   - **Save cleaning:** a JSON round trip keeps a shelf in the widened room.
5. **Park plants:** the park-plant check behind each bakery for the widest room. Remove any plants in the way, and remind you to save.
6. **Not testable here:** a second real player (visitor) sitting, and phone taps on the prompts.
