# Plan: Ingredients, grocery store, town square, cookbook counter, new oven, treats on the tray

## Context
You asked for six changes:
- **Tray:** show a treat on the carrying tray, the way treats show in display cases.
- **Employees:** a way to hire them. You chose to keep the existing Baker and Stocker in the Shop, so nothing changes here.
- **Oven:** a better-looking oven.
- **Cookbook counter:** a counter with a cookbook where you unlock recipes and check goals.
- **Town square:** bakeries laid out around a plaza instead of a uniform grid, with space for a grocery store.
- **Ingredients:** recipes need them, and they're easy to get from a free delivery crate, a grocery store selling cheap bundles, and a pantry shelf that shows what you have.

Bakery interiors keep their current size and layout. Scripts find everything by name relative to each bakery, so moving and rotating the bakeries is safe.

## 1. Town square layout
- **Plaza:** a round cobblestone plaza, about 62 studs across, replaces the straight street. It has a fountain near the middle, lamps, benches and a few trees. The spawn point moves to the plaza edge, next to the fountain.
- **Bakeries:** the 6 bakeries sit around the plaza with their doors facing it. Each one is placed at a different distance (82–100 studs) and spacing, angled up to about ±8° off center, so it looks like a town rather than a grid.
- **Grocery lot:** the remaining gap on the plaza holds the new grocery store.
- **How it's built:** a one-time Studio edit script moves each plot with `PivotTo`, removes the `Street` part, and builds the plaza. Customers still start at each bakery's `CustomerStart` spot, which will now be on the plaza.

## 2. Ingredients
- **Six ingredients** in `Config.Ingredients`: Flour, Sugar, Eggs, Butter, Milk and Berries. Each has a color and a small model, so it can appear on shelves and in menus.
- **Recipe costs:** each recipe gets an `Ingredients` table for one batch. A batch costs the same however big the Bigger Batches upgrade makes it.

| Recipe | Ingredients per batch |
|---|---|
| Cookie | Flour 1, Sugar 1, Butter 1 |
| Cupcake | Flour 1, Sugar 1, Eggs 1, Milk 1 |
| Donut | Flour 2, Sugar 1, Eggs 1, Milk 1 |
| Pie | Flour 2, Butter 1, Berries 2 |
| Birthday Cake | Flour 2, Sugar 2, Eggs 2, Butter 1, Milk 1 |

- **Pantry storage:** a new saved `Pantry` table holds one count per ingredient, capped by a new **Bigger Pantry** upgrade in the Shop (30, 50, 80 and 120 of each). New and existing players start with 15 of each.
- **Baking:** the server checks ingredients in the bake handler (`bakeEvent` in BakerySystem) and in the Baker helper's re-bake (`runHelpers`), then deducts them. When they're missing, the Bake menu greys out that recipe and shows "Needs 1 Butter". The Baker helper waits instead of baking.
- **Guide hint:** when you can't bake anything, the hint says "Out of ingredients! Unpack your delivery crate or visit the grocery store", and the arrow points to the crate.

### Free delivery crate
- **Arrival:** every 90 seconds, if no crate is waiting, a crate appears outside your door, beside the customer path.
- **Contents:** 12 ingredients, weighted toward what your unlocked recipes need.
- **Unpacking:** press E on it to fill your pantry. Anything that doesn't fit stays in the crate. A label shows what's inside.
- **Saving:** crates aren't saved. A new one arrives soon after you join.

### Pantry shelf
- **Where:** a wooden shelf against each bakery's left wall, between the cookbook counter and the first decoration square.
- **Display:** six jars or sacks, one per ingredient, with a small label like "Flour 12/30". Each jar's fill rises and falls with your stock, so you can see at a glance what you're short of.
- **Menu:** pressing E opens a **Pantry** menu listing each ingredient, how many you have, and where to get more.

### Grocery store
- **The building:** it sits on the plaza lot, with an awning and a "Grocery" sign. Inside are shelves stocked with ingredient models, a counter and a cashier.
- **Buying:** press E at the counter to open the Grocery menu, which offers bundles of 5 of any ingredient.

| Ingredient | Bundle of 5 |
|---|---|
| Flour, Sugar | 4 coins |
| Eggs, Butter, Milk | 6 coins |
| Berries | 8 coins |

- **Rules:** the server checks that you're near the counter, that you can afford the bundle, and that you have pantry space. The store is shared by everyone and doesn't belong to any bakery.

## 3. Cookbook counter
- **Model:** the existing `UpgradeStation` part in every plot becomes a wooden counter. It keeps its name so the scripts still find it.
- **Cookbook:** an open cookbook sits on top, with angled cream pages, a red cover and a ribbon bookmark. A small "Cookbook" sign floats above it.
- **Prompt:** "Open Cookbook" opens a **Cookbook** menu with two sections:
  - **Recipes:** unlock, with each recipe's ingredients listed.
  - **Daily Goals:** the existing goal rows.
- **Shop menu:** it keeps upgrades and helpers, but recipes move to the Cookbook. It still opens from the HUD Shop button.
- **HUD:** the Goals button becomes **Cookbook**. It turns green when a recipe is affordable or a goal is ready.
  - The server's `CanAfford` splits into two flags, one for upgrades and one for recipes and goals, so each button lights up for its own reason.

## 4. New oven
I'll rebuild the oven in each plot as a retro kitchen range, keeping the parts the scripts use: `Body` with its `Prompt` and `Status` label, `Window`, `Handle`, and `Chimney` with its `Smoke`.
- **Range:** a cream enamel body with a pink trim stripe, short feet, and a framed glass door.
- **Stovetop:** a dark stovetop with four burners.
- **Controls:** a control strip with three knobs.
- **Backsplash and hood:** a backsplash and a hood with the chimney pipe.
- **While baking:** the window glows orange as it does now, and the burners glow red too, via `setOvenWindow`.

## 5. Treat on the carrying tray
- **What shows:** `updateCarriedTray` in BakerySystem places one treat model on the tray. It shows the selected hotbar treat, or the first treat in the hotbar if none is selected.
- **How:** it uses `ItemBuilder.Build`, the same builder as the display cases, at case-slot size, welded to the tray.
- **Changes:** the model swaps when your selection or tray changes, and disappears when the tray is empty.

## Files changed
- **ReplicatedStorage.Config:** `Ingredients`, recipe ingredient costs, `Pantry` upgrade, starting pantry, crate settings, grocery prices.
- **ServerScriptService.PlayerData:** saves and cleans `Pantry`.
- **ServerScriptService.BakerySystem:**
  - Ingredient checks for baking and the Baker helper, the crate, pantry shelf updates, grocery purchases, and the Cookbook prompt.
  - Burner glow, the tray treat, and the out-of-ingredients hint.
  - New remotes: `UnpackCrate` (handled by the crate prompt), `BuyGroceries`.
- **StarterPlayerScripts.BakeryClient:**
  - New menus: Cookbook, Pantry, Grocery.
  - Changed menus: the Bake menu shows ingredients, and the Shop menu no longer lists recipes.
  - The HUD Goals button becomes Cookbook.
- **World:** plot positions, plaza, grocery store, new oven, cookbook counter and pantry shelf in all 6 plots. These are built once in Edit mode and saved with the place.

## Build order
Each step gets its own commits, pushed one at a time to `~/pookdevs`. Each script is exported and committed separately. World changes are recorded by committing the build script I used, under `tools/`.
1. Treat on the tray
2. New oven
3. Cookbook counter, menu and HUD changes
4. Ingredients: Config, saving, baking checks, Bake menu
5. Pantry shelf and Pantry menu
6. Delivery crate
7. Town square layout and grocery store, with the Grocery menu
8. Balance check of ingredient costs against earnings, then update the docs (roadmap, README)

## Verification
- **After each step:** start a playtest, check the console for errors, and take screenshots from fixed camera positions.
- **Interaction prompts:** Studio hasn't been showing E-key prompts during my tests, so I'll trigger prompt actions through the same server functions directly. You'll do the final check of pressing E yourself.
- **Ingredients:** baking deducts the right amounts, missing ingredients block baking, the Baker helper waits when out, and the crate refills while respecting the cap.
- **Grocery:** buying works, is refused when too far away or out of coins, and respects the cap.
- **Saving:** the pantry saves and loads with a real save, now that API access works.
- **Layout:** customers still walk in, buy and leave at every rotated bakery. I'll check all 6 plots by claiming each in turn.
- **Phone:** check the new menus and the tray treat in the iPhone simulator.
- **Wrap-up:** remove all test scripts. Real values stay unchanged (cookie at 5 coins, starting Stars at 5), and HTTP stays off.
