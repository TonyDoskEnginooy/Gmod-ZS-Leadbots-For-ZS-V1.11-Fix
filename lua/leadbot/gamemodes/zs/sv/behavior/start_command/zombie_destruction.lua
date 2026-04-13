ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local NEXT_TARGET_LOAD_REFRESH = 0

local TARGET_LOAD = setmetatable({}, { __mode = "k" })

if SC._ZombieTargetingLoaded then
    return
end

SC._ZombieTargetingLoaded = true

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

local function ScoreZombieObstacleTarget(bot, controller, target)
    if not ZSB.Map:GetValue("zombiePropCheck", false) then
        return false
    end

    if not SC.IsSimpleObstacleTarget(bot, target) then
        return nil
    end

    if target == controller.LastObstacleTarget and controller.ObstacleTargetRetryUntil > CurTime() then
        return nil
    end

    local temperament = SC.GetTemperament(bot)
    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())
    local score = 140 + temperament.obstacleBias + SC.GetDistanceScore(distanceSqr)

    if target == controller.Target then
        score = score + math.floor(temperament.holdBonus * 0.4)
    end

    if IsValid(controller.Target) and (controller.Target:IsPlayer() or controller.Target:IsNPC()) then
        score = score - 450
    end

    score = score + SC.StableNoise(bot, target, math.floor(temperament.imperfection * 0.4))

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

function SC.AcquireZombieBreakTarget(bot, controller, foundEnts)
    if bot:Team() ~= TEAM_ZOMBIE then return end

    RefreshTargetLoad()

    local state = {
        bestScore = -math.huge,
        bestTarget = nil
    }

    ConsiderBestTarget(bot, controller, state, foundEnts.near["func_breakable"], "func_breakable", ScoreZombieObstacleTarget)
    ConsiderBestTarget(bot, controller, state, foundEnts.near["func_physbox"], "func_physbox", ScoreZombieObstacleTarget)
    ConsiderBestTarget(bot, controller, state, foundEnts.near["prop_physics"], "prop_physics", ScoreZombieObstacleTarget)
    ConsiderBestTarget(bot, controller, state, foundEnts.near["prop_dynamic"], "prop_dynamic", ScoreZombieObstacleTarget)

    if IsValid(state.bestTarget) then
        controller.Target = state.bestTarget
        controller.ForgetTarget = CurTime() + 0.85
    end
end


