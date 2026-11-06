# Plan: Paint the walls, oven and cases, and an Expansion tab

## Context
You asked for these in the Decorate menu:
- **Paint:** recolour each of the 4 walls separately, and the stove. It should be cheap, with walls cheaper than the stove.
- **Display cases:** added during the build. Each case can be painted separately, for less than a wall.
- **Expansion:** a new tab that makes the bakery bigger.
- **Golden stove:** it lives in the Expansion tab. It can't be repainted, and a normal stove can never be painted gold.

The golden stove is the **Luxury Oven**: black and gold, 25,000 coins, bakes 15% faster. It was in the Shop, and you chose to move it into the Expansion tab.

## How it plays
**Decorate menu tabs:** Floor, Wall, Paint, Expansion. **Move things** stays at the top of Floor and Wall. On a narrow screen the tabs shrink to share the bar.

**Paint tab**
- **What you can paint:**

  | Row | Price |
  |---|---|
  | Back Wall | 25 coins |
  | Left Wall | 25 coins |
  | Right Wall | 25 coins |
  | Front Wall (the low walls on both sides of the door) | 25 coins |
  | Oven | 75 coins |
  | Each display case, such as "Display Case 1, front right" | 15 coins |

  Each row shows its current colour and a **Paint** button. A case's row also says roughly where it stands, as seen from the door, because the menu covers the bakery.
- **Picking a colour:** **Paint** opens a list of colours. Each has a button in that colour with its price, and the current one says **Now**. **Back** returns to the list.
- **Repainting:** costs the same again, including going back to the original colour.
- **Colours:** Vanilla, Snow, Strawberry, Bubblegum, Peach, Lemon, Mint, Sky, Lavender, Cocoa, Cherry.
  - Walls start Vanilla, the oven starts Mint, and cases start Bubblegum.
  - The oven can't use Lemon, and there are no gold or shiny finishes, so a normal oven never looks golden.
- **What gets painted:**
  - A wall's main panel. The pink trim stays pink.
  - The oven's body, backsplash and hood. The pink trim, steel and burners stay as they are.
  - A case's frame. The glass stays clear.
- **Luxury Oven:** if you own it, its row says "Gold finish, can't be repainted", with no button.
- **Moving and storing cases:** a case keeps its colour when moved, and loses it if it's put back in storage.

**Expansion tab**
- **Bigger Bakery:** three steps. Each adds 8 studs at the back and 2 on each side. The door, sign and front stay where they are.

  | Step | Inside size | Price |
  |---|---|---|
  | Start | 48 × 38 | |
  | 1 | 52 × 46 | 3,000 coins |
  | 2 | 56 × 54 | 8,000 coins |
  | 3 | 60 × 62 | 18,000 coins |

  At full size, no bakery touches another bakery, the grocery store, or a tree, lamp, bench or path.
- **What moves when you expand:**
  - The back and side walls move out, and new floor fills the space. The new floor is part of the grid.
  - Wall decorations move with their wall.
  - Furniture and stations stay where they are, so the oven may end up away from the back wall until you move it.
- **Luxury Oven:** the row moved here from the Shop. It has the same price, says "Owned" once bought, and goes to its usual spot, or the first free spot if that's taken. The Shop's "Shop!" alert no longer counts it.

**Other players:** each owner's size and colours are saved. When an owner leaves, the bakery goes back to the starting size and original colours.

## Files changed
- **`Config`:**
  - `Paints`: the 11 colours. Lemon has `Oven = false`.
  - `PaintTargets`: the four walls and the oven, with their part names, original colour and price.
  - Prices: `WallPaintCoins`, `OvenPaintCoins` and `CasePaintCoins`.
  - `CaseOriginalPaint`: Bubblegum.
  - `Expansions`: three steps.
  - Display cases' pink parts are marked `Paint = true`.
- **`ItemBuilder`:** `Build` takes a paint colour for parts marked `Paint`.
- **`Layout`:**
  - The grid's cell 0, 0 stays the starting room's back left corner, so saved spots never change. A bigger bakery adds cells with negative numbers on the left and back.
  - `Layout.Bounds(level)` gives the floor inside the walls at each size.
  - `EntryAt`, `Rotated`, `WallEntryAt`, `OnWall` and `Check` take those bounds, and `Inside` is shared.
  - `CleanEntry` accepts cells inside the biggest bakery.
- **`PlayerData`:**
  - `Expansion`: 0–3.
  - `Paint`: target → colour, dropping colours a target can't use.
  - A case's placed entry keeps `Paint`.
  - Saved spots are checked against the saved size.
- **`BakerySystem`:**
  - **At startup:** records each wall part's size, position and colour, and the oven's paint parts' colour.
  - **`applyExpansion`:**
    - stretches and moves the walls and trims by fixed amounts per stud
    - adds a `FloorExtension` copy of the floor, 0.02 lower, under the grown area
    - leaves the original `Floor`, which floor space is measured from, where it is
  - **`applyPaint`:** colours the walls and oven, or restores them when the owner leaves.
  - **Claiming and releasing a plot:** applies the owner's size and paint, or goes back to the start.
  - **Purchase kinds:**
    - **"Expand":** moves wall decorations on the walls that move.
    - **"Paint" (target, colour):** the Luxury Oven isn't a target, and the oven can't take Lemon.
    - **"PaintCase" (key, colour):** rebuilds the case in its colour.
    - Painting something its current colour costs nothing.
  - **Place remote:** keeps a case's paint when it moves.
  - **Room edges:** stations, the Luxury Oven's free spot and placing all use the owner's size.
  - **`syncStats`:** sends `Expansion` and `Paint`.
- **`BakeryClient`:**
  - **Tabs:** the four tabs, sharing the bar's width.
  - **Paint tab:** the list and colour views, with readable text on each colour.
  - **Expansion tab:** Bigger Bakery and the Luxury Oven, which is removed from the Shop.
  - **Decorating:**
    - The grid, wall grid and preview checks use your size.
    - Pointing at the floor also finds the new floor.
    - The grid is redrawn if the bakery grows while you decorate.
    - A moved case's preview shows its colour.

## Build order
Each step was synced to Studio, committed on its own, and pushed.
1. `Config`: paints, prices and expansion steps
2. `ItemBuilder`: painted parts
3. `Layout`: bounds for each size
4. `PlayerData`: save size, paint and case colours
5. `BakerySystem`: stations and placing use the owner's size
6. `BakerySystem`: expansion
7. `BakerySystem`: painting
8. `BakerySystem`: the Shop alert drops the Luxury Oven
9. `BakeryClient`: decorating follows the bakery's size
10. `BakeryClient`: Paint tab
11. `BakeryClient`: Expansion tab, with the Luxury Oven out of the Shop
12. Docs: README, roadmap and this plan

## Verification
- **Rules at the starting size:** the old and new `Layout` gave the same answers for 16 floor and wall cases.
- **Rules at each size:**
  - pieces fit in the new floor and are refused past the walls
  - wall pieces go on the moved walls
  - saved spots are accepted only inside the biggest bakery
- **Saves:** your real save was run through `clean()` read-only and loaded unchanged. Test values in memory kept valid paint, sizes and case colours, and dropped Lemon on the oven, unknown colours and targets, a spot outside the saved size, and a size above 3.
- **Playtest through the server:**
  - **Painting:** all four walls, the oven and both cases changed exactly the right parts and took 205 coins in total.
  - **Refused:** Lemon on the oven, painting the Luxury Oven, an unknown target or colour, and painting a sconce as a case. Painting a case its own colour cost nothing.
  - **Expansion:** all three steps took 29,000 coins, and a fourth was refused. The walls, trims and front walls ended exactly at the new edges, with new floor underneath. Your Wall Sconce moved out with the left wall and stayed flush.
  - **New space:** a plant and a clock went into the new space. The Luxury Oven, bought in the expanded bakery, went to the first free spot.
  - **Owner leaves:** after kicking the player, the bakery went back to its starting walls, floor and colours, with no Luxury Oven.
  - **Saving:** after rejoining, the size, all paint, both case colours and every piece came back.
- **Playtest through the menus with the mouse:**
  - The Expansion tab bought step 1 and the Luxury Oven.
  - The Paint tab painted the oven Strawberry and a case Strawberry. The oven's list had no Lemon, and **Now** moved to the new colour.
  - Decorating showed the grid at the new size, and clicking the new floor moved a held piece there.
  - The Shop no longer lists the Luxury Oven.
- **Not tested:** tapping on a phone, and the four tabs on a real phone screen.
- **Cleanup:**
  - Your save was restored to its exact copy from before the tests. That's 1,854 coins, 24 Stars, the starting size, no paint, helpers at level 1, your pantry and your layout, and it's unlocked.
  - The test bridge is removed and HTTP is off.
  - During the tests, someone clicked the Baker and Stocker helper upgrades in the Shop. Those were undone by the restore.
