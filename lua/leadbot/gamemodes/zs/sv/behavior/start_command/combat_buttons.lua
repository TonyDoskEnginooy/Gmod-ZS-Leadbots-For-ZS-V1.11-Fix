ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

if SC._CombatButtonsLoaded then
    return
end

SC._CombatButtonsLoaded = true

local function IsCombatTarget(bot, target)
    if not IsValid(target) or target == bot then
        return false
    end

    if target:IsPlayer() then
        return target:Alive()
            and target:Team() ~= bot:Team()
            and not target:HasGodMode()
    end

    return target:IsNPC() and bot:Team() == TEAM_SURVIVORS
end

local function HasClearShot(bot, controller, target)
    local targetPos = ZSB.Util:GetCombatAimPoint(bot, target)
    if not targetPos then
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
        return false
    end

    local tr = util.TraceLine({
        start = bot:GetShootPos(),
        endpos = targetPos,
        filter = {bot, controller}
    })

    if tr.Entity == target then
        return true
    end

    if target:IsPlayer() then
        local bodyTrace = util.TraceLine({
            start = bot:GetShootPos(),
            endpos = target:WorldSpaceCenter(),
            filter = {bot, controller}
        })

        return bodyTrace.Entity == target
    end

    return false
end

local function IsActiveSurvivorMelee(bot)
    if bot:Team() ~= TEAM_SURVIVORS then
        return false
    end

    local weapon = bot:GetActiveWeapon()
    if not IsValid(weapon) then
        return false
    end

    local className = string.lower(weapon:GetClass() or "")

    return className == "weapon_zs_swissarmyknife"
        or className:find("knife", 1, true)
        or className:find("axe", 1, true)
        or className:find("crowbar", 1, true)
        or className:find("fists", 1, true)
        or className:find("machete", 1, true)
        or className:find("melee", 1, true)
end

local function IsMeleeRetreatActive(controller)
    return (controller.MeleeRetreatUntil or 0) > CurTime()
end

local function ShouldPressAttack(bot, controller)
    local target = controller.Target
    if not IsValid(target) then
        return false
    end

    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())

    if bot:Team() == TEAM_SURVIVORS then
        if not IsCombatTarget(bot, target) then
            return false
        end

        if IsActiveSurvivorMelee(bot) then
            if IsMeleeRetreatActive(controller) then
                return false
            end

            return distanceSqr <= 72 * 72 and HasClearShot(bot, controller, target)
        end

        return HasClearShot(bot, controller, target)
    end

    if bot:Team() == TEAM_ZOMBIE then
        if IsCombatTarget(bot, target) then
            return distanceSqr <= 22500
        end

        if SC.IsSimpleObstacleTarget(bot, target) then
            return distanceSqr <= 10000
        end
    end

    return false
end

function SC.BuildActionButtons(bot, controller)
    local buttons = IN_SPEED
    local weapon = bot:GetActiveWeapon()
    local target = controller.Target
    local onStairs = controller.IsTraversingStairs == true

    if IsValid(weapon) then
        local clip1 = weapon:Clip1()
        local maxClip1 = weapon:GetMaxClip1()

        if clip1 == 0 or (not IsValid(target) and maxClip1 > 0 and clip1 <= maxClip1 / 2) then
            buttons = bit.bor(buttons, IN_RELOAD)
        end
    end

    if ShouldPressAttack(bot, controller) then
        buttons = bit.bor(buttons, IN_ATTACK)

        if IsActiveSurvivorMelee(bot) then
            -- Create a short hit-and-run window after a melee swing.
            controller.LastMeleeAttackTime = CurTime()
            controller.MeleeRetreatUntil = CurTime() + 0.55
        end
    end

    if bot:GetMoveType() == MOVETYPE_LADDER then
        local pos = controller.goalPos or bot:GetPos()
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        if pos.z > controller:GetPos().z then
            controller.LookAt = Angle(-30, ang.y, 0)
        else
            controller.LookAt = Angle(30, ang.y, 0)
        end

        controller.LookAtTime = CurTime() + 0.1
        controller.NextJump = -1
        buttons = bit.bor(buttons, IN_FORWARD)
    elseif onStairs then
        controller.NextJump = -1
        buttons = bit.bor(buttons, IN_FORWARD)
    end

    if controller.NextDuck and controller.NextDuck > CurTime() then
        buttons = bit.bor(buttons, IN_DUCK)
    elseif not onStairs and controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1
        buttons = bit.bor(buttons, IN_JUMP)
    end

    if not bot:IsOnGround() and not onStairs and controller.NextJump and controller.NextJump > CurTime() then
        buttons = bit.bor(buttons, IN_DUCK)
    end

    return buttons
end

function SC.UpdateGoalFromTarget(bot, controller)
    if not IsValid(controller.Target) then return end

    if (bot:IsPlayer() and controller.Target:IsPlayer() and bot:Team() ~= controller.Target:Team())
        or (bot:Team() == TEAM_SURVIVORS and controller.Target:IsNPC())
    then
        controller.PosGen = controller.Target:GetPos()
        controller.LastSegmented = CurTime() + 0.1
    end
end
