ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local CLOSE_THREAT_DISTANCE_SQR = 220 * 220
local FACING_THREAT_DISTANCE_SQR = 320 * 320
local RECENT_THREAT_DISTANCE_SQR = 260 * 260
local SURVIVOR_BREAK_IMMEDIATE_THREAT_DISTANCE_SQR = 180 * 180

local NEXT_TARGET_LOAD_REFRESH = 0
local TARGET_LOAD = setmetatable({}, { __mode = "k" })

local function IsEnemyCandidate(bot, ent)
    if not IsValid(ent) or ent == bot then return false end

    if ent:IsPlayer() then
        return ent:Alive()
            and ent:Team() ~= bot:Team()
            and not ent:HasGodMode()
            and ZSB.Util:CanPerceiveTarget(bot, ent)
    end

    return ent:IsNPC() and bot:Team() == TEAM_SURVIVORS
end

local function ShouldAvoidChemZombie(bot, ent)
    if not ent:IsPlayer() or bot:Team() ~= TEAM_SURVIVORS or not ent.GetZombieClass then
        return false
    end

    return ent:GetZombieClass() == 4 and (ZSB.Util:Odds(25) or ent:GetPos():DistToSqr(bot:GetPos()) <= 67500)
end

local function ClearTargetLoad()
    for ent in pairs(TARGET_LOAD) do
        TARGET_LOAD[ent] = nil
    end
end

local function RefreshTargetLoad()
    if NEXT_TARGET_LOAD_REFRESH > CurTime() then return end

    ClearTargetLoad()

    for _, ply in ipairs(player.GetBots()) do
        if IsValid(ply) and ply.IsLBot and ply:IsLBot() then
            local controller = ply:GetController()

            if IsValid(controller) and IsValid(controller.Target) then
                TARGET_LOAD[controller.Target] = (TARGET_LOAD[controller.Target] or 0) + 1
            end
        end
    end

    NEXT_TARGET_LOAD_REFRESH = CurTime() + 0.2
end

local function ScoreTarget(bot, controller, target, sourceTag)
    if not IsEnemyCandidate(bot, target) or ShouldAvoidChemZombie(bot, target) then
        return nil
    end

    local temperament = SC.GetTemperament(bot)
    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())
    local score = 0

    if target:IsPlayer() then
        score = score + 1350
        score = score + math.Clamp((100 - target:Health()) * temperament.preferWeak * 1.5, 0, 180)
    elseif target:IsNPC() then
        score = score + 900
    end

    score = score + SC.GetDistanceScore(distanceSqr)

    if sourceTag == "facing_player" then
        score = score + 220
    elseif sourceTag == "near_player" or sourceTag == "near_npc" then
        score = score + 140
    elseif sourceTag == "area_player" or sourceTag == "area_npc" then
        score = score + 55
    end

    if target == controller.Target then
        score = score + temperament.holdBonus
    end

    local load = TARGET_LOAD[target] or 0

    if target == controller.Target and load > 0 then
        load = load - 1
    end

    local loadPenalty = temperament.loadPenalty

    if bot:Team() == TEAM_SURVIVORS and target:IsPlayer() then
        loadPenalty = math.max(loadPenalty, 125)
    end

    score = score - (load * loadPenalty)
    score = score + SC.StableNoise(bot, target, temperament.imperfection)

    return score
end

local function ConsiderBestTarget(bot, controller, state, list, sourceTag, scorer)
    if not SC.HasEntries(list) then return end

    for _, ent in ipairs(list) do
        if IsValid(ent) then
            local score = scorer(bot, controller, ent, sourceTag)

            if score and score > state.bestScore then
                state.bestScore = score
                state.bestTarget = ent
            end
        end
    end
end

local function ScoreEmergencySurvivorThreat(bot, controller, target, sourceTag)
    if not SC.IsValidEnemyZombie(bot, target) or ShouldAvoidChemZombie(bot, target) then
        return nil
    end

    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())
    local recentThreat = SC.GetRecentCloseThreat(controller)
    local maxDistanceSqr = CLOSE_THREAT_DISTANCE_SQR

    if sourceTag == "panic_facing_player" then
        maxDistanceSqr = FACING_THREAT_DISTANCE_SQR
    elseif target == recentThreat then
        maxDistanceSqr = RECENT_THREAT_DISTANCE_SQR
    end

    if distanceSqr > maxDistanceSqr then
        return nil
    end

    local score = 4200 - (distanceSqr * 0.012)

    if sourceTag == "panic_facing_player" then
        score = score + 850
    end

    if target == recentThreat then
        score = score + 1700
    end

    if distanceSqr <= 110 * 110 then
        score = score + 1300
    elseif distanceSqr <= 170 * 170 then
        score = score + 800
    else
        score = score + 250
    end

    if target == controller.Target then
        score = score + 120
    end

    return score
end

function SC.HasImmediateZombieThreat(bot, controller, foundEnts)
    if IsValid(SC.GetRecentCloseThreat(controller)) then
        return true
    end

    local nearPlayers = foundEnts and foundEnts.near and foundEnts.near["player"] or nil

    if SC.HasEntries(nearPlayers) then
        for _, target in ipairs(nearPlayers) do
            if SC.IsValidEnemyZombie(bot, target) then
                return true
            end
        end
    end

    local facingPlayers = foundEnts and foundEnts.facing and foundEnts.facing["player"] or nil

    if SC.HasEntries(facingPlayers) then
        for _, target in ipairs(facingPlayers) do
            if SC.IsValidEnemyZombie(bot, target)
                and bot:GetPos():DistToSqr(target:GetPos()) <= SURVIVOR_BREAK_IMMEDIATE_THREAT_DISTANCE_SQR
            then
                return true
            end
        end
    end

    return false
end

function SC.AcquireEmergencySurvivorThreat(bot, controller, foundEnts)
    if bot:Team() ~= TEAM_SURVIVORS then
        return nil
    end

    local state = {
        bestScore = -math.huge,
        bestTarget = nil
    }

    local recentThreat = SC.GetRecentCloseThreat(controller)

    if IsValid(recentThreat) then
        local score = ScoreEmergencySurvivorThreat(bot, controller, recentThreat, "panic_recent")

        if score and score > state.bestScore then
            state.bestScore = score
            state.bestTarget = recentThreat
        end
    end

    ConsiderBestTarget(bot, controller, state, foundEnts.facing["player"], "panic_facing_player", ScoreEmergencySurvivorThreat)
    ConsiderBestTarget(bot, controller, state, foundEnts.area["player"], "panic_area_player", ScoreEmergencySurvivorThreat)

    return state.bestTarget
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

function SC.AcquireTemperamentTarget(bot, controller, foundEnts)
    RefreshTargetLoad()

    if math.random(1, 100) <= 40 then
        local emergencyTarget = SC.AcquireEmergencySurvivorThreat(bot, controller, foundEnts)

        if IsValid(emergencyTarget) then
            controller.Target = emergencyTarget
            controller.ForgetTarget = CurTime() + 1.1
            return
        end
    end

    local state = {
        bestScore = -math.huge,
        bestTarget = nil
    }

    ConsiderBestTarget(bot, controller, state, foundEnts.facing["player"], "facing_player", ScoreTarget)
    ConsiderBestTarget(bot, controller, state, foundEnts.near["NPCs"], "near_npc", ScoreTarget)

    if IsValid(state.bestTarget) and bot:Team() == TEAM_ZOMBIE then
        --ConsiderBestTarget(bot, controller, state, foundEnts.near["player"], "near_player", ScoreTarget)
        --ConsiderBestTarget(bot, controller, state, foundEnts.area["player"], "area_player", ScoreTarget)
        ConsiderBestTarget(bot, controller, state, foundEnts.area["NPCs"], "area_npc", ScoreTarget)
    end

    if IsValid(state.bestTarget) then
        controller.Target = state.bestTarget
        controller.ForgetTarget = CurTime() + 0.85
    end
end

function SC.ForgetInvalidTarget(bot, controller)
    local target = controller.Target

    if not IsValid(target) then
        SC.ClearObstacleTargetState(controller)
        return
    end

    local targetIsLivingActor = target:IsPlayer() or target:IsNPC()

    if controller.ForgetTarget < CurTime()
    or (targetIsLivingActor and target:Health() < 1)
    or (target:IsPlayer() and target:HasGodMode())
    or not ZSB.Util:CanPerceiveTarget(bot, target) then
        controller.Target = nil
        controller.LookAtTime = 0
        SC.ClearObstacleTargetState(controller)
        SC.ClearGoal(controller)
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
