# Plan: Calmer customers, and boosts for busy spells

## Context
Normal times were far too busy. A decorated bakery got a customer every 2–4 seconds, up to 5 inside at once, and the gaps between them barely changed, so it felt like a steady drip. You asked for:
- **Calmer, more random normal times:** about one customer every 12–15 seconds for a decorated bakery.
- **Hand out flyers** on the plaza.
- **Bake Sale:** once per real hour, everything 25% off and 50% more customers for 2 minutes.
- **Stars and Robux boosts:** spend Sugar Stars on a rush, and the 2x Boost also doubles customers.

## How it plays
**Normal times**
- A bakery with no decorations gets about one customer every 18 seconds. Charm brings that down to about 14 seconds at Charm 12, 13.5 at Charm 24, and never below 12. Every decoration still helps a little, but decor alone can't cause a stampede.
- The waits vary a lot. About 15% of the time someone comes right behind the last person, and about 20% of the time there's a quiet spell of roughly 25–65 seconds, shorter with more Charm. Now and then a pair (12%) or a group of three (3%) arrives together.
- At most 3 customers are in the bakery at once, or 5 while any boost is on.

**Bake Sale** (Boosts menu, free)
- Once per real hour. Leaving the game doesn't reset the hour.
- For 2 minutes customers pay 25% less and 50% more of them come. A "BAKE SALE · 25% OFF" sign hangs over your door where everyone can see it.
- Delivery orders and "while you were away" sales keep their full price.

**Flyers** (free)
- A flyer stand sits outside your door, across the path from the ingredient crate. Take a stack of 5.
- You carry the stack in your right hand, one sheet for each flyer left, until you run out.
- Walk onto the plaza. Anyone strolling within a few steps of you takes a flyer, says "Ooh, I'll take a look!", and walks to your bakery. You hand out at most one a second.
- A new stack is ready 3 minutes after you take one, and the stand counts down.

**Bakery Buzz** (3 Sugar Stars)
- Twice as many customers for 5 minutes. Buying it again adds another 5 minutes.

**2x Boost** (Robux)
- It now doubles customers as well as coins, for the same 15 minutes.

**Stacking:** boosts add together. A Bake Sale gives 1.5×, Buzz or the 2x Boost gives 2×, and all three at once give 3.5×, which is about as busy as the bakery was before this change.

**Boosts menu:** a new button under Cookbook. It turns green and says "Boosts!" when a Bake Sale is ready, and turns gold with a countdown such as "Rush 1:24" while a boost is on. The flyer stand shows its own countdown, so a ready stack doesn't light the button. Inside, the first row says how many customers are coming compared with usual, such as "2.5x as many as usual right now". Then come the Bake Sale, Flyers, Bakery Buzz and 2x Boost rows, each with a live countdown.

## How it's built
- **Config:** `CustomerInterval` 18, `CharmSpeed = { Max = 0.5, Half = 12 }` instead of `CharmSpeedBonus`, a table of wait kinds in `CustomerGap`, `MaxCustomers` 3 and `MaxCustomersBoosted` 5, and new `BakeSale`, `Flyers` and `Buzz` settings.
- **Saving:** `BakeSaleAt` (when the last sale started) and `BuzzUntil`, kept like `BoostUntil`.
- **Spawner:** it checks every half second and moves a step closer to the next customer, by how strong the boosts are. A boost works straight away, without waiting out a long gap.
- **Strolls:** someone called to a bakery stops mid-walk and turns, rather than finishing their stroll first.
- **Flyer stand and sale sign** are built when a bakery is claimed and removed when its owner leaves, like the crate.

## Not changed
- Offline sales still follow the customer rate, but they are limited by the treats left in cases, so they sell about the same.
- Golden customers, wanted treats and tips work as before, and during a sale they're worked out from the discounted price.
