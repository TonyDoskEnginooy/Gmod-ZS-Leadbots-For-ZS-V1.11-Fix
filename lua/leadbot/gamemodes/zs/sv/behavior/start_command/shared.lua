ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local leadbot_zcheats = GetConVar("leadbot_zcheats")
local leadbot_hordes = GetConVar("leadbot_hordes")
local leadbot_quota = GetConVar("leadbot_quota")

local FALLBACK_TEMPERAMENT = {
    name = "rusher",
    holdBonus = 220,
    imperfection = 30,
    preferWeak = 1.0,
    obstacleBias = 0
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
        and IsValid(target)
        and bot:Team() == TEAM_SURVIVORS
        and target:Team() == TEAM_ZOMBIE
        and target:IsPlayer()
        and target:Alive()
        and not target:HasGodMode()
        and ZSB.Util:CanPerceiveTarget(bot, target)
end

function SC.IsEnemyCandidate(bot, ent)
    if not IsValid(ent) or ent == bot then
        return false
    end

    if ent:IsPlayer() then
        return ent:Alive()
            and ent:Team() ~= bot:Team()
            and not ent:HasGodMode()
            and ZSB.Util:CanPerceiveTarget(bot, ent)
    end

    return ent:IsNPC() and bot:Team() == TEAM_SURVIVORS
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

function SC.IsFragileMapBreakable(ent)
    if not IsValid(ent) or ent:GetClass() ~= "func_breakable" then
        return false
    end

    if not ZSB.Map:GetValue("zombieBreakCheck") then
        return false
    end

    if not ent.GetMaxHealth then
        return true
    end

    return ent:GetMaxHealth() <= 500
end

function SC.IsSimpleObstacleTarget(_, ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass()

    if class == "func_breakable" or class == "func_physbox" then
        if ent.GetMaxHealth and ent:GetMaxHealth() > 1 then
            return true
        end

        return class == "func_breakable" and SC.IsFragileMapBreakable(ent)
    end

    if class == "func_breakable_surf" then
        return true
    end

    if class == "prop_physics" then
        if not ent.GetMaxHealth then
            return false
        end

        local model = ent:GetModel()

        if SC.IsIgnoredPropModel(model) then
            return false
        end

        if SC.IsBoardModel(model) then
            return SC.IsMapBoardEntity(ent)
        end

        return true
    end

    if class == "prop_dynamic" then
        return ent.GetMaxHealth and ent:GetMaxHealth() > 1
    end

    if class == "func_physbox" then
        return ent.GetMaxHealth and ent:GetMaxHealth() > 1
    end

    return false
end