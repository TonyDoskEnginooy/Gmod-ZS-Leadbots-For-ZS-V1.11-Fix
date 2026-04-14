ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local function IsCombatTarget(bot, target)
    if not IsValid(target) or target == bot then
        return false
    end

    if target:IsPlayer() then
        return target:Alive()
            and target:Team() ~= bot:Team()
            and not target:HasGodMode()
            and ZSB.Util:CanPerceiveTarget(bot, target)
    end

    return target:IsNPC() and bot:Team() == TEAM_SURVIVORS
end

local function HasClearShot(bot, controller, target)
    local now = CurTime()

    if controller.NextHasClearShot < now then
        controller.NextHasClearShot = now + 0.15
    else
        return controller.HasClearShot
    end

    local targetPos = ZSB.Util:GetCombatAimPoint(bot, target)
    if not targetPos then
        controller.HasClearShot = false
        return false
    end

    local distanceSqr = bot:GetShootPos():DistToSqr(targetPos)
    local aimDir = (targetPos - bot:GetShootPos()):GetNormalized()
    local requiredDot = 0.85

    if distanceSqr <= 110 * 110 then
        requiredDot = 0.3
    elseif distanceSqr <= 220 * 220 then
        requiredDot = 0.5
    elseif distanceSqr <= 380 * 380 then
        requiredDot = 0.7
    end

    if distanceSqr > 80 * 80 and bot:GetAimVector():Dot(aimDir) < requiredDot then
        controller.HasClearShot = false
        return false
    end

    local tr = util.TraceLine({
        start = bot:GetShootPos(),
        endpos = targetPos,
        filter = {bot, controller}
    })

    if tr.Entity == target then
        controller.HasClearShot = true
        return true
    end

    if target:IsPlayer() then
        local bodyCenter = ZSB.Util:GetTargetBodyCenter(target)
        if not bodyCenter then
            controller.HasClearShot = false
            return false
        end

        local bodyTrace = util.TraceLine({
            start = bot:GetShootPos(),
            endpos = bodyCenter,
            filter = {bot, controller}
        })

        controller.HasClearShot = bodyTrace.Entity == target
        return controller.HasClearShot
    end

    controller.HasClearShot = false
    return false
end

local function IsMeleeRetreatActive(controller)
    return (controller.MeleeRetreatUntil or 0) > CurTime()
end

local function GetWeaponClassLower(weapon)
    if not IsValid(weapon) then
        return ""
    end

    return string.lower(weapon:GetClass() or "")
end

local function SafeWeaponCall(weapon, methodName, defaultValue)
    if not IsValid(weapon) then
        return defaultValue
    end

    local method = weapon[methodName]
    if not isfunction(method) then
        return defaultValue
    end

    local ok, value = pcall(method, weapon)
    if not ok then
        return defaultValue
    end

    if value == nil then
        return defaultValue
    end

    return value
end

local function SafeWeaponBool(weapon, methodName, defaultValue)
    local value = SafeWeaponCall(weapon, methodName, defaultValue)

    if isbool(value) then
        return value
    end

    return defaultValue
end

local function SafeWeaponNumber(weapon, methodName, defaultValue)
    local value = SafeWeaponCall(weapon, methodName, defaultValue)

    if isnumber(value) then
        return value
    end

    return defaultValue
end

local function IsHeadcrabLeapWeapon(className)
    return className == "weapon_zs_headcrab"
        or className == "weapon_zs_fastheadcrab"
end

local function IsHeadcrabLeapReady(weapon)
    return IsValid(weapon)
        and not weapon.Leaping
        and (weapon.NextLeap or 0) <= CurTime()
end

local function ShouldUseHeadcrabLeap(bot, controller, weapon, target, distanceSqr, className)
    if not IsHeadcrabLeapReady(weapon) or not bot:IsOnGround() then
        return false
    end

    if not HasClearShot(bot, controller, target) then
        return false
    end

    local minRange = 52
    local maxRange = className == "weapon_zs_fastheadcrab" and 460 or 360

    if distanceSqr < minRange * minRange or distanceSqr > maxRange * maxRange then
        return false
    end

    local verticalDelta = math.abs(target:WorldSpaceCenter().z - bot:WorldSpaceCenter().z)

    return verticalDelta <= 180
end

local function CanStartPoisonHeadcrabLeap(weapon)
    return IsValid(weapon)
        and SafeWeaponNumber(weapon, "GetNextLeap", 0) <= CurTime()
        and not SafeWeaponBool(weapon, "IsLeaping", false)
        and not SafeWeaponBool(weapon, "IsGoingToSpit", false)
end

local function CanStartPoisonHeadcrabSpit(weapon)
    return IsValid(weapon)
        and SafeWeaponNumber(weapon, "GetNextSpit", 0) <= CurTime()
        and not SafeWeaponBool(weapon, "IsLeaping", false)
        and not SafeWeaponBool(weapon, "IsGoingToSpit", false)
end

local function ShouldUsePoisonHeadcrabLeap(bot, controller, weapon, target, distanceSqr)
    if not CanStartPoisonHeadcrabLeap(weapon) or not bot:IsOnGround() then
        return false
    end

    if not HasClearShot(bot, controller, target) then
        return false
    end

    if distanceSqr < 60 * 60 or distanceSqr > 320 * 320 then
        return false
    end

    local verticalDelta = math.abs(target:WorldSpaceCenter().z - bot:WorldSpaceCenter().z)

    return verticalDelta <= 170
end

local function ShouldUsePoisonHeadcrabSpit(bot, controller, weapon, target, distanceSqr)
    if not CanStartPoisonHeadcrabSpit(weapon) or not bot:IsOnGround() then
        return false
    end

    if distanceSqr < 180 * 180 or distanceSqr > 900 * 900 then
        return false
    end

    return HasClearShot(bot, controller, target)
end

local function CanUseFastZombieSecondary(weapon)
    return IsValid(weapon)
        and not weapon.Leaping
        and not SafeWeaponBool(weapon, "GetSwinging", false)
        and not SafeWeaponBool(weapon, "GetClimbing", false)
        and SafeWeaponNumber(weapon, "GetPounceTime", 0) <= CurTime()
end

local function ShouldUseFastZombieSecondary(bot, controller, weapon, target, distanceSqr)
    if not CanUseFastZombieSecondary(weapon) then
        return false
    end

    if bot:IsOnGround() then
        local verticalDelta = target:WorldSpaceCenter().z - bot:WorldSpaceCenter().z

        if verticalDelta > 72 and distanceSqr <= 260 * 260 and controller.NextJump ~= 0 then
            controller.NextJump = 0
        end

        if distanceSqr < 95 * 95 or distanceSqr > 625 * 625 then
            return false
        end

        return HasClearShot(bot, controller, target)
    end

    if (weapon.NextClimb or 0) > CurTime() then
        return false
    end

    if distanceSqr > 700 * 700 then
        return false
    end

    local toTarget = (target:WorldSpaceCenter() - bot:GetShootPos())
    if toTarget:LengthSqr() <= 0.001 then
        return false
    end

    return bot:GetAimVector():Dot(toTarget:GetNormalized()) > 0.55
end

local function GetPoisonZombieHeadcrabCount(weapon)
    if not IsValid(weapon) then
        return 0
    end

    if isnumber(weapon.Headcrabs) then
        return weapon.Headcrabs
    end

    return SafeWeaponNumber(weapon, "GetHeadcrabs", 0)
end

local function ShouldUsePoisonZombieThrow(bot, controller, weapon, target, distanceSqr)
    if controller.NextPoisonZombieThrow > CurTime() then
        return false
    end

    if GetPoisonZombieHeadcrabCount(weapon) <= 0 then
        return false
    end

    if distanceSqr < 190 * 190 or distanceSqr > 950 * 950 then
        return false
    end

    if not HasClearShot(bot, controller, target) then
        return false
    end

    return bot:GetVelocity():Length2DSqr() <= 350 * 350
end

function SC.ChooseZombieSecondaryAttack(bot, controller, weapon, target, distanceSqr)
    if bot:Team() ~= TEAM_ZOMBIE or not IsValid(weapon) or not IsCombatTarget(bot, target) then
        return nil
    end

    local className = GetWeaponClassLower(weapon)

    if className == "weapon_zs_fastzombie" then
        if ShouldUseFastZombieSecondary(bot, controller, weapon, target, distanceSqr) then
            return "fastzombie_special"
        end

        return nil
    end

    if className == "weapon_zs_poisonheadcrab" then
        if ShouldUsePoisonHeadcrabSpit(bot, controller, weapon, target, distanceSqr) then
            return "poisonheadcrab_spit"
        end

        return nil
    end

    if className == "weapon_zs_poisonzombie" then
        if ShouldUsePoisonZombieThrow(bot, controller, weapon, target, distanceSqr) then
            return "poisonzombie_throw"
        end
    end

    return nil
end

local function GetBlockedAttackTargetPos(ent, fallbackPos)
    if not IsValid(ent) then
        return fallbackPos
    end

    if ent.NearestPoint and isvector(fallbackPos) then
        local ok, nearestPoint = pcall(ent.NearestPoint, ent, fallbackPos)
        if ok and isvector(nearestPoint) then
            return nearestPoint
        end
    end

    if ent.WorldSpaceCenter then
        local ok, center = pcall(ent.WorldSpaceCenter, ent)
        if ok and isvector(center) then
            return center
        end
    end

    return ent:GetPos()
end

function SC.GetBlockedAttackEntity(bot, controller, now)
    if controller.NextBlockedAttackEntity > now then return end

    controller.NextBlockedAttackEntity = now + 0.35

    if not IsValid(bot) or not IsValid(controller) then
        return nil, nil
    end

    if bot:IsFrozen() or bot:GetMoveType() == MOVETYPE_LADDER then
        return nil, nil
    end

    -- Only use this fallback for zombies or melee survivors.
    if bot:Team() ~= TEAM_ZOMBIE and not SC.IsActiveSurvivorMelee(bot) then
        return nil, nil
    end

    local velocity2DSqr = bot:GetVelocity():Length2DSqr()

    -- Treat "almost stopped" as blocked movement.
    if velocity2DSqr > 55 * 55 then
        return nil, nil
    end

    local goalPos = controller.GoalPos or controller.PosGen
    local forwardDir

    if isvector(goalPos) then
        forwardDir = goalPos - bot:GetPos()
        forwardDir.z = 0

        if forwardDir:LengthSqr() > 1 then
            forwardDir:Normalize()
        else
            forwardDir = bot:GetForward()
        end
    else
        forwardDir = bot:GetForward()
    end

    -- Do not trigger if the bot is not really trying to move ahead.
    if bot:GetForward():Dot(forwardDir) < 0.15 then
        return nil, nil
    end

    local hullMins, hullMaxs = bot:GetHull()
    local traceMins = Vector(hullMins.x * 0.35, hullMins.y * 0.35, 0)
    local traceMaxs = Vector(hullMaxs.x * 0.35, hullMaxs.y * 0.35, math.max(hullMaxs.z * 0.35, 24))

    local startPos = bot:WorldSpaceCenter()
    local endPos = startPos + forwardDir * 58

    local tr = util.TraceHull({
        start = startPos,
        endpos = endPos,
        mins = traceMins,
        maxs = traceMaxs,
        filter = function(ent)
            if not IsValid(ent) then
                return false
            end

            if ent == bot or ent == controller then
                return false
            end

            return true
        end
    })

    if not tr.Hit or not IsValid(tr.Entity) then
        return nil, nil
    end

    local ent = tr.Entity

    -- Ignore friendly players to avoid dumb accidental swings.
    if ent:IsPlayer() then
        if ent == bot or ent:Team() == bot:Team() or not ent:Alive() or ent:HasGodMode() then
            return nil, nil
        end
    end

    local hitPos = GetBlockedAttackTargetPos(ent, tr.HitPos)

    if not isvector(hitPos) then
        return nil, nil
    end

    if bot:GetPos():DistToSqr(hitPos) > 90 * 90 then
        return nil, nil
    end

    return ent, hitPos
end

function SC.ShouldPressAttack(bot, controller)
    local target = controller.Target
    if not IsValid(target) then
        return false
    end

    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())

    if bot:Team() == TEAM_SURVIVORS then
        if SC.IsSurvivorBreakTarget(bot, target) then
            return SC.ShouldSwingAtSurvivorBreakTarget(bot, controller, target)
        end

        if not IsCombatTarget(bot, target) then
            return false
        end

        if SC.IsActiveSurvivorMelee(bot) then
            if IsMeleeRetreatActive(controller) then
                return false
            end

            return distanceSqr <= 72 * 72 and (HasClearShot(bot, controller, target) or math.random(1, 100) <= 40)
        end

        return HasClearShot(bot, controller, target) or distanceSqr <= 120 * 120 and math.random(1, 100) <= 80
    end

    if bot:Team() == TEAM_ZOMBIE then
        if IsCombatTarget(bot, target) then
            local weapon = bot:GetActiveWeapon()
            local className = GetWeaponClassLower(weapon)

            if IsHeadcrabLeapWeapon(className) then
                return ShouldUseHeadcrabLeap(bot, controller, weapon, target, distanceSqr, className)
            end

            if className == "weapon_zs_poisonheadcrab" then
                return ShouldUsePoisonHeadcrabLeap(bot, controller, weapon, target, distanceSqr)
            end

            return distanceSqr <= 22500
        end
    end

    return false
end
