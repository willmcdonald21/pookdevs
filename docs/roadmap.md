# Roadmap

| Step | What | Status |
|---|---|---|
| 1. Setup | Roblox account, Studio, and Claude Code connected through the Studio MCP server | Done |
| 2. Playable core | One plot per player, baking, customers, coins, upgrades, saving | Built |
| 3. Real game | Five recipes, shop, tutorial, sounds, phone controls, walking customers | Built |
| Redesign | Tray and display cases, customers shop on their own, decorations, Sugar Stars, deliveries, Robux store, hotbar | Built |
| Engagement batch | Game passes (2x Coins, VIP, Starter, Cozy and Winter packs), 2x Boost, daily reward, offline sales, golden customers, daily goals, Baker and Stocker helpers. See `engagement-plan.md` | Built 2026-11-05 |
| Town and ingredients | Town square layout, grocery store, ingredients with a pantry shelf and free delivery crate, cookbook counter, new oven, treat shown on the carried tray. See `town-and-ingredients-plan.md` | Built 2026-11-05 |
| Free placement | Decorating on a 1-stud grid with the normal camera, a Rotate button, and every piece movable, including the oven, pantry, cookbook counter, checkout counter and delivery counter. Customers walk around furniture. See `free-placement-plan.md` | Built 2026-11-05 |
| Decorating fixes | Click a piece itself to pick it up, so tall pieces by walls work; Rotate always on screen; click or drag the floor to move a held piece; Move things at the top of the menu; delivery station rebuilt as a counter with a laptop, with nothing left on the wall | Built 2026-11-05 |
| Wall decorations | A Wall tab in the Decorate menu with 8 pieces for the back and side walls: Wall Sconce, Neon Heart Sign, Hanging Ivy, Wall Planter, Cupcake Painting, Sunset Painting, Wall Clock and Chalkboard Menu. They snap to a 1-stud grid along and up the wall, can't overlap furniture that reaches up to them, and add Charm. See `wall-decor-plan.md` | Built 2026-11-05 |
| Luxury Oven | A black and gold second oven sold in the Shop for 25,000 coins, as a luxury. It bakes 15% faster, appears in the first free spot when bought, and moves like the other stations. Baking uses the nearest empty oven, and the Baker, Stocker and guide arrow work with both ovens | Built 2026-11-06 |
| Paint and expansion | Decorate menu Paint tab: each wall 25 coins, the oven 75, each display case 15, in 11 colours (no gold for the oven, and the Luxury Oven can't be painted). Expansion tab: three steps from 48 × 38 to 60 × 62 for 3,000, 8,000 and 18,000 coins, with wall decorations moving with their wall. The Luxury Oven moved here from the Shop. See `paint-and-expansion-plan.md` | Built 2026-11-06 |
| Visible case treats | Display cases hold one row of three treats per shelf, so none hide behind another. The Display Case has two shelves of three at the same height as before, and the Tall Display Case has four shelves of three and is 6.9 studs tall. Both still hold 6 and 12 | Built 2026-11-06 |
| Walking helpers | The Baker walks from the oven to the pantry shelf and back, and starts baking your last treat only once it's standing at an empty oven. The Stocker takes a finished batch from the oven, as much as the cases have room for, carries it on a pink tray, and puts treats in each case only when it gets there. Upgrades now set walking speed (10, then 18) instead of a wait. Their arms and legs swing as they walk | Built 2026-11-06 |
| 4. Her version | Exclusive items (system built, none assigned yet), publish with limited access, first playtest | In progress |
| 5. Public launch | Game passes and products, maturity questionnaire, icon, thumbnails, description, publish to 16+ | Not started |
| 6. Grow | Creator Dashboard analytics, regular updates, seasonal events | Not started |

## Not yet verified
- **Purchase window:** all passes and products exist and are connected, and a simulated receipt paid out and saved correctly. Studio wouldn't show Roblox's purchase window, so the first full purchase will be in the published game.
- **Prompts:** during the 2026-11-05 tests, Studio wouldn't show any proximity prompt, even a new test prompt. The oven, cases, cookbook counter, pantry shelf, crate and grocery counter were tested by calling the same server code directly, not by pressing E.
- **Decorating on a phone:** Studio's simulator doesn't turn simulated clicks into taps, so tapping the floor to move the preview, tapping a wall to move a wall piece, and tapping a piece to pick it up are untested. The mouse controls were tested. The four Decorate tabs shrink to share the bar on narrow screens, but haven't been seen on a phone.
- **A bakery going back to its default layout** when its owner leaves while another player is in the server.
- **Live play:** two players at once, a real phone, and a full playthrough at normal prices.

## Before launch
- Set the server size to 6 players, since there are six bakeries.
- Have 2–3 people who haven't seen the game play it without help.

## Money notes
- **Creator share:** creators receive 70% of Robux spent.
- **Cashing out:** DevEx needs at least 30,000 Earned Robux, which is about $114. That requires a verified email, a DevEx account, and a tax form.
- **Audience:** publishing to the 16+ audience is free. Kids and Select need a fee or a subscription, plus an evaluation.
