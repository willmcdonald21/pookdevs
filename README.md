# pookdevs: Bakery Tycoon

A Roblox bakery tycoon. Players bake treats, stock display cases, sell to customers who shop on their own, and pack deliveries for coins and Sugar Stars. Coins and Stars pay for upgrades, recipes and decorations.

- **Place:** Bakery Tycoon, placeId 124037168545233
- **Built in:** Roblox Studio, with Claude Code connected through the Studio MCP server

## Contents
| Path | In Studio | Does |
|---|---|---|
| `src/ReplicatedStorage/Config.luau` | ReplicatedStorage › Config | Every tunable value: recipes, upgrades, decorations, deliveries, Robux products |
| `src/ReplicatedStorage/ItemBuilder.luau` | ReplicatedStorage › ItemBuilder | Builds treats and decorations from Config part lists |
| `src/ServerScriptService/PlayerData.luau` | ServerScriptService › PlayerData | Saving and loading, with a session lock so two servers can't overwrite each other |
| `src/ServerScriptService/PurchaseHandler.luau` | ServerScriptService › PurchaseHandler | Robux purchases. Each receipt is saved, so a retry never pays twice |
| `src/ServerScriptService/BakerySystem.server.luau` | ServerScriptService › BakerySystem | Server game logic: plots, oven, cases, customers, deliveries, shop, hotbar |
| `src/StarterPlayer/StarterPlayerScripts/BakeryClient.client.luau` | StarterPlayerScripts › BakeryClient | HUD, menus, hotbar, decoration placing, guide arrow, sounds |
| `backups/*.rbxl` | Whole place file | The world and plots. The snapshot dates from 2026-10-31, so its scripts are older than `src/` |
| `docs/` | | Roadmap and the engagement and monetization plan |

The `.server.luau` and `.client.luau` names follow Rojo's convention for a Script and a LocalScript. Files ending in plain `.luau` are ModuleScripts.

## Restoring from this backup
1. Open the place file from `backups/` in Studio with **File → Open from File**.
2. For each file in `src/`, open the matching script from the table above in Studio.
3. Replace that script's text with the file's contents.
4. Publish with **File → Save to Roblox**, or **File → Publish to Roblox** if the place is new.
