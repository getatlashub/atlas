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
	return notify("Your executor has no HTTP request function.")
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
	return notify("Could not reach the ATLAS site.")
end

local decoded, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
if not decoded or type(data) ~= "table" then
	return notify("The ATLAS site sent a bad answer.")
end

if not data.found then
	return notify(data.message or "This game is not supported yet.")
end
if data.enabled == false then
	return notify(data.message or "This script is paused right now.")
end
if type(data.source) ~= "string" or data.source == "" then
	return notify("No code is set for " .. (data.name or "this game") .. " yet.")
end

-- Tell the player a paid version exists, when the site says so.
if data.has_paid then
	notify("A paid version of " .. (data.name or "this script") .. " is available" .. (data.paid_note ~= "" and (": " .. data.paid_note) or "."))
end

local chunk, err = loadstring(data.source, "=ATLAS/" .. (data.name or "script"))
if not chunk then
	return notify("Script error: " .. tostring(err))
end
chunk()
