ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

if SC._ZombieTargetingLoaded then
    return
end

SC._ZombieTargetingLoaded = true

local function IsEnemyCandidate(bot, ent)
    if not IsValid(ent) or ent == bot then return false end

    if ent:IsPlayer() then
        return ent:Alive()
            and ent:Team() ~= bot:Team()
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
    for ent in pairs(SC.TARGET_LOAD) do
        SC.TARGET_LOAD[ent] = nil
    end
end

local function RefreshTargetLoad()
    if SC.NEXT_TARGET_LOAD_REFRESH > CurTime() then return end

    ClearTargetLoad()

    for _, ply in ipairs(player.GetBots()) do
        if IsValid(ply) and ply.IsLBot and ply:IsLBot() then
            local controller = ply:GetController()

            if IsValid(controller) and IsValid(controller.Target) then
                SC.TARGET_LOAD[controller.Target] = (SC.TARGET_LOAD[controller.Target] or 0) + 1
            end
        end
    end

    SC.NEXT_TARGET_LOAD_REFRESH = CurTime() + 0.2
end

local function ScoreZombieEnemyTarget(bot, controller, target, sourceTag)
    if not IsEnemyCandidate(bot, target) or ShouldAvoidChemZombie(bot, target) then
        return nil
    end

    local temperament = SC.GetZombieTemperament(bot)
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
    end

    if target == controller.Target then
        score = score + temperament.holdBonus
    end

    local load = SC.TARGET_LOAD[target] or 0

    if target == controller.Target and load > 0 then
        load = load - 1
    end

    score = score - (load * temperament.loadPenalty)
    score = score + SC.StableNoise(bot, target, temperament.imperfection)

    return score
end

local function ScoreZombieObstacleTarget(bot, controller, target)
    if not SC.IsSimpleObstacleTarget(bot, target) then
        return nil
    end

    local temperament = SC.GetZombieTemperament(bot)
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

function SC.AcquireTemperamentTarget(bot, controller, foundEnts)
    RefreshTargetLoad()

    local state = {
        bestScore = -math.huge,
        bestTarget = nil
    }

    ConsiderBestTarget(bot, controller, state, foundEnts.facing["player"], "facing_player", ScoreZombieEnemyTarget)
    ConsiderBestTarget(bot, controller, state, foundEnts.near["player"], "near_player", ScoreZombieEnemyTarget)
    ConsiderBestTarget(bot, controller, state, foundEnts.near["npc"], "near_npc", ScoreZombieEnemyTarget)

    if not IsValid(state.bestTarget) then
        ConsiderBestTarget(bot, controller, state, foundEnts.near["func_breakable"], "func_breakable", ScoreZombieObstacleTarget)
        ConsiderBestTarget(bot, controller, state, foundEnts.near["func_physbox"], "func_physbox", ScoreZombieObstacleTarget)
        ConsiderBestTarget(bot, controller, state, foundEnts.near["prop_physics"], "prop_physics", ScoreZombieObstacleTarget)
        ConsiderBestTarget(bot, controller, state, foundEnts.near["prop_dynamic"], "prop_dynamic", ScoreZombieObstacleTarget)
    end

    if IsValid(state.bestTarget) then
        controller.Target = state.bestTarget
        controller.ForgetTarget = CurTime() + 0.9
    end
end

function SC.IsSimpleObstacleTarget(_, ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass()

    if class == "func_breakable" or class == "func_physbox" then
        return ent.GetMaxHealth and ent:GetMaxHealth() > 1
    end

    if class == "prop_physics" then
        if not ent.GetMaxHealth or ent:GetMaxHealth() <= 1 then
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

    return false
end