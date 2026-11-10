# Treat Designer

Built 2026-11-10.

## What it does
Every recipe the bakery knows has a **🎨 Customize** button in the Cookbook. It opens a popup:
- **Preview:** the treat turns slowly on the left, and can be dragged round. **Reset to original** under it needs a second tap.
- **Colours tab:** Pastry, Frosting and Filling, for whichever the treat has, in 18 food colours or its own (↺). The Cookie and Macaron have no frosting, so picking one gives them a layer of icing.
- **Toppings tab:** Sprinkles (None, 🌈 Rainbow or one colour), and steppers for Cherries (0–4), Whipped cream dollops (0–6) and Candles (0–5), plus a candle colour.
- **Draw tab:** a 25×25 canvas over the treat's top in its colour, with Pen, Big (3×3), Eraser (3×3), Fill, Clear (second tap) and the 18 colours. Only cells on the treat can be painted, so the donut's hole stays clear. The Croissant and Éclair are too curvy to draw on.
- **Save and Close:** Save is free. Close with unsaved changes needs a second tap ("Discard?").

The saved design is the look of that treat everywhere in that bakery: display cases, your tray and a co-baker's, the Stocker's tray, hotbar icons, the Bake menu and Customize store shelves pictures, and customers' thought bubbles. Each restaurant keeps its own designs, so a new restaurant starts with the original looks.

The thought bubbles also used to be empty. A ViewportFrame in a BillboardGui under the Workspace draws nothing, so bubbles now live in PlayerGui with the customer as Adornee.

## How it's built
- **`Config.Recipes`:** each part has a `Role` (Dough, Frosting, Filling, Cherry, Candle, Flame). Each recipe has a `Top`: where toppings and the drawing sit, with `Dome`, `Hole`, `Busy`, `Icing` and `NoArt` where needed. `Config.TreatDesign` holds the limits and `Config.TreatColors` the 18 colours. A drawing stores one letter per colour ("a" is the first), so new colours only ever go at the end.
- **`ReplicatedStorage.TreatDesign`** (shared):
  - `Clean` checks a design and returns nil when it's the same as the recipe.
  - `Definition` and `Build` make the part list.
  - `CleanAll` and `For` work on a save's designs, keyed by recipe index as text.
  - `Publish` puts a plot's designs (JSON) and a `DesignStamp` on the plot model for clients.
- **`ItemBuilder`:** a part with `Art` is an invisible plate turned 180°, with a `TreatArt` decal on top that holds the drawing in its `Art` attribute.
- **`PlayerData`:** `TreatDesigns` is a restaurant field.
- **`BakerySystem`:** the `DesignTreat` remote takes `(recipeIndex, design)` or `(recipeIndex, "Reset")`, from the owner only, for a known recipe, once a second. It then rebuilds the cases holding that treat and the trays. `claimPlot` and `releasePlot` publish. A customer's `WantsPlot` says whose design their bubble shows, and a co-baker's `Work.Plot` says which bakery they're working in.
- **`StarterPlayerScripts.TreatArt`** (client): turns drawings into 25×25 EditableImages, shared by every treat with the same drawing, and paints decals as they arrive.
- **`StarterPlayerScripts.TreatCustomizer`** (client): the popup, handed BakeryClient's helpers like ExteriorPanel. The canvas image is also the preview's decal, so drawing shows on the 3D treat straight away.

**Script room:** BakerySystem and BakeryClient are both completely full.
- **BakerySystem:** its one new local (`TreatDesign`) only fit after `PathfindingService` was written out where it's used.
- **BakeryClient:** it requires TreatArt inside `showTreat` rather than at the top.

## Needs the creator: Allow Mesh / Image APIs
The drawings use EditableImage. Roblox blocks that until **Game Settings → Security → Allow Mesh / Image APIs** is on.
- **With it off:** making an image works but writing to it fails, so `TreatArt.NewImage` test-writes once. The Draw tab then says drawing isn't ready yet. Colours and toppings still work, and saved drawings just don't show.
- **Edit mode:** EditableImage works in Edit mode even with the setting off. The drawing plate was checked there, including that its top edge is the far side of the treat.

## Tested in Studio (2026-11-10, fake save)
- **Customize buttons:** shown on all five known recipes.
- **Real clicks:** opened the popup for the Cupcake, picked Mint frosting, Rainbow sprinkles, 3 cherries and 4 cream dollops, and saved.
- **Saving:** the server saved and published the design.
- **Display case:** the cupcakes rebuilt with mint frosting, cherries and cream (screenshot), and the Birthday Cake beside them kept its look.
- **Thought bubble:** a customer wanting a cupcake showed the 24-part designed cupcake.
- **Closing:** returned to the Cookbook.
- **Draw tab:** showed its "not ready" notice with the setting off.
- **Other treats:** with no design, every treat looks as before (Edit-mode screenshots, and part lists unchanged apart from the new Role tags).
- **`TreatDesign.Clean`:** junk values, unknown colours, counts over the caps, bad letters, cells off the treat or in the donut's hole, drawings on the Croissant, and non-tables were all cleaned or dropped. The JSON round trip kept designs.

## Not yet tested
- **Drawing in Play:** the canvas, strokes, Fill, and drawings on cases and in bubbles. These need the setting on.
- **Saving and restaurants:** Reset with real clicks, a real save and rejoin, and switching restaurants with different designs.
- **Phones:** tapping the canvas, and how much a phone slows down with several cases full of fully decorated treats. A fully decorated treat is about 35 parts.
