# Plan: Employees, and a line at the register

## Context
The HUD had Deliveries and Cookbook buttons, although both already have their own counters in the bakery. Helpers were two fixed Shop upgrades, the Baker Helper and the Stocker Helper, and customers paid by themselves the moment they reached the checkout counter. You asked for:
- **No Deliveries or Cookbook buttons.** Their counters open those menus.
- **An Employees button** that replaces hiring helpers in the Shop.
- **Up to 2 employees**, not called Baker or Stocker, each with a name and a Roblox look you choose.
- **Jobs:** each employee is a Baker, a Stocker or the new Cashier.
- **Checking out:** customers can only pay when a Cashier or a player is at the register, and a player checks someone out with one tap of E.

**Your choices:**
- **Looks:** mix and match, in a window like the avatar editor on the Roblox website.
- **Waiting:** customers wait until they're served, in a single-file line at the register.
- **Away sales:** they stay as they were, for everyone.
- **Prices:** first hire 1,000 coins, second hire 3,000, and training 5,000 per employee.
- **Checkout speed:** an employee Cashier takes about 2.5 seconds per customer. A player is quicker.

## How it plays
**The HUD**
- The left column is Shop, Decorate, Employees and Boosts.
- The Delivery Counter and the Cookbook Counter open their menus as before. A bouncing gold "!" hangs over the Delivery Counter when an order can be packed, and over the Cookbook Counter when a daily goal can be claimed or a recipe unlocked. Those used to turn the old buttons green.
- The Employees button turns green and says "Employees!" when you can afford a hire or a training.

**The line at the register**
- After choosing a treat, a customer joins a single-file line in front of the cash register. The first one says "Ready to pay!".
- **If there's no Cashier:** a "Check out" prompt appears on the register. One tap of E checks out the first person in line, and they pay, tip and leave as before. The hint bar says "A customer is waiting! Tap E at the register", and you get a notice at most every 10 seconds.
- **If there is a Cashier:** they stand behind the register and check out the first person after 2.5 seconds, or 1.5 seconds once trained. You can still tap E to be quicker.
- The line steps up when someone leaves it, and follows the register if you move the counter.
- Nobody leaves the line unserved. While the bakery is full, new customers wait, so sales simply pause until someone checks people out.
- Co-bakers can use the register too.

**Employees**
- **Hiring:** the Employees menu has a card for each of the two places. The first hire costs 1,000 coins and the second 3,000.
- **New hires:** each one gets a random name (Maple, Biscuit, Poppy and so on), a random outfit, and the first job nobody has, in the order Cashier, Baker, Stocker.
- **Jobs:** each card has Cashier, Baker and Stocker buttons. The current job is pink, the other employee's job is gold, and picking a gold one swaps their jobs. No two employees share a job, so you always do the job left over.
  - **Baker:** fetches ingredients from the pantry shelf and bakes a random treat you have ingredients for, as the Baker Helper did.
  - **Stocker:** carries finished batches to your display cases, as the Stocker Helper did. A Stocker who still has treats on their tray finishes putting them away before starting a new job.
  - **Cashier:** checks customers out at the register.
- **Training:** 5,000 coins each. It makes the employee walk at speed 18 instead of 10, and a Cashier checks people out in 1.5 seconds instead of 2.5.
- **Looks:** everyone wears the pink bakery apron over their outfit, with a name tag above their head such as "Maple · Cashier".

**The dressing room** (Customize on a card)
- **Left side:** the employee's name in a box you can type in, over a big picture of them turning slowly, which you can drag round.
- **Right side:** tabs for Skin, Hair, Shirts, Pants and Hats, over a grid of pictures. Everything is free and made by Roblox: 10 skin tones, 25 hairstyles, 11 shirts, 8 pants and 2 caps.
- **Changing an outfit:** tapping a picture dresses the employee in the bakery as well. The picture says "Dressing..." until they've changed.
- **Names:** they're at most 20 characters, and Roblox filters them before anyone sees them.

**Your old helpers:** a hired Baker Helper or Stocker Helper becomes an employee with that job, and a fully upgraded one is already trained. Your save has the Stocker hired, so you start with one Stocker employee.

## How it's built
- **Config:** `Config.Employees` holds the limits, prices, speeds, checkout times, jobs and default names. `Config.Wardrobe` lists the categories and their items. The `Baker` and `Stocker` upgrades are gone.
- **Save:** `Employees`, a list of `{ Name, Job, Trained, Look }`. `PlayerData.clean` turns old `BakerLevel` and `StockerLevel` values into employees, and those fields stop being saved.
- **Server** (`BakerySystem`):
  - **The checkout section:** `checkout.wait` puts a customer in `plot.line` and walks them to their spot, `checkout.checkOut` takes payment from the first person, and `checkout.update` sets the prompt, the notice and the hint.
  - **Payment:** the code that used to sit in `shopAt` is now `checkout.pay`.
  - **Employees:** `setUpEmployees` builds each one with `Players:CreateHumanoidModelFromDescription`, changes clothes with `Humanoid:ApplyDescription`, and filters names with `TextService`. `runEmployee` runs one loop per place, doing one task of the employee's job at a time.
  - **Menu actions:** the `EmployeeAction` remote handles Hire, Train, SetJob, SetLook and Rename. The server checks every value.
- **Client** (`BakeryClient`): the HUD changes, `setCounterAlerts`, `panels.Employees`, and `wardrobe`, which builds the dressing room and draws employee pictures with ViewportFrames.

## What was tested (Studio, 2026-11-07, on a throwaway save that was never written)
- **Customers and the register:**
  - Customers lined up single file 2.5 studs apart, and the first said "Ready to pay!". The prompt, the hint and the notice appeared.
  - One tap of E checked out one customer and paid them.
  - The line stepped up, and followed the register when the counter was moved.
- **Hiring and jobs:**
  - Hiring cost 1,000 and then 3,000, and a third hire was refused.
  - Jobs swapped, and the Stocker carried a batch to the case.
  - The Cashier checked customers out in 2.50 seconds, and in 1.50 once trained. Training was charged once only.
- **The dressing room:**
  - Skin, hair, shirt and hat changes replaced the old ones on the employee and in the picture.
  - Bad values were ignored, and names were tidied and cut to 20 characters.
- **The HUD:** the Deliveries and Cookbook buttons are gone, and the "!" showed over the Cookbook Counter.
- **Screenshots:** the line, the Cashier, the Employees menu and the dressing room were checked in screenshots.

**Not yet tested**
- **Co-bakers:** a co-baker checking customers out and claiming goals at a friend's cookbook counter. This needs the two-player test.
- **Real saves:** loading an old save into the new employees in the published game, and employees surviving a rejoin, since the test save is never written.
- **Phones:** tapping the dressing room's pictures and dragging the preview on a real phone.
- **Hidden markers:** Studio screenshots don't show markers that draw on top of walls, which is how the guide arrow is drawn, so the "!" was made to draw normally. It can be hidden behind a wall when you're outside the bakery.
