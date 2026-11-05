# Creator Hub setup for purchases

Every pass and product in the game shows **Soon** until it exists in Creator Hub and its ID is in `src/ReplicatedStorage/Config.luau`. Use the names exactly as written. The game finds each one by name the first time, so the IDs can be filled in.

Prices are suggestions based on similar games. The store always shows the price set in Creator Hub.

## Game passes
Go to Creator Hub, then **Creations → Bakery Tycoon → Monetization → Passes**.

| Name | Suggested price | What it gives |
|---|---|---|
| 2x Coins | 199 | Double coins from customers and deliveries, permanently |
| VIP | 149 | VIP tag over the head and in chat, Red Carpet and Velvet Rope, +1 Star on each daily reward |
| Starter Pack | 49 | One time: 1,000 coins, 15 Sugar Stars, and Party Bunting |
| Cozy Pack | 99 | Fireplace, Bookshelf and Armchair |
| Winter Pack | 149 | Christmas Tree, Snowman and Gingerbread House. Take it off sale in January, and buyers keep the items |

## Developer products
These can be bought again and again. Go to **Monetization → Developer Products**.

| Name | Suggested price | What it gives |
|---|---|---|
| Coin Bag | 25 | 500 coins |
| Coin Sack | 75 | 2,000 coins |
| Coin Chest | 199 | 6,000 coins |
| Star Pouch | 25 | 10 Sugar Stars |
| Star Jar | 65 | 30 Sugar Stars |
| Star Chest | 199 | 100 Sugar Stars |
| 2x Boost | 25 | Double coins for 15 minutes. Buying again adds 15 more |

## Then
1. Turn on **File → Game Settings → Security → Enable Studio Access to API Services**, then click **Save**.
2. With Studio open, ask Claude to fill in the IDs and run test purchases.
