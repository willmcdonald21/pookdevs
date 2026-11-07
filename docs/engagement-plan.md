# Plan: Engagement and Robux additions for Bakery Tycoon

## Context
You asked what other tycoon games, especially bakery games, do to keep players coming back and spending. I checked 14 popular food and shop tycoons on Roblox, including their live game-pass lists, and then you chose a first batch:

- **Gameplay:** offline earnings, daily rewards, hired helpers, rare customers, and daily goals
- **Robux:** 2x Coins and VIP passes, a starter pack, timed boosts, and themed decor packs

The goal is a game people return to each day, with clear and fair things to buy. Everything stays playable for free.

## What similar games do
| Game | Players at the time | Relevant features | Game passes (Robux) |
|---|---|---|---|
| Restaurant Tycoon 3 | ~7,100 | Earns money offline | Auto collect 299, 3x Customer Luck 399, 2x Milestone Boost 249, themed bundles 349–399 |
| Run a Restaurant! | ~5,400 | Hire staff, earns offline | VIP 399, Rare Customers 629, Plot Expansion 999, Auto Collect 199 |
| My Small Business | ~14,200 | Packing orders, hire workers, earns offline, friends help | x2 Coins 399, VIP 199, decor packs 54–119, a shop cat 179 |
| Sell a Million Sushi | ~13,100 | Hire and merge workers | Staff passes 29–499 |
| Cook & Sell! (bakery) | ~330 | Goals unlock recipes, stocking shelves | VIP 400, seasonal shop skins 199 each, permanent cashier 199, 48-hour sale on products |
| Pet Store Tycoon | ~5,000 | Stocking shelves, hire staff | Staff 199–749, 2x Customer Traffic 299, Unlock All Decor 199 |
| 2 Player Bakery Tycoon | ~60 | Classic button tycoon | 2x Cash 119, VIP 149, Auto Collect 35 |
| Make a Pancake! | ~6,400 | | Starter Pack 11, 2x Cash 19, limited chairs 61–99 |

**Patterns:**
- Nearly every successful one says "earns money while you're offline" in its description.
- Hiring helpers to automate work is the standard way tycoons progress.
- 2x Coins and VIP are the most common passes.
- Cosmetic packs, including limited seasonal ones, are common and don't affect fairness.
- Cheap starter packs are used to get a player's first purchase.

**Roblox rules to follow:**
- **Random items:** paid random items such as loot boxes or spin wheels require showing exact odds and extra region checks, so I'm leaving them out.
- **Subscriptions:** possible later, at 49+ Robux a month with 70% to you.

## How purchases will work
- **Passes:** add a `Config.Passes` list next to `Config.Products`, with `GamePassId = 0` showing "Soon" until you create the pass.
- **Ownership check:** extend `ServerScriptService.PurchaseHandler` to check passes when a player joins (`UserOwnsGamePassAsync`). It will also pick up mid-game purchases through `PromptGamePassPurchaseFinished`, then re-check on the server.
- **Store menu:** the client Store panel (`panels.Store` in `BakeryClient`) gets three sections: Passes, Packs, and Coins & Stars. It shows real prices from `GetProductInfo` and opens purchases with `PromptGamePassPurchase`.
- **One coin multiplier:** a new `earn(player, data, amount)` in `BakerySystem` applies 2x Coins and the timed boost to customer sales, deliveries and offline earnings. They stack to 4x. It replaces the direct `data.Coins +=` lines in `runCustomer` and the ship handler. Robux coin packs, daily rewards and goals aren't multiplied.

### Suggested prices
You set the final prices in Creator Hub.

| Item | Type | Price | What it does |
|---|---|---|---|
| 2x Coins | Game pass | 199 | Doubles coins from sales, deliveries and offline earnings, permanently |
| VIP | Game pass | 149 | Gold "VIP" tag over your head and in chat, two VIP-only decorations, and +1 Star on each daily reward |
| Starter Pack | Game pass | 49 | One time: 1,000 coins, 15 Stars, and an exclusive Bunting decoration |
| Cozy Pack | Game pass | 99 | Fireplace, Bookshelf and Armchair decorations |
| Winter Pack | Game pass, limited | 149 | Christmas Tree, Snowman and Gingerbread House. You turn sales off in January, and buyers keep the items |
| 2x Boost (15 min) | Developer product | 25 | Doubles coins for 15 minutes. Buying again adds time |

Pack and VIP items use the existing exclusive-item system:
- **Item field:** a new `Pass = "CozyPack"` field on items in `Config.Items`.
- **Ownership:** `Config.IsAllowed` checks pass ownership, and `applyExclusiveItems` in `BakerySystem` grants or removes those items, the same way `OnlyFor` items work.
- **Saved progress:** the boost end time (`BoostUntil`) and whether the Starter Pack was claimed (`StarterPackClaimed`) are saved, so the boost lasts across visits and the pack can't pay out twice.

## Gameplay additions
1. **Daily reward:**
   - **Streak:** a 7-day login streak. Days 1–6 pay rising coins (100 → 600), and day 7 pays 5 Stars. Missing a day restarts it at day 1.
   - **Claiming:** a popup on joining has a Claim button. Each day starts at midnight US Eastern time (EST or EDT), the same for daily goals. Until 2026-11-07 days were counted in UTC.
   - **Saved progress:** the last claim day (`DailyDay`) and the streak (`DailyStreak`).
2. **Offline earnings:**
   - **How it works:** when you come back, customers are counted as having shopped while you were away. One treat sells per normal customer interval, up to 8 hours, and only from treats left in your cases.
   - **Effect:** stocking cases before leaving is rewarded, and the cases really are emptier when you return.
   - **Popup:** "While you were away, customers bought 14 treats: +230 coins."
   - **Saved progress:** `LastSeen` is written on every save.
3. **Rare customers:**
   - **Chance:** about 1 in 12 customers is a VIP customer, with a gold crown and sparkles.
   - **Reward:** they pay 3x, and 1 in 3 of them also tips 1 Star.
   - **Setting:** the chance goes in `Config.RareCustomer`, and the logic in `runCustomer`.
4. **Daily goals:**
   - **Goals:** three a day, picked from a pool, such as "Sell 20 treats", "Ship 2 deliveries", "Bake 5 batches", or "Sell 6 cupcakes" (only recipes you've unlocked).
   - **Rewards:** each pays coins plus 1 Star.
   - **Where:** a new HUD "Goals" button and Goals panel.
   - **Tracking:** progress updates where sales, shipping and baking already happen.
   - **Saved progress:** `Goals`.
5. **Hired helpers:**
   - **What you buy:** helpers cost coins in the Shop. Each one appears as a person in an apron, reusing the customer model builder.
   - **Baker** (about 2,000 coins): restarts the oven with the last treat you baked whenever it's idle.
   - **Stocker** (about 3,500 coins): when the oven is ready, moves the batch straight into cases with room. Your carried tray isn't used.
   - **Effect:** with both, the bakery runs on its own, while deliveries stay hands-on.
   - **Saved progress:** `BakerLevel` and `StockerLevel`. Higher levels work faster.

**Save data:** all new saved fields are added to `clean()` in `ServerScriptService.PlayerData` with safe defaults, so existing saves load without problems.

## Build order
Each step ends with a playtest.
1. **Purchase setup:** the pass system, the shared coin multiplier, and the new Store layout.
2. **Robux items:** 2x Coins, VIP (tag and decor), Starter Pack, 2x Boost, and the Cozy and Winter packs.
3. **Return rewards:** daily reward and offline earnings.
4. **Rare customers and daily goals.**
5. **Helpers.**
6. **Rebalance:** re-check how long progression takes, since helpers and 2x Coins speed it up. Helper and recipe costs may need raising.

## Files changed
- `ReplicatedStorage.Config`: Passes, new Products, pack and VIP items, helpers, daily reward table, goal pool, rare customer settings
- `ServerScriptService.PurchaseHandler`: pass ownership, Starter Pack, and Boost
- `ServerScriptService.PlayerData`: new saved fields and `LastSeen`
- `ServerScriptService.BakerySystem`: `earn()`, offline earnings, daily reward, goals, rare customers, helpers, VIP tag
- `StarterPlayerScripts.BakeryClient`: Store sections, Goals button and panel, daily and welcome-back popups, helper rows in the Shop, VIP chat tag

## Verification
- **Each step:** playtest in Studio, check the console for errors, and take screenshots, including the iPhone simulator.
- **Test values:** use temporary server scripts and Config values for testing, such as granting a pass in a test, setting `LastSeen` to 3 hours ago, or forcing a rare customer. Revert them afterward, with the cookie at 5 coins and starting Stars at 5.
- **Purchases:** after you create the passes and products, I fill in the IDs and run Studio test purchases of each.
- **Still blocked:** saving-related features (offline earnings, streaks, starter pack claimed) can only be fully tested once Studio API access is turned on.

## What you'll need to do
1. Turn on **Game Settings → Security → Enable Studio Access to API Services** and click Save. This is still off.
2. In Creator Hub, create the 5 game passes and the 2x Boost product, plus the 6 earlier coin and Star products. Use the exact names above.
3. Press **File → Save to Roblox** after each session.

## Later ideas (not in this batch)
- **Long-term progression:** rebirth or a new location.
- **Social:** friends co-op and visiting bakeries.
- **Paid conveniences:** an extra helper slot pass, more placement squares, and 2x customer traffic.
- **Subscription:** a monthly Baker's Club.
- **Events:** seasonal recipes.
- **Her exclusive items:** still waiting on your choices.

## Sources
- Live game data from Roblox's public games and game-pass APIs, checked 2026-11-05
- [Paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items)
- [Experience subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions)
- [Cake Tycoon VIP pass change (DevForum)](https://devforum.roblox.com/t/-/517427)
