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
local DISCORD = "https://discord.gg/your-invite" -- copied by the "Join Discord" button

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
local function tween(inst, t, goal)
	local tw = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
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

-- options: Title, Message, ShowGame (bool: show the current game's icon and name)
local function showCard(options)
	warn("[ATLAS] " .. tostring(options.Title) .. " — " .. tostring(options.Message))
	local parent
	pcall(function()
		parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
	end)
	parent = parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local old = parent:FindFirstChild("ATLAS_Loader")
	if old then
		old:Destroy()
	end

	local W = 380
	local gui = make("ScreenGui", { Name = "ATLAS_Loader", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local backdrop = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Active = true, Parent = gui })
	local card = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Background,
		Parent = gui,
	}, { corner(14), stroke(C.Stroke) })
	local scale = make("UIScale", { Scale = 0.94, Parent = card })
	make("UIPadding", { PaddingTop = UDim.new(0, 28), PaddingBottom = UDim.new(0, 24), PaddingLeft = UDim.new(0, 26), PaddingRight = UDim.new(0, 26), Parent = card })
	make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

	-- logo (bare white mark, like the key screen)
	local logo = make("Frame", { Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
	peak(logo, 44, C.Text)

	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = options.Title or "ATLAS",
		FontFace = font(Enum.FontWeight.ExtraBold),
		TextSize = 20,
		TextColor3 = C.Text,
		LayoutOrder = 2,
		Parent = card,
	})
	make("TextLabel", {
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

	-- the current game: icon + name + place id
	if options.ShowGame then
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.Surface, LayoutOrder = 4, Parent = card }, { corner(10), stroke(C.Stroke) })
		make("ImageLabel", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = C.Stroke,
			Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150",
			Parent = row,
		}, { corner(8) })
		local name = make("TextLabel", {
			Position = UDim2.fromOffset(54, 9),
			Size = UDim2.new(1, -62, 0, 18),
			BackgroundTransparency = 1,
			Text = "This game",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = font(Enum.FontWeight.Bold),
			TextSize = 14,
			TextColor3 = C.Text,
			Parent = row,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(54, 27),
			Size = UDim2.new(1, -62, 0, 16),
			BackgroundTransparency = 1,
			Text = "Place " .. tostring(game.PlaceId),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = font(Enum.FontWeight.SemiBold),
			TextSize = 13,
			TextColor3 = C.Muted,
			Parent = row,
		})
		task.spawn(function()
			local ok, info = pcall(function()
				return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
			end)
			if ok and info and info.Name and name.Parent then
				name.Text = info.Name
			end
		end)
	end

	-- buttons
	local buttons = make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 5, Parent = card })
	make("UIPadding", { PaddingTop = UDim.new(0, 4), Parent = buttons })
	local half = (W - 52 - 10) / 2
	local function button(text, x, primary)
		local b = make("TextButton", {
			Position = UDim2.fromOffset(x, 4),
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
		make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = text,
			FontFace = font(Enum.FontWeight.Bold),
			TextSize = 15,
			TextColor3 = C.Text,
			ZIndex = 2,
			Parent = b,
		})
		b.MouseEnter:Connect(function()
			tween(b, 0.15, { BackgroundTransparency = 0.12 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.15, { BackgroundTransparency = 0 })
		end)
		return b
	end
	local discord = button("Join Discord", 0, false)
	local close = button("Close", half + 10, true)

	local status = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		Visible = false,
		TextWrapped = true,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 13,
		TextColor3 = C.Muted,
		LayoutOrder = 6,
		Parent = card,
	})

	local closing = false
	local function dismiss()
		if closing then
			return
		end
		closing = true
		tween(backdrop, 0.2, { BackgroundTransparency = 1 })
		tween(scale, 0.2, { Scale = 0.94 })
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				tween(d, 0.18, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tween(d, 0.18, { Transparency = 1 })
			end
		end
		tween(card, 0.2, { BackgroundTransparency = 1 })
		task.delay(0.22, function()
			gui:Destroy()
		end)
	end
	close.Activated:Connect(dismiss)
	discord.Activated:Connect(function()
		local copy = (typeof(setclipboard) == "function" and setclipboard) or (typeof(toclipboard) == "function" and toclipboard)
		status.Visible = true
		if copy and pcall(copy, DISCORD) then
			status.Text = "Discord invite copied — paste it in your browser"
		else
			status.Text = DISCORD
		end
	end)

	gui.Parent = parent
	tween(backdrop, 0.3, { BackgroundTransparency = 0.45 })
	tween(scale, 0.35, { Scale = 1 })
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
	return showCard({ Title = "Executor not supported", Message = "Your executor has no HTTP request function, so ATLAS can't reach its server. Try another executor." })
end

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
	return showCard({ Title = "Can't reach ATLAS", Message = "The ATLAS server didn't answer. Check your connection and try again in a moment." })
end

local decoded, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
if not decoded or type(data) ~= "table" then
	return showCard({ Title = "Something went wrong", Message = "The ATLAS server sent an unexpected answer. Try again in a moment." })
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
	return showCard({ Title = "Game not supported", Message = "ATLAS doesn't support this game yet. Join our Discord to see the supported games and request new ones.", ShowGame = true })
end
if data.enabled == false then
	return showCard({ Title = "Script paused", Message = data.message or "This script is paused right now. Check our Discord for updates.", ShowGame = true })
end
if type(data.source) ~= "string" or data.source == "" then
	return showCard({ Title = "Coming soon", Message = "The " .. (data.name or "script") .. " script isn't ready yet. Check our Discord for updates.", ShowGame = true })
end

-- Tell the player a paid version exists, when the site says so.
if data.has_paid then
	notify("A paid version of " .. (data.name or "this script") .. " is available" .. (data.paid_note ~= "" and (": " .. data.paid_note) or "."))
end

local chunk, err = loadstring(data.source, "=ATLAS/" .. (data.name or "script"))
if not chunk then
	return showCard({ Title = "Script error", Message = "The script for this game failed to load. Report it in our Discord.\n" .. tostring(err) })
end
chunk()
