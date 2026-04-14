ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local SURVIVOR_BREAK_DECISION_CHANCE = 35
local SURVIVOR_BREAK_DECISION_MIN_DELAY = 0.45
local SURVIVOR_BREAK_DECISION_MAX_DELAY = 0.9
local SURVIVOR_BREAK_MAX_DISTANCE_SQR = 480 * 480
local SURVIVOR_BREAK_MELEE_DISTANCE_SQR = 82 * 82

local function HasMapOwnership(ent)
    return IsValid(ent)
        and ent.CreatedByMap
        and ent:CreatedByMap()
end

local function HasHealthyBreakableState(ent)
    if not IsValid(ent) then
        return false
    end

    if ent.GetMaxHealth and ent:GetMaxHealth() > 1 then
        return true
    end

    return ent:Health() > 1
end

local function IsSurvivorMeleeWeaponClass(className)
    className = string.lower(className or "")

    return className == "weapon_zs_swissarmyknife"
        or className:find("knife", 1, true)
        or className:find("crowbar", 1, true)
        or className:find("fists", 1, true)
        or className:find("machete", 1, true)
        or className:find("melee", 1, true)
end

local function HasSurvivorMeleeWeapon(bot)
    if not IsValid(bot) or bot:Team() ~= TEAM_SURVIVORS then
        return false
    end

    for _, weapon in ipairs(bot:GetWeapons()) do
        if IsValid(weapon) and IsSurvivorMeleeWeaponClass(weapon:GetClass()) then
            return true
        end
    end

    return false
end

function SC.IsSurvivorBreakTarget(bot, target)
    if not IsValid(bot) or bot:Team() ~= TEAM_SURVIVORS then
        return false
    end

    if not IsValid(target) or not ZSB.Map:GetValue("survivorBreak") then
        return false
    end

    local className = target:GetClass()

    if className == "func_breakable" then
        return true
    end

    if className == "func_breakable_surf" then
        return true
    end

    if className == "prop_dynamic" then
        return HasHealthyBreakableState(target)
    end

    if not ZSB.Map:GetValue("survivorBoxBreak") then
        return false
    end

    if className == "func_physbox" then
        return HasHealthyBreakableState(target)
    end

    if className == "prop_physics" then
        return HasMapOwnership(target) and (HasHealthyBreakableState(target) or SC.IsMapBoardEntity(target))
    end

    return false
end

function SC.ShouldSwingAtSurvivorBreakTarget(bot, controller, target)
    if not SC.IsSurvivorBreakTarget(bot, target) then
        return false
    end

    local activeWeapon = bot:GetActiveWeapon()
    if not IsValid(activeWeapon) or not IsSurvivorMeleeWeaponClass(activeWeapon:GetClass()) then
        return false
    end

    local targetPos = ZSB.Util.GetPos(target, bot:GetShootPos())
    if not isvector(targetPos) then
        return false
    end

    if bot:GetShootPos():DistToSqr(targetPos) > SURVIVOR_BREAK_MELEE_DISTANCE_SQR then
        return false
    end

    return true
end

local function ScoreSurvivorBreakTarget(bot, controller, target, sourceTag)
    if not SC.IsSurvivorBreakTarget(bot, target) then
        return nil
    end

    if target == controller.LastObstacleTarget and controller.ObstacleTargetRetryUntil > CurTime() then
        return nil
    end

    local targetPos = ZSB.Util.GetPos(target, bot:GetPos())
    if not isvector(targetPos) then
        return nil
    end

    local distanceSqr = bot:GetPos():DistToSqr(targetPos)
    if distanceSqr > SURVIVOR_BREAK_MAX_DISTANCE_SQR then
        return nil
    end

    local className = target:GetClass()
    local score = 0

    if sourceTag == "near" then
        score = score + 210
    elseif sourceTag == "facing" then
        score = score + 130
    else
        score = score + 40
    end

    if distanceSqr <= 80 * 80 then
        score = score + 180
    elseif distanceSqr <= 160 * 160 then
        score = score + 110
    elseif distanceSqr <= 280 * 280 then
        score = score + 55
    else
        score = score - 25
    end

    if className == "func_breakable_surf" then
        score = score + 35
    elseif className == "func_breakable" then
        score = score + 20
    elseif className == "prop_dynamic" then
        score = score + 10
    elseif className == "func_physbox" then
        score = score - 10
    elseif className == "prop_physics" then
        score = score - 20
    end

    if target == controller.Target then
        score = score + 90
    end

    score = score + SC.StableNoise(bot, target, 35)

    return score
end

local function ConsiderSurvivorBreakBucket(bot, controller, state, bucket, sourceTag)
    if not SC.HasEntries(bucket) then return end

    for _, ent in ipairs(bucket) do
        if IsValid(ent) then
            local score = ScoreSurvivorBreakTarget(bot, controller, ent, sourceTag)

            if score and score > state.bestScore then
                state.bestScore = score
                state.bestTarget = ent
            end
        end
    end
end

function SC.AcquireSurvivorBreakTarget(bot, controller, foundEnts)
    if not IsValid(bot) or bot:Team() ~= TEAM_SURVIVORS then
        return nil
    end

    if IsValid(controller.Target)
        or not ZSB.Map:GetValue("survivorBreak")
        or not HasSurvivorMeleeWeapon(bot)
        or bot:Health() <= 25
        or SC.HasImmediateZombieThreat(bot, controller, foundEnts)
    then
        return nil
    end

    if (controller.NextSurvivorBreakAttempt or 0) > CurTime() then
        return nil
    end

    controller.NextSurvivorBreakAttempt = CurTime() + math.Rand(
        SURVIVOR_BREAK_DECISION_MIN_DELAY,
        SURVIVOR_BREAK_DECISION_MAX_DELAY
    )

    if not ZSB.Util:Odds(SURVIVOR_BREAK_DECISION_CHANCE) then
        return nil
    end

    local state = {
        bestScore = -math.huge,
        bestTarget = nil
    }

    local scopes = {
        { name = "near", weight = "near" },
        { name = "facing", weight = "facing" },
        { name = "area", weight = "area" }
    }

    local buckets = {
        "func_breakable",
        "func_breakable_surf",
        "prop_dynamic"
    }

    if ZSB.Map:GetValue("survivorBoxBreak") then
        table.insert(buckets, "func_physbox")
        table.insert(buckets, "prop_physics")
    end

    for _, scopeInfo in ipairs(scopes) do
        local scope = foundEnts and foundEnts[scopeInfo.name]

        if istable(scope) then
            for _, bucketName in RandomPairs(buckets) do
                ConsiderSurvivorBreakBucket(bot, controller, state, scope[bucketName], scopeInfo.weight)
            end
        end
    end

    if not IsValid(state.bestTarget) then
        return nil
    end

    controller.Target = state.bestTarget
    controller.ForgetTarget = CurTime() + 0.9

    return state.bestTarget
end
