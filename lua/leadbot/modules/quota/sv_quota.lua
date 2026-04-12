local quotaCvar = CreateConVar(
    "leadbot_quota",
    "24",
    {FCVAR_ARCHIVE},
    "TF2 Style Quota for bots\nUse leadbot_add if you want unkickable bots",
    0
)

local nextCheck = 0
local quotaGeneration = 0

local function GetQuota()
    return math.max(quotaCvar:GetInt(), 0)
end

local function GetLeadBots()
    local bots = {}

    for _, ply in ipairs(player.GetBots()) do
        if IsValid(ply) and ply:IsLBot(true) then
            bots[#bots + 1] = ply
        end
    end

    return bots
end

local function GetAllowedBotCount()
    return math.max(GetQuota() - #player.GetHumans(), 0)
end

local function KickExcessBots(bots, allowedBots)
    if #bots <= allowedBots then return end

    for i = allowedBots + 1, #bots do
        local bot = bots[i]
        if IsValid(bot) then
            bot:Kick()
        end
    end
end

local function ScheduleMissingBots(currentBots, allowedBots)
    local missingBots = allowedBots - currentBots
    if missingBots <= 0 then return end

    local currentGeneration = quotaGeneration

    nextCheck = CurTime() + 0.5

    for i = 1, missingBots do
        timer.Simple(0.1 + (i * 0.5), function()
            if currentGeneration ~= quotaGeneration then return end
            if GetQuota() <= 0 then return end

            local liveAllowedBots = GetAllowedBotCount()
            local liveBots = GetLeadBots()

            if #liveBots >= liveAllowedBots then return end

            LeadBot.AddBot()
        end)

        nextCheck = nextCheck + 0.5
    end
end

cvars.AddChangeCallback("leadbot_quota", function(_, oldValue, newValue)
    oldValue = tonumber(oldValue) or 0
    newValue = tonumber(newValue) or 0

    quotaGeneration = quotaGeneration + 1

    if oldValue > 0 and newValue <= 0 then
        RunConsoleCommand("leadbot_kick", "all")
    end
end, "LeadBot_Quota")

hook.Add("Think", "LeadBot_Quota", function()
    if GetQuota() <= 0 then return end
    if nextCheck >= CurTime() then return end

    local bots = GetLeadBots()
    local allowedBots = GetAllowedBotCount()

    KickExcessBots(bots, allowedBots)
    ScheduleMissingBots(#bots, allowedBots)

    if #bots >= allowedBots then
        nextCheck = CurTime() + 1
    end
end)