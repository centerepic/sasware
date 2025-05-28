local Version = 1
local SubVersion = "a"
local Start = os.clock()
Unloaded = false

local function RoundVector3(Vector)
    return Vector3.new(math.floor(Vector.X), math.floor(Vector.Y), math.floor(Vector.Z))
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LocalPlayer = Players.LocalPlayer
local Ragdoll = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Player"):WaitForChild("Ragdoll")
local DebrisFolder = workspace:WaitForChild("Debris")
local HitChance = 100

local Repository = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/refs/heads/main/"
local Library = loadstring(game:HttpGet(Repository .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(Repository .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(Repository .. "addons/SaveManager.lua"))()

local Nightbound = 137064773215574

local ESP = loadstring(game:HttpGet("https://kiriot22.com/releases/ESP.lua"))()
local VelocityFly = loadstring(game:HttpGet("https://raw.githubusercontent.com/centerepic/VelocityFly/main/VelocityFly.lua"))()
local Aiming = loadstring(game:HttpGet("https://raw.githubusercontent.com/centerepic/sasware_blackout/main/aiming_lib.lua"))()

Aiming.Enabled = false
Aiming.FOV = 60
Aiming.FOVColor = Color3.fromRGB(255, 255, 255)
Aiming.NPCs = true
Aiming.Players = true

local TeleportLocations = {
    ["Military Base Control Room"] = Vector3.new(1295, 39, -425),
    ["Vultures Base"] = Vector3.new(1303, 69, -30),
    ["Rebel Base"] = Vector3.new(403, 40, 666),
    ["Bunker Entrance [Outside]"] = Vector3.new(258, 35, 25),
    ["Bunker Entrance [Inside]"] = Vector3.new(152, 36, 25),
    ["Bunker Reactor Bridge"] = Vector3.new(-267, 28, 25),
    ["Bunker Wave Defense"] = Vector3.new(-104, -12, 30),
    ["Arena"] = Vector3.new(1156, -109, -77)
}

local TeleportLocations_DropDownValues = {}

if game.PlaceId ~= Nightbound then
    for Location, _ in next, TeleportLocations do
        table.insert(TeleportLocations_DropDownValues, Location)
    end
end

local Collection = {}
function Collect(Item : RBXScriptConnection | thread)
    table.insert(Collection, Item)
end

-- Map elements

local MSPS = 90

local NPCs = workspace:WaitForChild("NPCs")
local Characters = workspace:WaitForChild("Chars")
local Terminals = Instance.new("Folder")
if game.PlaceId ~= Nightbound then
    Terminals = workspace:WaitForChild("Terminals")
end
local FastCast = require(ReplicatedStorage.Mods.FastCast)

local Remotes = {
    MinigameResult = ReplicatedStorage.Events.Loot.MinigameResult,
    LootObject = ReplicatedStorage.Events.Loot.LootObject,
    Buy = ReplicatedStorage.Events.Stations.Buy,
    Minigame = ReplicatedStorage.Events.Loot.Minigame,
    Swing = ReplicatedStorage.MeleeStorage.Events.Swing,
    MeleeHit = ReplicatedStorage.MeleeStorage.Events.Hit,
    GunHit = ReplicatedStorage.GunStorage.Events.Hit,
    DialogEvent = ReplicatedStorage.Events.Dialogue.Event,
    TransferCurrency = ReplicatedStorage.Events.Stash.TransferCurrency
}

shared.State = {
    NoFall = false,
    NoRagdoll = false
}

local State = {}
local Functions

local HookStorage = {}
local AttributeSpoof = {}

local Limbs = {
    "Head",
    "Torso"
}

-- Functions

local function Miss()
	return (math.random(0, 100) > HitChance)
end

local function RegisterHook(Old : (any) -> any, New : (any) -> any)
    local HookId = #HookStorage + 1
    HookStorage[HookId] = hookfunction(Old, New)
    return HookId
end

local function UndoHook(HookId : number)
    if HookStorage[HookId] then
        hookfunction(HookStorage[HookId], HookStorage[HookId])
    end
end

local PreTeleportValue = nil
local function PreTeleport()
    if LocalPlayer.Character then
        PreTeleportValue = LocalPlayer.Character:GetPivot()
    end
end

local function Attribute(Instance : Instance, Name : string, Value : any)

    if Value == nil then
        return Instance:GetAttribute(Name)
    else
        Instance:SetAttribute(Name, Value)
    end

    return nil
end

local function GetData(Player : Player, GetCharacterData : boolean)
    local PlayerData = {
        Reputation = Attribute(Player, "Reputation"),
        Cash = Attribute(Player, "Cash") or 0,
        Level = Attribute(Player, "Level") or 1,
        Bounty = Attribute(Player, "Bounty") or 0,
        Valuables = Attribute(Player, "Valuables") or 0,
        Combat = Attribute(Player, "InDanger") or false,
    }

    if GetCharacterData and Player:GetAttribute("LoadedCharacterData") == true then -- If the player has spawned in from the menu
        
        local Character = Player.Character
        if Character then
            local Humanoid = Character:FindFirstChildOfClass("Humanoid")
            if Humanoid then

                PlayerData.Health = Humanoid.Health or 0
                PlayerData.MaxHealth = Humanoid.MaxHealth or 0
                PlayerData.Downed = Attribute(Character, "Downed") or false

            end
        else
            PlayerData.NoCharacter = true
        end

    end

    return PlayerData
end

local function GetPlayerState()
    local PlayerState = {}

    for State, Value in next, LocalPlayer.PlayerGui:GetAttributes() do
        PlayerState[State] = Value
    end

    return PlayerState
end

local function SetState(Key : string, Value : any)
    LocalPlayer.PlayerGui:SetAttribute(Key, Value)
end

local function LockState(Key : string, Value : any)
    AttributeSpoof[LocalPlayer.PlayerGui] = {Key = Key, Value = Value}
end

local function FreeState(Key : string)
    AttributeSpoof[LocalPlayer.PlayerGui] = nil
end

local function GetClosest(Instances : {Model | BasePart}, Position : Vector3)
    local Closest = nil
    local ClosestDistance = math.huge

    for _, Object in ipairs(Instances) do
        local InstancePosition = Object:GetPivot().Position
        local Distance = (InstancePosition - Position).Magnitude
        if Distance < ClosestDistance then
            Closest = Object
            ClosestDistance = Distance
        end
    end

    return Closest, ClosestDistance
end

local function GetWithinRange(Instances : {Model | BasePart}, Position : Vector3, Range : number)
    local Objects = {}

    for _, Object in ipairs(Instances) do
        local InstancePosition = Object:GetPivot().Position
        local Distance = (InstancePosition - Position).Magnitude
        if Distance <= Range then
            table.insert(Objects, Object)
        end
    end

    return Objects
end

local function Unlock(Container : Model)
    -- i forgor
end

function TP(Target: Vector3 | CFrame | PVInstance, Bypass: boolean?): boolean
    local Pivot: CFrame

    if typeof(Target) == "CFrame" then
        Pivot = Target
    elseif typeof(Target) == "Vector3" then
        Pivot = CFrame.new(Target)
    elseif typeof(Target) == "PVInstance" then
        Pivot = Target:GetPivot()
    elseif typeof(Target) == "BasePart" then
        Pivot = Target:GetPivot()
    elseif typeof(Target) == "Model" then
        Pivot = Target:GetPivot()
    end

    local Character = LocalPlayer.Character
    if Character then
        Character:PivotTo(Pivot)
        return true
    end

    return false
end

-- ts is so bad
function BypassTP(Target: Vector3 | CFrame | PVInstance): RBXScriptSignal

    shared.Teleporting = true

    local Pivot: CFrame
    if typeof(Target) == "CFrame" then
        Pivot = Target
    elseif typeof(Target) == "Vector3" then
        Pivot = CFrame.new(Target)
    elseif typeof(Target) == "PVInstance" then
        Pivot = Target:GetPivot()
    else
        error("Unsupported target type!")
    end

    local Character = LocalPlayer.Character :: Model
    local Start = Character:GetPivot()

    local HorizontalDistance = (Vector2.new(Start.Position.X, Start.Position.Z)
        - Vector2.new(Pivot.Position.X, Pivot.Position.Z)).Magnitude
    local VecticalDist = math.abs(Start.Position.Y + 22) + math.abs(Pivot.Position.Y + 22)
    local TotalPathLength = HorizontalDistance + VecticalDist

    local TravelTime = TotalPathLength / MSPS
    local StartTime = os.clock()
    local EndTime = StartTime + TravelTime
    local Signal = Instance.new("BindableEvent")

    local DropFraction = 0.2
    local RiseFraction = 0.2
    local MiddleFraction = 1 - DropFraction - RiseFraction
    local StartY = Start.Position.Y
    local EndY = Pivot.Position.Y
    local DropY = -22

    local function GetPiecewiseY(Alpha: number)
        if Alpha < DropFraction then
            local localAlpha = Alpha / DropFraction
            return StartY + (DropY - StartY) * localAlpha
        elseif Alpha < DropFraction + MiddleFraction then
            return DropY
        else
            local localAlpha = (Alpha - DropFraction - MiddleFraction) / RiseFraction
            return DropY + (EndY - DropY) * localAlpha
        end
    end

    local TPConnection
    TPConnection = RunService.Heartbeat:Connect(function()
        local Now = os.clock()
        local Alpha = math.clamp((Now - StartTime) / TravelTime, 0, 1)

        if Now >= EndTime then
            Character:PivotTo(Pivot)
            TPConnection:Disconnect()
            shared.Teleporting = false
            Signal:Fire()
            Signal:Destroy()

            for _, Limb in next, Limbs do
                local C_Limb = LocalPlayer.Character:FindFirstChild(Limb)
                if C_Limb then
                    C_Limb.CanCollide = true
                end
            end
        else
            if EndTime - Now > 1.4 then
                if Toggles.RagdollTPBypass.Value then
                    Ragdoll:FireServer(Character)
                end
            end
            Functions.BreakVelocity()

            for _, Object in next, Character:GetDescendants() do
                if Object:IsA("BasePart") then
                    Object.CanCollide = false
                end
            end
            
            local Horizontal = Start.Position:Lerp(Pivot.Position, Alpha)
            local NewY = GetPiecewiseY(Alpha)
            local NewPos = Vector3.new(Horizontal.X, NewY, Horizontal.Z)
            Character:PivotTo(CFrame.new(NewPos))
        end
    end)

    return Signal.Event
end

local function RestoreConnections(Event : RBXScriptSignal)
    pcall(function()
        for _, Connection in next, getconnections(Event) do
            Connection:Enable()
        end
    end)
end

local function FindFirstDescendant(Object : Instance, Name : string)
    for _, Descendant in ipairs(Object:GetDescendants()) do
        if Descendant.Name == Name then
            return Descendant
        end
    end

    return nil
end

-- Initialize coroutines, functions, connections, etc.

Functions = {
    AutoRevive = function()
        if LocalPlayer.Character:GetAttribute("Downed") == true then
            local Stats = GetData(LocalPlayer, false)
            local Reputation = Stats.Reputation
            local Faction = nil

            if Reputation > 0 then
                Faction = "Rebel"
            elseif Reputation < 0 then
                Faction = "Vulture"
            else
                Library:Notify("Auto-Revive | You have no faction, cannot auto-revive.")
            end

            if Faction ~= nil then

                PreTeleport()

                if Faction == "Vulture" then
                    BypassTP(CFrame.new(Vector3.new(1348, 76, 29)))
                elseif Faction == "Rebel" then
                    BypassTP(CFrame.new(Vector3.new(403, 36, 671)))
                end

                Library:Notify("Auto-Revive | Initializing, please wait...")

                task.wait(1.5)

                local FriendlyNPCs = {}

                for _, NPC in ipairs(NPCs.Hostile:GetChildren()) do
                    if NPC:GetAttribute("Faction") == Faction then
                        table.insert(FriendlyNPCs, NPC)
                    end
                end

                local Closest, _ = GetClosest(FriendlyNPCs, LocalPlayer.Character:GetPivot().Position)

                BypassTP(Closest:GetPivot())
            end     
        end
    end,
    BreakVelocity = function()
        if LocalPlayer.Character then
            for _, Object in ipairs(LocalPlayer.Character:GetDescendants()) do
                if Object:IsA("BasePart") then
                    Object.Velocity = Vector3.zero
                    Object.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end
}

Functions.GuiHooks = function()
    local Gui = LocalPlayer:WaitForChild("PlayerGui")
    local MainGui = Gui:WaitForChild("MainGui")
    local Minimap = MainGui:WaitForChild("Minimap")

    do
        local NoSignal = Minimap:WaitForChild("NoSignal")
        local MapFrame = Minimap:WaitForChild("TabsFrame")

        Collect(NoSignal:GetPropertyChangedSignal("Visible"):Connect(function()
            if NoSignal.Visible and Toggles.AlwaysMap.Value then
                NoSignal.Visible = false
            end
        end))

        Collect(MapFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if (not MapFrame.Visible) and Toggles.AlwaysMap.Value then
                MapFrame.Visible = true
            end
        end))
    end
end

function Functions.GetCharacters()
    local Characters = {}

    for _, Player: Player in next, Players:GetPlayers() do

        if Player == LocalPlayer then
            continue
        end

        if Player.Character then
            table.insert(Characters, Player.Character)
        end
    end

    return Characters
end

function Functions.SafePosition(Position: Vector3, Range: number)
    local Characters = Functions.GetCharacters()

    for _, Character in next, Characters do
        local Pivot = Character:GetPivot()

        if Pivot then
            local Distance = (Position - Pivot.Position).Magnitude

            if Distance <= Range then
                return false
            end
        end
    end

    return true
end

Functions.CharacterAdded = function(Character)
    Collect(Character:GetAttributeChangedSignal("Downed"):Connect(function()
        if Toggles.AutoRevive.Value then
            Functions.AutoRevive()
        end

        if Toggles.AntiDown.Value then
            task.wait()
            Character:SetAttribute("Downed", false)
        end
    end))

    Collect(RunService.Heartbeat:Connect(function()

        if LocalPlayer.Character then
            if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                State.HRPCFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
            end
        end

        if Toggles.Noclip and Toggles.Noclip.Value == true then

            if GetPlayerState().Downed then
                return
            end

            for _, Object in ipairs(Character:GetDescendants()) do
                if Object:IsA("BasePart") then
                    Object.CanCollide = false
                end
            end
        end
    end))

    Functions.GuiHooks()
end

Functions.GotoNearestMerchant = function()
    PreTeleport()
    local Merchants = {}
    for _, NPC in next, NPCs.Other:GetChildren() do
        if NPC.Name == "Merchant" then
            table.insert(Merchants, NPC)
        end
    end

    local Closest, _ = GetClosest(Merchants, LocalPlayer.Character:GetPivot().Position)
    return BypassTP(Closest:GetPivot() + Closest.PrimaryPart.CFrame.LookVector.Unit * 3), Closest
end

Functions.GotoNearestBroker = function()
    PreTeleport()
    local Brokers = {}
    for _, NPC in next, NPCs.Other:GetChildren() do
        if NPC.Name == "Broker" then
            table.insert(Brokers, NPC)
        end
    end

    local Closest, _ = GetClosest(Brokers, LocalPlayer.Character:GetPivot().Position)
    return BypassTP(Closest:GetPivot() + Closest.PrimaryPart.CFrame.LookVector.Unit * 3), Closest
end

Functions.GotoNearestTerminal = function()
    PreTeleport()
    local Closest, _ = GetClosest(Terminals:GetChildren(), LocalPlayer.Character:GetPivot().Position)
    return BypassTP(Closest.CFrame + Closest.CFrame.RightVector.Unit * -3), Closest
end

Functions.GotoDestination = function()
    if DebrisFolder.Nav:FindFirstChild("Destination") then
        PreTeleport()
        BypassTP(DebrisFolder.Nav.Destination:GetPivot())
    else
        Library:Notify("Destination | No destination set.")
    end
end

Functions.UndoLastTeleport = function()
    if PreTeleportValue then
        BypassTP(PreTeleportValue)
    else
        Library:Notify("Undo Teleport | No previous teleport to undo.")
    end
end

Functions.IsUnlocked = function(LootObject : Model)
    return Attribute(LootObject, "Unlocked")
end

Functions.GetLoot = function(Types : {string}?)
    local Loot = CollectionService:GetTagged("Loot")
    local Filtered = {}

    if Types then
        for i, Item in next, Loot do

            if not Types[Item.Name] then
                continue
            end

            if not Item:FindFirstChild("LootBase") then
                continue
            end

            if not Item.LootBase:FindFirstChild("LootTable") then
                continue
            end

            table.insert(Filtered, Item)
        end
    end

    return Filtered
end

Functions.FilterZeroMoneyObjects = function(Loot : {Model})

    local Filtered = {}

    for i, Item in next, Loot do
        if Attribute(Item.LootBase.LootTable, "Cash") == 0 and Attribute(Item.LootBase.LootTable, "Valuables") == 0 then
            if not FindFirstDescendant(Item, "LockMinigame") then
                continue
            end
        end

        table.insert(Filtered, Item)
    end

    return Filtered
end

function Functions.FilterObjectsInRangeOfPlayers(Objects : {Model}, Range : number)
    local Filtered = {}

    for _, Object in next, Objects do
        local Safe = Functions.SafePosition(Object:GetPivot().Position, Range)
        if Safe then
            table.insert(Filtered, Object)
        end
    end

    return Filtered
end

Functions.GetClosestLootObjectOfType = function(Position : Vector3, Types : {string}?, FilterMoney : boolean?)
    local Loot = Functions.GetLoot(Types)
    if FilterMoney then
        Loot = Functions.FilterZeroMoneyObjects(Loot)
    end

    Loot = Functions.FilterObjectsInRangeOfPlayers(Loot, 50)

    return GetClosest(Loot, Position)
end

function Functions.GotoAirdrop()
    local Airdrop = DebrisFolder:FindFirstChild("Airdrop")

    if Airdrop then
        local Drop = Airdrop:FindFirstChild("Drop")
        local Crate = Drop:FindFirstChild("Crate")
        if Crate then
            PreTeleport()
            BypassTP(Crate.Base:GetPivot())
        end
    end
end

local BlockedEvents = {}

Collect(Remotes.LootObject.OnClientEvent:Connect(function(LootTable : Folder)
    if Toggles.AutoLootEnabled.Value then
        if Toggles.TakeValuables.Value then
            Remotes.LootObject:FireServer(LootTable, "Valuables")
        end

        if Toggles.TakeCash.Value then
            Remotes.LootObject:FireServer(LootTable, "Cash")
        end
    end
end))

Collect(ProximityPromptService.PromptButtonHoldBegan:Connect(function(ProximityPrompt : ProximityPrompt)
    if Toggles.InstantProximityPrompt.Value then
        fireproximityprompt(ProximityPrompt)
    end
end))

Collect(Remotes.Minigame.OnClientEvent:Connect(function(Minigame : Instance)
    if Toggles.AutoMinigame.Value then
        Remotes.MinigameResult:FireServer(Minigame, true)
    end
end))

local EventBlockerCoroutine = coroutine.create(function()
    while task.wait() do
        for _, Event in next, BlockedEvents do
            pcall(function()
                for _, Connection in next, getconnections(Event) do
                    if not isexecutorclosure(Connection.Function) then
                        Connection:Disable()
                    end
                end
            end)
        end
    end
end)
Collect(EventBlockerCoroutine)

local FloorHideCoroutine = coroutine.create(function()
    local FloorHiding = false
    local OriginalPivot = nil

    while RunService.Heartbeat:Wait() do
        if Toggles.FloorHide.Value then
            if not FloorHiding then
                OriginalPivot = LocalPlayer.Character:GetPivot()
                FloorHiding = true
            else
                LocalPlayer.Character:PivotTo(
                    CFrame.new(OriginalPivot.Position - (Vector3.yAxis * 6), OriginalPivot.Position)
                )
                Functions.BreakVelocity()
            end
        else
            if FloorHiding then
                LocalPlayer.Character:PivotTo(OriginalPivot)
                FloorHiding = false
                Functions.BreakVelocity()
            end
        end
    end
end)
Collect(FloorHideCoroutine)

local AutofarmCoroutine = coroutine.create(function()
    while task.wait() do
        if Toggles.AutoFarmEnabled.Value then

            BlockedEvents["Minigame"] = Remotes.Minigame.OnClientEvent

            local FarmTypes = Options.AutoFarmType.Value :: {string}
            local Target = Functions.GetClosestLootObjectOfType(LocalPlayer.Character:GetPivot().Position, FarmTypes, true)

            if Target then
                print("Teleporting to target...")
                BypassTP(Target:GetPivot()):Wait()
                print("Teleported to target.")
                
                if not Functions.IsUnlocked(Target) then

                    print("Unlocking target...")
                    if Target.Lid.Lockpick:FindFirstChild("LockMinigame") then

                        local UnlockWaitConnection
                        local UnlockResult = false
                        local UnlockAttemptThread = coroutine.create(function()
                            while task.wait(0.1) do
                                if Target.Lid.Lockpick:FindFirstChild("LockMinigame") then
                                    fireproximityprompt(Target.Lid.Lockpick.LockMinigame)
                                else
                                    UnlockWaitConnection:Disconnect()
                                    UnlockResult = true
                                end
                            end
                        end)
                        coroutine.resume(UnlockAttemptThread)
                        
                        print("Waiting for minigame...")

                        UnlockWaitConnection = Remotes.Minigame.OnClientEvent:Once(function()
                            coroutine.close(UnlockAttemptThread)
                            UnlockResult = true
                        end)

                        while not UnlockResult do
                            task.wait()
                        end

                        Remotes.MinigameResult:FireServer(Target, true)
                        print("Unlocked target.")
                    end

                end

                print("Opening target...")

                local OpenAttemptThread = coroutine.create(function()
                    while task.wait(0.1) do
                        fireproximityprompt(Target.LootBase.OpenLootTable)
                    end
                end)
                coroutine.resume(OpenAttemptThread)

                print("Waiting for loot...")
                local LootTable = Remotes.LootObject.OnClientEvent:Wait()
                coroutine.close(OpenAttemptThread)

                print("Taking valuables and cash...")

                repeat task.wait()
                    Remotes.LootObject:FireServer(LootTable, "Valuables")
                    Remotes.LootObject:FireServer(LootTable, "Cash")
                until Attribute(LootTable, "Cash") == 0 and Attribute(LootTable, "Valuables") == 0
                print("Closing target...")
                Remotes.LootObject:FireServer("Cancel", Target)
            end
        else
            if not Toggles.AutoMinigame.Value then
                BlockedEvents["Minigame"] = nil
                RestoreConnections(Remotes.Minigame.OnClientEvent)
            end
        end
    end
end)
Collect(AutofarmCoroutine)

local KillAuraCoroutine = coroutine.create(function()
    while task.wait(.5) do
        if Toggles.KillAuraEnabled.Value and LocalPlayer.Character then
            print('kainit')
            if not (LocalPlayer.Character:FindFirstChild("ServerMeleeModel")) then
                continue
            end
            print('kainit2')

            local Range = Options.KillAuraRange.Value
            local TargetPart = Options.KillAuraParts.Value

            local TargetNPCs = Toggles.KillAuraNPCs.Value
            local TargetPlayers = Toggles.KillAuraPlayers.Value

            if TargetPlayers then

                local FilteredPlayers = {}

                for _, Player in ipairs(Characters:GetChildren()) do
                    if not Player:GetAttribute("Downed") then
                        table.insert(FilteredPlayers, Player)
                    end
                end

                local Closest, ClosestRange = GetClosest(FilteredPlayers, LocalPlayer.Character:GetPivot().Position)
                if Closest and ClosestRange <= Range then
                    
                    local Limb = Closest:FindFirstChild(TargetPart)
                    if Limb then
                        local Result = Remotes.Swing:InvokeServer()

                        if Result then
                            task.wait(Result.Delay or 0.25)
                            Remotes.MeleeHit:FireServer(Limb, Limb.Position)
                        end
                    end

                    continue

                end
            end

            if TargetNPCs then

                local FilteredNPCs = {}

                -- for _, NPC in ipairs(NPCs.Hostile:GetChildren()) do
                --     if not NPC:GetAttribute("Downed") then
                --         table.insert(FilteredNPCs, NPC)
                --     end
                -- end

                for _, NPC in next, CollectionService:GetTagged("NPC") do
                    if NPC:IsDescendantOf(workspace) and NPC:IsA("Model") and NPC:FindFirstChild("HumanoidRootPart") and (CollectionService:HasTag(NPC, "ActiveCharacter") or game.PlaceId == Nightbound) then
                        table.insert(FilteredNPCs, NPC)
                    end
                end

                if game.PlaceId ~= Nightbound then
                    local Arena = workspace:FindFirstChild("Arena") :: Model
                    for _, Child in next, Arena:GetChildren() do
                        if Child:FindFirstChildOfClass("Humanoid") and not Child:GetAttribute("Downed") then
                            table.insert(FilteredNPCs, Child)
                        end
                    end
                end

                local Closest, ClosestRange = GetClosest(FilteredNPCs, LocalPlayer.Character:GetPivot().Position)
                if Closest and ClosestRange <= Range then
                    
                    local Limb = Closest:FindFirstChild(TargetPart)
                    if Limb then
                        local Result = Remotes.Swing:InvokeServer()

                        if Result then
                            task.wait(Result.Delay or 0.25)
                            Remotes.MeleeHit:FireServer(Limb, Limb.Position)
                        end
                    end
                end
            end
        end
    end
end)
Collect(KillAuraCoroutine)


Collect(LocalPlayer.CharacterAdded:Connect(Functions.CharacterAdded))

-- Initialize UI

Library.RiskColor = Color3.new(0.960784, 0.592157, 0.376471)

local Window = Library:CreateWindow({
    Title = 'sasware | Blackout | ' .. tostring(Version) .. SubVersion,
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Main = Window:AddTab('Main'),
    Automation = Window:AddTab('Automation'),
    Combat = Window:AddTab('Combat'),
    Visuals = Window:AddTab('Visuals'),
    UISettings = Window:AddTab('UI Settings')
}

do
    local TeleportsGroupBox = Tabs.Main:AddRightGroupbox('Teleports')
    local CharacterGroupBox = Tabs.Main:AddLeftGroupbox('Character')
    local AssistanceGroupBox = Tabs.Main:AddLeftGroupbox('Assistance')

    TeleportsGroupBox:AddButton('Undo Last Teleport', Functions.UndoLastTeleport)
    TeleportsGroupBox:AddDivider()
    TeleportsGroupBox:AddButton('Nearest Merchant', Functions.GotoNearestMerchant)
    TeleportsGroupBox:AddButton('Nearest Broker', Functions.GotoNearestBroker)
    TeleportsGroupBox:AddButton('Nearest Terminal', Functions.GotoNearestTerminal)
    TeleportsGroupBox:AddDivider()
    TeleportsGroupBox:AddButton('Airdrop', Functions.GotoAirdrop)
    TeleportsGroupBox:AddButton('Destination', Functions.GotoDestination)

    TeleportsGroupBox:AddDivider()

	TeleportsGroupBox:AddDropdown("TeleportsDropdown", {
		Values = TeleportLocations_DropDownValues,
		Default = 1,
		Multi = false,

		Text = "Select location",
		Tooltip = "Location to teleport to",
	})

    TeleportsGroupBox:AddButton("Teleport", function()
		local Selected = Options.TeleportsDropdown.Value
		local Position = TeleportLocations[Selected]

		if Position then
            PreTeleport()
			BypassTP(Position)
		end
	end)

    TeleportsGroupBox:AddToggle('RagdollTPBypass', {
        Text = 'RagdollVelocityBypass',
        Default = true,
        Tooltip = 'Disable if carrying a person. Risky to leave off.',
        Risky = true
    })

    CharacterGroupBox:AddToggle('FloorHide', {
        Text = 'Hide in Floor [!]',
        Default = false,
        Tooltip = 'Hides your character under the floor.',
        Risky = true
    }):AddKeyPicker('FloorHide', {
        Default = 'X',
        SyncToggleState = true,
        Mode = 'Toggle',
        Text = 'Toggle Floor Hide',
        NoUI = false
    })

    CharacterGroupBox:AddToggle('AntiDown', {
        Text = 'No Downed [!]',
        Default = false,
        Tooltip = 'Prevents you being downed, you will still bleed out.',
        Risky = true
    })

    CharacterGroupBox:AddToggle('InfStam', {
        Text = 'Infinite Stamina',
        Default = false,
        Tooltip = 'Gives you infinite stamina.',
        Callback = function(Value)
            if Value then
                LockState("Stamina", 100)
            else
                FreeState("Stamina")
            end
        end
    })

    CharacterGroupBox:AddToggle('InfHunger', {
        Text = 'Infinite Hunger',
        Default = false,
        Tooltip = 'Gives you infinite hunger.',
        Callback = function(Value)
            if Value then
                LockState("Hunger", 100)
            else
                FreeState("Hunger")
            end
        end
    })

    CharacterGroupBox:AddToggle('InfThirst', {
        Text = 'Infinite Thirst',
        Default = false,
        Tooltip = 'Gives you infinite thirst.',
        Callback = function(Value)
            if Value then
                LockState("Thirst", 100)
            else
                FreeState("Thirst")
            end
        end
    })

    CharacterGroupBox:AddToggle('AlwaysSneak', {
        Text = 'Spoof Crouch',
        Default = false,
        Tooltip = 'Makes game think you\'re always crouching.'
    })

    CharacterGroupBox:AddToggle('NoFall', {
        Text = 'No Fall Damage',
        Default = false,
        Tooltip = 'Prevents you taking fall damage.'
    })

    CharacterGroupBox:AddToggle('NoRagdoll', {
        Text = 'No Ragdoll',
        Default = false,
        Tooltip = 'Prevents you from ragdolling.'
    })

    CharacterGroupBox:AddToggle('Flight', {
        Text = 'Flight',
        Default = false,
        Tooltip = 'Enables flight.',
        Callback = function(Value)
            VelocityFly:Toggle(Value)
        end
    })

    CharacterGroupBox:AddSlider('FlightSpeed', {
        Text = 'Flight Speed',
        Default = 1,
        Min = 1,
        Max = 10,
        Rounding = 0,
        Compact = false
    })

    CharacterGroupBox:AddToggle('Noclip' , {
        Text = 'Noclip',
        Default = false,
        Tooltip = 'Enables noclip.',
        Callback = function(Value)
            if not Value then
                for _, Limb in ipairs(Limbs) do
                    LocalPlayer.Character:FindFirstChild(Limb).CanCollide = true
                end
            end
        end
    })

    Options.FlightSpeed:OnChanged(function()
        VelocityFly.Speed = Options.FlightSpeed.Value
    end)

    CharacterGroupBox:AddToggle('AutoRevive', {
        Text = 'Auto Revive [!]',
        Default = false,
        Tooltip = 'Teleports you to a friendly NPC when downed.',
        Risky = true
    })

    AssistanceGroupBox:AddToggle('InstantProximityPrompt', {
        Text = 'Instant Interact',
        Default = false,
        Tooltip = 'Makes all proximityprompts instant.'
    })
    
    AssistanceGroupBox:AddDivider()

    AssistanceGroupBox:AddToggle('AutoMinigame', {
        Text = 'Auto-Minigame',
        Default = false,
        Tooltip = 'Automatically complete minigames.',
        Callback = function(Value)
            if Value then
                BlockedEvents["Minigame"] = Remotes.Minigame.OnClientEvent
            else
                BlockedEvents["Minigame"] = nil
                RestoreConnections(Remotes.Minigame.OnClientEvent)
            end
        end
    })

    AssistanceGroupBox:AddDivider()

    AssistanceGroupBox:AddToggle('AutoLootEnabled', {
        Text = 'Auto-Loot',
        Default = false,
        Tooltip = 'Automatically loot items when opened.'
    })

    AssistanceGroupBox:AddToggle('TakeValuables', {
        Text = 'Take Valuables',
        Default = true,
        Tooltip = 'Automatically take valuables.'
    })

    AssistanceGroupBox:AddToggle('TakeCash', {
        Text = 'Take Cash',
        Default = true,
        Tooltip = 'Automatically take cash.'
    })

end
-- Main tab

do

    local FarmingGroupBox = Tabs.Automation:AddRightGroupbox('Autofarm')

    FarmingGroupBox:AddToggle('AutoFarmEnabled', {
        Text = 'Auto-Farm',
        Default = false,
        Tooltip = 'Automatically farm money.'
    })

    FarmingGroupBox:AddDropdown('AutoFarmType', {
        Values = { 'Safe', 'Locker', 'Case', 'BunkerCrate', 'BunkerLocker' },
        Default = 1,
        Multi = true,
        Text = 'Farm type',
        Tooltip = 'Select what to farm.'
    })

    local TasksGroupBox = Tabs.Automation:AddLeftGroupbox('Tasks')

    TasksGroupBox:AddButton('Trade Valuables', function()
        local Origin = LocalPlayer.Character:GetPivot()
        local TeleportSignal, Broker = Functions.GotoNearestBroker()
        TeleportSignal:Wait()
        local HRP = Broker:WaitForChild("HumanoidRootPart", 3)
        if not HRP then
            return BypassTP(Origin):Wait()
        end
        local Prompt = HRP:WaitForChild("TalkWithNPC", 3)
        if not Prompt then
            return BypassTP(Origin):Wait()
        end

        shared.State.NoFall = true
        shared.State.NoRagdoll = true

        repeat
            RunService.Heartbeat:Wait();
            Functions.BreakVelocity()
            TP(Broker:GetPivot() - Vector3.new(0, 10, 0))
            for _, Object in next, LocalPlayer.Character:GetDescendants() do
                if Object:IsA("BasePart") then
                    Object.CanCollide = false
                end
            end
        until Attribute(LocalPlayer.PlayerGui, "CombatTimer") == 0

        for _, Limb in next, Limbs do
            local C_Limb = LocalPlayer.Character:FindFirstChild(Limb)
            if C_Limb then
                C_Limb.CanCollide = true
            end
        end

        shared.State.NoFall = false
        shared.State.NoRagdoll = false

        TP(Broker:GetPivot() + Broker.PrimaryPart.CFrame.LookVector.Unit * 3)

        local PromptAttemptThread = coroutine.create(function()
            while task.wait(0.1) do
                fireproximityprompt(Prompt)
            end
        end)
        coroutine.resume(PromptAttemptThread)

        local _, _, Choices = Remotes.DialogEvent.OnClientEvent:Wait()
        coroutine.close(PromptAttemptThread)

        for _, Choice : string in next, Choices do
            if Choice:match("valuables") then
                Remotes.DialogEvent:FireServer(Choice)
                return BypassTP(Origin):Wait()
            end
        end

        return BypassTP(Origin):Wait()

    end)

    TasksGroupBox:AddButton('Deposit All', function()
        local Origin = LocalPlayer.Character:GetPivot()
        local TeleportSignal, Terminal = Functions.GotoNearestTerminal()
        TeleportSignal:Wait()

        shared.State.NoFall = true
        shared.State.NoRagdoll = true

        repeat
            RunService.Heartbeat:Wait();
            TP(Terminal:GetPivot() - Vector3.new(0, 10, 0))
            Functions.BreakVelocity()
            for _, Object in next, LocalPlayer.Character:GetDescendants() do
                if Object:IsA("BasePart") then
                    Object.CanCollide = false
                end
            end
        until Attribute(LocalPlayer.PlayerGui, "CombatTimer") == 0

        for _, Limb in next, Limbs do
            local C_Limb = LocalPlayer.Character:FindFirstChild(Limb)
            if C_Limb then
                C_Limb.CanCollide = true
            end
        end
        
        shared.State.NoFall = false
        shared.State.NoRagdoll = false
        
        TP(Terminal:GetPivot() + Terminal.CFrame.RightVector.Unit * -3) 
        task.wait(0.1)
        Remotes.TransferCurrency:FireServer("Deposit", Attribute(LocalPlayer.PlayerGui, "Cash"))

        return BypassTP(Origin):Wait()
    end)

end

do
    local KillAuraGroupBox = Tabs.Combat:AddRightGroupbox('Kill-Aura')
    KillAuraGroupBox:AddToggle('KillAuraEnabled', {
        Text = 'Enabled',
        Default = false,
        Tooltip = 'Toggles the kill-aura.'
    })

    KillAuraGroupBox:AddSlider('KillAuraRange', {
        Text = 'Range',
        Default = 7,
        Min = 1,
        Max = 12,
        Rounding = 1,
        Compact = false
    })

    KillAuraGroupBox:AddDropdown('KillAuraParts', {
        Values = { 'Head', 'Torso' },
        Default = 1,
        Multi = false,
        Text = 'Target part(s)',
        Tooltip = 'Select parts that the killaura will target',
    })

    KillAuraGroupBox:AddToggle('KillAuraNPCs', {
        Text = 'NPCs',
        Default = true,
        Tooltip = 'Targets NPCs'
    })

    KillAuraGroupBox:AddToggle('KillAuraPlayers', {
        Text = 'Players',
        Default = false,
        Tooltip = 'Targets Players'
    })

    local GunModsGroupBox = Tabs.Combat:AddLeftGroupbox('Gun Modifications')

    GunModsGroupBox:AddToggle('InstantBulletTravel', {
        Text = 'Instant Bullet Travel',
        Default = false,
        Tooltip = 'Makes bullets travel instantly.'
    })

    GunModsGroupBox:AddToggle('InstantHit', {
        Text = 'Instant Hit [!]',
        Default = false,
        Tooltip = 'Forces bullets to hit.',
        Risky = true
    })

    GunModsGroupBox:AddDivider()

    GunModsGroupBox:AddToggle('SilentAimEnabled', {
        Text = 'Silent Aim',
        Default = false,
        Tooltip = 'Toggles the silent-aim.',
        Callback = function(Value)
            Aiming.Enabled = Value
        end
    })
    
    GunModsGroupBox:AddSlider('SilentAimFOV', {
        Text = 'FOV',
        Default = 60,
        Min = 20,
        Max = 180,
        Rounding = 0,
        Compact = false,
        Callback = function(Value)
            Aiming.FOV = Value
        end
    })

    GunModsGroupBox:AddSlider('SilentAimHitChance', {
        Text = 'Hit Chance',
        Default = 100,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Compact = false,
        Callback = function(Value)
            HitChance = Value
        end
    })

    GunModsGroupBox:AddLabel('FOV Color'):AddColorPicker('FOVColor', {
        Default = Color3.new(1, 1, 1),
        Title = 'FOV Color',
        Transparency = nil,
    
        Callback = function(Value)
            Aiming.FOVColor = Value
        end
    })

    GunModsGroupBox:AddLabel('Tracer Color'):AddColorPicker('TracerColor', {
        Default = Color3.new(1, 0, 0),
        Title = 'FOV Color',
        Transparency = nil,
    
        Callback = function(Value)
            Aiming.AimTracerColor = Value
        end
    })

    GunModsGroupBox:AddDropdown('SilentAimParts', {
        Values = { 'Head', 'Torso' },
        Default = 1,
        Multi = false,
        Text = 'Target part',
        Tooltip = 'Select parts that the silent-aim will target',
    })

    GunModsGroupBox:AddToggle('SilentAimNPCs', {
        Text = 'NPCs',
        Default = true,
        Tooltip = 'Targets NPCs',
        Callback = function(Value)
            Aiming.NPCs = Value
        end
    })

    GunModsGroupBox:AddToggle('SilentAimPlayers', {
        Text = 'Players',
        Default = true,
        Tooltip = 'Targets Players',
        Callback = function(Value)
            Aiming.Players = Value
        end
    })

end -- Combat tab

do
    local VisualModificationsGroupBox = Tabs.Visuals:AddLeftGroupbox('Modifications')
    local ESPGroupBox = Tabs.Visuals:AddRightGroupbox('ESP')

    ESPGroupBox:AddToggle('ESPEnabled', {
        Text = 'Enabled',
        Default = false,
        Tooltip = 'Toggles the ESP.',
        Callback = function(Value)
            ESP:Toggle(Value)
        end
    })

    ESPGroupBox:AddToggle('ESPBoxes', {
        Text = 'Boxes',
        Default = true,
        Tooltip = 'Toggles the ESP boxes.',
        Callback = function(Value)
            ESP.Boxes = Value
        end
    })

    ESPGroupBox:AddToggle('Tools', {
        Text = 'Tools',
        Default = true,
        Tooltip = 'Toggles the ESP tools.',
        Callback = function(Value)
            ESP.UseDistance = not Value
        end
    })

    ESPGroupBox:AddToggle('ESPNames', {
        Text = 'Names',
        Default = true,
        Tooltip = 'Toggles the ESP names.',
        Callback = function(Value)
            ESP.Names = Value
        end
    })

    ESPGroupBox:AddSlider('ESPRange', {
        Text = 'Range',
        Default = 100,
        Min = 50,
        Max = 1000,
        Rounding = 0,
        Compact = false,
        Callback = function(Value)
            ESP.PlayerDistance = Value
        end
    })

    VisualModificationsGroupBox:AddToggle('AlwaysMap', {
        Text = 'Map always enabled',
        Default = false,
        Tooltip = 'Always show the map.',
        Callback = function(Value)
            if Value then
                LocalPlayer.PlayerGui.MainGui.Minimap.NoSignal.Visible = false
                LocalPlayer.PlayerGui.MainGui.Minimap.TabsFrame.MapFrame.Visible = true
            else
                if LocalPlayer.PlayerGui.MainGui.Minimap.TabsFrame.Edge.ImageColor3 ~= Color3.fromRGB(101, 255, 84) then
                    LocalPlayer.PlayerGui.MainGui.Minimap.NoSignal.Visible = true
                    LocalPlayer.PlayerGui.MainGui.Minimap.TabsFrame.MapFrame.Visible = false
                end
            end
        end
    })
end

local function Unload()
    Library:Unload()
    Aiming.Unload()
    ESP:Unload()

    VelocityFly:Toggle(false)

    for _, Item in ipairs(Collection) do

        if typeof(Item) == 'RBXScriptConnection' then
            Item:Disconnect()
        end

        if type(Item) == 'thread' then
            coroutine.close(Item)
        end

    end

    for _, Event in next, BlockedEvents do
        RestoreConnections(Event)
    end

    for _, Limb in ipairs(Limbs) do
        LocalPlayer.Character:FindFirstChild(Limb).CanCollide = true
    end

    for _, Hook in next, HookStorage do
        hookfunction(Hook, Hook)
    end

    Unloaded = true
end

shared.sasware_unload = Unload

if LocalPlayer.Character then
    Functions.CharacterAdded(LocalPlayer.Character)
end

local OldNamecall; OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)

    if not Unloaded then
        if not checkcaller() then
            local Args = {...}
            local Method = getnamecallmethod()
            
            if Method == "FireServer" then
                if self.Name == "Damage" then
                    if Toggles.NoFall.Value or Toggles.Flight.Value or shared.State.NoFall then
                        if Args[1] ~= 1000 then -- Resetting does 1000 damage, so we ignore that
                            return
                        end
                    end
                elseif self.Name == "Ragdoll" then
                    if Toggles.NoRagdoll.Value or Toggles.Flight.Value or shared.State.NoRagdoll then
                        return
                    end
                elseif self.Name == "UpdateStates" then
                    if Toggles.AlwaysSneak.Value then
                        Args[4].Crouching = true
                        Args[4].Sprinting = false
                    end
                elseif self.Name == "Shoot" then
                    if Toggles.InstantHit.Value then
                        if Toggles.SilentAimEnabled.Value then
                            if Aiming.CurrentTarget then
                                if not shared.MissNextShot then
                                    task.delay(0.1, function()
                                        Remotes.GunHit:FireServer(
                                            Aiming.CurrentTarget[Options.SilentAimParts.Value],
                                            Args[6]
                                        )
                                    end)
                                end
                            end
                        end
                    end
                end
            elseif Method == "GetAttribute" then
                if AttributeSpoof[self] and AttributeSpoof[self].Key == Args[1] then
                    return AttributeSpoof[self].Value
                end
            end
        end
    end

    return OldNamecall(self, ...)
end)

local FireHook

local OldFire; OldFire = hookfunction(FastCast.Fire, function(...)
    return FireHook(...)
end)

FireHook = function(...)

    if not Unloaded then
        local Args = {...}
        local Caller = getcallingscript()

        if tostring(Caller) == "GunHandler" then

            shared.MissNextShot = Miss()

            if Toggles.InstantBulletTravel.Value then
                Args[4] = 90000
            end

            if not shared.MissNextShot then
                if Toggles.SilentAimEnabled.Value then
                    if Aiming.CurrentTarget then
                        Args[3] = (Aiming.CurrentTarget[Options.SilentAimParts.Value].Position - Args[2])
                    end
                end
            end

            return OldFire(unpack(Args))
        end
    end

    return OldFire(...)
end

local MenuGroup = Tabs.UISettings:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', Unload)

Collect(RunService.RenderStepped:Connect(function()
    Library:SetWatermark('Current connections: ' .. #Collection)
end))

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightControl', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()

SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('sasware_blackout')
SaveManager:SetFolder('sasware_blackout/main')

SaveManager:BuildConfigSection(Tabs.UISettings)

ThemeManager:ApplyToTab(Tabs.UISettings)

coroutine.resume(FloorHideCoroutine)
coroutine.resume(KillAuraCoroutine)
coroutine.resume(EventBlockerCoroutine)
coroutine.resume(AutofarmCoroutine)
