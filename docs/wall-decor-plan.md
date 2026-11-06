# Plan: Wall decorations and a Wall tab

## Context
Every decoration used to stand on the floor. You asked for decorations that hang on the walls, such as sconces, plants and paintings, in their own **Wall** tab in the Decorate menu. You picked all four kinds, two items each.

This was built on top of the decorating fixes, which gave every piece a height. Wall pieces use those heights so a painting can't hang where the oven or the pantry shelf is.

## How it plays
- **Decorate menu:** two tabs at the top, **Floor** (everything that stands on the floor) and **Wall** (the new items). **Move things** is at the top of both. The menu reopens on the tab you used last.
- **Which walls:** the back, left and right walls. The front is a low wall under the sign, so nothing hangs there.
- **Placing:** a new wall piece starts on the wall nearest the spot in front of you, at about head height. Click or drag on a wall to move it, or tap a wall on a phone. It snaps to a 1-stud grid along the wall and up it, and can move to a different wall. While you hold one:
  - An outline on the wall behind it shows green when it fits and red when it doesn't, and the banner says why.
  - Grid lines show on all three walls.
  - Rotate stays grey, because wall pieces always face into the room. Pressing it or **R** says so.
- **Move things:** click or tap a wall piece to pick it up. **Store** works as it does for floor pieces.
- **Rules:**
  - Wall pieces can't overlap each other.
  - They can't overlap furniture that stands against the wall and reaches up to them. For example: "Hang it above the pantry shelf". The oven's chimney reaches above the wall, so nothing hangs over the oven.
  - The same rule works the other way: a tall piece can't move under a low painting.
  - Rugs never clash with wall pieces.
  - Everything stays below the trim at the top of the wall, 13 studs up.
- **Not solid:** players and customers walk past wall pieces without bumping them, so customer paths don't change.
- **Charm:** wall pieces add Charm like any other decoration.

## The items
| Kind | Item | Price | Charm | Notes |
|---|---|---|---|---|
| Lighting | Wall Sconce | 70 coins | 1 | Brass plate and arm with a glowing bulb that gives off light |
| Lighting | Neon Heart Sign | 10 Stars | 5 | Pink neon pixel heart on a dark board, glows pink |
| Plants | Hanging Ivy | 60 coins | 1 | Wall hook, a hanging pot and two trailing vines |
| Plants | Wall Planter | 80 coins | 2 | Wooden box of pink, yellow and white flowers on two wall brackets |
| Paintings | Cupcake Painting | 90 coins | 2 | Gold frame with a cupcake and a cherry |
| Paintings | Sunset Painting | 110 coins | 2 | Pink and purple sky, a sun setting into a blue sea |
| Extras | Wall Clock | 80 coins | 1 | Round white face, pink rim, two hands |
| Extras | Chalkboard Menu | 100 coins | 2 | Wooden frame, green board, chalk lines and a cupcake doodle |

The game is always daytime, so the glowing parts show more than the light they cast. Prices and Charm can be changed in `Config`.

## Files changed
- **`ItemBuilder`:**
  - **New `Plate` part kind:** a round part whose flat face points out of the wall, used for the clock, the sun and the frosting.
  - **Lights:** a part with `Light = <range>` gets a `PointLight` in its own colour.
- **`Layout`:**
  - **Wall entries:** a wall piece's entry is `{ X, Z, R, Y }`. X, Z and R work as for floor pieces: the strip of cells along the wall, and the direction it faces. R is 0 on the back wall, 1 on the right and 3 on the left. Y is the height of its bottom.
  - **`WallHeight`:** 13.
  - **`ItemShape`:** measures `Plate` parts, and sits a wall item flush against the wall.
  - **`CFrame`:** lifts a piece by its Y.
  - **`WallEntryAt`:** puts a piece on the nearest wall to a point.
  - **`OnWall`:** checks a piece is against the wall it faces away from and below the trim.
  - **`CleanEntry`:** takes an optional y.
  - **Pieces:** each gets `Wall` and `Bottom`.
  - **`Check`:** solid pieces clash only where both their cells and their heights overlap. Every floor piece starts at 0, so floor-to-floor rules are unchanged. Wall pieces skip the doorway and customer-strip rules.
- **`Config`:** 8 items with `Wall = true`. Their origin is on the wall at the piece's bottom, and their parts stick out toward −Z.
- **`PlayerData`:** a saved wall piece keeps its Y, and is dropped if the Y is missing or it's no longer on a wall. Floor pieces drop any stray Y. The save version stays 2.
- **`BakerySystem`:**
  - **`Place` remote:** takes a y for wall pieces. A wall piece without one, or a floor piece or station with one, is refused.
  - **`buildPlaced`:** wall pieces aren't solid.
- **`BakeryClient`:**
  - Floor and Wall tabs.
  - While a wall piece is held, the pointer finds the back and side walls instead of the floor.
  - The outline is drawn on the wall, the wall grid shows, and Rotate stays grey.
  - Picking a piece checks its height range, so wall pieces can be clicked up on the wall.
  - Previews drop the light.

## Build order
Each step was synced to Studio, committed on its own, and pushed.
1. `ItemBuilder`: Plate kind and lights
2. `Layout`: wall rules
3. `Config`: the 8 wall items
4. `PlayerData`: keep wall spots
5. `BakerySystem`: Place remote with heights, and wall pieces not solid
6. `BakeryClient`: Floor and Wall tabs
7. `BakeryClient`: wall placing and moving
8. `Config`: planter brackets and ivy vines, after seeing them in the game
9. Docs: README, roadmap and this plan

## Verification
- **Floor rules unchanged:** 11 floor cases gave the same answer with the old and new `Layout`: overlaps, a rug under a table, a rug on a rug, out of bounds, the doorway, a case facing the wall, a piece in a case's customer strip, a piece moved onto its own spot, and free spots.
- **Wall rules:** checked against the real stations:
  - two clocks overlapping are blocked, and a clock above another clock fits
  - nothing hangs over the oven
  - a painting low over the pantry shelf is blocked, and above it fits
  - the front wall, a piece off the wall, and a piece whose top is above 13 are all refused
  - two paintings meeting in a corner clash
  - a bookshelf can't go under a low planter, but a rug can, and a plant fits under a high painting
- **Saves:** your real save was run through `clean()` read-only, with test wall entries added in memory. Good spots kept their Y. A missing Y, a piece not on a wall, and a half-stud Y were dropped.
- **Playtest:**
  - **Buying:** all 8 items bought through the real purchase remote, with the right prices taken.
  - **Mouse:** Decorate → Wall tab → Place opened the preview on a wall. Clicking a wall moved it there, dragging moved it along and up the wall, and the Place button placed it. Clicking the clock picked it up, and it moved to another wall. The heart sign was picked up and stored.
  - **Server checks:** the server refused a wall piece with no height, a piece on the front wall, a floor case given a height, a painting low over the pantry, and an overlap. It placed 8 more pieces across all three walls.
  - **Charm:** went from 1 to 18.
  - **Saving:** after stopping and starting again, all 10 wall pieces loaded at their saved heights.
  - **Looks:** screenshots of every item on the walls.
- **Not tested here:** tapping a wall on a real phone, and how the sconce and heart light look at night, since the game has no night.
- **Cleanup:** your save is back to 814 coins, 23 Stars, no wall items, and your two cases, and it's unlocked. The test script is removed and HTTP is off.
