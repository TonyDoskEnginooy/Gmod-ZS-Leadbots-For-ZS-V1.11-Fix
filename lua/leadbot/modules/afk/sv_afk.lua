util.AddNetworkString("LeadBot_AFK_Off")

local afkTimeCvar = CreateConVar("leadbot_afk_timetoafk", "300", {FCVAR_ARCHIVE})

local function IsValidAFKPlayer(ply)
    return IsValid(ply) and ply:IsPlayer()
end

local function GetAFKTimeout()
    return afkTimeCvar:GetFloat()
end

local function IsAFKEnabled()
    return afkTimeCvar:GetBool()
end

local function ResetAFKTimer(ply)
    ply.LastAFKCheck = CurTime() + GetAFKTimeout()
end

local function ShouldResetAFKTimer(ply)
    return ply:KeyDown(IN_FORWARD)
        or ply:KeyDown(IN_BACK)
        or ply:KeyDown(IN_MOVELEFT)
        or ply:KeyDown(IN_MOVERIGHT)
        or ply:KeyDown(IN_ATTACK)
end

local function ShouldBecomeAFKBot(ply)
    return ply.LastAFKCheck < CurTime()
        and not ply:IsLBot()
        and not ply:GetNWBool("LeadBot_AFK")
end

concommand.Add("leadbot_afk", function(ply)
    if not IsValidAFKPlayer(ply) then return end
    LeadBot.Botize(ply)
end, nil, "Adds a LeadBot ;)")

net.Receive("LeadBot_AFK_Off", function(_, ply)
    if not IsValidAFKPlayer(ply) then return end

    LeadBot.Botize(ply, false)
    ResetAFKTimer(ply)
end)

hook.Add("PlayerTick", "LeadBot_AFK", function(ply)
    if not IsAFKEnabled() then return end
    if not IsValidAFKPlayer(ply) then return end

    if ply.LastAFKCheck == nil then
        ResetAFKTimer(ply)
    end

    if ShouldResetAFKTimer(ply) then
        ResetAFKTimer(ply)
    end

    if ShouldBecomeAFKBot(ply) then
        LeadBot.Botize(ply, true)
    end
end)

function LeadBot.Botize(ply, togg)
    if not IsValidAFKPlayer(ply) then return false end

    if togg == nil then
        togg = not ply.Botized
    end

    local stateChanging = (not togg and ply.Botized) or (togg and not ply.Botized)

    if stateChanging and LeadBot.SuicideAFK and ply:Alive() then
        ply:Kill()
    end

    if not togg then
        ply:SetNWBool("LeadBot_AFK", false)
        ply.Botized = false

        if IsValid(ply.ControllerBot) then
            ply.ControllerBot:Remove()
            ply.ControllerBot = nil
        end

        ply.LastSegmented = CurTime()
        ply.CurSegment = 2

        return true
    end

    ply:SetNWBool("LeadBot_AFK", true)
    ply.Botized = true
    ply.BotColor = ply:GetPlayerColor()
    ply.BotSkin = ply:GetSkin()
    ply.BotModel = ply:GetModel()
    ply.BotWColor = ply:GetWeaponColor()

    local controller = ents.Create("leadbot_navigator")
    if not IsValid(controller) then
        ply:SetNWBool("LeadBot_AFK", false)
        ply.Botized = false
        return false
    end

    controller:Spawn()
    controller:SetOwner(ply)
    controller:SetFOV(ply:GetFOV())

    ply.ControllerBot = controller
    ply.LastSegmented = CurTime()
    ply.CurSegment = 2

    ply.LBConfig = {}

    if GetConVar("leadbot_strategy"):GetBool() then
        ply.LBConfig.strategy = math.random(0, LeadBot.Strategies)
    else
        ply.LBConfig.strategy = nil
    end

    ply.LBConfig = {
        model = ply.BotModel,
        color = ply.BotColor,
        weaponColor = ply.BotWColor,
        strategy = ply.LBConfig.strategy
    }

    return true
end