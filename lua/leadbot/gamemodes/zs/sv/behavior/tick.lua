-- Cache cvars
local leadbot_hordes = GetConVar("leadbot_hordes")
local leadbot_cs = GetConVar("leadbot_cs")
local leadbot_quota = GetConVar("leadbot_quota")
local leadbot_minzombies = GetConVar("leadbot_minzombies")

local DEFAULT_ZOMBIE_CLASS = 1
local CS_ZOMBIE_SPEED = 200
local CS_HUMAN_HEALTH = 30

ZSB = ZSB or {}

local function GetMinimumZombieCount(totalPlayers)
    return math.ceil(totalPlayers * (leadbot_minzombies:GetInt() * 0.01))
end

local function ShouldRedeemPlayers(quota)
    return ZSB.INTERMISSION == 1
        and leadbot_hordes:GetInt() >= 1
        and quota < 2
end

local function ApplyCounterStrikeRules(ply)
    if ply:Team() == TEAM_ZOMBIE then
        if ZSB then
            ZSB.playerCSSpeed = CS_ZOMBIE_SPEED
        end

        GAMEMODE:SetPlayerSpeed(ply, CS_ZOMBIE_SPEED, CS_ZOMBIE_SPEED)

        if ply:GetZombieClass() ~= DEFAULT_ZOMBIE_CLASS then
            ply:SetZombieClass(DEFAULT_ZOMBIE_CLASS)
        end

        return
    end

    if ply:Health() > CS_HUMAN_HEALTH then
        ply:SetMaxHealth(CS_HUMAN_HEALTH)
        ply:SetHealth(CS_HUMAN_HEALTH)
    end
end

local function TryConvertSurvivorBot(bot, totalPlayers, minimumZombies, totalZombies, pendingZombieCount, quota)
    if bot:Team() ~= TEAM_SURVIVORS then
        return pendingZombieCount
    end

    if totalPlayers < quota then
        return pendingZombieCount
    end

    if minimumZombies <= totalZombies + pendingZombieCount then
        return pendingZombieCount
    end

    bot:Kill()
    return pendingZombieCount + 1
end

local function TryRespawnBot(bot, now)
    if not LeadBot.RespawnAllowed then return end
    if not bot.NextSpawnTime then return end
    if bot:Alive() then return end
    if bot.NextSpawnTime >= now then return end

    bot:Spawn()
end

local function TryRedeemZombiePlayer(ply, redeemPlayers)
    if redeemPlayers and ply:Team() == TEAM_ZOMBIE then
        ply:Redeem()
    end
end

local function KillLonelyHordeBot(quota, bot)
    if quota < 2 and bot:IsBot() and bot:Team() == TEAM_SURVIVORS then
        bot:Kill()
    end
end

function LeadBot.Tick()
    local players = player.GetAll()
    local totalPlayers = #players
    local quota = leadbot_quota:GetInt()
    local minimumZombies = GetMinimumZombieCount(totalPlayers)
    local redeemPlayers = ShouldRedeemPlayers(quota)
    local csMode = leadbot_cs:GetBool()
    local totalZombies = team.NumPlayers(TEAM_ZOMBIE)
    local pendingZombieCount = 0
    local now = CurTime()
    
    for _, ply in ipairs(players) do
        if csMode then
            ApplyCounterStrikeRules(ply)
        end

        if ply:IsLBot() then
            pendingZombieCount = TryConvertSurvivorBot(
                ply,
                totalPlayers,
                minimumZombies,
                totalZombies,
                pendingZombieCount,
                quota
            )

            TryRespawnBot(ply, now)
        else
            TryRedeemZombiePlayer(ply, redeemPlayers)
        end

        KillLonelyHordeBot(quota, ply)
    end

    totalZombies = team.NumPlayers(TEAM_ZOMBIE)

    if totalZombies >= 1 and totalZombies < totalPlayers then
        ZSB.INTERMISSION = 0
    end
end