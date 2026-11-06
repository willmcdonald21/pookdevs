# pookdevs: Bakery Tycoon

A Roblox bakery tycoon set around a town square. Players bake treats from ingredients, stock display cases, sell to customers who shop on their own, and pack deliveries for coins and Sugar Stars. Ingredients come from a free delivery crate and the grocery store on the square. Coins and Stars pay for upgrades, recipes and decorations. Everything in a bakery, including the oven and counters, can be moved and turned on a grid of 1-stud squares. Wall decorations, such as sconces, plants and paintings, hang on the back and side walls and have their own Wall tab in the Decorate menu. The Decorate menu's Paint tab recolours each wall, the oven and each display case. Its Expansion tab makes the bakery bigger in three steps, and sells the gold Luxury Oven, a second oven for 25,000 coins that bakes 15% faster and can't be repainted.

- **Place:** Bakery Tycoon, placeId 124037168545233
- **Built in:** Roblox Studio, with Claude Code connected through the Studio MCP server

## Contents
| Path | In Studio | Does |
|---|---|---|
| `src/ReplicatedStorage/Config.luau` | ReplicatedStorage › Config | Every tunable value: recipes, ingredients, upgrades, decorations, deliveries, Robux passes and products |
| `src/ReplicatedStorage/ItemBuilder.luau` | ReplicatedStorage › ItemBuilder | Builds treats, ingredients and decorations from Config part lists |
| `src/ReplicatedStorage/Layout.luau` | ReplicatedStorage › Layout | Placement rules for the floor grid and the walls, shared by the server and the decorating preview |
| `src/ServerScriptService/PlayerData.luau` | ServerScriptService › PlayerData | Saving and loading, with a session lock so two servers can't overwrite each other |
| `src/ServerScriptService/PurchaseHandler.luau` | ServerScriptService › PurchaseHandler | Robux purchases. Each receipt is saved, so a retry never pays twice |
| `src/ServerScriptService/BakerySystem.server.luau` | ServerScriptService › BakerySystem | Server game logic: plots, oven, ingredients, crates, grocery, cases, customers, deliveries, shop, helpers, hotbar |
| `src/StarterPlayer/StarterPlayerScripts/BakeryClient.client.luau` | StarterPlayerScripts › BakeryClient | HUD and menus (Bake, Cookbook, Pantry, Grocery, Shop, Store and more), hotbar, decoration placing, guide arrow, sounds |
| `tools/*.luau` | Run once in Studio | Builders for the world: the oven, cookbook counter, pantry shelf, the town square with the grocery store, the movable checkout counter and delivery counter, and the Luxury Oven. Each is safe to run again |
| `backups/*.rbxl` | Whole place file | The original world and plots. The snapshot dates from 2026-10-31, before the town square, so use `tools/` and `src/` for anything newer |
| `docs/` | | Roadmap, plans, and the Creator Hub list of passes and products |

The `.server.luau` and `.client.luau` names follow Rojo's convention for a Script and a LocalScript. Files ending in plain `.luau` are ModuleScripts.

## Restoring from this backup
1. Open the place file from `backups/` in Studio with **File → Open from File**.
2. For each file in `src/`, open the matching script from the table above in Studio.
3. Replace that script's text with the file's contents.
4. Run each builder in `tools/` from the Studio command bar, in this order: oven, cookbook, pantry, town, layout, luxury oven.
5. Publish with **File → Save to Roblox**, or **File → Publish to Roblox** if the place is new.
