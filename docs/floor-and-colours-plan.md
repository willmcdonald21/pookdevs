# Plan: pick a colour when buying, and tiled floors

## Context
Two decorating requests:
1. **Colour when buying.** Buying a customizable piece opens the colour window, so its colour is part of the purchase. Before this, a new display case always arrived pink, and changing it meant paying 15 coins in the Paint tab.
2. **Floor tiles.** The floor becomes a grid of tiles about the size of a cafe table. Each tile can be laid in one of several styles for 5–10 coins.

Your choices:
- **Which pieces:** only the Display Case and Tall Display Case for now, built so any future piece with paintable parts gets the colour window too.
- **Colour cost:** the colour picked when buying is free. Repainting later still costs 15.
- **Laying tiles:** tap tiles, or click and drag on a computer, plus a **Fill floor** button that shows the total and needs a second tap. Tiles cost 5–10 coins each.
- **Styles:** wood planks, marble & stone, pastel tiles and checkerboards. Going back to the original cream planks is free.

## How it plays

### Colour when buying
- In the Decorate menu's Floor or Wall tab, tapping the price of a paintable piece you can afford opens "New Display Case: pick its colour. It's free with the display case".
- The colour list has Back at the top, then one row per colour. Each colour's button is in that colour and shows the piece's price. The starting colour (Bubblegum for cases) is marked "Its original colour".
- Picking a colour buys the piece and goes back to the list, where its Place button appears as before.
- Placing it shows the preview in the chosen colour, and the piece is built in that colour.
- **Inventory:** a piece put away keeps its colour, so placing it again brings it back in the same colour. Selling a stored copy drops one remembered colour.
- **Can't afford it:** the price button buys straight away, so the server's "You need N more coins" message shows, without opening the colour list.
- **Paint tab:** it lists every placed paintable piece (for now, the cases) for repainting at 15 coins, as before.

### Floor tiles
- **The grid:** 4-stud squares. Columns line up with the middle of the floor, and rows count from the starting back wall. Expansions move the back wall 8 studs at a time, so the rows never shift.
- **Cut tiles:** tiles at the walls are cut to fit:
  - a 2-stud strip along the front wall;
  - 2-stud strips down the sides after expansions 1 and 3.
- **Count:** 120 tiles at the starting size, 168 after the first expansion, and up to 256 at the largest size.
- **Menu:** the Paint tab's first row is "Floor tiles: wood, marble, stone or pastels, 5 to 10 coins a tile". Its Tiles button lists the styles, each with a button in its colour showing the price.
- **Styles:**

| Style | Price per tile | Material |
|---|---|---|
| Cream Planks (the original) | Free: takes tiles up | WoodPlanks |
| Oak, Walnut, Cherry Planks | 6 | WoodPlanks |
| White Marble, Pink Marble | 8 | Marble |
| Grey Slate | 8 | Slate |
| Pink, Mint, Sky, Lemon, Lavender Tiles | 5 | CeramicTiles |
| Black & White Check, Pink & White Check | 10 | SmoothPlastic, alternating colour from tile to tile |

- **Tile mode:** picking a style closes the menu and starts tile mode, with the normal camera.
  - The banner says "Laying Pink Tiles, 5 coins a tile. Tap or drag across your floor".
  - Grid lines mark the tile edges.
  - With a mouse, a see-through preview tile in the style follows the pointer.
- **Laying:**
  - A click or tap lays the tile under it.
  - Dragging with the mouse held down lays each tile it crosses, each paid once.
  - Tiles that are already that style are skipped.
- **Bottom row:** "Fill floor: N coins" and Done.
  - The first tap on Fill floor asks "Lay Pink Tiles on 120 tiles for 600 coins? Tap Sure? to do it".
  - A second tap within 3 seconds lays them all.
  - With Cream Planks, the button says Clear floor and takes every tile up for free.
- **Not enough coins:**
  - Tapping a tile you can't afford shows "You need N more coins for a tile".
  - Several tiles sent at once lay as many as the coins cover.
  - Fill floor is all or nothing.
- **Under everything:** tiles are thin parts just above the floor, so rugs, furniture, the decorate grid and the placement marker all show on top of them. Customers and players walk over them as before.

## How it's built
- **`Config`:**
  - `IsPaintable(item)` and `OriginalPaint(item)`.
  - `PiecePaintCoins` 15 and `PieceOriginalPaint` "Bubblegum" (these were `CasePaintCoins` and `CaseOriginalPaint`).
  - `Floors`, `GetFloor`, `TileColor(style, i, j)` and `FloorFill.ConfirmSeconds` 3.
- **`Layout`:** `TileSize` 4, `TileKey`, `TileOfKey`, `TileRect`, `TileAt` and `Tiles(bounds)`. Keys are `"i,j"` strings.
- **`PlayerData`:**
  - `Floor = { ["i,j"] = styleId }` drops bad keys, unknown styles, Original and tiles outside the biggest bakery.
  - `SparePaint = { [itemId] = { paintId, ... } }`, newest last, is cut to the number of unplaced copies, keeping the newest.
- **`BakerySystem`:**
  - **Spare colours:** a `sparePaint` table (push, pop, fit). Buying with a colour pushes it, placing a new copy pops it, putting a piece away pushes its colour, and selling a spare fits the list.
  - **Tiles:** a `floorTiles` table (lay, build, buy), with tile parts in each plot's `FloorTiles` folder. Tiles are laid on claim, cleared on release, and laid again when the bakery expands.
  - **Purchases:** new `"Floor"` (style, list of keys) and `"FloorFill"` (style) kinds. "PaintCase" accepts any paintable piece.
  - **Sync:** `syncStats` sends `Floor` and `SparePaint`.
- **`BakeryClient`:**
  - **Colours:** `colourRows` is shared by repainting and buying, and `paintablePieces` replaces `paintableCases`.
  - **Tile mode:** a `tiling` table (start, fillCost, refresh, tileAt, layAt, showHover), a Fill bar button, and `showGrid` drawing tile edges while laying.
  - **Overlays:** the decorate grid now sits at 0.05 and the doorway tint at 0.06, above the tiles' 0.03.
