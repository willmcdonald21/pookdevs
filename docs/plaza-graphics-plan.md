# Plaza graphics: Roblox-avatar townsfolk, a new fountain, a spring park

## Why
The plaza was a bare cobblestone disc on a flat mint baseplate. It had a basic fountain (two glass discs, a column and one particle spout), seven ball-on-a-stick trees far behind the buildings, and townsfolk built from six plain boxes with swinging limbs. The user asked for:
- a better fountain with real water movement;
- townsfolk that don't look like cardboard boxes;
- greenery around the plaza.

## Decisions (from the user)
- **Townsfolk:** Roblox-style R15 avatars in free Roblox catalog hair and clothes, with Roblox's walk and idle animations. The Baker and Stocker use the same builder, so they changed too.
- **Greenery:** a spring park: green and pink cherry trees that drop petals, stone planters, pastel flower beds and a grass lawn.
- **Fountain:** a full overhaul, with a water sound and dancing jets. Players can't wade in.

## Townsfolk (`tools/build_townsfolk.luau`, `BakerySystem`, `BakeryClient`)
- **Looks:** the builder makes 36 looks in `ServerStorage.TownsfolkLooks.People`, plus `Helpers.Baker` and `Helpers.Stocker`. Each is built with `Players:CreateHumanoidModelFromDescription` from a seeded mix of free Roblox-made items:
  - 25 hairs;
  - 11 classic shirts and 8 classic pants;
  - a few layered tops, skirts and shorts (only about a quarter of the looks have one, to keep phones smooth);
  - the odd cap;
  - 6 skin tones.
- **Left out:** Brown Hair (62234425), because its texture is missing from Roblox.
- **Helpers:**
  - **Baker:** a white tee, a pink apron, and a chef's hat made of parts.
  - **Stocker:** a striped tee, the same apron, and a pink cap.
- **Set up for tweening:** every part is non-colliding and massless, and the HumanoidRootPart is anchored. The Humanoid shows no name or health and doesn't run its state machine, and the Animate script is removed.
- **Joints:** new R15 rigs use kinematic AnimationConstraints instead of Motor6Ds. They still move as one piece when the root's CFrame is tweened.
- **Server:**
  - `buildPerson(name, look)` clones a look and adds the speech bubble.
  - `buildCustomer` picks a random look, and golden customers keep their crown and sparkles.
  - `CUSTOMER_HEIGHT` is 3, the measured root height.
  - `fade` and `spawnPerson` leave the root part invisible.
  - `walkCustomer` sets a `Speed` attribute before each walk.
- **Client:** each person plays Roblox's walk while `Walking` is on, at `Speed / 6.4`. Roblox's Animate script plays the walk at normal speed for 6.4 studs a second. Otherwise they idle, and they always blink. A 0.15 s grace period keeps pathfinding steps from flickering into idle.
- **Script size:** the whole section sits in a `do` block with its numbers written in place. A version with named constants in the block ran out of Luau registers, because the block's locals and loop variables add to the top-level ones.

## Fountain (`tools/build_fountain.luau`, `ReplicatedStorage.WaterArc`, `PlazaClient`)
- **Shape:**
  - a dark-stone plinth;
  - a 16-sided marble ledge with a pink band and a teal tiled pool;
  - a fluted pedestal;
  - a middle bowl and a top bowl with stepped undersides and pink bands;
  - a pink finial.
- **`Basin`:** it's still a cylinder lying on its side, with `Size.Y` as the diameter (21), because `setUpTown` puts the ring of fountain spots at its radius + 4.
- **Moving water with no script:**
  - sheets of water spill all around both bowls: Beams using a streak texture that scrolls down, curving outward, with the width along the rim;
  - splashes and flat ripple rings where water lands;
  - shimmer textures on every water surface;
  - a faint mist.
- **Arcs:** `WaterArc.Aim` sends water from one attachment up to a height and down onto another, under a gravity of 35 studs/s² (real gravity at Roblox's scale). The drops get the matching launch speed and lifetime. The Beam is bent to the same parabola: a thrown arc is a quadratic Bézier with control point `start + velocity × time / 2`, and the Beam's cubic matches it when each end's handle reaches ⅔ of the way to that point.
- **Jets:** eight jets on the ledge arc in toward the pedestal, and six small arcs make an umbrella on the finial.
- **`PlazaClient`:**
  - re-aims every jet each frame;
  - jet heights (2–6 studs) follow three patterns that blend every 12 seconds: a wave around the ring, all together, and every other jet;
  - the dance is timed by `workspace:GetServerTimeNow()`, so every player sees the same one;
  - splash rates scale with jet height, the umbrella spray breathes, and the shimmer scrolls;
  - it plays the fountain sound, ProSoundEffects "Water Fountain 2 (SFX)", 9120557577;
  - it stops when the camera is more than 220 studs away, and looks the effects part up again if streaming removes it.
- **Textures:** drawn by `art/plaza/build_textures.py` and uploaded with the Studio MCP:
  - WaterStreak 85429443771374;
  - Ripple 136264013809055;
  - Shimmer 136162882548820;
  - Petal 74180373620457;
  - Droplet 109115073089942.

## Park (`tools/build_greenery.luau`)
- **Lawn:** the baseplate becomes Grass.
- **`Town.Greenery`:**
  - **Planters:** 7 round marble planters with a pink band on the plaza (r 46, a little before each gap's way out). Cherry and green trees take turns in them, with bushes and flowers.
  - **Flower beds** just outside the plaza's rim, where they're clear.
  - **Pots** at both ends of each bench, and **baskets** on the lamps.
  - **On the lawn:** 75 trees (about a third of them cherries), 45 bushes and 7 flower patches out to r 240, placed from a fixed seed.
  - **Petals:** cherry trees within r 130 drop petals.
- **Keep-clear zones:** one `isClear` check covers:
  - each bakery's largest expansion plus 4 studs;
  - the strip in front of each bakery (|x| ≤ 14, covering the path, crate and flyer stand) down to the plaza;
  - the grocery store and its front;
  - the townsfolk's ways in and out (±7 studs out to r 185);
  - their stroll spots, the benches, the lamps, the spawn and the fountain.
- **Check:** a separate overlap check found no greenery in any of those zones, except the bench pots, which sit beside benches that were already on a way out.
- **Collisions:** trees, bushes and planters collide; flowers, beds, petals and baskets don't. In all it's 1,315 parts.
- **`build_town`:** it no longer builds the fountain or trees, and says to run `build_fountain` and `build_greenery` after it.

## Verified in Studio (2026-11-07)
- **Edit-mode screenshots:** the lineup of looks, the fountain from two angles, the park from above and at eye level, and a cherry tree.
- **Play:**
  - townsfolk spawned as avatars, root invisible, walking at 6.4–9 studs/s with the walk at 1.05–1.41× speed, then idling;
  - customers walked up the path, shopped and tipped ("Just what I wanted!");
  - golden customers wore crowns, and a customer heading to a bakery had a thought bubble;
  - the Baker stood at the oven in a chef's hat;
  - two fountain screenshots a few seconds apart showed different jet heights;
  - the fountain sound was playing.
- **Console:** the only warnings were for Brown Hair's missing texture, now left out.
- **Save:** the playtest's offline and live sales were undone by writing back the save copied before Play.
