# Creator Hub setup for purchases

All passes and products were created on 2026-11-05 through Roblox's Open Cloud API, and their IDs are in `src/ReplicatedStorage/Config.luau`. Prices can be changed in Creator Hub at any time. The in-game store always shows the price set there.

## Game passes
| Name | Price | ID | What it gives |
|---|---|---|---|
| 2x Coins | 199 | 2072444566 | Double coins from customers and deliveries, permanently |
| VIP | 149 | 2072630512 | VIP tag over the head and in chat, Red Carpet and Velvet Rope, +1 Star on each daily reward |
| Starter Pack | 49 | 2068562637 | One time: 1,000 coins, 15 Sugar Stars, and Party Bunting |
| Cozy Pack | 99 | 2070589101 | Fireplace, Bookshelf and Armchair |
| Winter Pack | 149 | 2072654528 | Christmas Tree, Snowman and Gingerbread House. Take it off sale in January, and buyers keep the items |

The game's creator owns every pass automatically, so the creator's account always plays with all of them.

## Developer products
These can be bought again and again.

| Name | Price | ID | What it gives |
|---|---|---|---|
| Coin Bag | 25 | 3728575847 | 500 coins |
| Coin Sack | 75 | 3728575849 | 2,000 coins |
| Coin Chest | 199 | 3728575852 | 6,000 coins |
| Star Pouch | 25 | 3728575854 | 10 Sugar Stars |
| Star Jar | 65 | 3728575857 | 30 Sugar Stars |
| Star Chest | 199 | 3728575858 | 100 Sugar Stars |
| 2x Boost | 25 | 3728575863 | Double coins for 15 minutes. Buying again adds 15 more |

## Icons
Every pass and product has its own icon, a round badge with a pink frosting rim. They were uploaded through Open Cloud on 2026-11-07, replacing Roblox's grey stock icons, and nothing else on the items changed. The drawings are in `art/store/`: `build_icons.py` writes each SVG and renders it to the PNG that was uploaded. The in-game Get More menu shows whatever icon Roblox has for each item, so a new icon set in Creator Hub appears in the game as well. Roblox reviews each new image first, and until it's approved, players see a grey placeholder.

To change an icon, edit its drawing in `build_icons.py` and run `python3 art/store/build_icons.py`. Then upload the PNG in Creator Hub: open the pass or product, choose its image, and save. Or have Claude upload it with an API key that has write access for **game-passes** and **developer-products**.

## Creating more later
1. Create an Open Cloud API key with the **game-pass** and **developer-product** APIs, each with read and write access, limited to Sweetopia and your IP address. Saving changes to a key's permissions may generate a new key.
2. Give the key to Claude through the clipboard, not in chat. Delete the key in Creator Hub when finished.
3. Add the new item to `Config.Passes` or `Config.Products`, with its ID.

## Tested
- **Payout:** a simulated Roblox receipt for the Coin Bag paid 500 coins. It was saved to the real save with its receipt, and sending the same receipt again paid nothing.
- **Purchase window:** not tested. Studio wouldn't show Roblox's purchase window during testing, so the first real check will be a purchase in the published game.
