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
SC.OBSTACLE_TARGET_TIMEOUT = SC.OBSTACLE_TARGET_TIMEOUT or 4
SC.OBSTACLE_TARGET_RETRY_DELAY = SC.OBSTACLE_TARGET_RETRY_DELAY or 6
SC.OBSTACLE_TARGET_SWING_LIMIT_MIN = SC.OBSTACLE_TARGET_SWING_LIMIT_MIN or 1
SC.OBSTACLE_TARGET_SWING_LIMIT_MAX = SC.OBSTACLE_TARGET_SWING_LIMIT_MAX or 2
SC.OBSTACLE_TARGET_SWING_DEBOUNCE = SC.OBSTACLE_TARGET_SWING_DEBOUNCE or 0.55

SC.FALLBACK_TEMPERAMENT = SC.FALLBACK_TEMPERAMENT or {
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
    controller.NextRandomJump = controller.NextRandomJump or 0
    controller.LastStairTime = controller.LastStairTime or 0
    controller.strafeAngle = controller.strafeAngle or 1
    controller.NextPropThrow = controller.NextPropThrow or 0
    controller.NextPoisonZombieThrow = controller.NextPoisonZombieThrow or 0
    controller.ObstacleTargetSince = controller.ObstacleTargetSince or 0
    controller.ObstacleTargetRetryUntil = controller.ObstacleTargetRetryUntil or 0
    controller.ActiveObstacleTarget = controller.ActiveObstacleTarget or nil
    controller.LastObstacleTarget = controller.LastObstacleTarget or nil
    controller.ObstacleSwingCount = controller.ObstacleSwingCount or 0
    controller.ObstacleSwingLimit = controller.ObstacleSwingLimit or 0
    controller.NextObstacleSwingCount = controller.NextObstacleSwingCount or 0
    controller.RecentCloseThreatUntil = controller.RecentCloseThreatUntil or 0
    controller.NextSurvivorBreakAttempt = controller.NextSurvivorBreakAttempt or 0
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

function SC.ResetObstacleSwingState(controller)
    controller.ObstacleSwingCount = 0
    controller.ObstacleSwingLimit = 0
    controller.NextObstacleSwingCount = 0
end

function SC.BeginObstacleTarget(controller, target)
    controller.ActiveObstacleTarget = target
    controller.ObstacleTargetSince = CurTime()
    controller.ObstacleSwingCount = 0
    controller.ObstacleSwingLimit = math.random(
        SC.OBSTACLE_TARGET_SWING_LIMIT_MIN,
        SC.OBSTACLE_TARGET_SWING_LIMIT_MAX
    )
    controller.NextObstacleSwingCount = 0
end

function SC.RegisterObstacleSwing(controller, target)
    if not IsValid(controller) or not IsValid(target) or controller.Target ~= target then
        return false
    end

    if controller.ActiveObstacleTarget ~= target then
        SC.BeginObstacleTarget(controller, target)
    end

    if controller.NextObstacleSwingCount > CurTime() then
        return false
    end

    controller.ObstacleSwingCount = (controller.ObstacleSwingCount or 0) + 1
    controller.NextObstacleSwingCount = CurTime() + SC.OBSTACLE_TARGET_SWING_DEBOUNCE

    if controller.ObstacleSwingCount >= math.max(controller.ObstacleSwingLimit or 0, 1) then
        SC.MarkObstacleTargetTimedOut(controller, target)
    end

    return true
end

function SC.ClearObstacleTargetState(controller)
    controller.ActiveObstacleTarget = nil
    controller.ObstacleTargetSince = 0
    SC.ResetObstacleSwingState(controller)
end

function SC.MarkObstacleTargetTimedOut(controller, target)
    controller.LastObstacleTarget = target
    controller.ObstacleTargetRetryUntil = CurTime() + SC.OBSTACLE_TARGET_RETRY_DELAY
    SC.ClearObstacleTargetState(controller)
    controller.Target = nil
    controller.PosGen = nil
end

function SC.ForgetInvalidTarget(bot, controller)
    local target = controller.Target
    local targetIsLivingActor = IsValid(target) and (target:IsPlayer() or target:IsNPC())

    if not IsValid(target)
    or controller.ForgetTarget < CurTime()
    or (targetIsLivingActor and target:Health() < 1)
    or (target:IsPlayer() and target:HasGodMode())
    or not ZSB.Util:CanPerceiveTarget(bot, target) then
        controller.Target = nil
        SC.ClearObstacleTargetState(controller)
        return
    end

    if not SC.IsSimpleObstacleTarget(bot, target) then
        SC.ClearObstacleTargetState(controller)
        return
    end

    if controller.ActiveObstacleTarget ~= target then
        SC.BeginObstacleTarget(controller, target)
        return
    end

    if controller.ObstacleTargetSince + SC.OBSTACLE_TARGET_TIMEOUT < CurTime() then
        SC.MarkObstacleTargetTimedOut(controller, target)
    end
end

function SC.GetTemperament(bot)
    return bot.LeadBot_Temperament or SC.FALLBACK_TEMPERAMENT
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

function SC.IsZombiePlayerEnemy(bot, target)
    return IsValid(bot)
        and bot:Team() == TEAM_SURVIVORS
        and IsValid(target)
        and target:IsPlayer()
        and target:Alive()
        and target:Team() == TEAM_ZOMBIE
        and not target:HasGodMode()
        and ZSB.Util:CanPerceiveTarget(bot, target)
end

function SC.SetRecentCloseThreat(controller, target, duration)
    if not IsValid(controller) then
        return
    end

    if not IsValid(target) then
        controller.RecentCloseThreat = nil
        controller.RecentCloseThreatUntil = 0
        return
    end

    controller.RecentCloseThreat = target
    controller.RecentCloseThreatUntil = CurTime() + math.max(duration or 0, 0)
end

function SC.GetRecentCloseThreat(controller)
    if not IsValid(controller) then
        return nil
    end

    if (controller.RecentCloseThreatUntil or 0) < CurTime() then
        controller.RecentCloseThreat = nil
        return nil
    end

    local target = controller.RecentCloseThreat

    if not IsValid(target) then
        controller.RecentCloseThreat = nil
        controller.RecentCloseThreatUntil = 0
        return nil
    end

    if target:IsPlayer() and (not target:Alive() or target:Health() < 1) then
        controller.RecentCloseThreat = nil
        controller.RecentCloseThreatUntil = 0
        return nil
    end

    return target
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