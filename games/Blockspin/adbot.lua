local TeleportService = cloneref(game:GetService('TeleportService'))
local HttpService = cloneref(game:GetService('HttpService'))

local ServerHop = {}
do
    ServerHop._history = {}
    ServerHop._servers = {}
    ServerHop._base_url = 'https://games.roproxy.com/v2/games/%s/servers/public?limit=100'
    ServerHop._cursor = ''

    function ServerHop:init()
        self:load_history_from_cache()
        self:load_server_list()
    end

    function ServerHop:load_history_from_cache()
        if not TeleportService:GetTeleportSetting('RoBeats.ServerHistory') then
            return
        end
        self._history = HttpService:JSONDecode(TeleportService:GetTeleportSetting('RoBeats.ServerHistory'))
    end

    function ServerHop:clear_server_history()
        table.clear(self._history)
        TeleportService:SetTeleportSetting('RoBeats.ServerHistory', HttpService:JSONEncode(self._history))
    end

    function ServerHop:process_server_list()
        local success, result = pcall(game.HttpGet, game, string.format(self._base_url, game.PlaceId, self._cursor))
        if not success then
            warn(string.format('ServerHop:process_server_list success false Err(%s)', result))
            task.wait(10)
            return self:process_server_list()
        end

        local success, decoded = pcall(HttpService.JSONDecode, HttpService, result)
        if not success then
            warn(string.format('ServerHop:process_server_list JSONDecode success false Err(%s)', result))
            task.wait(10)
            return self:process_server_list()
        end

        if type(decoded.data) ~= 'table' then
            warn(string.format('ServerHop:process_server_list decoded.data invalid type (%s) resp(%s)', type(decoded.data), tostring(result)))
            task.wait(10)
            return self:process_server_list()
        end

        local function processServer(server)
            if type(server.playing) ~= 'number' then return end 
            if type(server.maxPlayers) ~= 'number' then return end 
            if type(server.id) ~= 'string' then return end

            table.insert(self._servers, server)
        end

        for _, server in decoded.data do
            processServer(server)
        end

        if decoded.nextPageCursor == nil then
            return self._servers
        end

        self._cursor = decoded.nextPageCursor
        return self:process_server_list()
    end

    function ServerHop:load_server_list()
        if isfile('server-list.json') then
            local success, decoded = pcall(function()
                return HttpService:JSONDecode(readfile('server-list.json'))
            end)
    
            if success and decoded and decoded.servers and type(decoded.servers) == "table" and decoded.timestamp then
                if os.time() - decoded.timestamp <= 120 then
                    self._servers = decoded.servers
                    return
                end
            end
        end
    
        self:process_server_list()
        writefile('server-list.json', HttpService:JSONEncode({
            servers = self._servers,
            timestamp = os.time()
        }))
    end
    

    function ServerHop:find_server()
        local available_servers = table.clone(self._servers)
        for i = #available_servers, 1, -1 do
            local server = available_servers[i]
            if table.find(self._history, server.id) then
                table.remove(available_servers, i)
            end
        end

        if #available_servers == 0 then
            return false, 'No servers left' 
        end

        if Nexus then
            Nexus:Log(string.format('Account[%s] AvailableServers[%d]', game.Players.LocalPlayer.Name, #available_servers))
        end

        local server = table.remove(available_servers, math.random(1, #available_servers))
        return true, server
    end
    
    function ServerHop:teleport_to_server(server)
        table.insert(self._history, server.id)
        TeleportService:SetTeleportSetting('RoBeats.ServerHistory', HttpService:JSONEncode(self._history))
        while true do
            task.wait(1)
            
            local sc, err = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, server.id)
            if sc then break end
        end
    end
end

local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
local TextChatService = game:GetService("TextChatService")
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
	task.wait(3)
end

queue_on_teleport(game:HttpGet("https://raw.githubusercontent.com/centerepic/sasware/refs/heads/main/games/Blockspin/adbot.lua", true))

while task.wait(math.random(5, 10)) do
    pcall(function()
        ServerHop:init()
        local paste, server = ServerHop:find_server()
        ServerHop:teleport_to_server(server)
    end)
end
