# Plan: Sell placed pieces for half price, and an Inventory tab

## Context
Right now, when you pick up a decoration or display case with **Move things**, the bottom row shows Rotate, Place, **Store** and Cancel. Store puts the piece away. Put-away pieces then only show up as "You have N to place" in the Floor and Wall tabs, mixed in with the shop rows. There's no way to sell anything.

You asked for:
- **Two buttons when you pick up a placed piece:**
  - **Sell** gives back 50% of what it cost.
  - **Inventory** puts it away. This is today's Store button with a clearer name, which also stops it being confused with the Robux Store.
- **An Inventory tab** in the Decorate menu, listing everything you've put away.

Your choices: Inventory rows get both **Place** and **Sell**, and Sell always needs **two taps** to confirm.

## How it plays
- **Bottom row while holding a placed piece:** Rotate, Place, **Sell**, **Inventory**, Cancel. The row widens from 440 to 540 pixels to fit five buttons. That still fits the smallest phone in landscape.
- **Stations:** the oven, counters, pantry shelf and Luxury Oven still show only Rotate, Place and Cancel. They can't be put away or sold.
- **Selling:**
  - The first tap turns Sell into **"Sure?"** and the banner says "Sell Rug for 30 coins? Tap Sure? to sell it".
  - A second tap within 3 seconds sells it. After 3 seconds, or if you cancel or pick up something else, the button goes back to "Sell".
  - When it sells, the piece disappears, the money is added, and a message says "Sold Rug for 30 coins".
  - Treats in a sold display case go back to your tray, the same as putting it away does now.
  - A customer sitting on a sold table or armchair gets up, the same as when it's moved.
- **Can't be sold:**
  - In these cases Sell is grey, and tapping it shows the reason in the banner, the same way the grey Rotate button works now.
  - Your last display case: "Keep at least one display case so customers can shop".
  - VIP items (Red Carpet, Velvet Rope): "It comes with VIP, so it can't be sold".
  - The first copy of a pack item: "The first one comes with the Cozy Pack, so it can't be sold". Extra copies bought with coins can be sold.
  - Gift items (`OnlyFor`), if any are added later.
- **Inventory tab:**
  - The tabs become Floor, Wall, **Inventory**, Paint and Expansion.
  - There's one row for each piece you have put away, for example "Rug: You have 2. Sells for 30 coins each".
  - Each row has a **Place** button, which picks the piece up to place it, and a **Sell** button, which sells one copy and also needs a second tap ("Sure?").
  - A piece that can't be sold shows only Place, and its row says why.
  - When nothing is put away, the tab says "Your inventory is empty" and "Pick something up with Move things and press Inventory to keep it here".
  - The Floor and Wall tabs keep their Place buttons, so you can still buy something and place it straight away.

## Sell prices
Prices are half the item's current price, rounded down, in the same currency it was bought with. They don't use what you paid at the time, because the save doesn't record that.

| Kind | Bought with | Sells for |
|---|---|---|
| Coin pieces | Display Case 100, Tall Display Case 800, Rug 60, Plant 50, Lamp 80, Table 120, wall pieces 60–110 | Half, in coins (50, 400, 30, 25, 40, 60, …) |
| Sugar Star pieces | Giant Cupcake 8, Heart Sign 10, Rainbow Arch 15, Golden Cake 25 | Half, in Stars (4, 5, 7, 12) |
| Extra pack copies | `ExtraCoins` (Fireplace 400, Bookshelf 300, …) | Half, in coins (200, 150, …) |

Money from selling is added directly. It skips the 2x Coins pass, the 2x Boost and the Friend Boost, so a sale never pays back more than half the price.

## Files changed
- **`ReplicatedStorage.Config`:**
  - adds `Config.SellShare = 0.5` and `Config.SellConfirmSeconds = 3`
  - adds `Config.SellValue(item, owned)`, which returns `amount, "Coins" | "Stars"`, or `nil, reason`
  - it's shared, so the client's button text and the server's payment always agree
  - it uses `Config.GetPass` for the pass names in the reasons
- **`ServerScriptService.BakerySystem`:** two new actions on the existing `Place` remote, in the handler at `BakerySystem.server.luau:1192`, next to `"Store"`:
  - **`("Sell", key)`** (a placed piece):
    - The checks: the entry exists, the last-case rule is the same one `"Store"` uses (`placedCaseCount`), and `Config.SellValue` passes.
    - Then it runs the existing `storePlaced(plot, data, key)`, does `data.Owned[id] -= 1`, and adds Coins or Stars directly (not through `earn`).
    - Then it calls `refreshEmployees`, `notify(..., "Coin")` and `syncStats`.
  - **`("SellSpare", itemId)`** (from the Inventory tab):
    - The checks: the item exists, `Config.IsAllowed` passes, `Owned - placedCount > 0`, and `Config.SellValue` passes.
    - Then it does `Owned -= 1`, pays, notifies and syncs.
  - The payment, the "Sold …" message and the sync happen in one small helper used by both actions.
  - `"Store"` stays as the action name, so nothing else changes on the server.
  - A rejoin can't bring a sold copy back: `applyExclusiveItems` only tops pack items up to 1, and the first copy can't be sold.
- **`StarterPlayerScripts.BakeryClient`:**
  - **Bottom row** (`placeBar`):
    - `placeBar` becomes 540 wide.
    - The row's buttons now share one `barButtons` table (`barButtons.Rotate`, `barButtons.Sell`, …), filled in by `barButton`, to make room under the 200-local limit (see below).
    - Store becomes `barButtons.Inventory`, labelled "Inventory", in blue.
    - The new `barButtons.Sell` is gold, at layout order 3, and Cancel and Done move up one place.
    - `refreshBar` shows Sell and Inventory under the same rule Store used. Sell is gold or grey, and reads "Sure?" while it's waiting for the second tap. The "waiting" time is stored on `held`, so dropping or swapping the piece clears it.
    - A tap on a grey Sell shows the reason in the banner. Otherwise the second tap sends `placeEvent:FireServer("Sell", held.key)` and calls `drop(true)`, the same as the Inventory path.
  - **`saleText(item, placed)`** gives the price as text ("30 coins", "4 Stars"), or nil and the reason. It adds the last-display-case rule for placed pieces. Both the bottom row and the Inventory tab use it.
  - **Inventory tab** (`inventoryRows`, beside `paintRows` and `expansionRows`):
    - Adds `"Inventory"` to `DECOR_TABS` after Wall.
    - It lists `state.Owned[id] - placedCount(id)` for allowed items, using the existing `addRow`, `startPlacing`, `starText` and `withCommas`.
    - The second-tap state for a row's Sell is one `sellConfirm = { Id, Until }` value. It redraws with `refreshPanel()`, which keeps the list's scroll position, so `currentPanel` and `refreshPanel` are now declared with the other forward declarations.
- **Script room:** BakeryClient had room for only 1 more top-level local at its tightest spot, the Bake Together request card's `do` block. Grouping the 5 bottom-row buttons into `barButtons` frees 4 from there on. The room was measured with `loadstring` before syncing.
- **Docs:**
  - this plan as `docs/sell-and-inventory-plan.md`
  - a README line about selling at half price and the Inventory tab
  - a roadmap row

## Build order
Each step is its own commit, pushed right away over SSH.
1. `Config`: `SellShare` and `SellValue`.
2. `BakerySystem`: the `Sell` and `SellSpare` actions.
3. `BakeryClient`: the Sell and Inventory buttons on the bottom row.
4. `BakeryClient`: the Inventory tab.
5. Docs: the plan, README and roadmap.

## Syncing into Studio
- **Before:** check `git status`, `git log` and Studio's play state for another session's work. Then compare each script's Studio Source with `git show HEAD:<file>`.
- **How:** sync each script with `tools/studio_patch.py` and execute_luau in Edit mode, checking the checksum and running a `loadstring` compile before setting Source.

## Verification
I'll run a playtest on a throwaway save that never writes to the DataStore, using the `TEST_Patch_DELETE` fake-player patch. Your real save isn't touched. The patch gives the test save coins, a few owned pieces (Rug, Table, Giant Cupcake, a second Display Case and an extra Fireplace), and a Cashier.

- **Bottom row:** place a Rug and click its visible face in Move mode. Take a screenshot of the five buttons.
- **Two taps:**
  - One tap on Sell turns it to "Sure?" with the banner. After waiting 4 seconds it's back to "Sell".
  - Two taps sell it: coins go up by exactly 30, `Owned.Rug` goes down by 1, and the piece is gone.
- **Inventory:** put the Table away with Inventory. It shows in the Inventory tab (screenshot with the five tabs). Place from the tab picks it up. Selling it from the tab with two taps pays 60.
- **Stars:** the Giant Cupcake sells for 4 Stars.
- **Can't sell:**
  - The Sell button is grey with a reason for the last display case, the Red Carpet (you own VIP), and the only Fireplace.
  - An extra Fireplace sells for 200.
- **Case treats:** a stocked second Display Case sells, and its treats go back to the tray.
- **Server checks:** firing `Sell` and `SellSpare` straight from the client is refused, with no money paid, for:
  - a station id
  - a missing key
  - the last case
  - an item with none put away
- **No boost on sales:** with the 2x Boost on, a sale still pays exactly half.
- **Phone:** iPhone simulator screenshots of the bottom row and the tabs. Not done: Studio's device simulator can't be switched from a script. The bar is 540 wide, and the smallest phone in landscape is about 667.
- **Not testable here:** real phone taps. You'll check those yourself.
- **Cleanup:**
  - delete the test patch and turn BakerySystem back on
  - confirm your real save is unchanged
  - remind you to save in Studio (File › Save) and publish
