ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

function SC.BuildActionButtons(bot, controller)
    local buttons = IN_SPEED
    local weapon = bot:GetActiveWeapon()
    local target = controller.Target
    local onStairs = controller.IsTraversingStairs == true
    local distanceSqr = IsValid(target) and bot:GetPos():DistToSqr(target:GetPos()) or math.huge
    local secondaryAttack = SC.ChooseZombieSecondaryAttack(bot, controller, weapon, target, distanceSqr)
    local blockedAttackEntity, blockedAttackPos = SC.GetBlockedAttackEntity(bot, controller)

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
            controller.NextPoisonZombieThrow = CurTime() + 4
        end
    elseif SC.ShouldPressAttack(bot, controller) then
        buttons = bit.bor(buttons, IN_ATTACK)

        if SC.IsActiveSurvivorMelee(bot) then
            -- Create a short hit-and-run window after a melee swing.
            controller.LastMeleeAttackTime = CurTime()
            controller.MeleeRetreatUntil = CurTime() + 0.55
        end
    elseif IsValid(blockedAttackEntity) then
        buttons = bit.bor(buttons, IN_ATTACK)

        -- Briefly look at the blocking entity so melee attacks connect more reliably.
        controller.LookAt = (blockedAttackPos - bot:GetShootPos()):Angle()
        controller.LookAtTime = CurTime() + 0.2

        if SC.IsActiveSurvivorMelee(bot) then
            controller.LastMeleeAttackTime = CurTime()
            controller.MeleeRetreatUntil = CurTime() + 0.4
        end
    end

    if bot:GetMoveType() == MOVETYPE_LADDER then
        local pos = controller.GoalPos or bot:GetPos()
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()
        local forceLadderExit = controller.ForceLadderExitUntil and controller.ForceLadderExitUntil > CurTime()

        if forceLadderExit then
            -- Press jump to leave the ladder after being stuck on it for too long.
            controller.LookAt = Angle(0, ang.y, 0)
            controller.LookAtTime = CurTime() + 0.1
            controller.NextJump = -1
            buttons = bit.bor(buttons, IN_JUMP)
        else
            if pos.z > controller:GetPos().z then
                controller.LookAt = Angle(-30, ang.y, 0)
            else
                controller.LookAt = Angle(30, ang.y, 0)
            end

            controller.LookAtTime = CurTime() + 0.1
            controller.NextJump = -1
            buttons = bit.bor(buttons, IN_FORWARD)
        end
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