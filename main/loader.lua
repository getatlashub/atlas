--[[
	ATLAS — loader (the only file hosted on GitHub)
	Run this one line in any supported game:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/getatlashub/atlas/refs/heads/main/main/loader.lua"))()

	It asks your site which script to run for the current game (by place id / universe id),
	then runs the Lua the site returns. Add or edit games on the site, not here.
	Set SITE to your site's address.
]]

local SITE = "https://getatlas.lol"
local TOKEN = "b3389993354b581de83e14b7b270774e" -- from the site: Settings → API token
local DISCORD = "https://discord.gg/xWG7vJzYkG" -- copied by the "Join Discord" button

local HttpService = game:GetService("HttpService")

local env = (typeof(getgenv) == "function" and getgenv()) or _G
env.ATLAS_BASE = SITE .. "/lib/" -- game scripts load NOIR from the site
env.ATLAS_TOKEN = TOKEN -- game scripts reuse it to reach the API

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "ATLAS", Text = text, Duration = 6 })
	end)
	warn("[ATLAS] " .. text)
end

--// Message card -----------------------------------------------------------------------
-- A small window in the hub's style for anything that stops the hub from opening
-- (game not supported, script paused, site offline...). Same look as NOIR: dark card,
-- BuilderSans, the white "peak" mark and a blue primary button.

local TweenService = game:GetService("TweenService")
local C = {
	Background = Color3.fromRGB(10, 12, 20),
	Surface = Color3.fromRGB(16, 19, 30),
	Stroke = Color3.fromRGB(36, 42, 62),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(168, 176, 198),
	AccentA = Color3.fromRGB(0, 70, 255),
	AccentB = Color3.fromRGB(0, 18, 120),
}
local function font(weight)
	return Font.new("rbxasset://fonts/families/BuilderSans.json", weight, Enum.FontStyle.Normal)
end

-- Icons: the Lucide pack of the Nebula Icon Library
-- (github.com/Nebula-Softworks/Nebula-Icon-Library, CC-BY-NC 4.0). The pack is fetched in
-- parallel at start-up and only READ as text (name = asset id), never executed, so nothing
-- from a third-party repo runs here. These ids come from the same pack and cover the card
-- if the fetch is slow or fails.
local ICON_PACK = "https://raw.githubusercontent.com/Nebula-Softworks/Nebula-Icon-Library/master/LucideIcons.luau"
local Icons = {
	["gamepad-2"] = 123513783706820,
	["circle-pause"] = 75601858754638,
	hourglass = 97354459771104,
	["wifi-off"] = 128431848377922,
	["circle-alert"] = 86075768491850,
	["code-xml"] = 130876992978049,
	["plug-zap"] = 101683967511440,
	["message-circle"] = 103253555420242,
	x = 73070135088117,
	check = 83827110621355,
	["clipboard-check"] = 119930716282333,
	hash = 79281219073716,
	users = 109023655602096,
	user = 81899856845503,
	globe = 111578783307093,
}
task.spawn(function()
	local ok, body = pcall(function()
		return game:HttpGet(ICON_PACK)
	end)
	if ok and type(body) == "string" then
		for name, id in body:gmatch('%["([%w%-]+)"%]%s*=%s*(%d+)') do
			Icons[name] = tonumber(id)
		end
		for name, id in body:gmatch("\n%s*([%w_]+)%s*=%s*(%d+)") do
			Icons[name] = tonumber(id)
		end
	end
end)
local function iconImage(name)
	local id = Icons[name]
	return id and ("rbxassetid://" .. id) or ""
end

local function make(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end
local function corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r) })
end
local function stroke(color, transparency)
	return make("UIStroke", { Color = color, Thickness = 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function tween(inst, t, goal, style, direction)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- Makes everything under `root` (and root itself) invisible, remembering the original
-- transparencies so `reveal` can fade them back in. Used for the staggered entrance.
local function hideAll(root)
	local saved = {}
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in ipairs(list) do
		local s = {}
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			s.TextTransparency = d.TextTransparency
			d.TextTransparency = 1
		end
		if d:IsA("GuiObject") then
			s.BackgroundTransparency = d.BackgroundTransparency
			d.BackgroundTransparency = 1
		end
		if d:IsA("ImageLabel") then
			s.ImageTransparency = d.ImageTransparency
			d.ImageTransparency = 1
		end
		if d:IsA("UIStroke") then
			s.Transparency = d.Transparency
			d.Transparency = 1
		end
		if next(s) then
			saved[d] = s
		end
	end
	return saved
end
local function reveal(saved, duration, delay)
	task.delay(delay or 0, function()
		for inst, props in pairs(saved) do
			if inst.Parent then
				tween(inst, duration, props, Enum.EasingStyle.Quad)
			end
		end
	end)
end

-- ATLAS "peak" mark (same geometry as NOIR's BrandMarks.peak), whole-pixel rows.
local function peak(holder, px, color)
	local k = px / 120
	local function cell(x, y, w, a)
		make("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 1), BackgroundColor3 = color, BackgroundTransparency = 1 - a, BorderSizePixel = 0, ZIndex = 3, Parent = holder })
	end
	local function span(xl, xr, y)
		if xr - xl <= 0.05 then
			return
		end
		local a, b = math.ceil(xl), math.floor(xr)
		if b < a then
			cell(math.floor(xl), y, 1, xr - xl)
			return
		end
		if b > a then
			cell(a, y, b - a, 1)
		end
		if a - xl > 0.02 then
			cell(a - 1, y, 1, a - xl)
		end
		if xr - b > 0.02 then
			cell(b, y, 1, xr - b)
		end
	end
	local top, bottom = math.floor(14 * k + 0.5), math.floor(104 * k + 0.5)
	local barTop = math.floor(78.5 * k + 0.5)
	local barBottom = math.max(math.floor(85.5 * k + 0.5), barTop + 1)
	local cx = 60 * k
	for y = top, bottom - 1 do
		local v = (y + 0.5) / k
		local outer = (v - 14) * 46 / 90 * k
		if y >= barTop and y < barBottom then
			span(cx - outer, cx + outer, y)
		elseif v > 56 then
			local inner = (v - 56) * 24 / 48 * k
			span(cx - outer, cx - inner, y)
			span(cx + inner, cx + outer, y)
		else
			span(cx - outer, cx + outer, y)
		end
	end
end

-- The loading card while the loader works (set below); a message card replaces it.
local loading

-- options: Title, Message, Icon (Lucide name, shown next to the title), ShowGame (bool: show the current game's icon and name)
local function showCard(options)
	if loading then
		loading.close()
		loading = nil
	end
	warn("[ATLAS] " .. tostring(options.Title) .. " — " .. tostring(options.Message))
	local Players = game:GetService("Players")
	local parent
	pcall(function()
		parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
	end)
	parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = parent:FindFirstChild("ATLAS_Loader")
	if old then
		old:Destroy()
	end

	local W = 380
	local HOVER = Color3.fromRGB(24, 28, 44)

	-- small "icon + text" pair laid out horizontally (used in several places)
	local function iconText(props)
		local holder = make("Frame", {
			AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
			Position = props.Position or UDim2.new(),
			Size = UDim2.fromOffset(0, props.Height or 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder or 0,
			ZIndex = props.ZIndex or 1,
			Parent = props.Parent,
		}, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, props.Gap or 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local glyph = make("ImageLabel", {
			Size = UDim2.fromOffset(props.IconSize or 14, props.IconSize or 14),
			BackgroundTransparency = 1,
			Image = iconImage(props.Icon),
			ImageColor3 = props.IconColor or props.Color or C.Muted,
			LayoutOrder = 1,
			ZIndex = props.ZIndex or 1,
			Parent = holder,
		})
		local label = make("TextLabel", {
			Size = UDim2.fromOffset(0, props.Height or 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = props.Text or "",
			RichText = props.RichText or false,
			FontFace = font(props.Weight or Enum.FontWeight.SemiBold),
			TextSize = props.TextSize or 13,
			TextColor3 = props.Color or C.Muted,
			LayoutOrder = 2,
			ZIndex = props.ZIndex or 1,
			Parent = holder,
		})
		return holder, label, glyph
	end

	local gui = make("ScreenGui", { Name = "ATLAS_Loader", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local backdrop = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Active = true, Parent = gui })
	local card = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { corner(14) })
	local scale = make("UIScale", { Scale = 0.9, Parent = card })
	-- Border with a soft highlight travelling around it (same as NOIR's key screen).
	local border = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	local sheen = make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.84),
			NumberSequenceKeypoint.new(0.42, 0.84),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.58, 0.84),
			NumberSequenceKeypoint.new(1, 0.84),
		}),
		Parent = border,
	})
	local spin = game:GetService("RunService").RenderStepped:Connect(function(dt)
		sheen.Rotation = (sheen.Rotation + dt * 60) % 360
	end)
	make("UIPadding", { PaddingTop = UDim.new(0, 28), PaddingBottom = UDim.new(0, 18), PaddingLeft = UDim.new(0, 26), PaddingRight = UDim.new(0, 26), Parent = card })
	make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

	-- logo (bare white mark, like the key screen); the inner frame pops in from its centre
	local logo = make("Frame", { Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
	local mark = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, Parent = logo })
	local markScale = make("UIScale", { Scale = 0.55, Parent = mark })
	peak(mark, 44, C.Text)

	-- title: state icon + text, centred as one unit
	local title = iconText({
		Icon = options.Icon or "circle-alert",
		IconSize = 20,
		IconColor = C.Muted,
		Text = options.Title or "ATLAS",
		Weight = Enum.FontWeight.ExtraBold,
		TextSize = 20,
		Color = C.Text,
		Height = 24,
		Gap = 8,
		LayoutOrder = 2,
		Parent = card,
	})
	local message = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = options.Message or "",
		TextWrapped = true,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 14,
		LineHeight = 1.1,
		TextColor3 = C.Muted,
		LayoutOrder = 3,
		Parent = card,
	})

	-- the current game: icon + name, then place id and players in this server
	local row
	if options.ShowGame then
		row = make("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.Surface, LayoutOrder = 4, Parent = card }, { corner(10), stroke(C.Stroke) })
		make("ImageLabel", {
			Position = UDim2.fromOffset(9, 9),
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = C.Stroke,
			Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150",
			Parent = row,
		}, { corner(8) })
		local name = make("TextLabel", {
			Position = UDim2.fromOffset(58, 10),
			Size = UDim2.new(1, -68, 0, 18),
			BackgroundTransparency = 1,
			Text = "This game",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = font(Enum.FontWeight.Bold),
			TextSize = 14,
			TextColor3 = C.Text,
			Parent = row,
		})
		local meta = make("Frame", {
			Position = UDim2.fromOffset(58, 30),
			Size = UDim2.new(1, -68, 0, 16),
			BackgroundTransparency = 1,
			Parent = row,
		}, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		iconText({ Icon = "hash", IconSize = 12, Text = tostring(game.PlaceId), Height = 16, Gap = 4, LayoutOrder = 1, Parent = meta })
		local playerCount = #Players:GetPlayers()
		iconText({ Icon = "users", IconSize = 12, Text = playerCount .. (playerCount == 1 and " player" or " players"), Height = 16, Gap = 4, LayoutOrder = 2, Parent = meta })
		task.spawn(function()
			local ok, info = pcall(function()
				return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
			end)
			if ok and info and info.Name and name.Parent then
				name.Text = info.Name
			end
		end)
	end

	-- buttons: icon + text; a light overlay brightens on hover, the button sinks while pressed
	local buttons = make("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = 5, Parent = card })
	local half = (W - 52 - 10) / 2
	local function button(text, x, primary, icon)
		local b = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x + half / 2, 23),
			Size = UDim2.fromOffset(half, 38),
			BackgroundColor3 = primary and C.Text or C.Surface,
			AutoButtonColor = false,
			Text = "",
			Parent = buttons,
		}, { corner(9), stroke(primary and C.AccentA or C.Stroke) })
		-- the gradient tints the button's own text too, so the text lives in a child label
		if primary then
			make("UIGradient", { Color = ColorSequence.new(C.AccentA, C.AccentB), Rotation = 0, Parent = b })
		end
		local glow = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 1, Parent = b }, { corner(9) })
		local _, label, glyph = iconText({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Icon = icon,
			IconSize = 16,
			Text = text,
			Weight = Enum.FontWeight.Bold,
			TextSize = 15,
			Color = C.Text,
			Gap = 7,
			ZIndex = 2,
			Parent = b,
		})
		local press = make("UIScale", { Parent = b })
		b.MouseEnter:Connect(function()
			tween(glow, 0.18, { BackgroundTransparency = primary and 0.88 or 0.94 })
			if not primary then
				tween(b, 0.18, { BackgroundColor3 = HOVER })
			end
		end)
		b.MouseLeave:Connect(function()
			tween(glow, 0.22, { BackgroundTransparency = 1 })
			tween(press, 0.22, { Scale = 1 })
			if not primary then
				tween(b, 0.22, { BackgroundColor3 = C.Surface })
			end
		end)
		b.MouseButton1Down:Connect(function()
			tween(press, 0.08, { Scale = 0.96 }, Enum.EasingStyle.Quad)
		end)
		b.MouseButton1Up:Connect(function()
			tween(press, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		return b, label, glyph
	end
	local discord, discordLabel, discordGlyph = button("Join Discord", 0, false, "message-circle")
	local close = button("Close", half + 10, true, "x")

	-- "copied" line: opens by growing its height instead of popping in
	local status = make("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 6, Parent = card })
	local _, statusText, statusIcon = iconText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Icon = "clipboard-check",
		Parent = status,
	})
	statusText.TextTransparency = 1
	statusIcon.ImageTransparency = 1

	-- footer: who is playing + where ATLAS lives
	local footer = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 7, Parent = card })
	make("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Stroke, BorderSizePixel = 0, Parent = footer })
	iconText({ Position = UDim2.fromOffset(0, 12), Icon = "user", IconSize = 13, Text = "Playing as " .. Players.LocalPlayer.DisplayName, Height = 18, Gap = 5, Parent = footer })
	iconText({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 12), Icon = "globe", IconSize = 13, Text = SITE:gsub("^https?://", ""), Height = 18, Gap = 5, Parent = footer })

	-- Entrance -----------------------------------------------------------------------------
	local stagger = { logo, title, message }
	if row then
		table.insert(stagger, row)
	end
	table.insert(stagger, buttons)
	table.insert(stagger, footer)
	local hidden = {}
	for i, item in ipairs(stagger) do
		hidden[i] = hideAll(item)
	end

	-- warm up the icon images so they don't pop in after the card
	task.spawn(function()
		local images = {}
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("ImageLabel") and d.Image ~= "" then
				table.insert(images, d)
			end
		end
		table.insert(images, iconImage("check"))
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(images)
		end)
	end)

	gui.Parent = parent
	tween(backdrop, 0.4, { BackgroundTransparency = 0.45 }, Enum.EasingStyle.Quad)
	tween(card, 0.35, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
	tween(card, 0.5, { Position = UDim2.fromScale(0.5, 0.5) })
	tween(scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(border, 0.5, { Transparency = 0 }, Enum.EasingStyle.Quad)
	for i, saved in ipairs(hidden) do
		reveal(saved, 0.35, 0.12 + (i - 1) * 0.06)
	end
	task.delay(0.1, function()
		tween(markScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	-- Exit ---------------------------------------------------------------------------------
	local closing = false
	local function dismiss()
		if closing then
			return
		end
		closing = true
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				tween(d, 0.14, { TextTransparency = 1 }, Enum.EasingStyle.Quad)
			end
			if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
				tween(d, 0.14, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
			end
			if d:IsA("ImageLabel") then
				tween(d, 0.14, { ImageTransparency = 1 }, Enum.EasingStyle.Quad)
			end
			if d:IsA("UIStroke") then
				tween(d, 0.14, { Transparency = 1 }, Enum.EasingStyle.Quad)
			end
		end
		task.delay(0.06, function()
			tween(scale, 0.22, { Scale = 0.94 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(card, 0.22, { Position = UDim2.new(0.5, 0, 0.5, 10), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(backdrop, 0.26, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		end)
		task.delay(0.34, function()
			spin:Disconnect()
			gui:Destroy()
		end)
	end
	close.Activated:Connect(dismiss)

	local copiedAt = 0
	discord.Activated:Connect(function()
		local copy = (typeof(setclipboard) == "function" and setclipboard) or (typeof(toclipboard) == "function" and toclipboard)
		local copied = copy and pcall(copy, DISCORD)
		statusText.Text = copied and "Discord invite copied — paste it in your browser" or DISCORD
		if status.Size.Y.Offset < 18 then
			tween(status, 0.3, { Size = UDim2.new(1, 0, 0, 18) })
			tween(statusText, 0.3, { TextTransparency = 0 }, Enum.EasingStyle.Quad)
			tween(statusIcon, 0.3, { ImageTransparency = 0 }, Enum.EasingStyle.Quad)
		end
		if copied then
			-- the button confirms for a moment (check + "Copied"), then goes back
			local stamp = os.clock()
			copiedAt = stamp
			discordLabel.Text = "Copied"
			discordGlyph.Image = iconImage("check")
			task.delay(1.6, function()
				if copiedAt == stamp and discordLabel.Parent then
					discordLabel.TextTransparency = 1
					discordGlyph.ImageTransparency = 1
					discordLabel.Text = "Join Discord"
					discordGlyph.Image = iconImage("message-circle")
					tween(discordLabel, 0.25, { TextTransparency = 0 }, Enum.EasingStyle.Quad)
					tween(discordGlyph, 0.25, { ImageTransparency = 0 }, Enum.EasingStyle.Quad)
				end
			end)
		end
	end)
end

--// Loading card ------------------------------------------------------------------------
-- Shown from the moment the loader starts until the hub (or its key screen) is on screen.
-- Small, centred, doesn't dim the game. step() moves the bar to the next stage; between
-- stages it keeps creeping a little so it never looks frozen while the network works.

local function showLoading()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local parent
	pcall(function()
		parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
	end)
	parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = parent:FindFirstChild("ATLAS_Loading")
	if old then
		old:Destroy()
	end

	local W = 300
	local gui = make("ScreenGui", { Name = "ATLAS_Loading", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local card = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.fromOffset(W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { corner(14) })
	local scale = make("UIScale", { Scale = 0.92, Parent = card })
	local border = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	local sheen = make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.84),
			NumberSequenceKeypoint.new(0.42, 0.84),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.58, 0.84),
			NumberSequenceKeypoint.new(1, 0.84),
		}),
		Parent = border,
	})
	make("UIPadding", { PaddingTop = UDim.new(0, 24), PaddingBottom = UDim.new(0, 18), PaddingLeft = UDim.new(0, 24), PaddingRight = UDim.new(0, 24), Parent = card })
	make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

	-- logo
	local logo = make("Frame", { Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
	local mark = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, Parent = logo })
	local markScale = make("UIScale", { Scale = 0.55, Parent = mark })
	peak(mark, 36, C.Text)

	local title = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "ATLAS",
		FontFace = font(Enum.FontWeight.ExtraBold),
		TextSize = 17,
		TextColor3 = C.Text,
		TextTransparency = 1,
		LayoutOrder = 2,
		Parent = card,
	})
	local status = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = "Connecting to ATLAS",
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 13,
		TextColor3 = C.Muted,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 3,
		Parent = card,
	})

	-- progress bar: blue gradient fill with a light band running across it
	local track = make("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = C.Surface,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 4,
		Parent = card,
	}, { corner(2) })
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	}, {
		corner(2),
		make("UIGradient", { Color = ColorSequence.new(C.AccentA, Color3.fromRGB(70, 130, 255)) }),
	})
	local shine = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = fill })
	local band = make("UIGradient", {
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine,
	})

	-- footer: the game being loaded
	local footer = make("Frame", { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 5, Parent = card }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local gameIcon = make("ImageLabel", {
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = C.Stroke,
		BackgroundTransparency = 1,
		Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150",
		ImageTransparency = 1,
		LayoutOrder = 1,
		Parent = footer,
	}, { corner(4) })
	local gameName = make("TextLabel", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "This game",
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 12,
		TextColor3 = C.Muted,
		TextTransparency = 1,
		LayoutOrder = 2,
		Parent = footer,
	})
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)
		if ok and info and info.Name and gameName.Parent then
			gameName.Text = #info.Name > 34 and (info.Name:sub(1, 32) .. "…") or info.Name
		end
	end)

	-- bar motion: `shown` eases toward `target`; `target` creeps toward `cap` meanwhile
	local shown, target, cap = 0, 0, 0
	local baseText, dotsAt = status.Text, 0
	local finished = false
	local heartbeat = RunService.RenderStepped:Connect(function(dt)
		sheen.Rotation = (sheen.Rotation + dt * 60) % 360
		if not finished then
			target = math.min(target + dt * 0.02, cap)
		end
		shown += (target - shown) * math.min(1, dt * 7)
		fill.Size = UDim2.fromScale(shown, 1)
		dotsAt += dt
		if not finished then
			status.Text = baseText .. string.rep(".", math.floor(dotsAt * 2.5) % 4)
		end
	end)
	task.spawn(function()
		while gui.Parent do
			band.Offset = Vector2.new(-1, 0)
			tween(band, 1.1, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.6)
		end
	end)

	gui.Parent = parent
	tween(card, 0.35, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
	tween(card, 0.5, { Position = UDim2.fromScale(0.5, 0.5) })
	tween(scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(border, 0.5, { Transparency = 0 }, Enum.EasingStyle.Quad)
	task.delay(0.08, function()
		tween(markScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	task.delay(0.14, function()
		tween(title, 0.35, { TextTransparency = 0 }, Enum.EasingStyle.Quad)
		tween(status, 0.35, { TextTransparency = 0 }, Enum.EasingStyle.Quad)
		tween(track, 0.35, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
		tween(gameName, 0.35, { TextTransparency = 0 }, Enum.EasingStyle.Quad)
		tween(gameIcon, 0.35, { ImageTransparency = 0, BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
	end)

	local api = {}
	local closed = false
	local function fadeOut(delay)
		if closed then
			return
		end
		closed = true
		task.delay(delay or 0, function()
			for _, d in ipairs(card:GetDescendants()) do
				if d:IsA("TextLabel") then
					tween(d, 0.16, { TextTransparency = 1 }, Enum.EasingStyle.Quad)
				end
				if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
					tween(d, 0.16, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
				end
				if d:IsA("ImageLabel") then
					tween(d, 0.16, { ImageTransparency = 1 }, Enum.EasingStyle.Quad)
				end
			end
			tween(border, 0.2, { Transparency = 1 }, Enum.EasingStyle.Quad)
			tween(card, 0.22, { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -8) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(scale, 0.22, { Scale = 0.96 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.26, function()
				heartbeat:Disconnect()
				gui:Destroy()
			end)
		end)
	end

	-- move to a new stage: `frac` is where the bar goes, `nextFrac` how far it may creep
	function api.step(text, frac, nextFrac)
		baseText = text
		target = math.max(target, frac)
		cap = math.max(cap, nextFrac or math.min(frac + 0.15, 0.95))
	end
	-- the hub is on screen: fill the bar, say so, fade out
	function api.done()
		if finished then
			return
		end
		finished = true
		target, cap = 1, 1
		status.Text = "Ready"
		fadeOut(0.2)
	end
	-- something went wrong: get out of the way at once (the message card takes over)
	function api.close()
		finished = true
		fadeOut(0)
	end
	return api
end

-- A stable id for this PC (for the site's unique-user count).
local function deviceId()
	local hwid = env.gethwid or (typeof(gethwid) == "function" and gethwid)
	if hwid then
		local ok, value = pcall(hwid)
		if ok and value then
			return tostring(value)
		end
	end
	local ok, value = pcall(function()
		return game:GetService("RbxAnalyticsService"):GetClientId()
	end)
	return ok and tostring(value) or ""
end

local function requestFn()
	return (typeof(request) == "function" and request)
		or (typeof(http_request) == "function" and http_request)
		or (syn and syn.request)
		or (http and http.request)
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local send = requestFn()
if not send then
	return showCard({ Title = "Executor not supported", Icon = "plug-zap", Message = "Your executor has no HTTP request function, so ATLAS can't reach its server. Try another executor." })
end

loading = showLoading()
loading.step("Connecting to ATLAS", 0.12, 0.45)

-- Cada pedido ao site gasta ~1 s só de conexão. Em vez de o script do jogo baixar a NOIR e
-- conferir a key depois, o loader dispara os dois agora, junto com o pedido do script.
-- O script do jogo pega o resultado em ATLAS_PREFETCH (e espera se ainda não chegou).
local prefetch = {}
env.ATLAS_PREFETCH = prefetch

-- Cópia local da NOIR: o site diz qual versão está publicada (lib_version) e o loader só
-- baixa de novo quando ela muda. Sem cópia, baixa já, em paralelo com o pedido do script.
local CACHE, CACHE_VERSION = "ATLAS/NOIR.lua", "ATLAS/NOIR.version"
local hasFiles = typeof(isfile) == "function" and typeof(readfile) == "function" and typeof(writefile) == "function"
local cached = false
pcall(function()
	cached = hasFiles and isfile(CACHE) and isfile(CACHE_VERSION)
end)
local function downloadNoir()
	local okNoir, body = pcall(function()
		return game:HttpGet(SITE .. "/lib/NOIR.lua?token=" .. TOKEN)
	end)
	prefetch.noir = (okNoir and type(body) == "string" and body:find("return Library", 1, true)) and body or false
end
local function saveNoir(version)
	if not hasFiles or not version or version == "" then
		return
	end
	task.spawn(function()
		while prefetch.noir == nil do
			task.wait()
		end
		if type(prefetch.noir) == "string" then
			pcall(function()
				if typeof(isfolder) == "function" and not isfolder("ATLAS") then
					makefolder("ATLAS")
				end
				writefile(CACHE, prefetch.noir)
				writefile(CACHE_VERSION, version)
			end)
		end
	end)
end
if not cached then
	task.spawn(downloadNoir)
end
local savedKey
pcall(function()
	if typeof(isfile) == "function" and isfile("NOIR/key.txt") then
		savedKey = readfile("NOIR/key.txt"):gsub("^%s+", ""):gsub("%s+$", "")
	end
end)
if savedKey and savedKey ~= "" then
	prefetch.key = { key = savedKey }
	task.spawn(function()
		local okKey, res = pcall(send, {
			Url = SITE .. "/api/v1/validate",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json", ["X-ATLAS-Token"] = TOKEN },
			Body = HttpService:JSONEncode({ key = savedKey, hwid = deviceId() }),
		})
		local decoded, data = false, nil
		if okKey and res and res.Body then
			decoded, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
		end
		if decoded and type(data) == "table" then
			prefetch.key.valid = data.valid == true
			prefetch.key.message = data.message
			prefetch.key.type = data.type -- "paid" | "free": libera recursos pagos no script
		end
		prefetch.key.done = true
	end)
end

local ok, response = pcall(send, {
	Url = SITE .. "/api/v1/script",
	Method = "POST",
	Headers = { ["Content-Type"] = "application/json", ["X-ATLAS-Token"] = TOKEN },
	Body = HttpService:JSONEncode({
		place_id = tostring(game.PlaceId),
		game_id = tostring(game.GameId),
		hwid = deviceId(),
	}),
})
if not ok or not response or not response.Body then
	return showCard({ Title = "Can't reach ATLAS", Icon = "wifi-off", Message = "The ATLAS server didn't answer. Check your connection and try again in a moment." })
end

local decoded, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
if not decoded or type(data) ~= "table" then
	return showCard({ Title = "Something went wrong", Icon = "circle-alert", Message = "The ATLAS server sent an unexpected answer. Try again in a moment." })
end

-- NOIR: usa a cópia local se a versão bate; senão baixa (e guarda a nova versão).
local libVersion = type(data.lib_version) == "string" and data.lib_version or nil
if cached then
	local cachedVersion
	pcall(function()
		cachedVersion = readfile(CACHE_VERSION)
	end)
	if libVersion and cachedVersion == libVersion then
		local okRead, body = pcall(readfile, CACHE)
		prefetch.noir = (okRead and type(body) == "string" and body:find("return Library", 1, true)) and body or nil
	end
	if prefetch.noir == nil then
		task.spawn(downloadNoir)
		saveNoir(libVersion)
	end
else
	saveNoir(libVersion)
end

if not data.found then
	return showCard({ Title = "Game not supported", Icon = "gamepad-2", Message = "ATLAS doesn't support this game yet. Join our Discord to see the supported games and request new ones.", ShowGame = true })
end
if data.enabled == false then
	return showCard({ Title = "Script paused", Icon = "circle-pause", Message = data.message or "This script is paused right now. Check our Discord for updates.", ShowGame = true })
end
if type(data.source) ~= "string" or data.source == "" then
	return showCard({ Title = "Coming soon", Icon = "hourglass", Message = "The " .. (data.name or "script") .. " script isn't ready yet. Check our Discord for updates.", ShowGame = true })
end

-- Tell the player a paid version exists, when the site says so.
if data.has_paid then
	notify("A paid version of " .. (data.name or "this script") .. " is available" .. (data.paid_note ~= "" and (": " .. data.paid_note) or "."))
end

loading.step("Loading " .. (data.name or "script"), 0.5, 0.7)
local chunk, err = loadstring(data.source, "=ATLAS/" .. (data.name or "script"))
if not chunk then
	return showCard({ Title = "Script error", Icon = "code-xml", Message = "The script for this game failed to load. Report it in our Discord.\n" .. tostring(err) })
end

-- Run the game script and keep the loading card up until its window (or key screen) shows.
-- An older hub may still be on screen for a moment, so wait for a NEW "NOIR" interface.
loading.step("Loading interface", 0.72, 0.95)
local hui
pcall(function()
	hui = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
end)
local previous = hui and hui:FindFirstChild("NOIR")
local failed = false
task.spawn(function()
	local ran, runError = pcall(chunk)
	if not ran then
		failed = true
		showCard({ Title = "Script error", Icon = "code-xml", Message = "The script for this game stopped while loading. Report it in our Discord.\n" .. tostring(runError) })
	end
end)
task.spawn(function()
	local started = os.clock()
	while loading and not failed and os.clock() - started < 30 do
		local current = hui and hui:FindFirstChild("NOIR")
		if current and current ~= previous and (current:FindFirstChild("KeySystem", true) or current:FindFirstChild("Window", true)) then
			break
		end
		task.wait(0.1)
	end
	if loading and not failed then
		loading.done()
		loading = nil
	end
end)
