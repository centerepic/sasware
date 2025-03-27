--!native
--!nolint BuiltinGlobalWrite
--!nolint UnknownGlobal

local DEBUGGING = false
local USERCONSOLE = true
local HOOKING_ENABLED = true

local Version = "1.0.0"
local SubVersion = " | BETA"
local HIDN = 0

_G.__HOOK_KEY = ""
_G.__ORIGINAL_KEY = ""

if not (rconsolecreate and rconsolesettitle) then
	USERCONSOLE = false
end

if USERCONSOLE then
	rconsolesettitle("Sasware Debugger")
	rconsolecreate()
end

--#region Initializing core functionality

-- Generates a unique hook ID for hooks with same name
local function GHID()
	HIDN += 1
	return HIDN
end

local function G_Toggle(ToggleName : string) : boolean

	if not getgenv().Library then
		repeat wait() until getgenv().Library
	end

	if not getgenv().Library.Toggles then
		repeat wait() until getgenv().Library.Toggles
	end

	if not getgenv().Library.Toggles[ToggleName] then
		repeat wait() until getgenv().Library.Toggles[ToggleName]
	end

	return getgenv().Library.Toggles[ToggleName].Value
end

local function G_Option(OptionName : string) : any

	if not getgenv().Library then
		repeat wait() until getgenv().Library
	end

	if not getgenv().Library.Options then
		repeat wait() until getgenv().Library.Options
	end

	if not getgenv().Library.Options[OptionName] then
		repeat wait() until getgenv().Library.Options[OptionName]
	end

	return getgenv().Library.Options[OptionName].Value
end

local function HookSwitch(Hooking : (...any) -> ...any, NoHooking : (...any) -> ...any)
	if HOOKING_ENABLED then
		return Hooking()
	else
		return NoHooking()
	end
end

local function Stringify(Values : {any}) : {string}
	local Stringified = {}
	for Index, Value in next, Values do
		table.insert(Stringified, tostring(Value))
	end
	return Stringified
end

local function flen(Table) : number
	local Count = 0
	for _ in next, Table do
		Count += 1
	end
	return Count
end

local function dbgprint(...)
	if DEBUGGING then
		if USERCONSOLE then
			rconsoleprint("[DEBUGGING] " .. table.concat(Stringify({...}), " "))
		else
			dbgprint("[DEBUGGING]", ...)
		end
	end
end

local function dbgwarn(...)
	if DEBUGGING then
		if USERCONSOLE then
			rconsolewarn("[DEBUGGING] " .. table.concat(Stringify({...}), " "))
		else
			warn("[DEBUGGING]", ...)
		end
	end
end

local function sprint(...)
	if USERCONSOLE then
		rconsoleprint("[SASWARE] " .. table.concat(Stringify({...}), " "))
	else
		dbgprint("[SASWARE]", ...)
	end
end

local function swarn(...)
	if USERCONSOLE then
		rconsolewarn("[SASWARE] " .. table.concat(Stringify({...}), " ") .. "\n")
	else
		warn("[SASWARE]", ...)
	end
end

local function ssuccess(...)
	if USERCONSOLE then
		rconsoleinfo("[SASWARE] " .. table.concat(Stringify({...}), " ") .. "\n")
	else
		dbgprint("[SASWARE]", ...)
	end
end

local function flen(Table) : number
	local Count = 0
	for _ in next, Table do
		Count += 1
	end
	return Count
end

local function mfind(Table, ...) : boolean
	local Values = {...}

	for _, Value in next, Values do
		if not table.find(Table, Value) then
			return false
		end
	end

	return true
end

--#endregion

--#region Checking executor environment

---@diagnostic disable-next-line: undefined-global
if not (hookfunction and hookmetamethod and isexecutorclosure and getgc and debug and restorefunction) then
	HOOKING_ENABLED = false
	swarn("Hooking is disabled due to the executor environment not supporting it.")
end

--#endregion

--#region Cleanup library

local Cleaner = {
	Registry = {},
	AllowedTypes = {
		["RBXScriptConnection"] = true,
		["Instance"] = true,
		["table"] = true,
		["function"] = true,
		["thread"] = true
	},
	CleanEvent = Instance.new("BindableEvent")
}

function Cleaner.Register(Object : any)
	if not Cleaner.AllowedTypes[typeof(Object)] then
		swarn("Attempted to register an invalid object type:", typeof(Object))
		return
	end

	if Cleaner.Registry[Object] then
		swarn("Object is already registered for cleanup:", Object)
		return
	end

	Cleaner.Registry[Object] = true
end

function Cleaner.Clean()
	dbgprint("Cleaning up", flen(Cleaner.Registry), "objects.")
	for Object, _ in next, Cleaner.Registry do
		if typeof(Object) == "RBXScriptConnection" then
			Object:Disconnect()
		elseif typeof(Object) == "Instance" then
			Object:Destroy()
		elseif type(Object) == "table" then
			for Index, Value in next, Object do
				Object[Index] = nil
			end
		elseif type(Object) == "function" then
			Object()
		elseif type(Object) == "thread" then
			coroutine.close(Object)
		end

		Cleaner.Registry[Object] = nil
	end
	Cleaner.CleanEvent:Fire()
end

function Cleaner.GetCleanEvent()
	return Cleaner.CleanEvent.Event
end

setmetatable(Cleaner, {
	__call = function(self, Object : any)
		self.Register(Object)
		return Object
	end
})

--#endregion

--#region Hooking library

local HookMgr = {
	Registry = {},
	GameMT = getrawmetatable(game),
}

HookMgr.RegisterHook = function(HookName : string, FunctionReference : (...any) -> (...any), Hook : (Original : (...any) -> (...any), ...any) -> (...any)) : {Original : (...any) -> (...any), Reference : (...any) -> (...any)}
	local OriginalFunction : (...any) -> (...any)

	if HOOKING_ENABLED then
		local HookKey = "HookMgr_Hook_" .. HookName
		local OriginalKey = "HookMgr_Original_" .. HookName
		
		shared.HookRegistry = shared.HookRegistry or {}
		
		-- _G.__HOOK_KEY = HookKey
		-- _G.__ORIGINAL_KEY = OriginalKey
		
		shared.HookRegistry[HookKey] = Hook

		local Success, Error = pcall(function()

			-- function __HookWrapper(...)
			-- 	return shared.HookRegistry[_G.__HOOK_KEY]( shared.HookRegistry[_G.__ORIGINAL_KEY], ... )
			-- end			

			-- dbgprint(`return shared.HookRegistry["{HookKey}"]( shared.HookRegistry["{OriginalKey}"], ... )`)
			-- dbgprint(`return function(...) return shared.HookRegistry["{HookKey}"]( shared.HookRegistry["{OriginalKey}"], ... ) end`)

			OriginalFunction = hookfunction(FunctionReference, loadstring(`return function(...) return shared.HookRegistry["{HookKey}"]( shared.HookRegistry["{OriginalKey}"], ... ) end`)())
		end)

		if not Success then
			swarn("Failed to hook function:", HookName, "Error:", Error)
		end

		local RegistryEntry = HookMgr.Registry[HookName]
		if RegistryEntry then
			restorefunction(RegistryEntry.Reference)
			swarn("Hook for function", HookName, "already exists. Overriding.")
		end

		shared.HookRegistry[OriginalKey] = OriginalFunction
	else
		swarn("Hooking is disabled. Skipping hook for function:", HookName)
	end

	HookMgr.Registry[HookName] = {
		Original = OriginalFunction or FunctionReference,
		Reference = FunctionReference
	}

	return HookMgr.Registry[HookName]
end

HookMgr.UnregisterHook = function(HookName : string)
	if HOOKING_ENABLED then
		local RegistryEntry = HookMgr.Registry[HookName]

		if RegistryEntry then
			local Success, Error = pcall(function()
				restorefunction(RegistryEntry.Reference)
			end)

			if not Success then
				swarn("Failed to unhook function:", HookName, "Error:", Error)
			end
		else
			swarn("Hook for function", HookName, "does not exist.")
		end
	else
		swarn("Hooking is disabled. Skipping unhook for function:", HookName)
	end

	HookMgr.Registry[HookName] = nil
end

HookMgr.ClearHooks = function()
	if HOOKING_ENABLED then
		dbgprint("Clearing", flen(HookMgr.Registry), "hooks.")
		for HookName, RegistryEntry in next, HookMgr.Registry do
			local Success, Error = pcall(function()
				restorefunction(RegistryEntry.Reference)
			end)

			if not Success then
				swarn("Failed to unhook function:", HookName, "Error:", Error)
			end
		end
	else
		swarn("Hooking is disabled. Skipping clearing hooks.")
	end

	HookMgr.Registry = {}
end

--#endregion

--#region ConnectionProxyManager library

local ConnectionProxyMgr = {
	Registry = {},
	Id = 0
}

function ConnectionProxyMgr._requestId()
	ConnectionProxyMgr.Id += 1
	return ConnectionProxyMgr.Id
end

function ConnectionProxyMgr._newProxyHandler(ConnectionProxy)

	local Id = ConnectionProxyMgr._requestId()

	local Handler = {
		Proxy = ConnectionProxy,
		Enabled = true,
		ClearSignal = Instance.new("BindableEvent"),
	}

	function Handler:Disable()
		self.Enabled = false
		self.Proxy:Disable()
	end

	function Handler:Enable()
		self.Enabled = true
		self.Proxy:Enable()
	end

	Handler.ClearSignal.Event:Once(function()
		pcall(function()
			Handler.Proxy:Enable()
			ConnectionProxyMgr.Registry[Id] = nil
		end)
	end)

	ConnectionProxyMgr.Registry[Id] = Handler

	return Handler
end

function ConnectionProxyMgr:Register(ConnectionProxy)
	return ConnectionProxyMgr._newProxyHandler(ConnectionProxy)
end

function ConnectionProxyMgr:Clear()
	for _, Handler in next, ConnectionProxyMgr.Registry do
		Handler.ClearSignal:Fire()
	end
end

function ConnectionProxyMgr:YieldForConnection(Signal : RBXScriptSignal, SourceNeedle : string, Timeout : number?)
	local Start = os.clock()

	while task.wait() do

		local Connections = getconnections(Signal) :: {any} -- linter thinks it returns connections instead of proxies
		for _, Connection in next, Connections do
			local Function = Connection.Function
			if Function then
				if debug.info(Function, "s"):match(SourceNeedle) then
					return Connection
				end
			end
		end
		
		if Timeout and os.clock() - Start >= Timeout then
			return nil
		end

	end

	return nil

end
--#endregion

--#region ESP library

local ESP_Library

do
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera
	
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		Camera = workspace.CurrentCamera
	end)
	
	local ESP = {
		Config = {
			Enabled = false,
			TeamCheck = false,
			Players = false,
			Boxes = false,
			Text = false,
			BoxType = "3DFull",
			BoxSize = Vector3.new(4, 6, 2),
			StaticSize = Vector2.new(20, 60),
			BoxColor = Color3.fromRGB(255, 255, 255),
			TextColor = Color3.fromRGB(255, 255, 255),
			UseTeamColor = false,
			MaxDistance = 500,
			FadeDistance = 100,
		}
	}
	
	-- Collection Library
	local Collection = {}
	local RenderQueue = {}
	
	local function Collect(Item : RBXScriptConnection | thread)
		table.insert(Collection, Item)
	end
	
	local function Unload()

		for _, Item in next, Collection do
			if typeof(Item) == "RBXScriptConnection" then
				Item:Disconnect()
			end
			if type(Item) == "thread" then
				coroutine.close(Item)
			end
		end

		for Index, Box in next, RenderQueue do
			Box:Destroy()
			RenderQueue[Index] = nil
		end

	end
	
	local function Cleanup(Item : any)
		if typeof(Item) == "Instance" then
			Item:Destroy()
			return
		end
		if typeof(Item) == "RBXScriptConnection" then
			Item:Disconnect()
			return
		end
		if type(Item) == "thread" then
			coroutine.close(Item)
			return
		end
		if type(Item) == "table" then
			for Index, Value in pairs(Item) do
				Cleanup(Value)
			end
			table.clear(Item)
			return
		end
		pcall(function()
			Item:Remove()
			return
		end)
	end
	
	-- Function Setup
	
	local function Distance(Position : Vector3)
		return (Position - Camera.CFrame.Position).Magnitude
	end
	
	local function ToV2(Vector : Vector3) : Vector2
		return Vector2.new(Vector.X, Vector.Y)
	end
	
	local function WTVP(Position : Vector3) : (Vector3, boolean)
		return Camera:WorldToViewportPoint(Position)
	end
	
	local function WTVP2D(Position : Vector3) : Vector2
		local ScreenPosition, _ = Camera:WorldToViewportPoint(Position)
		local Vector = ToV2(ScreenPosition)
		return Vector
	end
	
	local function EnsureInstance(Instance : Instance)
		if not Instance then
			return false
		end
		if Instance.Parent == nil then
			return false
		end
		if not Instance:IsDescendantOf(workspace) then
			return false
		end
		return true
	end
	
	local function GetPlayer(Character : Model) : Player?
		return Players:GetPlayerFromCharacter(Character)
	end
	
	local function GetColor(Model : Model, Box : any) : Color3
		
		if Box.IsPlayer then
			if ESP.Config.UseTeamColor then
				local Player = GetPlayer(Model)
				if Player then
					return Player.TeamColor.Color
				end
			end
		end

		if Box.DynamicColor then
			return Box.DynamicColor(Model)
		elseif Box.BoxColor then
			return Box.BoxColor
		end

		return ESP.Config.BoxColor
	end
	
	local function CalculateTransparency(Distance : number) : number
		local MaxDistance = ESP.Config.MaxDistance
		local FadeDistance = ESP.Config.FadeDistance
		
		if Distance >= MaxDistance then
			return 0
		elseif Distance > (MaxDistance - FadeDistance) then
			return 1 - (Distance - (MaxDistance - FadeDistance)) / FadeDistance
		else
			return 1
		end
	end
	
	local function CreateBox(Root : PVInstance, Config : {any})
		local Box = {
			Root = Root,
			BoxType = ESP.Config.BoxType,
			DynamicColor = nil,
			DrawingObject = nil,
			TextObject = nil,
			Color = nil,
			IsPlayer = false
		}

		assert(Box.Root.Parent and Box.Root.Parent:IsA("Model"), "Root must be a descendant of a Model")
		
		if Config then
			for Index, Value in Config do
				Box[Index] = Value
			end
		end
		
		Box.BoxColor = GetColor(Box.Root.Parent, Box)

		function Box:GetPivot() : CFrame
			local Pos, _ = Box.Root.Parent:GetBoundingBox() :: CFrame, Vector3
			return Pos
		end

		local function GetScreen(Model : Model)
			local Pivot = Model:GetPivot()
			local Position = Pivot.Position
			local ScreenPosition, Visible = WTVP(Position)
			return ScreenPosition, Visible
		end

		local function Create2DBox()
			local Drawing = Drawing.new("Quad")
			local DrawingObject = {
				Drawing = Drawing
			}
			function DrawingObject.Update()
				local Center, Visible = GetScreen(Box.Root.Parent)
				Visible = Visible and ESP.Config.Boxes
				if Visible then
					Drawing.Visible = true
					local ESPSize : Vector2 = ESP.Config.StaticSize
					local Distance = Distance(Box:GetPivot().Position)
					local FieldOfView = Camera.FieldOfView
					if Distance > ESP.Config.MaxDistance then
						Drawing.Visible = false
						return
					end
					
					Drawing.Transparency = CalculateTransparency(Distance)
					
					local Size = ESPSize / (Distance / 100) * (FieldOfView / 70)
					local TopLeft = Vector2.new(Center.X - Size.X / 2, Center.Y - Size.Y / 2)
					local TopRight = Vector2.new(Center.X + Size.X / 2, Center.Y - Size.Y / 2)
					local BottomRight = Vector2.new(Center.X + Size.X / 2, Center.Y + Size.Y / 2)
					local BottomLeft = Vector2.new(Center.X - Size.X / 2, Center.Y + Size.Y / 2)
					Drawing.PointA = TopLeft
					Drawing.PointB = TopRight
					Drawing.PointC = BottomRight
					Drawing.PointD = BottomLeft
				else
					Drawing.Visible = false
				end
			end
			return DrawingObject
		end
		local function CreateBox3D()
			local Drawing = Drawing.new("Quad")
			local DrawingObject = {
				Drawing = Drawing
			}
			function DrawingObject.Update()
				local _, Visible = GetScreen(Box.Root.Parent)
				Visible = Visible and ESP.Config.Boxes
				if Visible then
					Drawing.Visible = true
					local ESPSize = ESP.Config.BoxSize
					local Pivot = Box:GetPivot()
					local Distance = Distance(Pivot.Position)
					if Distance > ESP.Config.MaxDistance then
						Drawing.Visible = false
						return
					end
					
					Drawing.Transparency = CalculateTransparency(Distance)
					
					local TopLeft = WTVP2D((Pivot * CFrame.new(ESPSize.X / 2, ESPSize.Y / 2, 0)).Position)
					local TopRight = WTVP2D((Pivot * CFrame.new(-ESPSize.X / 2, ESPSize.Y / 2, 0)).Position)
					local BottomRight = WTVP2D((Pivot * CFrame.new(-ESPSize.X / 2, -ESPSize.Y / 2, 0)).Position)
					local BottomLeft = WTVP2D((Pivot * CFrame.new(ESPSize.X / 2, -ESPSize.Y / 2, 0)).Position)
					Drawing.PointA = TopLeft
					Drawing.PointB = TopRight
					Drawing.PointC = BottomRight
					Drawing.PointD = BottomLeft
				else
					Drawing.Visible = false
				end
			end
			return DrawingObject
		end
		local function CreateBox3DFull()
			local Lines = {}
			local DrawingObject = {
				Drawing = Lines
			}
			for i = 1, 12 do
				Lines[i] = Drawing.new("Line")
				Lines[i].Thickness = 1
				Lines[i].Transparency = 1 
			end
			function DrawingObject.Update()
				local _, Visible = GetScreen(Box.Root.Parent)
				Visible = Visible and ESP.Config.Boxes
				for _, Line in ipairs(Lines) do
					Line.Visible = Visible
				end
				if Visible then
					local ESPSize = ESP.Config.BoxSize
					local Pivot = Box:GetPivot()
					local Distance = Distance(Pivot.Position)
					if Distance > ESP.Config.MaxDistance then
						for _, Line in ipairs(Lines) do
							Line.Visible = false
						end
						return
					end
					
					local Transparency = CalculateTransparency(Distance)
					for _, Line in ipairs(Lines) do
						Line.Transparency = Transparency
					end
					
					local sizeX = ESPSize.X/2
					local sizeY = ESPSize.Y/2 
					local sizeZ = ESPSize.Z/2
					local Top1 = WTVP2D((Pivot * CFrame.new(-sizeX, sizeY, -sizeZ)).Position)
					local Top2 = WTVP2D((Pivot * CFrame.new(-sizeX, sizeY, sizeZ)).Position)
					local Top3 = WTVP2D((Pivot * CFrame.new(sizeX, sizeY, sizeZ)).Position)
					local Top4 = WTVP2D((Pivot * CFrame.new(sizeX, sizeY, -sizeZ)).Position)
					local Bottom1 = WTVP2D((Pivot * CFrame.new(-sizeX, -sizeY, -sizeZ)).Position)
					local Bottom2 = WTVP2D((Pivot * CFrame.new(-sizeX, -sizeY, sizeZ)).Position)
					local Bottom3 = WTVP2D((Pivot * CFrame.new(sizeX, -sizeY, sizeZ)).Position)
					local Bottom4 = WTVP2D((Pivot * CFrame.new(sizeX, -sizeY, -sizeZ)).Position)
					Lines[1].From, Lines[1].To = Top1, Top2
					Lines[2].From, Lines[2].To = Top2, Top3  
					Lines[3].From, Lines[3].To = Top3, Top4
					Lines[4].From, Lines[4].To = Top4, Top1
					Lines[5].From, Lines[5].To = Bottom1, Bottom2
					Lines[6].From, Lines[6].To = Bottom2, Bottom3
					Lines[7].From, Lines[7].To = Bottom3, Bottom4
					Lines[8].From, Lines[8].To = Bottom4, Bottom1
					Lines[9].From, Lines[9].To = Bottom1, Top1
					Lines[10].From, Lines[10].To = Bottom2, Top2
					Lines[11].From, Lines[11].To = Bottom3, Top3
					Lines[12].From, Lines[12].To = Bottom4, Top4
					
					local BoxColor = GetColor(Box.Root.Parent, Box)
					for _, Line in ipairs(Lines) do
						Line.Color = BoxColor
					end
				end
			end
			function DrawingObject:Remove()
				for _, Line in ipairs(Lines) do
					Line:Remove()
				end
			end
			return DrawingObject
		end
		function Box:Update()

			if not EnsureInstance(self.Root) then

				if self.BoxType == "3DFull" then
					for _, Line in ipairs(self.DrawingObject.Drawing) do
						Line.Visible = false
					end
				else
					self.DrawingObject.Drawing.Visible = false
				end

				if self.TextObject then
					self.TextObject.Visible = false
				end

				return
			end

			if not ESP.Config.Enabled then

				if self.BoxType == "3DFull" then
					for _, Line in ipairs(self.DrawingObject.Drawing) do
						Line.Visible = false
					end
				else
					self.DrawingObject.Drawing.Visible = false
				end

				if self.TextObject then
					self.TextObject.Visible = false
				end

				return
			end

			if self.IsPlayer and not ESP.Config.Players then

				if self.BoxType == "3DFull" then
					for _, Line in ipairs(self.DrawingObject.Drawing) do
						Line.Visible = false
					end
				else
					self.DrawingObject.Drawing.Visible = false
				end

				if self.TextObject then
					self.TextObject.Visible = false
				end

				return
			end

			if self.IsPlayer then
				if ESP.Config.Text then
					if not self.TextObject then
						self.TextObject = Drawing.new("Text")

						if self.TextObject then
							self.TextObject.Size = 16

							if self.Root and self.Root.Parent then
								self.TextObject.Text = self.Root.Parent.Name or "Unknown"
							else
								self.TextObject.Text = "Unknown"
							end

							self.TextObject.Center = true
							self.TextObject.Outline = true

						end
					end

					self.TextObject.Color = ESP.Config.TextColor
					local TextPosition = self.Root.Position + Vector3.new(0, 5, 0)
					local ScreenPos, OnScreen = WTVP(TextPosition)
					local Distance = Distance(self.Root.Position)
					
					if Distance > ESP.Config.MaxDistance then
						self.TextObject.Visible = false
					else
						self.TextObject.Visible = OnScreen and ScreenPos.Z > 0
						self.TextObject.Transparency = CalculateTransparency(Distance)
						self.TextObject.Size = math.max(16 / Distance * 100, 13)
						self.TextObject.Position = Vector2.new(ScreenPos.X, ScreenPos.Y)
					end
				else
					if self.TextObject then
						self.TextObject:Remove()
						self.TextObject = nil
					end
				end
			end

			if self.IsPlayer then
				if self.BoxType ~= ESP.Config.BoxType then
					if self.BoxType == "3DFull" then
						for _, Line in ipairs(self.DrawingObject.Drawing) do
							Line:Remove()
						end
					else
						self.DrawingObject.Drawing:Remove()
					end
					Cleanup(self.DrawingObject)
					self.BoxType = ESP.Config.BoxType
					if Box.BoxType == "2D" then
						Box.DrawingObject = Create2DBox()
					elseif Box.BoxType == "3D" then
						Box.DrawingObject = CreateBox3D()
					elseif Box.BoxType == "3DFull" then
						Box.DrawingObject = CreateBox3DFull()
					else
						error("Invalid BoxType")
					end
				end
			end
			
			if self.BoxType ~= "3DFull" then
				self.DrawingObject.Drawing.Color = GetColor(self.Root.Parent, self)
			end
			self.DrawingObject.Update()
		end

		local Index = #RenderQueue + 1
		Box.Index = Index
		RenderQueue[Index] = Box

		function Box:Destroy()

			RenderQueue[Index] = nil

			if self.TextObject then
				self.TextObject:Remove()
				self.TextObject = nil
			end
			if self.DrawingObject then
				if self.BoxType == "3DFull" then
					for _, Line in ipairs(self.DrawingObject.Drawing) do
						Line:Remove()
					end
				else
					self.DrawingObject.Drawing:Remove()
				end
			end
		end

		if Box.BoxType == "2D" then
			Box.DrawingObject = Create2DBox()
		elseif Box.BoxType == "3D" then
			Box.DrawingObject = CreateBox3D()
		elseif Box.BoxType == "3DFull" then
			Box.DrawingObject = CreateBox3DFull()
		else
			error("Invalid BoxType")
		end
		
		return Box
	end
	
	local function CreateESP(Player : Player, Config : {any}) : {any}
		local Character = Player.Character

		dbgprint("Creating ESP for player", Player)

		if not Character then
			repeat task.wait() until Player.Character
			Character = Player.Character
		end

		dbgprint("Character found for player", Player)

		Character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

		local Box

		local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid

		local OnDied; OnDied = function()

			dbgprint("Recreating ESP for player", Player)

			Humanoid = nil

			Box:Destroy()
			Box = nil

			repeat 
				task.wait() 
				Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
			until Player.Character and Humanoid and Humanoid.Health > 0

			dbgprint("Character re-found for player", Player)

			Box = CreateBox(Character:WaitForChild("HumanoidRootPart") :: Part, Config)
			Box.IsPlayer = true

			dbgprint("ESP recreated for player", Player)

			task.spawn(function()
				repeat task.wait() until Humanoid.Health <= 0
				OnDied()
			end)
		end

		task.spawn(function()
			repeat task.wait() until Humanoid.Health <= 0
			OnDied()
		end)

		local Root = Character:WaitForChild("HumanoidRootPart") :: Part

		Box = CreateBox(Root, Config)
		Box.IsPlayer = true

		dbgprint("ESP created for player", Player)

		return Box
	end
	
	local function Update()
		for _, Box in pairs(RenderQueue) do
			pcall(function()
				Box:Update()
			end)
		end
	end
	
	ESP.Config.Enabled = false
	ESP.Config.Players = false
	ESP.Config.Boxes = false
	
	Collect(RunService.RenderStepped:Connect(Update))
	
	for _, Player in ipairs(Players:GetPlayers()) do
		
		if Player ~= LocalPlayer then
			task.defer(function()
				local _ = CreateESP(Player, {
					IsPlayer = true,
					DynamicColor = function(Model : Model)
						local Color = Color3.new(0, 0, 0)
						local Humanoid = Model:FindFirstChildOfClass("Humanoid") :: Humanoid
						local ForceField = Model:FindFirstChild("ForceField") :: ForceField

						if ForceField then
							return Color3.fromRGB(15, 207, 255)
						end

						if Humanoid then
							local Health = Humanoid.Health
							local MaxHealth = Humanoid.MaxHealth

							local HealthPercentage = Health / MaxHealth

							Color = Color3.fromRGB(255 - (255 * HealthPercentage), 255 * HealthPercentage, 0)
						end

						return Color
					end
				})
			end)
		end
	end

	Collect(Players.PlayerAdded:Connect(function(Player)
		if Player ~= LocalPlayer then
			local _ = CreateESP(Player, {
				IsPlayer = true,
				DynamicColor = function(Model : Model)
					local Color = Color3.new(0, 0, 0)
					local Humanoid = Model:FindFirstChildOfClass("Humanoid") :: Humanoid
					local ForceField = Model:FindFirstChild("ForceField") :: ForceField

					if ForceField then
						return Color3.fromRGB(15, 207, 255)
					end

					if Humanoid then
						local Health = Humanoid.Health
						local MaxHealth = Humanoid.MaxHealth

						local HealthPercentage = Health / MaxHealth

						Color = Color3.fromRGB(255 - (255 * HealthPercentage), 255 * HealthPercentage, 0)
					end

					return Color
				end
			})
		end
	end))

	ESP.Unload = Unload

	ESP_Library = ESP
end

--#endregion

--#region Aiming library
local Aiming_Library
do
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Camera = workspace.CurrentCamera

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		Camera = workspace.CurrentCamera
	end)

	local Aiming = {
		FOV = 60,
		NPCs = false,
		Players = true,
		Enabled = true,
		ShowFOV = true,
		AimTracer = true,
		DynamicFOV = true,
		FOVColor = Color3.fromRGB(255, 255, 255),
		AimTracerColor = Color3.fromRGB(255, 0, 0),
		CurrentTarget = nil
	}

	local InternalFOV = Aiming.FOV
	local FOVCircle = Drawing.new("Circle")

	FOVCircle.NumSides = 20
	FOVCircle.Transparency = 1
	FOVCircle.Thickness = 2
	FOVCircle.Color = Aiming.FOVColor
	FOVCircle.Filled = false

	local FOVTracer = Drawing.new("Line")

	FOVTracer.Thickness = 2

	local function UpdateFOV()

		if Aiming.ShowFOV then
			if Aiming.DynamicFOV then
				InternalFOV = Aiming.FOV * (70 / Camera.FieldOfView)
			else
				InternalFOV = Aiming.FOV
			end
		
			FOVCircle.Visible = true
			FOVCircle.Radius = InternalFOV
			FOVCircle.Color = Aiming.FOVColor
			FOVCircle.Position = UserInputService:GetMouseLocation()
		else
			FOVCircle.Visible = false
		end

	end

	local function GetCharactersInViewport() : {{Character: Model, Position: Vector2}}
		local ToProcess = {}
		local CharactersOnScreen = {}

		if Aiming.Players then
			for _, Player in ipairs(Players:GetPlayers()) do

				if Player == Players.LocalPlayer then
					continue
				end

				if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
					table.insert(ToProcess, Player.Character)
				end
			end
		end

		if Aiming.NPCs then
			-- for _, NPC in ipairs(workspace.NPCs.Hostile:GetChildren()) do
			--     if NPC:IsA("Model") and NPC:FindFirstChild("HumanoidRootPart") then
			--         table.insert(ToProcess, NPC)
			--     end
			-- end

			for _, NPC in next, game:GetService("CollectionService"):GetTagged("NPC") do
				if NPC:IsDescendantOf(workspace) and NPC:IsA("Model") and NPC:FindFirstChild("HumanoidRootPart") and game:GetService("CollectionService"):HasTag(NPC, "ActiveCharacter") then
					table.insert(ToProcess, NPC)
				end
			end

		end

		for _, Character in ipairs(ToProcess) do
			local Position, OnScreen = Camera:WorldToViewportPoint(Character.HumanoidRootPart.Position)

			if OnScreen then
				table.insert(CharactersOnScreen, {
					Character = Character,
					Position = Vector2.new(Position.X, Position.Y)
				})
			end
		end

		return CharactersOnScreen
	end

	local function DistanceFromMouse(Position : Vector2) : number
		return (UserInputService:GetMouseLocation() - Position).Magnitude
	end

	local function GetPlayersInFOV() : {{Character: Model, Distance: number, Position: Vector2}}
		local Characters = GetCharactersInViewport()
		local PlayersInFOV = {}

		for _, Character in ipairs(Characters) do
			local Distance = DistanceFromMouse(Character.Position)
			if Distance <= InternalFOV then
				table.insert(PlayersInFOV, {
					Character = Character.Character,
					Distance = Distance,
					Position = Character.Position
				})
			end
		end

		return PlayersInFOV
	end

	local function GetClosestPlayer() : (Model, number, Vector2)
		local PlayersInFOV = GetPlayersInFOV()
		local ClosestPlayer = nil
		local ClosestDistance = math.huge
		local ClosestPosition = nil

		for _, Player in ipairs(PlayersInFOV) do
			if Player.Distance < ClosestDistance then
				ClosestPlayer = Player.Character
				ClosestPosition = Player.Position
				ClosestDistance = Player.Distance
			end
		end

		return ClosestPlayer, ClosestDistance, ClosestPosition
	end

	local Connection = RunService.RenderStepped:Connect(function()

		if Aiming.Enabled then
			UpdateFOV()
			local ClosestPlayer, Distance, Position = GetClosestPlayer()
			Aiming.CurrentTarget = ClosestPlayer
			if ClosestPlayer then
				FOVTracer.Visible = Aiming.AimTracer
				FOVTracer.From = UserInputService:GetMouseLocation()
				FOVTracer.To = Position
				FOVTracer.Color = Aiming.AimTracerColor
			else
				FOVTracer.Visible = false
			end
		else
			FOVCircle.Visible = false
			FOVTracer.Visible = false
			Aiming.CurrentTarget = nil
		end

	end)

	local function Unload()
		Connection:Disconnect()
		FOVCircle:Remove()
		FOVTracer:Remove()
	end

	Aiming.Unload = Unload
	Aiming_Library = Aiming
end

--#endregion

--#region Main closure
local Success, Error = xpcall(function()
	--#region Enviroment Scanning

	local HookTargets = {
		"sprint_bar"
	}

	local GameRegistry = {
		consume_stamina = {}
	}

	local Storage = {
		Originals = {},
		Gun_Attributes = {
			{Name = "Accuracy", Type = "number", Max = 1, Min = 0.2},
			{Name = "Automatic", Type = "boolean"},
			{Name = "FireRate", Type = "number", Max = 5000, Min = 100},
			{Name = "Range", Type = "number", Max = 2000, Min = 50},
			{Name = "Recoil", Type = "number", Max = 5, Min = 0}
		},
		Melee_Attributes = {
			{Name = "ConeAngle", Type = "number", Min = 30, Max = 360},
			{Name = "Range", Type = "number", Min = 1, Max = 20},
			{Name = "Speed", Type = "number", Min = 0.1, Max = 5}
		}
	}

	if HOOKING_ENABLED then
		for _, v in next, getgc(true) do
			if type(v) == "table" then
				pcall(function()
					if rawget(v, "consume_stamina") and type(rawget(v, "consume_stamina")) == "function" then
						swarn("consume_stamina function found @", v)
						table.insert(GameRegistry.consume_stamina, rawget(v, "consume_stamina"))
					end
				end)
			end
		end
	else
		swarn("Skipping enviroment scanning due to hooking being disabled.")
	end

	--#endregion

	--#region Game Initialization

	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local CollectionService = game:GetService("CollectionService")
	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera

	local Modules = ReplicatedStorage:WaitForChild("Modules")
	local Core = Modules:WaitForChild("Core")
	local Game = Modules:WaitForChild("Game")

	local Net = require(Core:WaitForChild("Net"))
	local Gun = require(Game.ItemTypes:WaitForChild("Gun"))
	local Crate = require(Game.CrateSystem.Crate)

	Aiming_Library.Enabled = true
	Aiming_Library.FOV = 60
	Aiming_Library.Players = true

	--#endregion

	--#region Defining game-related runtime constants / functions

	HookSwitch(
		function()
			for _, Function in next, GameRegistry.consume_stamina do

				local Sprint_Bar = debug.getupvalue(Function, 2).sprint_bar
				if Sprint_Bar then
					swarn("Sprint bar found @", Sprint_Bar)
				end

				HookMgr.RegisterHook("inf_stamina" .. tostring(Sprint_Bar.update), Sprint_Bar.update, function(Old, ...)
					if G_Toggle("InfiniteStamina") then
						return Old(function()
							return 1
						end)
					else
						return Old(...)
					end
				end)
			end
		end,
		function()
			Cleaner(LocalPlayer:GetAttributeChangedSignal("StaminaConsumeMultiplier"):Connect(function()
				if G_Toggle("InfiniteStamina") then
					if LocalPlayer:GetAttribute("StaminaConsumeMultiplier") ~= 0 then
						LocalPlayer:SetAttribute("StaminaConsumeMultiplier", 0)
					end
				end
			end))
		end
	)

	local function CharacterAdded(Character : Model)

		local BodyMoverConnection = ConnectionProxyMgr:YieldForConnection(Character.DescendantAdded, "PlayerWellbeing", 5)
		dbgprint("BodyMoverConnection:", BodyMoverConnection)
		if BodyMoverConnection then
			ConnectionProxyMgr:Register(BodyMoverConnection):Disable()
		end

	end

	local function AssertCharacter() : Model
		return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	end

	local function GetAttributeByName(Instance, AttributeName)
		local HashKey = workspace:GetAttribute("HashKey") or workspace:GetAttributeChangedSignal("HashKey"):Wait()
		local Hash = 5381
		
		for i = 1, #AttributeName do
			Hash = (Hash * 33 + string.byte(AttributeName, i)) % 4294967296
		end
		
		local HashedName = HashKey .. tostring(Hash)
		return Instance:GetAttribute(HashedName)
	end

	local function SetAttributeByName(Instance, AttributeName, Value)
		local HashKey = workspace:GetAttribute("HashKey") or workspace:GetAttributeChangedSignal("HashKey"):Wait()
		local Hash = 5381
		
		for i = 1, #AttributeName do
			Hash = (Hash * 33 + string.byte(AttributeName, i)) % 4294967296
		end
		
		local HashedName = HashKey .. tostring(Hash)
		Instance:SetAttribute(HashedName, Value)
		return HashedName
	end

	Cleaner(RunService.Heartbeat:Connect(function(DeltaTime)
		local Character = AssertCharacter()
		local Humanoid = Character:FindFirstChildOfClass("Humanoid") :: Humanoid
		local MoveDirection = Humanoid.MoveDirection

		if MoveDirection.Magnitude > 0 then
			local SpeedBoost = G_Option("SpeedBoost")
			if SpeedBoost > 0 then
				Character:TranslateBy(MoveDirection * DeltaTime * SpeedBoost * 2.5)
			end
		end
	end))

	Cleaner(LocalPlayer.CharacterAdded:Connect(CharacterAdded))
	if LocalPlayer.Character then
		CharacterAdded(LocalPlayer.Character)
	end

	-- HookMgr.RegisterHook("BulletHitLog", Gun.bullet_hit, function(Old, ...)
	-- 	dbgprint("bullet_hit called with", ...)
	-- 	return Old(...)
	-- end)

	-- HookMgr.RegisterHook("BulletTrailLog", Gun.bullet_trail, function(Old, ...)
	-- 	dbgprint("bullet_trail called with", ...)
	-- 	return Old(...)
	-- end)

	HookMgr.RegisterHook("SilentAimHook", Gun.calculate_bullet_direction, function(Old, ...)

		local Target = Aiming_Library.CurrentTarget

		if Target and G_Toggle("SilentAimEnabled") then
			dbgprint("hook stage 1", ...)
			local HitPart : BasePart? = Target:FindFirstChild(G_Option("SilentAimPart")) or Target:FindFirstChild("HumanoidRootPart")
			if HitPart then
				dbgprint("hook stage 2", ...)
				local NewDirection = CFrame.new(Camera.CFrame.Position, HitPart.Position).LookVector
				return NewDirection.Unit
			end
		end

		return Old(...)
	end)

	HookMgr.RegisterHook("PrimaryNamecallHook", HookMgr.GameMT.__namecall, function(Old, ...)

		if not checkcaller() then
			
			local Method = getnamecallmethod()

			if G_Toggle("GunModificationEnabled") and (Method == "GetAttribute") then

				-- dbgprint("GetAttribute called with", ...)

				local Args = {...}
				local AttributeName = Args[2]

				for _, Attribute in next, Storage.Gun_Attributes do
					if AttributeName == Attribute.Name and Attribute.Type == "number" then
						-- dbgprint("GetAttribute called with", AttributeName)
						return G_Option("GunMods_" .. AttributeName)
					elseif AttributeName == Attribute.Name and Attribute.Type == "boolean" then
						-- dbgprint("GetAttribute called with", AttributeName)
						return G_Toggle("GunMods_" .. AttributeName)
					-- elseif game.IsDescendantOf(LocalPlayer.Character, Args[1]) then
					-- 	dbgprint("GetAttribute called but not found with", AttributeName)
					-- 	-- return Old(...)
					end
				end
			end

		end

		return Old(...)

	end)

	HookMgr.RegisterHook("SkipCrateAnimationHook", Crate.spin, function(Old, ...)
		if G_Toggle("SkipSpinAnimation") then
			local Args = {...}
			local Reward = Args[2]

			game:GetService("StarterGui"):SetCore("SendNotification", {
				["Title"] = "Crate Reward",
				["Text"] = Reward.amount .. " " .. Reward.name,
				["Duration"] = 3
			})

			return
		end
		return Old(...)
	end)

	Cleaner(task.spawn(function()
		while task.wait(1) do
			if G_Toggle("HideName") then
				Net.send("enter_character_creator")
			end
		end
	end))

	--#endregion

	--#region UI Initialization

	local Repository = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
	local Library = loadstring(game:HttpGet(Repository .. "Library.lua"))()
	local ThemeManager = loadstring(game:HttpGet(Repository .. "addons/ThemeManager.lua"))()
	local SaveManager = loadstring(game:HttpGet(Repository .. "addons/SaveManager.lua"))()

	Library.RiskColor = Color3.new(0.960784, 0.592157, 0.376471)

	-- Library.Scheme = {
	-- 	BackgroundColor = Color3.fromRGB(14, 4, 20),
	-- 	MainColor = Color3.fromRGB(26, 15, 36),
	-- 	AccentColor = Color3.fromRGB(116, 61, 180),
	-- 	OutlineColor = Color3.fromRGB(41, 28, 45),
	-- 	FontColor = Color3.new(1, 1, 1),
	-- 	Font = Font.fromEnum(Enum.Font.BuilderSans),
	-- }

	Cleaner.GetCleanEvent():Connect(function()
		Library:Unload()
		ESP_Library.Unload()
	end)

	local Window = Library:CreateWindow({
		Title = "sasware blockspin",
		Center = true,
		AutoShow = true,
		Footer = "Version: " .. Version .. " | " .. SubVersion
	})
	
	local Tabs = {
		Main = Window:AddTab("Main"),
		Automation = Window:AddTab("Automation"),
		Combat = Window:AddTab("Combat"),
		Visuals = Window:AddTab("Visuals"),
		UISettings = Window:AddTab("UI Settings")
	}

	-- Main tab

	local UtilitiesGroup = Tabs.Main:AddLeftGroupbox("Utilities")

	UtilitiesGroup:AddToggle("SkipSpinAnimation", {
		Text = "Skip Spin Animation",
		Default = false,
		Tooltip = "Skips the crate spin animation"
	})

	local CharacterGroup = Tabs.Main:AddRightGroupbox("Character")

	CharacterGroup:AddToggle("InfiniteStamina", {
		Text = "Infinite Stamina",
		Default = false,
		Tooltip = "Disables stamina consumption",
		Callback = function(Value)
			if not HOOKING_ENABLED then
				if Value then
					LocalPlayer:SetAttribute("StaminaConsumeMultiplier", 0)
				else
					LocalPlayer:SetAttribute("StaminaConsumeMultiplier", nil)
				end
			end
		end
	})

	CharacterGroup:AddSlider("SpeedBoost", {
		Text = "Speed Boost",
		Default = 0,
		Min = 0,
		Max = 2,
		Rounding = 1,
		Tooltip = "Sets the player speed"
	})

	local VulnerabilitiesGroup = Tabs.Main:AddLeftGroupbox("Vulnerabilities")

	VulnerabilitiesGroup:AddToggle("HideName", {
		Text = "Hide Name [SERVER]",
		Default = false,
		Tooltip = "Hides your name for everyone.",
		Risky = true,
		Callback = function(Value)
			if Value then
				Net.send("enter_character_creator")
			else
				Net.send("exit_character_creator")
			end
		end
	})

	VulnerabilitiesGroup:AddLabel({Text = "Hide name makes you unable to do damage.", DoesWrap = true})

	VulnerabilitiesGroup:AddLabel("rest are patched :(")

	-- Automation tab

	local AutomationGroup = Tabs.Automation:AddRightGroupbox("Automation")

	AutomationGroup:AddLabel("coming soon im lazy")

	-- Combat tab

	local GunModificationsGroup = Tabs.Combat:AddRightGroupbox("Gun Mods")

	local CurrentGun = GunModificationsGroup:AddLabel("Current: None")

	GunModificationsGroup:AddToggle("GunModificationEnabled", {
		Text = "Enabled",
		Default = false,
		Tooltip = "Enables gun modification features"
	})

	for _, Attribute in next, Storage.Gun_Attributes do
		if Attribute.Type == "number" then
			GunModificationsGroup:AddSlider("GunMods_" .. Attribute.Name, {
				Text = Attribute.Name,
				Default = Attribute.Min,
				Min = Attribute.Min,
				Max = Attribute.Max,
				Rounding = 2,
				Tooltip = "Sets the " .. Attribute.Name .. " for guns"
			})
		elseif Attribute.Type == "boolean" then
			GunModificationsGroup:AddToggle("GunMods_" .. Attribute.Name, {
				Text = Attribute.Name,
				Default = false,
				Tooltip = "Enables " .. Attribute.Name .. " for guns"
			})
		end
	end

	local SilentAimGroup = Tabs.Combat:AddLeftGroupbox("Silent Aim")

	SilentAimGroup:AddToggle("SilentAimEnabled", {
		Text = "Enabled",
		Default = false,
		Tooltip = "Enables silent aim features",
		Callback = function(Value)
			if Value then
				Aiming_Library.Enabled = true
			else
				Aiming_Library.Enabled = false
			end
		end
	})

	SilentAimGroup:AddSlider("SilentAimFOV", {
		Text = "FOV",
		Default = 60,
		Min = 0,
		Max = 360,
		Rounding = 0,
		Tooltip = "Sets the field of view for silent aim",
		Callback = function(Value)
			Aiming_Library.FOV = Value
		end
	})

	SilentAimGroup:AddDropdown("SilentAimPart", {
		Text = "Part",
		Default = "UpperTorso",
		Values = { "HumanoidRootPart", "UpperTorso", "Head" },
		Tooltip = "Sets the part to aim at"
	})

	-- Visuals tab

	local ESPGroup = Tabs.Visuals:AddLeftGroupbox("ESP")

	ESPGroup:AddToggle("ESPEnabled", {
		Text = "Enabled",
		Default = false,
		Tooltip = "Enables ESP features",
		Callback = function(Value)
			ESP_Library.Config.Enabled = Value
		end
	})

	ESPGroup:AddSlider("ESPRange", {
		Text = "Range",
		Default = 500,
		Min = 0,
		Max = 1500,
		Rounding = 0,
		Tooltip = "Sets the maximum distance for ESP",
		Callback = function(Value)
			ESP_Library.Config.MaxDistance = Value
		end
	})

	ESPGroup:AddSlider("ESPFade", {
		Text = "Fade",
		Default = 100,
		Min = 0,
		Max = 500,
		Rounding = 0,
		Tooltip = "Sets the fade distance for ESP",
		Callback = function(Value)
			ESP_Library.Config.FadeDistance = Value
		end
	})

	ESPGroup:AddToggle("ESPPlayers", {
		Text = "Players",
		Default = false,
		Tooltip = "Shows ESP for players",
		Callback = function(Value)
			ESP_Library.Config.Players = Value
		end
	})

	ESPGroup:AddToggle("ESPBoxes", {
		Text = "Boxes", 
		Default = false,
		Tooltip = "Shows boxes around players",
		Callback = function(Value)
			ESP_Library.Config.Boxes = Value
		end
	})

	ESPGroup:AddToggle("ESPText", {
		Text = "Text",
		Default = false,
		Tooltip = "Shows text labels for ESP",
		Callback = function(Value)
			ESP_Library.Config.Text = Value
		end
	}):AddColorPicker("TextColor", {
		Default = Color3.new(1, 1, 1),
		Title = "Text Color",
		Transparency = nil,
	
		Callback = function(Value)
			ESP_Library.Config.TextColor = Value
		end
	})

	local MenuGroup = Tabs.UISettings:AddLeftGroupbox("Menu")

	MenuGroup:AddButton("Unload", function()
		sprint("Cleaning up.")
		HookMgr.ClearHooks()
		Cleaner.Clean()
		ConnectionProxyMgr:Clear()
		ESP_Library.Unload()
		Aiming_Library.Unload()
		rconsoledestroy()
	end)

	-- Cleaner(RunService.RenderStepped:Connect(function()
	-- 	Library:SetWatermark("Current connections: " .. flen(Cleaner.Registry))
	-- end))

	-- MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })

	-- Library.ToggleKeybind = Options.MenuKeybind

	ThemeManager:SetLibrary(Library)
	SaveManager:SetLibrary(Library)

	SaveManager:IgnoreThemeSettings()

	SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

	ThemeManager:SetFolder("sasware_blockspin")
	SaveManager:SetFolder("sasware_blockspin/main")

	SaveManager:BuildConfigSection(Tabs.UISettings)
	ThemeManager:ApplyToTab(Tabs.UISettings)

	SaveManager:LoadAutoloadConfig()

	Cleaner(LocalPlayer.CharacterAdded:Connect(function(Character)
		Cleaner(Character.ChildAdded:Connect(function(Child)
			if CollectionService:HasTag(Child, "Gun") then
				CurrentGun:SetText("Current: " .. Child.Name)
			end
		end))
		Cleaner(Character.ChildRemoved:Connect(function(Child)
			if CollectionService:HasTag(Child, "Gun") then
				CurrentGun:SetText("Current: None")
			end
		end))
	end))

	if LocalPlayer.Character then
		Cleaner(LocalPlayer.Character.ChildAdded:Connect(function(Child)
			dbgprint(Child, 'added')
			if CollectionService:HasTag(Child, "Gun") then
				CurrentGun:SetText("Current: " .. Child.Name)
			end
		end))
		Cleaner(LocalPlayer.Character.ChildRemoved:Connect(function(Child)
			dbgprint(Child, 'removed')
			if CollectionService:HasTag(Child, "Gun") then
				CurrentGun:SetText("Current: None")
			end
		end))
	end

	--#endregion

end, function(Error)
	warn("An error occurred during execution:", Error)
	dbgprint(debug.traceback())
end)

--#endregion

-- task.delay(30, function()
-- 	if Success then
-- 		sprint("Cleaning up.")
-- 		task.wait(3)
-- 		HookMgr.ClearHooks()
-- 		Cleaner.Clean()
-- 		rconsoledestroy()
-- 	end
-- end)
