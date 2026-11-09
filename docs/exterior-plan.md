# Plan: bakery exteriors — name, colours and a garden

## Context
Right now a bakery's outside can't be changed. The sign always says "<DisplayName>'s Bakery". The outer walls show whatever colour the inside walls are painted, because each wall is a single part. The lawn around the building is bare.

You asked for:
- Tapping **your own bakery's sign** in the plaza opens an exterior popup. Its top line is the bakery's name, and tapping that lets you rename it.
- The popup also sets a **primary** colour (the outside walls) and a **secondary** colour (the trim/accent).
- A **greenery shop** of bushes, small trees, flowers and so on, placed around the outside.

Your choices:
- **Garden area:** a front yard either side of the path, plus a ring down both sides and along the back. A few park plants near each bakery get removed to make room.
- **Garden cost:** the garden is bought for **8,000 coins**. The plants are expensive because they're a luxury.
- **Accent:** trim only. Don't add new pieces like an awning; the secondary colour paints the top trim and the sign board.
- **Prices:** renaming is free and colours cost coins. Going back to an original colour is free.
- **Charm:** coin plants give some Charm. Deluxe plants cost Stars and give extra Charm.

The plan is copied to `docs/exterior-plan.md` as the first commit, as usual.

## How it plays

### Opening it
- On your own bakery, a tap or click on the `Sign` part opens the **Exterior** popup. This works from anywhere in the plaza, up to about 150 studs away.
- Only the owner can open it. Other bakeries' signs, and co-bakers, do nothing.
- Your own sign shows a small "✏️ Tap to customize" tag, visible only to you, so you can find the feature.
- Taps are ignored while decorating, and when the tap lands on a button or menu.

### The popup
- **Title row:** the bakery's name with a ✏️. Tapping it turns it into a text box (`ClearTextOnFocus = false`, at most 24 characters).
  - Leaving the box saves the name.
  - An empty name goes back to "<DisplayName>'s Bakery".
  - The sign shows the name after Roblox's filter, so everyone (including you) sees the filtered text. It shows the default name until filtering finishes.
- **Tabs:** `Colours | Garden`.
- **Colours tab:**
  - "Walls: the outside of your bakery" (primary, **100 coins**) and "Trim: the top edge and the sign board" (secondary, **50 coins**).
  - Each row's Change button opens the shared colour list (`colourRows`). The original colour is marked and free.
  - Colours come from `Config.Paints`, with four new ones that also show up indoors: White, Brick, Sage and Charcoal.
- **Garden tab, before buying:** one row, "Garden: a yard around your bakery for bushes, trees and flowers", with an **8,000 coins** button.
  - The first tap asks "Sure?" and a second tap within 3 seconds buys it (the same two-tap rule as Sell and Fill).
  - If you can't afford it, the box shows just an OK button (your can't-afford rule).
- **Garden tab, after buying:** one row per plant, with Buy, then Place, the same way the Decorate tab's rows work.
  - Place closes the popup and starts decorate mode with that plant held on the lawn.
  - Garden plants you've put away show in Decorate → Inventory as usual.

### Outside colours
- **Primary:** thin wall skins on the outside face of every outer wall. This includes the cut pieces of the back wall and the Sweet Stash's outer walls. The inside paint stays inside.
- **Secondary:** the `Trim*` parts and the sign board. The sign text switches between dark and light so it stays readable on the board colour.
- **Originals:** the starting colours are the walls' and trim's current colours, so nothing changes until you pick one.
  - Players who painted their inside walls will now see the original outside colour on the outside, rather than their inside paint.

### The garden
- **Size:** one fixed outer rectangle in floor space, taken from `Layout.Largest` plus the walls.
  - About 6 studs out at the sides and back (X −37..37, Z −50).
  - A front yard out to Z 30.
- **Kept clear:**
  - the current bakery and its walls;
  - the Sweet Stash room, if bought;
  - the path (|X| ≤ 5 plus a margin);
  - the crate at (9, 24) and the flyer stand at (−9, 24).
- **Small bakeries get a bigger yard.** The back and sides have extra room until the bakery grows into it.
  - When an expansion or the Stash would cover a plant, that plant goes to your Inventory and a message says so.
  - The Expand button's text warns about this.
- **Placing:** pieces sit on the lawn, not at floor height. The grid, Rotate, Move, Store and Sell all work as they do indoors.
- **Plants:**

| Plant | Price | Charm |
|---|---|---|
| Flower Patch | 400 coins | 2 |
| Tulip Row | 600 coins | 2 |
| Round Bush | 750 coins | 2 |
| Flowering Bush | 1,000 coins | 3 |
| Potted Topiary | 1,200 coins | 3 |
| Box Hedge (4 long) | 1,500 coins | 3 |
| Little Green Tree | 2,000 coins | 4 |
| Rose Arch | 2,500 coins | 4 |
| ⭐ Heart Topiary | 20 Stars | 10 |
| ⭐ Cherry Blossom Tree (falling petals) | 30 Stars | 12 |
| ⭐ Golden Flower Bed | 40 Stars | 15 |

  The shapes are fixed versions of the park builders in `tools/build_greenery.luau` (`bush`, `greenTree`, `cherryTree`, `flowerPatch`), using the same palettes.

## How it's built

### Script room
- **BakeryClient** has 0 top-level locals left, so the new client UI goes in a **new ModuleScript**, `src/StarterPlayer/StarterPlayerScripts/ExteriorPanel.luau`.
  - BakeryClient wires it up without a new local: `panels.Exterior = require(script.Parent.ExteriorPanel)({ ...helpers... })`. The helpers include `addRow`, `colourRows`, `showTabs`, `setPanel`, `panelTitle`, `isMine`, `myPlot`, `state`, the remotes, `startPlacing` and a `decorating` getter.
  - The module also owns the sign-tap handler and the ✏️ tag.
  - The garden changes to decorate mode are edits inside existing functions, which don't use top-level locals.
- **BakerySystem** has 2 left. One new `exterior` table holds every server function as a field.
- **Measure both** before syncing, with the dummy-locals-at-a-line method in `docs/roadmap.md`.

### `Config` (`src/ReplicatedStorage/Config.luau`)
- Settings:
  - `Config.Exterior = { WallCoins = 100, TrimCoins = 50, NameLength = 24, RenameSeconds = 2, Original = { Primary = ..., Secondary = ... } }`, with the originals filled in from the real wall and trim colours in Studio.
  - `Config.Garden = { Coins = 8000 }`.
- **Paints:** four new `Config.Paints` entries.
- **Garden items** in `Config.Items` with `Room = "Garden"`, using `Coins`/`Stars` and `Charm` from the table above.

### `ItemBuilder` (`src/ReplicatedStorage/ItemBuilder.luau`)
- `Ball` accepts a full `Size`, for squashed leaves and flowers.
- An optional `Tilt` (degrees) for the cherry tree's lean and branches.
- `Petals = true` adds the park's petal ParticleEmitter (texture 74180373620457).
- `Layout.ItemShape` uses the same `Size` for Balls when measuring footprints.

### `Layout` (`src/ReplicatedStorage/Layout.luau`)
- `Layout.Garden`: the outer rect, path half-width, and crate and flyer keep-clear boxes.
- `Layout.GardenBounds()`.
- `Layout.GardenThings(level, stashBought)`: fixed blocked rects with a `Reason` ("Keep it out of your bakery", "Keep the path clear"), modelled on `StashThings` (`Layout.luau:327`).
- `BoundsFor` dispatches on `item.Room` ("Stash" → `StashBounds`, "Garden" → `GardenBounds`).
- `Layout.Farthest` widens to include the garden.
- `Check`'s out-of-bounds message names the right room.
- `Layout.Version` stays 2. Bumping it would run every save through `convertLayout`.

### `PlayerData` (`src/ServerScriptService/PlayerData.luau`)
- New fields in `clean`:
  - `BakeryName`, cleaned with `cleanName` and cut to 24 characters; nil when empty.
  - `Exterior = { Primary, Secondary }`, valid paint ids only.
  - `Garden = saved.Garden == true`.
- `cleanLayout` (around lines 139–144) keeps Garden items only when `data.Garden` is set, and its Room checks name "Stash" explicitly.

### `BakerySystem` (`src/ServerScriptService/BakerySystem.server.luau`)
- **Room checks:** every `item.Room` check that means the Stash becomes `item.Room == "Stash"`. That covers `placedCaseCount` (around 278), `addCase` (1201), the Store/Sell, Treat and `New` gates, `stash.clearDoorway` (1429), `stash.moveShelves` (1460), `sellWhileAway` (4416) and the purchase message (1780). `New` and Purchase `Item` gate Garden items on `data.Garden`.
- **The `exterior` table:**
  - `exterior.clad(plot, data)` rebuilds an `Exterior` folder of 0.1-thick skins on the outward face of each wall part (using the wall's own material).
    - Wall parts: BackWall, BackWallRight, BackWallTop, LeftWall, RightWall, FrontLeft and FrontRight, plus the Stash room's outer walls. The Stash part names are checked in `tools/build_stash.luau`.
    - It skips the stretch of back wall inside the Stash room. It's called from `claimPlot`, `releasePlot`, after `applyExpansion` and after `stash.place`.
  - `exterior.paint(plot, data)` colours the skins and `Trim*`/`Sign` (originals recorded in `setUpPlot`) and sets the sign text colour.
  - `exterior.showName(plot)` filters the name with the `TextService` pattern from `filterName` (around 3504) and drops stale results. It updates `plot.signLabel` and is called from `claimPlot` in place of the DisplayName line.
  - `exterior.ground(plot)` measures the lawn drop with `groundPoint` (around 2414) and stores it as a `LawnDrop` attribute on the plot. When the garden is bought, it adds an invisible `GardenGround` part (CanQuery on, CanCollide off) over the garden rect for the client's rays.
  - `exterior.clearGarden(plot, data)` stores garden pieces that now overlap `GardenThings` and sends one message. It runs after Expand and after buying the Stash.
  - A new `BakeryName` RemoteEvent, owner-only and throttled to `RenameSeconds`.
- **Purchase kinds:** `"Exterior", "Primary"|"Secondary", paintId` (same checks as `"Paint"` at around 1850) and `"Garden"` (8,000 coins, sets `data.Garden`, builds `GardenGround`).
- **`buildPlaced` and `layoutThings`:** Garden items are built `LawnDrop` lower. `layoutThings` adds `GardenThings` for garden pieces.
- **`syncStats`:** sends `BakeryName`, `ShownName`, `Exterior` and `Garden`.
- **`releasePlot`:** resets the skins, trim and sign colours, the sign text, and `GardenGround`.

### `BakeryClient` (`src/StarterPlayer/StarterPlayerScripts/BakeryClient.client.luau`)
- `surfacePointAt` (around 2860) also hits `plot.GardenGround` when a Garden item is held.
- `myBounds` and `refreshHeld` already go through `BoundsFor`. The extra blocked things come through `allThings`.
- `stash.regrid` (around 3185) compares the bounds' room instead of `MaxZ < MinZ`.
- `holdItem` starts a new garden piece at the first free front-yard spot.
- The preview, grid and `pieceOnRay` use `LawnDrop` for Garden items.
- The Decorate item list (around 1208) leaves out `Room == "Garden"`, since those are sold in the popup, as it already does for Stash items.
- The Inventory tab includes stored garden pieces.

### `ExteriorPanel.luau` (new)
- The title TextBox, the Colours and Garden tabs, buying the garden, and the plant rows.
- The sign tap: `UserInputService.InputBegan` (MouseButton1) and `TouchTap`, with a raycast that only includes `myPlot().Sign`. It skips `processed`, GUI hits and decorate mode.
- The ✏️ BillboardGui tag on the owner's sign.

### The place (Studio, Edit mode)
- **Sign:** turn on `CanQuery` for each `PlotN.Sign` if it's off. Check how the board shows (Part colour, or the label's background) and colour that.
- **Overlap check:** before anything is removed, check each plot's garden rect against neighbouring plots' gardens, the grocery store, the townsfolk ways, lamps and benches. If a side clashes, shrink the ring for every plot.
- **Park plants:** delete the park plants inside the garden rects, without re-running the builder, because a re-run reshuffles the whole park. Then update `tools/build_greenery.luau`'s keep-clear (`BAKERY_BOX`, line 41) to the garden rect so a future run matches.
- **Saving:** remind you to save or publish afterwards.

## Commits (each one separate and pushed)
1. Plan doc.
2. Config.
3. ItemBuilder.
4. Layout.
5. PlayerData.
6. BakerySystem.
7. ExteriorPanel.
8. BakeryClient.
9. build_greenery.
10. README.
11. Roadmap, covering what was tested and what wasn't.

## Verification
1. **Before starting:** `git status` is clean and no other session is editing. `get_studio_state` shows Edit mode.
2. **Syncing:** sync each script with `tools/studio_patch.py`, check checksums and `loadstring`, and measure script room. Create the new ModuleScript `ExteriorPanel` in StarterPlayerScripts.
3. **Fake save:** run a fresh-save playtest with the `TEST_Patch_DELETE` patch, so the real save is never touched. Inject coins and Stars through a `TEST_Bridge_DELETE`.
4. **In Play, test:**
   - Tapping your own sign opens the popup, and tapping another plot's sign does nothing.
   - Renaming updates the sign, and an empty name goes back to the default.
   - Changing both colours: the outside changes and the inside paint doesn't. Going back to the original is free.
   - Buying the garden, buying and placing a coin plant and a Star plant, and the Charm going up.
   - Placing on the path or in the bakery is refused with the right message.
   - Expanding with a plant in the way sends it to Inventory, and placing it again works.
   - Buying the Stash with a plant behind the bakery.
   - Releasing the plot (leaving) resets the outside.
5. **Screenshots:** take them from outside each side of the bakery with `camera_position`/`look_at_position`, checking that each image really shows the scene.
6. **Cleaning up:** delete the TEST scripts, turn BakerySystem back on, and remind you to save the place.
7. **Not testable here:** a real phone tap on the sign, and how the filter behaves in the published game (Studio's filter is lenient).
