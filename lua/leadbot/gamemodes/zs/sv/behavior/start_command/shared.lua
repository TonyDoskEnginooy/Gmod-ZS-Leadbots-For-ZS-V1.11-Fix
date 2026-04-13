ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local leadbot_zcheats = GetConVar("leadbot_zcheats")
local leadbot_hordes = GetConVar("leadbot_hordes")
local leadbot_quota = GetConVar("leadbot_quota")

local FALLBACK_TEMPERAMENT = {
    name = "rusher",
    loadPenalty = 60,
    holdBonus = 220,
    imperfection = 30,
    preferWeak = 1.0,
    obstacleBias = 0,
    flankBias = 0.15,
    moveSpeedMul = 1.0
}


function SC.HasEntries(list)
    return istable(list) and #list > 0
end

function SC.ApplyZombieCheats(bot)
    if bot:Team() ~= TEAM_ZOMBIE or not leadbot_zcheats:GetBool() then return end

    local zombieClass = bot:GetZombieClass()

    if zombieClass == 8 then
        bot:Freeze(false)
    end

    if (zombieClass == 3 or zombieClass == 5) and ZombieClasses and ZombieClasses[zombieClass] then
        GAMEMODE:SetPlayerSpeed(bot, ZombieClasses[zombieClass].Speed)
    end
end

function SC.KillLonelyHordeBot(bot)
    if leadbot_hordes:GetInt() >= 1 and bot:Team() == TEAM_SURVIVORS and leadbot_quota:GetInt() < 2 then
        bot:Kill()
    end
end
function SC.GetTemperament(bot)
    return bot.LBConfig.temperament or FALLBACK_TEMPERAMENT
end

function SC.StableNoise(bot, ent, magnitude)
    local bucket = math.floor(CurTime() * 1.5)
    local seed = (bot.LBConfig.personalitySeed or 1) * 0.013 + ent:EntIndex() * 0.173 + bucket * 0.071
    return math.sin(seed * 23.417) * magnitude
end

function SC.GetDistanceScore(distanceSqr)
    if distanceSqr <= 2500 then
        return 260
    elseif distanceSqr <= 22500 then
        return 180
    elseif distanceSqr <= 90000 then
        return 100
    elseif distanceSqr <= 250000 then
        return 20
    end

    return -80
end

function SC.IsValidEnemyZombie(bot, target)
    return IsValid(bot)
        and bot:Team() == TEAM_SURVIVORS
        and IsValid(target)
        and target:IsPlayer()
        and target:Alive()
        and target:Team() == TEAM_ZOMBIE
        and not target:HasGodMode()
        and ZSB.Util:CanPerceiveTarget(bot, target)
end

function SC.IsIgnoredPropModel(model)
    return model == "models/props_c17/playground_carousel01.mdl"
        or model == "models/props_wasteland/prison_lamp001a.mdl"
end

function SC.IsBoardModel(model)
    return model == "models/props_debris/wood_board04a.mdl"
        or model == "models/props_debris/wood_board05a.mdl"
        or model == "models/props_debris/wood_board06a.mdl"
end

function SC.IsMapBoardEntity(ent)
    return IsValid(ent)
        and ent:GetClass() == "prop_physics"
        and SC.IsBoardModel(ent:GetModel())
        and ent.CreatedByMap
        and ent:CreatedByMap()
end

function SC.IsActiveSurvivorMelee(bot)
    if bot:Team() ~= TEAM_SURVIVORS then
        return false
    end

    local weapon = bot:GetActiveWeapon()
    if not IsValid(weapon) then
        return false
    end

    local className = string.lower(weapon:GetClass() or "")

    return className == "weapon_zs_swissarmyknife"
        or className:find("knife", 1, true)
        or className:find("crowbar", 1, true)
        or className:find("fists", 1, true)
        or className:find("machete", 1, true)
        or className:find("melee", 1, true)
end
