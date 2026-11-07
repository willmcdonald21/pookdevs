# Growth research: what's working on Roblox, and what Sweetopia should do next

## Context
On 2026-11-07 you asked me to look at forums and at successful games like Sweetopia, and recommend changes that would bring more players and earn more Robux. The engagement batch (`engagement-plan.md`) already added the standard tycoon features: passes, a daily streak, offline sales, helpers, golden customers, goals and boosts. This covers what that batch didn't.

You chose **Bake Together** to build first. Its plan is in `bake-together-plan.md`.

## Where Sweetopia stands (2026-11-07)
- **Traffic:** 6 visits and 0 likes.
- **Setup:** the server size is 50, no genre is set, and there are no badges.
- **Server size:** `claimPlot` in `BakerySystem` gives no bakery once all 6 are taken, so players 7–50 would get nothing. That has to be fixed before launch.

## Similar games that are working
Live numbers from Roblox's games, game-pass and badge APIs on 2026-11-07:

| Game | Playing | Age | What it promotes | Passes |
|---|---|---|---|---|
| My Small Business | 25,870 | 3 weeks | Design your own products, cute packing, hire workers, **earns offline**, **invite friends to help** | 16, from 54 to 399. x2 Coins 399, VIP 199, Shop Cat 179, brush and decor packs 54–119 |
| Cozy Lucky Scoop Order | 18,965 | 3 weeks | **Scoop surprises** (random rarity), pack orders, customize shop and garden, **up to 3 friends** | 14, from 29 to 349. 1.5x Coins 299, Starter Pack 99, animated cosmetics 29–79 |
| Restaurant Tycoon 3 | 10,296 | 2 years | Cook, serve, build, **earns offline** | 10, from 249 to 1,499. 3x Customer Luck 399 |
| Ice Cream Shop [Anomaly] | 7,456 | 4 weeks | Serve, hire penguin helpers, **solo or with 3 friends**, codes in a community server | not checked |
| Pet Store Tycoon | 6,944 | 5 months | Stock shelves, **team up with friends** | 28, mostly staff at 199–749. 2x Customer Traffic 299, Unlock All Decor 199, Roomba 99 |
| Run a Restaurant! | 5,347 | 7 months | Cook, decorate, hire staff, **earns offline** | 6, from 199 to 999. Plot Expansion 999, Rare Customers 629 |
| Bake Me Rich | 840 | 5 weeks | **Rare pastries, upgrade your luck, discover every recipe** | not checked |

**Patterns:**
- **Friends:** playing in the same shop is the top trend. 4 of the 6 newest hits advertise it.
- **Offline earnings:** the line hits lead their descriptions with.
- **Collecting rare things:** shared by Bake Me Rich, Cozy Lucky Scoop, and Grow a Garden's crop mutations and weather.
- **Lots of cheap cosmetic passes:** hits sell 14–28 passes, from 29 Robux. Sweetopia sells 5.
- **Prices:** Sweetopia's 2x Coins is 199, compared with 299–399 elsewhere.
- **Server size:** every hit tycoon uses 6–8 players per server.

## What Roblox rewards
- **Discovery** (June 2026 algorithm update, from a creator's summary):
  - **Packaging:** play-through rate from the home page, and how many players leave in the first 60 seconds or 61–180 seconds. Leaving early lowers recommendations.
  - **Retention and spending:** D1, D7 and D28 retention, playtime, and how many players pay.
  - **Friends:** friends playing together.
  - **Penalized:** template games without a twist.
- **Creator Rewards** (replaced Premium Payouts in July 2025):
  - **Daily Engagement:** 5 Robux per day for each "active spender" (spent $9.99 or more on Roblox in 60 days) who plays 10 minutes or more. It's automatic.
  - **Audience Expansion:** 35% of a new or returning user's first $100 of purchases, if they arrive through a direct link or by searching the game's name. It applies once the game averages 100 daily users.
- **Rewarded video ads:**
  - **How:** native through `AdService`, shown only to users 13 and older, after Roblox approves the ad questionnaire.
  - **Earnings:** Roblox says Brookhaven earns five figures a month from them. Blogs estimate 5–15% of revenue, which is unverified.
- **Paid random items:** a paid luck boost counts as one, so its exact odds must be shown before purchase. Free random rewards are exempt.
- **Subscriptions:** at least 49 Robux a month, or $2.99–$14.99 in local currency. Local-currency plans pay 70% the first month and 100% after that, and need an ID- or phone-verified account.
- **Regional Pricing:** opt-in. It needs prices read live, which the store already does with `GetProductInfo`. Price Optimization recommends prices once there's traffic.
- **Friend Referral System:** players invite friends from the game, and the server reads the inviter from `Player:GetJoinData().ReferredByPlayerId` to reward them.
- **Avoid:**
  - **Rewarding likes:** this drew DevForum backlash, and games can't detect likes anyway.
  - **Clickbait thumbnails:** these raise the early-leave rate.

## Recommendations
S, M and L are rough build sizes.

### A. Before launch (mostly small)
1. **Server size 50 → 6.** This is a blocker, changed in Creator Hub. S
2. **Genre: Simulation → Tycoon.** Every comparable hit has it set. Without it, Sweetopia is missing from genre filters and charts. S
3. **Description:** lead with "Your bakery earns coins even while you're offline!" and "Bake with friends". S
4. **Icon and 3–5 thumbnails,** tested with Thumbnail Personalization, keeping each for at least 7 days. They must match what the first 60 seconds show. S
5. **Analytics funnels** (`AnalyticsService`, sent from the server, published game only):
   - **Onboarding funnel:** joined → first bake → first stock → first sale → first upgrade → first decoration → first delivery.
   - **Store funnel:** opened → item viewed → prompt → bought.
   - **Economy events:** where coins and Stars come from and go.

   S
6. **8–10 milestone badges,** such as First Sale, Birthday Cake Baker, Fully Expanded and 7-Day Streak. They show on profiles and give players goals. S

### B. Engagement
7. **Bake Together:** co-op in a friend's bakery, plus invite rewards. L, being built. See `bake-together-plan.md`.
8. **Rare treats, a Treat Book and town weather:**
   - **Rare treats:** any treat can come out Golden (1 in 20, 3x price), Sparkly (1 in 100, 8x) or Rainbow (1 in 500, 25x).
   - **Treat Book:** 5 recipes × 4 versions = 20 entries.
   - **Weather:** a town-wide Sprinkle Shower about every 45 minutes triples rare chances for 3 minutes.

   M
9. **Deeper progression:** a Bakery Level that unlocks 7 more recipes, such as Croissant, Cinnamon Roll, Macaron, Éclair, Cheesecake, Shortcake and Wedding Cake, with a "new location" prestige later. Today's ~1 hour of progression is short for D7 and D28. M
10. **A return trigger players can see:**
    - **Sell-out timer:** "Your cases will sell out in ~2h 40m" when stocking or leaving.
    - **Notifications:** an opt-in notification, at most once a day for 13+ players.

    M
11. **Winter event, Dec 1 – Jan 5:** limited recipes, snow on the plaza, a Candy Cane event currency, and event decor. M, time-sensitive

### C. Profitability
12. **More cheap cosmetic passes** (49–119): themed decor packs, sparkly paints, animated neon signs, and a Bakery Cat that wanders the shop. S each
13. **Convenience passes:** 2x Customer Traffic, a second Baker or Stocker, Auto-Restock Pantry, and a 4th expansion step. S–M
14. **Prices:**
    - **2x Coins:** 199 → 299.
    - **VIP:** 149 → 199, with more perks.
    - **Starter Pack:** keep at 49.
    - **Regional Pricing:** opt in.
    - **Price Optimization:** use it later.

    S
15. **Rewarded video ad:** "Watch a short ad → 10-minute 2x Boost", reusing the 2x Boost product. S
16. **Offers at the right moment:**
    - **Out of ingredients:** offer the Coin Bag.
    - **A customer leaves with nothing:** offer the Stocker.
    - **Around minute 10 of the first visit:** a one-time Starter Pack offer.

    At most one popup per session. S
17. **Later: a Baker's Club subscription** with daily Stars, a monthly exclusive decoration, and +10% coins. M
18. **Creator Rewards (nothing to build):** share the game's direct link on TikTok and Discord, and aim for first visits of 10 minutes or more.

## Sources
- **Live Roblox data, 2026-11-07:** the games, game-pass and badge APIs.
- **Creator Rewards and Friend Referral:**
  - [Introducing Creator Rewards](https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628)
  - [Friend Referral System](https://devforum.roblox.com/t/announcing-the-new-friend-referral-system-for-your-experiences/3623795)
- **Discovery:**
  - [2025 Discovery Roadmap](https://devforum.roblox.com/t/roblox’s-2025-discovery-roadmap-and-ways-to-reach-and-engage-your-audience/3557533)
  - [June 2026 algorithm summary](https://sozai.app/transcript/roblox-algorithm-changes-june-2026/index.md) (a creator's interpretation)
- **Roblox docs:**
  - [Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events)
  - [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
  - [Subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions)
  - [AdService](https://create.roblox.com/docs/reference/engine/classes/AdService)
  - [Regional pricing for products](https://devforum.roblox.com/t/introducing-regional-pricing-for-developer-products/3971235)
- **DevForum:**
  - [Ads for Creators recap](https://devforum.roblox.com/t/ads-for-creators-rdc-recap-and-what%E2%80%99s-next/3929106)
  - [Bribing players for likes](https://devforum.roblox.com/t/the-issue-of-bribing-players-for-likes/4495969)
  - [Monetization ideas for a tycoon](https://devforum.roblox.com/t/monetization-ideas-for-my-tycoon-game/3048249)
  - [Liftoff case study](https://devforum.roblox.com/t/liftoff-a-case-study/468266)
- **Developer blogs** (opinion):
  - [D7 retention is a loop problem](https://rowatcher.com/news/roblox-d7-retention-is-a-loop-problem-not-a-content-problem)
  - [Tycoon genre overview](https://rowatcher.com/news/tycoon-games-the-genre-that-built-roblox-and-still-hasn-t-peaked)
  - [Deconstructor of Fun on Roblox in 2026](https://www.deconstructoroffun.com/blog/how-to-build-a-real-business-on-roblox-in-2026)
