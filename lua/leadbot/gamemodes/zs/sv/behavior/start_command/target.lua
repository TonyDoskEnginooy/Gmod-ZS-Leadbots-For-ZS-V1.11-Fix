local IsValid = IsValid
local CurTime = CurTime
local pairs = pairs
local math_max = math.max
local math_Clamp = math.Clamp

ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local SURVIVOR_BREAK_IMMEDIATE_THREAT_DISTANCE_SQR = 180 * 180

local CHEM_ZOMBIE_AVOID_CHANCE = 65

local SOURCE_FACING_PLAYER = 1
local SOURCE_AREA_PLAYER = 2
local SOURCE_NEAR_PLAYER = 3
local SOURCE_NEAR_NPC = 4
local SOURCE_AREA_NPC = 5
local SOURCE_PANIC_RECENT = 6

local SOURCE_PRIORITY = {
    [SOURCE_FACING_PLAYER] = 10,
    [SOURCE_AREA_PLAYER] = 20,
    [SOURCE_NEAR_PLAYER] = 30,
    [SOURCE_NEAR_NPC] = 40,
    [SOURCE_AREA_NPC] = 50,
    [SOURCE_PANIC_RECENT] = 60
}

local SOURCE_BASE_BONUS = {
    [SOURCE_FACING_PLAYER] = 220,
    [SOURCE_AREA_PLAYER] = 140,
    [SOURCE_NEAR_PLAYER] = 100,
    [SOURCE_NEAR_NPC] = 55,
    [SOURCE_AREA_NPC] = 12,
    [SOURCE_PANIC_RECENT] = 300
}

local function ShouldAvoidChemZombie(bot, ent)
    if not ent:IsPlayer() or bot:Team() ~= TEAM_SURVIVORS or not ent.GetZombieClass then
        return false
    end

    return ent:GetZombieClass() == 4 and (ZSB.Util:Odds(CHEM_ZOMBIE_AVOID_CHANCE) or ent:GetPos():DistToSqr(bot:GetPos()) <= 67500)
end

local function AddCandidate(candidateSources, ent, sourceType)
    if not IsValid(ent) then
        return
    end

    local currentSourceType = candidateSources[ent]

    if currentSourceType == nil or SOURCE_PRIORITY[sourceType] > SOURCE_PRIORITY[currentSourceType] then
        candidateSources[ent] = sourceType
    end
end

local function AddCandidateBonus(candidateSources, list, sourceType)
    if not ZSB.Util.HasEntries(list) then
        return
    end

    for i = 1, #list do
        AddCandidate(candidateSources, list[i], sourceType)
    end
end

local function ScoreTargetFast(ctx, target, sourceType)
    if not ZSB.Util.IsEnemyCandidate(ctx.bot, target) then
        return nil
    end

    local avoidChemZombie = ShouldAvoidChemZombie(ctx.bot, target)

    if avoidChemZombie then
        return nil
    end

    local targetPos = target:GetPos()
    local distanceSqr = ctx.botPos:DistToSqr(targetPos)
    local isPlayer = target:IsPlayer()
    local isNPC = not isPlayer and target:IsNPC()

    if not isPlayer and not isNPC then
        return nil
    end

    local isCurrentTarget = target == ctx.currentTarget
    local score = SOURCE_BASE_BONUS[sourceType] or 0

    if isPlayer then
        score = score + 1350
        score = score + math_Clamp((100 - target:Health()) * ctx.preferWeakScale, 0, 180)
    else
        score = score + 900
    end

    score = score + ZSB.Util.GetDistanceScore(distanceSqr)

    if isCurrentTarget then
        score = score + ctx.holdBonus
    end

    score = score + ZSB.Util.StableNoise(ctx.bot, target, ctx.imperfection)

    return score
end

local function EvaluateCandidateBonuses(ctx, state, candidateSources)
    for target, sourceType in pairs(candidateSources) do
        local score = ScoreTargetFast(ctx, target, sourceType)

        if score and score > state.bestScore then
            state.bestScore = score
            state.bestTarget = target
        end
    end
end

function SC.HasImmediateZombieThreat(bot, controller, foundEnts)
    if IsValid(SC.GetRecentCloseThreat(controller)) then
        return true
    end

    local nearPlayers = foundEnts and foundEnts.near and foundEnts.near["player"] or nil

    if ZSB.Util.HasEntries(nearPlayers) then
        for i = 1, #nearPlayers do
            local target = nearPlayers[i]

            if ZSB.Util.IsValidEnemyZombie(bot, target) then
                return true
            end
        end
    end

    local facingPlayers = foundEnts and foundEnts.facing and foundEnts.facing["player"] or nil

    if ZSB.Util.HasEntries(facingPlayers) then
        local botPos = bot:GetPos()

        for i = 1, #facingPlayers do
            local target = facingPlayers[i]

            if ZSB.Util.IsValidEnemyZombie(bot, target)
                and botPos:DistToSqr(target:GetPos()) <= SURVIVOR_BREAK_IMMEDIATE_THREAT_DISTANCE_SQR
            then
                return true
            end
        end
    end

    return false
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
    controller.RecentCloseThreatUntil = CurTime() + math_max(duration or 0, 0)
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

function SC.AcquireTemperamentTarget(bot, controller, foundEnts, now)
    if controller.NextAcquireTemperamentTarget > now then return end

    controller.NextAcquireTemperamentTarget = now + 1
    local botTeam = bot:Team()
    local temperament = ZSB.Util.GetTemperament(bot)
    local recentThreat = SC.GetRecentCloseThreat(controller)

    local ctx = {
        bot = bot,
        botPos = bot:GetPos(),
        botTeam = botTeam,
        currentTarget = controller.Target,
        recentThreat = recentThreat,
        holdBonus = temperament.holdBonus,
        imperfection = temperament.imperfection,
        preferWeakScale = temperament.preferWeak * 1.5
    }

    local state = {
        bestScore = -math.huge,
        bestTarget = nil
    }
    local candidateSources = {}
    
    if botTeam == TEAM_SURVIVORS then
        if IsValid(recentThreat) then
            AddCandidate(candidateSources, recentThreat, SOURCE_PANIC_RECENT)
        end

        local chance = math.random(1, 100)
        local extraScan = chance <= 20 and "near" or chance <= 5 and "area"

        if extraScan then
            AddCandidateBonus(candidateSources, foundEnts[extraScan]["player"], SOURCE_AREA_PLAYER)
        end

        if SC.ShouldFallbackToSigil(bot) then
            AddCandidateBonus(candidateSources, foundEnts.near["player"], SOURCE_NEAR_PLAYER)
        end
    end

    AddCandidateBonus(candidateSources, foundEnts.facing["player"], SOURCE_FACING_PLAYER)
    AddCandidateBonus(candidateSources, foundEnts.near["NPCs"], SOURCE_NEAR_NPC)

    EvaluateCandidateBonuses(ctx, state, candidateSources)

    if not IsValid(state.bestTarget) and ctx.botTeam == TEAM_ZOMBIE then
        AddCandidateBonus(candidateSources, foundEnts.area["player"], SOURCE_AREA_NPC)
        EvaluateCandidateBonuses(ctx, state, candidateSources)
    end

    if IsValid(state.bestTarget) then
        controller.Target = state.bestTarget
        controller.ForgetTarget = CurTime() + 0.85
    end
end

function SC.ForgetInvalidTarget(bot, controller)
    local target = controller.Target

    if not IsValid(target) then
        return
    end

    local targetIsLivingActor = target:IsPlayer() or target:IsNPC()

    if controller.ForgetTarget < CurTime()
    or (targetIsLivingActor and target:Health() < 1)
    or (target:IsPlayer() and target:HasGodMode())
    or not ZSB.Util:CanPerceiveTarget(bot, target) then
        controller.Target = nil
        controller.LookAtTime = 0
        SC.ClearGoal(controller)
        return
    end
end

function SC.UpdateGoalFromTarget(bot, controller, strategy)
    if not IsValid(controller.Target) then return end

    local PosGen = ZSB.Util.GetPos(controller.Target, bot:GetPos())
    local botTeam = bot:Team()

    if botTeam == TEAM_SURVIVORS and strategy == 2 and controller.Target then
        PosGen = ZSB.Util.GetTargetSpreadPosition(bot, controller.Target, PosGen, math.Rand(10, 40))
    end

    if controller.PosGen == PosGen then return end

    if bot:IsPlayer() and controller.Target:IsPlayer() and (
        botTeam ~= controller.Target:Team()
        or (botTeam == TEAM_SURVIVORS and controller.Target:IsNPC())
    ) then
        controller.PosGen = PosGen
    elseif botTeam == TEAM_SURVIVORS and SC.IsSurvivorBreakTarget(bot, controller.Target) then
        controller.PosGen = PosGen
    end
end

function SC.ClearGoal(controller)
    if not IsValid(controller) then
        return
    end

    controller.PosGen = nil
    controller.TPos = nil
    controller.ForgetTarget = 0
    controller.CurSegmentIndex = 2
    controller.GoalPos = vector_origin
    controller.SigilFallbackActive = false
    controller.SigilFallbackPos = nil
end
