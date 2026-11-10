# Bakery Level and new recipes

Phase 1 of the plan for keeping players playing once they max out. Phase 2 is in `new-restaurants-plan.md`.

## Context
Players reach the end of Sweetopia in about an hour. All 5 recipes unlock by 10,000 coins,
every upgrade line stops at level 4 (each level costs 6,000 or less), and once the Luxury Oven,
expansions, garden and stash are bought, coins have nothing left to buy. The user wants two
features built in two phases:

1. **Bakery Level.** Every sale earns XP. About 4 treats are bought with coins, and the rest
   are learned by levelling up. There are no new ingredients.
2. **Opening a new restaurant (prestige).** Once a restaurant is at the max level and has
   2 employees, the player can open a new one. The new one starts over with its own coin
   balance and gets a permanent +20% customer bonus. The player switches which restaurant they
   manage at its door. Restaurants they aren't managing run for show, with 3 AI workers.

Each phase is its own set of small commits, each pushed right after it's made. Each phase is
synced into Studio, playtested on a fake save, and only then committed.

## Plan

### Config (`src/ReplicatedStorage/Config.luau`)
- `Config.Recipes` grows from 5 to 12 entries, using only the 6 existing ingredients:
  Croissant (Flour, Butter, Milk), Cinnamon Roll (Flour, Sugar, Butter), Macaron (Sugar,
  Eggs, Berries), Éclair (Flour, Eggs, Milk, Sugar), Cheesecake (Milk, Eggs, Sugar, Butter),
  Strawberry Shortcake (Flour, Eggs, Berries, Milk), Wedding Cake (all of them, in large
  amounts). Each one also gets `Parts` for `ItemBuilder`, a price that keeps climbing after
  Birthday Cake's 70, and a BakeScale.
- Recipes 2–5 (Cupcake, Donut, Pie, Birthday Cake) keep their `UnlockCost` in coins. These are
  the "about 4 bought". Recipes 6–12 get `UnlockLevel` in place of `UnlockCost`.
- A new `Config.BakeryLevel = { XpPerCoin, Levels = { xp needed for each level }, Max }`,
  with about 15 levels. XP comes from the base price of each sale, so 2x Coins and boosts
  don't speed up levelling.
- `Config.Upgrades`: each line gets levels 5–8. These cost more coins, and each level also
  has a `NeedLevel` (the Bakery Level it needs).

### Save (`src/ServerScriptService/PlayerData.luau`)
- New fields `BakeryXp` and `BakeryLevel`. `RecipesUnlocked` stays as a count, so the
  existing recipe code still works.
- Migration for existing saves: set the starting level from what the player already owns
  (for example, Birthday Cake unlocked puts them at the level just below recipe 6). Nobody
  loses anything.

### Server (`BakerySystem.server.luau`, in a `do` block or new ModuleScript because of the register limit)
- `earn()` at line 168 also adds XP and levels the player up. When a level is reached and the
  next recipe is level-gated, it's learned straight away. This repeats if more than one
  becomes available at once.
- Buying the next recipe (line ~2000) refuses level-gated recipes. After a coin purchase, a
  level-gated recipe that's already reached is learned too.
- Buying an upgrade checks `NeedLevel`.
- `syncStats` sends `BakeryLevel`, `BakeryXp` and the XP needed for the next level.

### Client (`BakeryClient` or a new ModuleScript like `ExteriorPanel`)
- A level badge with an XP bar on the HUD, and a "Level up! You learned Croissant" popup.
- In the Cookbook, level-gated recipes show "Reach level N" in place of a price, and upgrade
  rows show "Needs level N".

## Built and tested (2026-11-09)

Built as planned, with these details:
- **Script room:** BakerySystem ran out of local variables with two new top-level functions, so they live in one table, `bakeryLevel` (`bakeryLevel.learn`, `bakeryLevel.addXp`). The badge is the ModuleScript `LevelBadge`, wired up in a `do` block, so BakeryClient gained no top-level locals.
- **XP:** customer sales give the treat's base Price. Deliveries give the base price of what's shipped, to the owner's bakery even when a co-baker packs it. Sales while away count too. Tips and golden customers' extra pay give no XP.
- **Level-ups** that teach a recipe get a popup, and others a toast.
- **Tested in Studio on a fake save:** a sale took level 5 to 6 and taught Croissant, with the popup and the badge. A level-5 oven was refused below level 9 ("Reach Bakery Level 9 first"), and level 5 was bought at level 6 for 15,000. The Shop and Cookbook showed "Level N". A sale at level 14 reached 15 (max), taught all six remaining recipes at once, and the badge read "Level 15 (max)".
- **Not seen:** Studio's screenshots timed out after the first two, so the seven new treats haven't been looked at in a case. Their sizes were worked out to fit inside the existing treats' size. The migration of a real save and the XP pace at normal play are untested.
