# Plan: Fix picking up pieces, always show Rotate, new delivery counter

## Context
After trying the grid decorating, you reported three problems:
- **No Rotate button.**
- **Oven and cookbook counter won't move.**
- **Delivery station:** some of its parts are on the wall and stay behind when it moves. You want it rebuilt as a countertop with a laptop.

**Why the oven and cookbook counter won't move:** clicking a piece looks only at the floor spot under the pointer. When you click the front of a tall piece that stands against a wall, the pointer passes over it and lands on the floor behind it, or past the edge of the floor, so nothing gets picked up. This affects the oven, cookbook counter, pantry shelf, and the tops of display cases. My earlier test clicked floor spots, not the pieces themselves, so it missed this.

**Why there's no Rotate button:** Rotate only appeared after something was picked up, and nothing could be picked up. Rotation already works: each press turns the piece a quarter turn, so 4 presses face it all four ways and back. You just never got to see the button.

## Changes
### 1. Click the piece itself to pick it up
- **How it works:** each piece now has a 3D box: its grid footprint plus its height. A click or tap picks the nearest box the pointer passes through, so clicking the front of the oven, the cookbook counter or a tall case works. The gold hover outline uses the same check.
- **Heights:**
  - `Layout.ItemShape` works out each item's height from its parts.
  - The server measures each station's height along with its footprint, and stores it as a `FootH` attribute.
  - `Layout.StationShape` returns that height.
- **Unchanged:** moving the preview still follows the floor spot under the pointer.

### 2. Rotate is always on screen while decorating
- **Nothing held:** the bottom row shows **Rotate** and **Done**. Rotate is grey, and pressing it says "Pick something up first, then rotate it".
- **Holding something:** Rotate turns blue. The row is Rotate, Place, Cancel, plus Store for decorations and bought cases. The R key still works on a computer.

### 3. New delivery station
- **Wall parts removed:** the dark hatch panel and the blue "Deliveries" board on the back wall come out of all 6 bakeries, so nothing is left behind when the station moves.
- **Countertop:** the brick-textured table and metal belt are replaced by a counter in the same wood and white marble as the checkout counter. It is about 9 studs wide and 3.6 deep, against the back wall where the old table stood.
- **Laptop:** a laptop sits on the counter, facing you, with a lit screen that says "Deliveries".
- **Prompt and guide:** the "Pack Delivery" prompt stays on the counter, and the guide arrow still points at the station.
- **Shipping animation:** a parcel appears on the counter beside the laptop, lifts up, and shrinks away. It no longer uses the belt.
- **Footprint:** the server measures the new size when it starts, so placement rules pick it up automatically.

## Files changed
- **`ReplicatedStorage.Layout`:** `ItemShape` adds `H`, `StationShape` reads `FootH`, and each piece described by `describe` gets a `Height`.
- **`BakerySystem`:**
  - `setUpStation` also measures the highest point and sets `FootH`.
  - The plot table drops `packingBelt` and adds the counter top.
  - `animateBox` plays the lift-and-shrink parcel.
- **`BakeryClient`:**
  - `pieceAt` becomes a ray-against-box check called `pieceOnRay`. Hover, click and tap all use it.
  - Rotate shows whenever decorating, greyed out when nothing is held.
- **`tools/build_layout.luau`:**
  - removes `Hatch`, `DeliveryBoard` and `PackingBelt`
  - restyles `PackingTable` as the counter base, keeping its name and prompt
  - adds `Top` and a `Laptop` model inside `PackingStation`

  It stays safe to run again.

## Build order
Each step is its own commit, pushed right after.
1. `Layout` heights
2. `BakerySystem` station heights
3. `BakeryClient` picking by piece
4. `BakeryClient` Rotate always shown
5. Delivery counter: the builder, run on all 6 plots
6. `BakerySystem` new parcel animation
7. Roadmap note

## Verification
In a playtest, with real mouse clicks on the pieces' visible fronts, not floor spots:
- **Picking up:**
  - click the oven, cookbook counter, pantry shelf, a display case's glass and the delivery laptop
  - each one picks up, and the banner reads "Moving …"
  - move the oven and cookbook counter, rotate each one 4 times, and check they come back to their starting direction
- **Rotate:** check the Rotate button shows in Move mode, greyed out, and shows the hint when pressed.
- **Delivery station:**
  - screenshots of the new counter and laptop, with nothing left on the back wall in any bakery
  - move the station, then ship an order: the parcel plays on the counter
- **Phone:** a screenshot of the bottom row in the iPhone simulator.
- **Cleanup:** restore your save's coins, stars, tray and layout with explicit values. Remove the test scripts, keep HTTP off, and reset the simulator to the laptop.
