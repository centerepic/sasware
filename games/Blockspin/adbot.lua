local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local PlaceId = game.PlaceId
local JobId = game.JobId
local Players = game:GetService("Players")

local Messages = {
	"saswaresoftworks is so pasted it made me crash my NEW WHIP! 🚗",
	"guys... u should get sasware it gives you SO MUCH MONEY 💸",
	"sasware #1 softwarez for blockspin... get now 🤑",
	"i just 💰 got 7 ZILLION dollars from sasware",
	"my grandma got me sasware and now i have NO surviving opps 👵",
	"sasware made my father come back 🥛",
	"sasware softworks LLC supported by Microsoft Windows 12 🪟",
	"sasware has best autofarm... made me crash my brand new whip.",
	"GET #1 BLOCKCHAIN SOFTWARE SASWARE SOFTWORKS LLC CHEAT WORK 2025",
	"get sasware and never miss a shot again.",
	"is your aim terrible? get sasware.",
	"dont get good, get sasware.",
	"sasguard protects my p2c and sasware gives me infinite money in blockspin",
	"the sasware engine upgrade service made my civic hit mach 5... get now",
	"sasware softworks llc is the best \"funny boxes\" provider for blockspin.",
	"riftcore blew up my old whip sasware bought me a new one",
	"get the only f2c that david baszucki approves: sasware",
	"i got sasware and now i have 20 RDC invitations in my inbox",
}

local Senders = {
	"[Blockspin Announcements]: ",
	"[Roblox]: ",
	"[sasware]: ",
	"[Builderman]: ",
	"[1x1x1x1]: ",
	"[Sasware]: ",
	"[Sasware Softworks]: ",
	"[david.baszucki]: ",
	"[your father]: ",
	"[Saint Von the III]: ",
	"[System]: ",
	"[JackCinnamon]: ",
}

for i = math.random(2, 5), 0, -1 do
	TextChatService.TextChannels.RBXGeneral:SendAsync(
		`.\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r{Senders[math.random(1, #Senders)]}{Messages[math.random(1,#Messages)]}`
	)
	task.wait(2.5)
end

queue_on_teleport(game:HttpGet("https://raw.githubusercontent.com/centerepic/sasware/refs/heads/main/games/Blockspin/adbot.lua", true))

while task.wait(3) do

    task.spawn(function()
        pcall(function()
            GuiService:ClearError()
        end)
    end)

    task.spawn(function()
        pcall(function()
            local servers = {}
            local req = httprequest({Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", PlaceId)})
            local body = HttpService:JSONDecode(req.Body)

            if body and body.data then
                for i, v in next, body.data do
                    if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= JobId then
                        table.insert(servers, 1, v.id)
                    end
                end
            end

            if #servers > 0 then
                TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], Players.LocalPlayer)
            end
        end)
    end)
end
