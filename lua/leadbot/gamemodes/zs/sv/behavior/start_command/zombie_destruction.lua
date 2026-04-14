ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local function ScoreZombieObstacleTarget(bot, controller, target)
    if not ZSB.Map:GetValue("zombiePropCheck") then
        return false
    end

    if not ZSB.Util.IsSimpleObstacleTarget(bot, target) then
        return nil
    end

    local temperament = ZSB.Util.GetTemperament(bot)
    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())
    local score = 140 + temperament.obstacleBias + ZSB.Util.GetDistanceScore(distanceSqr)

    if target == controller.Target then
        score = score + math.floor(temperament.holdBonus * 0.4)
    end

    if IsValid(controller.Target) and (controller.Target:IsPlayer() or controller.Target:IsNPC()) then
        score = score - 450
    end

    score = score + ZSB.Util.StableNoise(bot, target, math.floor(temperament.imperfection * 0.4))

    return score
end

local function ConsiderBestTarget(bot, controller, state, list, sourceTag, scorer)
    if not ZSB.Util.HasEntries(list) then return end

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


