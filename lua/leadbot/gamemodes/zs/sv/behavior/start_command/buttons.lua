ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

function SC.BuildActionButtons(bot, controller)
    local now = CurTime()
    local buttons = IN_SPEED
    local weapon = bot:GetActiveWeapon()
    local target = controller.Target
    local usingLadder = bot:GetMoveType() == MOVETYPE_LADDER
    local distanceSqr = IsValid(target) and bot:GetPos():DistToSqr(target:GetPos()) or math.huge
    local secondaryAttack = SC.ChooseZombieSecondaryAttack(bot, controller, weapon, target, distanceSqr)
    local blockedAttackEntity, blockedAttackPos = SC.GetBlockedAttackEntity(bot, controller, now)

    if IsValid(weapon) then
        local clip1 = weapon:Clip1()
        local maxClip1 = weapon:GetMaxClip1()

        if clip1 == 0 or (not IsValid(target) and maxClip1 > 0 and clip1 <= maxClip1 / 2) then
            buttons = bit.bor(buttons, IN_RELOAD)
        end
    end

    if secondaryAttack then
        buttons = bit.bor(buttons, IN_ATTACK2)

        if secondaryAttack == "poisonzombie_throw" then
            controller.NextPoisonZombieThrow = now + 4
        end
    elseif SC.ShouldPressAttack(bot, controller) then
        buttons = bit.bor(buttons, IN_ATTACK)

        if ZSB.Util.IsActiveSurvivorMelee(bot) then
            -- Create a short hit-and-run window after a melee swing.
            controller.LastMeleeAttackTime = now
            controller.MeleeRetreatUntil = now + 0.6
        end
    elseif IsValid(blockedAttackEntity) then
        buttons = bit.bor(buttons, IN_ATTACK)

        -- Briefly look at the blocking entity so melee attacks connect more reliably.
        controller.LookAt = (blockedAttackPos - bot:GetShootPos()):Angle()
        controller.LookAtTime = now + 0.2

        if ZSB.Util.IsActiveSurvivorMelee(bot) then
            controller.LastMeleeAttackTime = now
            controller.MeleeRetreatUntil = now + 0.4
        end
    end

    if usingLadder then
        local pos = controller.GoalPos or bot:GetPos()
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        controller.LookAtTime = now + 0.1

        if pos.z > controller:GetPos().z then
            controller.LookAt = Angle(-45, ang.y, 0)
        else
            controller.LookAt = Angle(45, ang.y, 0)
        end

        buttons = bit.bor(buttons, IN_FORWARD)
    else
        if controller.NextDuck and controller.NextDuck > now then
            buttons = bit.bor(buttons, IN_DUCK)
        end

        if controller.NextJump == 0 then
            controller.NextJump = now + 1.3
            buttons = bit.bor(buttons, IN_JUMP)
        end

        if not bot:IsOnGround() and controller.NextJump and controller.NextJump > now then
            buttons = bit.bor(buttons, IN_DUCK)
        end
    end

    return buttons
end