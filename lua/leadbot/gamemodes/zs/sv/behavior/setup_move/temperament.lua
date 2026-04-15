ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local FALLBACK_TEMPERAMENT = {
    name = "rusher"
}

local MELEE_APPROACH_DISTANCE_SQR = 92 * 92
local MELEE_STOP_DISTANCE_SQR = 50 * 50
local ZOMBIE_CLOSE_DISTANCE_SQR = 85 * 85

local TEMPERAMENT_PROFILES = {
    rusher = {
        comfortMinSqr = 115 * 115,
        comfortMaxSqr = 235 * 235,
        holdChance = 0.10,
        comfortAdvanceChance = 0.62,
        circleChance = 0.18,
        jukeChance = 0.24,
        closeHoldChance = 0.05,
        approachCircleChance = 0.10
    },
    flanker = {
        comfortMinSqr = 145 * 145,
        comfortMaxSqr = 300 * 300,
        holdChance = 0.18,
        comfortAdvanceChance = 0.22,
        circleChance = 0.52,
        jukeChance = 0.18,
        closeHoldChance = 0.08,
        approachCircleChance = 0.45
    },
    breaker = {
        comfortMinSqr = 105 * 105,
        comfortMaxSqr = 220 * 220,
        holdChance = 0.08,
        comfortAdvanceChance = 0.58,
        circleChance = 0.18,
        jukeChance = 0.34,
        closeHoldChance = 0.02,
        approachCircleChance = 0.16
    },
    drifter = {
        comfortMinSqr = 135 * 135,
        comfortMaxSqr = 275 * 275,
        holdChance = 0.32,
        comfortAdvanceChance = 0.16,
        circleChance = 0.26,
        jukeChance = 0.20,
        closeHoldChance = 0.14,
        approachCircleChance = 0.30
    },
    berserker = {
        comfortMinSqr = 95 * 95,
        comfortMaxSqr = 200 * 200,
        holdChance = 0.04,
        comfortAdvanceChance = 0.74,
        circleChance = 0.12,
        jukeChance = 0.28,
        closeHoldChance = 0.00,
        approachCircleChance = 0.08
    }
}

local DEFAULT_PROFILE = TEMPERAMENT_PROFILES.rusher

-- Each profile only answers one question: how this bot prefers to move while fighting.
local function GetTemperamentName(bot)
    local config = bot.LBConfig
    local temperament = config and config.temperament or FALLBACK_TEMPERAMENT
    return temperament.name or "rusher"
end

local function GetTemperamentProfile(bot)
    return TEMPERAMENT_PROFILES[GetTemperamentName(bot)] or DEFAULT_PROFILE
end

local function HasCombatTarget(controller)
    local target = controller.Target
    return IsValid(target) and (target:IsPlayer() or target:IsNPC())
end

local function GetRhythmValue(bot, controller, salt)
    local target = controller.Target
    local targetIndex = IsValid(target) and target:EntIndex() or 0
    local seed = (bot.LBConfig and bot.LBConfig.personalitySeed or 1) * 0.013
        + targetIndex * 0.173
        + math.floor(CurTime() * 2.8) * 0.071
        + salt

    return math.abs(math.sin(seed * 23.417))
end

local function CreateMovePlan()
    return {
        forwardMode = "hold",
        sideMode = "none"
    }
end

local function ApplyComfortMovement(profile, forwardRoll, sideRoll, move)
    if forwardRoll < profile.holdChance then
        move.forwardMode = "hold"
    elseif forwardRoll < profile.holdChance + profile.comfortAdvanceChance then
        move.forwardMode = "advance"
    else
        move.forwardMode = "hold"
    end

    if sideRoll < profile.circleChance then
        move.sideMode = "circle"
    elseif sideRoll < profile.circleChance + profile.jukeChance then
        move.sideMode = "juke"
    end
end

local function BuildSurvivorMeleePlan(bot, controller, distanceSqr, profile, sideRoll, now)
    local move = CreateMovePlan()

    if (controller.MeleeRetreatUntil or 0) > now then
        move.forwardMode = "retreat"
        move.sideMode = sideRoll < 0.45 and "circle" or "juke"
        return move
    end

    if distanceSqr > MELEE_APPROACH_DISTANCE_SQR then
        move.forwardMode = "advance"
    elseif distanceSqr <= MELEE_STOP_DISTANCE_SQR then
        move.forwardMode = "hold"
    else
        move.forwardMode = "advance"
    end

    if sideRoll < profile.circleChance + 0.18 then
        move.sideMode = "circle"
    elseif sideRoll < profile.circleChance + profile.jukeChance + 0.18 then
        move.sideMode = "juke"
    end

    return move
end

local function BuildSurvivorRangedPlan(bot, controller, distanceSqr, profile)
    local move = CreateMovePlan()
    local forwardRoll = GetRhythmValue(bot, controller, 0.11)
    local sideRoll = GetRhythmValue(bot, controller, 0.67)

    if distanceSqr < profile.comfortMinSqr then
        if forwardRoll < profile.closeHoldChance then
            move.forwardMode = "hold"
        else
            move.forwardMode = "retreat"
        end

        move.sideMode = sideRoll < 0.45 and "circle" or "juke"
        return move
    end

    if distanceSqr > profile.comfortMaxSqr then
        move.forwardMode = "advance"

        if sideRoll < profile.approachCircleChance then
            move.sideMode = "circle"
        end

        return move
    end

    ApplyComfortMovement(profile, forwardRoll, sideRoll, move)
    return move
end

local function BuildZombiePlan(bot, controller, distanceSqr, profile)
    local move = CreateMovePlan()
    local sideRoll = GetRhythmValue(bot, controller, 0.39)

    if distanceSqr > profile.comfortMinSqr then
        move.forwardMode = "advance"
    elseif distanceSqr <= ZOMBIE_CLOSE_DISTANCE_SQR then
        move.forwardMode = "hold"
    else
        move.forwardMode = "advance"
    end

    if sideRoll < profile.circleChance * 0.5 then
        move.sideMode = "circle"
    elseif sideRoll < (profile.circleChance * 0.5) + (profile.jukeChance * 0.35) then
        move.sideMode = "juke"
    end

    return move
end

function SM.ApplyTemperamentMovement(bot, controller, _, distanceSqr, _, now)
    -- This stage only builds a small movement plan.
    if not HasCombatTarget(controller) or not distanceSqr then
        controller.TemperamentMove = nil
        return
    end

    local profile = GetTemperamentProfile(bot)
    local move

    if bot:Team() == TEAM_SURVIVORS then
        if controller.ConserveAmmoWithKnife or ZSB.Util.IsActiveSurvivorMelee(bot) then
            move = BuildSurvivorMeleePlan(bot, controller, distanceSqr, profile, GetRhythmValue(bot, controller, 0.91), now)
        else
            move = BuildSurvivorRangedPlan(bot, controller, distanceSqr, profile)
        end
    else
        move = BuildZombiePlan(bot, controller, distanceSqr, profile)
    end

    move.temperamentName = GetTemperamentName(bot)
    controller.TemperamentMove = move
end
