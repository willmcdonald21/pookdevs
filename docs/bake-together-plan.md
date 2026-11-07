# Plan: Bake Together

## Context
Playing with friends in the same shop is the strongest trend among new cozy tycoon hits (see `growth-plan.md`). Roblox's recommendations also favour friends playing together. It fits how Sweetopia started, too: a game to play with your girlfriend. You chose this to build first, and you chose that **anyone in town can ask, and the owner approves**.

## How it plays
- **Asking:**
  - **Where:** each owned bakery has an "Ask to Bake Together" prompt in its doorway, which other players see.
  - **The owner's popup:** "*Name* wants to bake with you! **Yes!** / **No thanks**", which closes on its own after 20 seconds.
  - **Limits:** each player can have one open request, must wait 30 seconds before asking again, and a bakery takes up to 3 co-bakers.
- **Joining:** on Yes, the co-baker is moved into the owner's bakery, and both get a notice. The co-baker's own bakery keeps running while they're away.
- **What a co-baker can do in the friend's bakery:**
  - **Bake** with the owner's recipes, ingredients and oven upgrades.
  - **Finish Now** with their own Stars.
  - **Collect batches onto their own tray** (their own Tray upgrade), and stock the owner's cases.
  - **Pack deliveries** from their own tray, and get paid for them.
  - **Unpack the owner's crate** into the owner's pantry, and take and hand out the owner's flyers.
  - **Off-limits:** the Cookbook counter, Decorate, Shop, Bake Sale and Buzz stay owner-only.
- **Rewards** (new coins, so nobody loses anything):
  - **Owner:** +10% on every sale for each active co-baker.
  - **Co-baker:** 25% of each sale's price as a bonus.
  - **Active** means they did something in the bakery in the last 2 minutes.
  - **Multipliers:** each player's own multipliers apply to what they earn.
- **Ending:**
  - **Stopping:** the co-baker presses **Stop baking together**, or the owner presses **Remove**, in the Friends panel.
  - **Leaving:** if the owner leaves the game, co-bakers are sent home with a notice.
- **Friend Boost:** +10% coins for each Roblox friend in the same town, up to +30%. The HUD multiplier shows it, such as "x2.2".
- **Invite rewards:**
  - **Inviting:** an **Invite friends** button opens Roblox's invite prompt.
  - **Who gets Stars:** when a friend joins Sweetopia for the first time through it, both get 10 Sugar Stars. The inviter's reward is capped at 10 friends.
  - **Inviter offline:** if the inviter isn't in the same server, the reward waits in a `Referrals_v1` DataStore until they next join.

## Code changes
**`Config`** adds:
- `Config.CoBake = { Max = 3, Share = 0.25, OwnerBonus = 0.10, ActiveSeconds = 120, AskCooldown = 30, AnswerSeconds = 20 }`
- `Config.FriendBoost = { PerFriend = 0.10, Max = 0.30 }`
- `Config.Referral = { Stars = 10, MaxRewards = 10 }`

**`PlayerData`:** `clean()` saves `ReferredBy` and `ReferralRewards`. A save with `LastSeen` 0 is a first visit.

**`BakerySystem`:** "Helpers" already means the hired Baker and Stocker, so the new state uses the name `coBakers`.
- **New state:**
  - `coBakers[player] = plot`, `lastAction[player]` and `friendsInTown[player]`.
  - `workPlot(player)` returns the bakery the player is working in.
  - `workersOf(plot)` returns its owner plus its co-bakers.
- **`canUse`:** the owner, or a co-baker of this bakery when the prompt has the `CoBake` attribute. `CoBake` goes on the oven, case, packing, pantry, crate and flyer prompts, and not on the cookbook counter.
- **Splitting owner data from the player's data:** handlers use the owner's save for the bakery and the player's own save for their tray, Stars and goals. For an owner, both are the same save, so solo play is unchanged.
  - **Baking:** `bakeEvent` and `startBake` use the owner's recipes, pantry, batch size and bake time, and the player's own Bake goal.
  - **`stockCase`:** moves the player's own tray into the owner's case stock.
  - **`shipEvent` and `newOrderEvent`:** use the packer's tray, coins, Stars and goal, and orders refill from the owner's save.
  - **Crate and flyers:** they use `workPlot`. Flyers are handed out near anyone working in the bakery.
- **Customer sales:**
  - **Payouts:** the owner's bonus and each active co-baker's share are paid after the owner's sale.
  - **Rounding:** `earn` rounds down, so coins stay whole numbers.
  - **Multiplier:** `coinMultiplier` includes the Friend Boost.
- **`syncStats`:**
  - **Co-bakers' view:** they get a `Work` table with the owner's recipes, upgrade levels, pantry and orders.
  - **Owner's view:** owners get a `CoBakers` list.
  - **Keeping up to date:** syncing an owner also syncs their co-bakers.
  - **Guide arrow:** it's off while co-baking.
- **Door prompt:** an invisible part in each bakery's doorway, built when a plot is claimed and removed when it's released.
- **New remotes:** `AskCoBake`, `AnswerCoBake`, `LeaveCoBake`, `RemoveCoBaker` and `InviteFriends`, each checked on the server.
- **Clean-up:**
  - **Leaving:** co-bakers go home when their owner leaves. Open requests close when either player leaves.
  - **Respawn:** co-bakers respawn in the bakery they're working in.
- **Friend Boost and referrals:** friendships are checked once per pair on join and cached. On join, the server reads the referrer from `GetJoinData()`, pays first-visit rewards, and collects pending inviter rewards.

**`BakeryClient`:**
- **Prompts:** `CoBake` prompts show in the bakery a player is co-baking in. The door prompt shows only on other players' bakeries.
- **Panels:** the Bake, Pantry and Deliveries panels read `state.Work` when it's there.
- **Popup:** a Yes / No thanks popup for requests.
- **Friends button and panel:**
  - **Contents:** whose bakery you're in and Stop; your co-bakers with Remove; Invite friends; and the Friend Boost line.
  - **Button position:** near the coin and Star counters, because the left column is already full on phones.
- **Multiplier text:** it shows one decimal place, such as "x2.2".

## Verification
- **Solo regression:** baking, stocking, selling, shipping, crates and flyers still work for one player, and coins and goals change as before.
- **Two-player test** (Studio's Local Server test with 2 players):
  - **Joining:** ask, popup, Yes, then the move into the bakery.
  - **Ingredients and trays:** baking uses the owner's pantry, collecting goes onto the co-baker's own tray, and stocking fills the owner's case.
  - **Payouts:** a sale pays the owner +10% and the co-baker 25%, and nothing after 2 idle minutes. Shipping pays the packer.
  - **Limits:** the Cookbook counter is hidden for the co-baker, a 4th co-baker is refused, and the 30-second limit works.
  - **Ending:** Stop, Remove, and the owner leaving all work.
- **Friend Boost and referrals:** Studio test accounts aren't friends and can't send real invites, so the maths and the claim code are tested with a temporary TEST script. The real check is in the published game.
- **Screenshots** of the door prompt, the popup and the Friends panel, including the phone simulator.

## Your steps
1. **Server size:** set it to 6, with 2 slots kept for friends (Server Fill), so friends can join your server.
2. **Friend Referral reward:** set it up in Creator Hub, with text like "10 Sugar Stars for you and your friend".
3. **Two-player test:** start Studio's Local Server test with 2 players when asked.
4. **Publish:** File → Save to Roblox.
