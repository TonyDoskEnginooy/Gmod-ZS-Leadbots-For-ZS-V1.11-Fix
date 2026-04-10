util.AddNetworkString("leadbot_Flashlight_Request")
util.AddNetworkString("leadbot_Flashlight_Report")

local flashlightConVar = CreateConVar("leadbot_flashlight", "1", FCVAR_ARCHIVE, "Flashlight for bots")

local REQUEST_INTERVAL = 0.5
local REQUEST_TIMEOUT = 0.5
local TOGGLE_COOLDOWN = 0.3
local REQUIRED_DARK_SAMPLES = 3
local DARKNESS_THRESHOLD_SQR = 0.0001

local nextRequestAt = 0
local pendingRequest = nil

local function FlashlightsEnabled()
    return flashlightConVar:GetBool() and not LeadBot.NoFlashlight
end

local function IsTrackedBot(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:IsLBot()
end

local function BuildTrackedBotList()
    local bots = {}

    for _, ply in ipairs(player.GetAll()) do
        if IsTrackedBot(ply) then
            bots[#bots + 1] = ply
        end
    end

    return bots
end

local function ClearPendingRequest()
    pendingRequest = nil
end

local function UpdateBotFlashlightState(bot, lightColor)
    bot.LeadBotDarkSamples = bot.LeadBotDarkSamples or 0

    local isDark = lightColor:LengthSqr() <= DARKNESS_THRESHOLD_SQR

    if isDark then
        bot.LeadBotDarkSamples = math.min(bot.LeadBotDarkSamples + 1, REQUIRED_DARK_SAMPLES)
    else
        bot.LeadBotDarkSamples = 0
    end

    bot.FlashlightOn = isDark and bot.LeadBotDarkSamples >= REQUIRED_DARK_SAMPLES
end

hook.Add("Think", "leadbot_Flashlight", function()
    if not FlashlightsEnabled() then
        ClearPendingRequest()
        return
    end

    if pendingRequest and (not IsValid(pendingRequest.requester) or pendingRequest.expireAt < CurTime()) then
        ClearPendingRequest()
    end

    if nextRequestAt > CurTime() then return end

    local humans = player.GetHumans()
    if #humans == 0 then return end

    local bots = BuildTrackedBotList()
    if #bots == 0 then
        nextRequestAt = CurTime() + REQUEST_INTERVAL
        return
    end

    local requester = table.Random(humans)

    pendingRequest = {
        requester = requester,
        expireAt = CurTime() + REQUEST_TIMEOUT,
        bots = {}
    }

    net.Start("leadbot_Flashlight_Request")
        net.WriteUInt(#bots, 8)
        for _, bot in ipairs(bots) do
            pendingRequest.bots[bot] = true
            net.WriteEntity(bot)
        end
    net.Send(requester)

    nextRequestAt = CurTime() + REQUEST_INTERVAL
end)

net.Receive("leadbot_Flashlight_Report", function(_, ply)
    local request = pendingRequest
    if not request then return end
    if ply ~= request.requester then return end
    if request.expireAt < CurTime() then
        ClearPendingRequest()
        return
    end

    local reportedCount = net.ReadUInt(8)
    local processedBots = {}

    for _ = 1, reportedCount do
        local bot = net.ReadEntity()
        local lightColor = net.ReadVector()

        if not processedBots[bot] and IsTrackedBot(bot) and request.bots[bot] then
            processedBots[bot] = true
            UpdateBotFlashlightState(bot, lightColor)
        end
    end

    ClearPendingRequest()
end)

hook.Add("StartCommand", "leadbot_Flashlight", function(ply, cmd)
    if not IsTrackedBot(ply) then return end

    local desiredState = FlashlightsEnabled() and ply.FlashlightOn == true
    local currentState = ply:FlashlightIsOn()

    if desiredState == currentState then return end

    ply.NextLeadBotFlashlightToggle = ply.NextLeadBotFlashlightToggle or 0
    if ply.NextLeadBotFlashlightToggle > CurTime() then return end

    cmd:SetImpulse(100)
    ply.NextLeadBotFlashlightToggle = CurTime() + TOGGLE_COOLDOWN
end)