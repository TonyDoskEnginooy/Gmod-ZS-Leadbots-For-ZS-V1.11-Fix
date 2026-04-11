ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

if SC._SharedLoaded then
    return
end

SC._SharedLoaded = true

local leadbot_zcheats = GetConVar("leadbot_zcheats")
local leadbot_hordes = GetConVar("leadbot_hordes")
local leadbot_quota = GetConVar("leadbot_quota")

SC.TARGET_LOAD = SC.TARGET_LOAD or setmetatable({}, { __mode = "k" })

SC.NEXT_TARGET_LOAD_REFRESH = SC.NEXT_TARGET_LOAD_REFRESH or 0

SC.FALLBACK_ZOMBIE_TEMPERAMENT = SC.FALLBACK_ZOMBIE_TEMPERAMENT or {
    name = "rusher",
    loadPenalty = 60,
    holdBonus = 220,
    imperfection = 30,
    preferWeak = 1.0,
    obstacleBias = 0,
    flankBias = 0.15,
    moveSpeedMul = 1.0
}

SC.THROW_PROP_ZOMBIE_CLASSES = SC.THROW_PROP_ZOMBIE_CLASSES or {
    ["Zombie"] = true,
    ["Poison Zombie"] = true
}

function SC.HasEntries(list)
    return istable(list) and #list > 0
end

function SC.EnsureControllerState(controller)
    controller.ForgetTarget = controller.ForgetTarget or 0
    controller.LastSegmented = controller.LastSegmented or 0
    controller.NextJump = controller.NextJump or 0
    controller.NextCenter = controller.NextCenter or 0
    controller.nextStuckJump = controller.nextStuckJump or 0
    controller.LastStairTime = controller.LastStairTime or 0
    controller.strafeAngle = controller.strafeAngle or 1
    controller.NextPropThrow = controller.NextPropThrow or 0
    controller.MeleeRetreatUntil = controller.MeleeRetreatUntil or 0
    controller.LastMeleeAttackTime = controller.LastMeleeAttackTime or 0
end

function SC.SetRoamState(bot)
    if bot:Team() ~= TEAM_SURVIVORS then return end

    if bot:Health() <= 50 or team.NumPlayers(TEAM_SURVIVORS) <= team.NumPlayers(TEAM_ZOMBIE) then
        bot.freeRoam = false
    end
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

function SC.ForgetInvalidTarget(controller)
    if not IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end
end

function SC.GetZombieTemperament(bot)
    return bot.LeadBot_ZombieTemperament or SC.FALLBACK_ZOMBIE_TEMPERAMENT
end

function SC.StableNoise(bot, ent, magnitude)
    local bucket = math.floor(CurTime() * 1.5)
    local seed = (bot.LeadBot_PersonalitySeed or 1) * 0.013 + ent:EntIndex() * 0.173 + bucket * 0.071
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

function SC.IsIgnoredPropModel(model)
    return model == "models/props_c17/playground_carousel01.mdl"
        or model == "models/props_wasteland/prison_lamp001a.mdl"
end

function SC.IsBoardModel(model)
    return model == "models/props_debris/wood_board04a.mdl"
        or model == "models/props_debris/wood_board05a.mdl"
        or model == "models/props_debris/wood_board06a.mdl"
end
