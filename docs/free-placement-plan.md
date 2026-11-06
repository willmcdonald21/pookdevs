# Plan: Free placement decorating on a grid

## Context
Today, decorating has three limits:
- **Camera:** decorating jumps the camera to a top-down view.
- **Fixed pieces:** the oven, pantry, cookbook counter, checkout counter, packing table and starter display case can't be moved.
- **Squares:** decorations only go on 16 fixed squares.

You asked for:
- **Camera:** it stays as it is while you decorate.
- **Fine grid:** placement on a grid of small squares, so things can go almost anywhere.
- **Rotate button:** each click turns the piece a quarter turn, so 4 clicks bring it back to where it started.
- **Everything movable:** this includes the pantry, cookbook counter, oven and display case. You chose to make the checkout counter and packing table movable too.

## How it plays
- **Grid:** each square is 1 stud. Your bakery floor is 48 × 38 squares. Grid lines appear on your floor only while you decorate, and a pale tint marks the area just inside the door. That area stays clear so customers can get in, but rugs and carpets can go there.
- **Placing:** pick an item in the Decorate menu, or press **Move things** and tap something in your bakery. Your camera and walking work as normal. A see-through preview of the piece snaps to the grid. A green outline means it fits. Red means it doesn't, and the banner says why, for example "Something's in the way" or "Customers need room in front of the counter".
  - Computer: the preview follows your mouse. Click to place, and press **R** or the **Rotate** button to turn it.
  - Phone: tap the floor to move the preview there. Then press **Rotate** or **Place**.
  - Buttons along the bottom: **Rotate**, **Place**, **Cancel**, plus **Store** when you're moving a decoration or a bought case.
- **Facing:** a small arrow on the preview shows which way the piece faces. New items face the door to start with.
- **Rules:**
  - Solid pieces can't overlap each other.
  - Rugs and carpets can go under tables and other solid pieces, but not on top of another rug.
  - Display cases and the checkout counter need a 3-square strip in front kept clear, so customers can stand there.
  - Everything stays inside the walls.
- **Station pieces:** the oven, pantry shelf, cookbook counter, checkout counter and packing table can be moved and rotated, but never stored. Their prompts, labels, burner glow and smoke move with them.
- **Your first display case:** the glass case on the counter top becomes a free, floor-standing Display Case, the same model you can buy for 100 coins. It starts in the shop area near the counter, and its treats carry over. You can move it, but you can't store your last display case. A small cash register replaces it on the counter top.
- **Customers:** they now walk around furniture to reach a stocked case and then the counter, wherever those are. If you box something in completely, they fall back to walking straight there.
- **Deliveries:** the box now slides along the packing table's belt and disappears, so it works wherever the table is. The hatch and delivery board stay on the back wall as decoration.
- **Spawn:** you now spawn just inside the door, since that area is always kept clear.
- **Other players:** each owner's layout is saved. When an owner leaves, that bakery goes back to the default layout for the next player.

## Your current save
- **Your Tall Display Case:** it's on one of the old squares now. The squares are going away, so it moves to storage, ready to place. Any treats in it go back to your tray.
- **The free Display Case:** you get one, already placed, holding whatever was in your starter case.
- **Everything else:** all your pass decorations stay owned and ready to place.

## Files changed
- **New `ReplicatedStorage.Layout` module:** shared by server and client, so both check placements the same way. It holds:
  - the grid bounds and the entrance zone
  - item footprints, measured once from each item's parts using `ItemBuilder.Build`
  - station footprints, which the server measures when it starts and stores as attributes on each station
  - `Rect`, the front strip, `Check` (returns ok and a reason), and `ToCFrame`
- **`Config`:** remove `SpotCount`, `StarterCaseKey` and `StarterCaseSlots`, and add the starter case's default spot.
- **`PlayerData.clean`:**
  - **`Placed`:** becomes `{ [key] = { Id, X, Z, R } }`, where X and Z are whole-number grid corners and R is 0–3.
  - **New fields:** `Stations` (the same shape, one per station) and `LayoutVersion = 2`.
  - **Older saves:** placed items go to storage, their case treats go back to the tray, the player gets one free SmallCase placed as key "starter", and `Stock.starter` is kept.
  - **Validation:** entries are checked for type, range and owned count.
- **`BakerySystem`:**
  - **Stations:**
    - At startup each station records its parts' offsets and its default spot, snapped to the grid.
    - `moveStation` repositions all of a station's parts; it runs when a player claims the plot, when they move a station, and when the plot is released.
    - `refreshHelpers` re-places the Baker and Stocker next to the oven and the first case.
  - **The `Place` remote:** takes `("New", itemId, x, z, r)`, `("Move", key, x, z, r)` and `("Store", key)`. Each is checked with `Layout.Check` against the server's own data. `buildPlaced` and `addCase` read the grid entry, and a case's customer spot is in front of it.
  - **Starter case code removed:** `StarterCaseKey`, `DisplayCase`, the old `helperSpot` and `DecorSpots` lookups, and `counterRight`. The pay spot now comes from the checkout counter's front.
  - **Customers:** `walkCustomer` follows `PathfindingService` waypoints inside the bakery, and falls back to a straight line when no path is found.
  - **Other changes:** `animateBox` slides along the belt, and the guide's packing target is renamed to `PackingStation`.
- **`BakeryClient`:**
  - **Removed:** the top-down camera, the old pads, and the old square clicks.
  - **New decorate mode:**
    - drawing: the local grid lines and entrance tint, and a preview clone with a footprint outline and a facing arrow
    - modes: hover highlight in Move mode, with the original piece hidden while you move it
    - controls: the Rotate, Place, Cancel, Store and Done buttons, with R and click on computer and `TouchTap` on phone
  - **Panel:** the Decorate panel's last row becomes **Move things**, and `placedCount` reads the new format.
- **New `tools/build_layout.luau`, run once in Edit mode:** for each plot it will:
  - remove `DecorSpots` and the countertop `DisplayCase`
  - group the counter parts into a `Checkout` model with a cash register and drop `Spots.CustomerCounter`
  - group the table and belt into `PackingStation`
  - move `PlayerSpawn` inside the door

## Build order
Each step is exported and committed separately, and pushed after each commit.
1. `Layout` module, then the `Config` cleanup
2. World builder (`tools/build_layout.luau`), run on all 6 plots
3. `PlayerData` save format and migration
4. `BakerySystem`, in this order:
   1. moving stations
   2. the new `Place` remote and the free starter case
   3. customer pathfinding and the pay spot
   4. the packing animation
5. `BakeryClient`, in this order:
   1. grid and preview
   2. placing, rotating and storing
   3. Move mode for stations
6. Docs: README, roadmap and this plan in `docs/`

## Verification
- **Layout rules:** `Layout.Check` is run directly against a set of cases: overlap, rug under a table, out of bounds, the entrance zone, a case facing a wall, and moving a piece onto its own old spot.
- **Your save:** your real save is run through `clean()` read-only first: the Tall Display Case lands in storage, you own and have placed one free case, and the starter treats are kept. Then a real play session loads, saves and releases the lock.
- **In a playtest, through remotes:**
  - Place, move and store items.
  - Rotate 4 times and check it's back to its starting direction.
  - Storing your last case is refused.
  - Move every station, then:
    - bake at the moved oven and stock a case
    - open the cookbook and pantry
    - ship a delivery
    - check that customers pay at the moved counter
- **Customers:** put furniture between the door and a case, then check the customer's waypoints and a screenshot show them walking around it.
- **Leaving the plot:** release it, and check the stations return to their default spots and the next owner gets a normal bakery.
- **Client:**
  - The camera stays in its normal mode while you decorate.
  - The preview follows simulated mouse moves, and a click places.
  - Screenshots of the grid, a green and a red preview, and the arrow.
- **Phone:** check the button layout in the iPhone simulator. Simulated taps may not register in Studio. If they don't, you'll check tapping yourself.
- **Not testable here:** Studio still doesn't show interaction prompts for me, so you'll be the one to check pressing E after things move.
- **Cleanup:** test scripts removed, HTTP off, cookie price 5, starting Stars 5, your save unlocked.
