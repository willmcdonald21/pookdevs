-- The Bakery Level badge on the HUD, under the Boosts button: "Level 6" over a bar that
-- fills with XP toward the next level. From a second restaurant on, a line under it reads
-- "Restaurant 2 · +20% customers". BakeryClient requires this, calls the function it
-- returns with its gui and colours (ctx), and calls the update it gets back with each new
-- state.
return function(ctx)
	local colours = ctx.colours
	local badge = Instance.new("Frame")
	badge.Name = "LevelBadge"
	badge.Size = UDim2.fromOffset(120, 30)
	badge.Position = UDim2.fromOffset(10, 270)
	badge.BackgroundColor3 = colours.BROWN
	badge.BorderSizePixel = 0
	badge.ClipsDescendants = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = badge

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = colours.GOLD
	fill.BorderSizePixel = 0
	fill.Parent = badge

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = colours.WHITE
	text.Font = ctx.font
	text.TextScaled = true
	text.ZIndex = 2
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = text
	text.Parent = badge
	badge.Parent = ctx.gui

	local restaurant = Instance.new("TextLabel")
	restaurant.Name = "RestaurantLabel"
	restaurant.Size = UDim2.fromOffset(120, 20)
	restaurant.Position = UDim2.fromOffset(10, 302)
	restaurant.BackgroundTransparency = 1
	restaurant.TextColor3 = colours.BROWN
	restaurant.TextStrokeColor3 = colours.WHITE
	restaurant.TextStrokeTransparency = 0.3
	restaurant.Font = ctx.font
	restaurant.TextScaled = true
	restaurant.Visible = false
	restaurant.Parent = ctx.gui

	return function(state)
		local number = state.Restaurant or 1
		restaurant.Visible = number > 1
		restaurant.Text = ("Restaurant %d · +%d%% customers"):format(number, math.floor((state.CustomerBonus or 0) * 100 + 0.5))
		local level = state.BakeryLevel or 1
		if state.XpNeeded then
			text.Text = ("Level %d"):format(level)
			fill.Size = UDim2.fromScale(math.clamp(state.BakeryXp / state.XpNeeded, 0, 1), 1)
		else
			text.Text = ("Level %d (max)"):format(level)
			fill.Size = UDim2.fromScale(1, 1)
		end
	end
end
