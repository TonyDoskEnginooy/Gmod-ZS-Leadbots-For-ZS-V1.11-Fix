ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local function TraceIgnoringProps(startPos, endPos, controller, bot)
    return util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = function(ent)
            if ent == controller or ent == bot then
                return true
            end

            return IsValid(ent) and ent:GetClass() == "prop_physics"
        end
    })
end

local function ApplyRetreatStrafe(controller, mv, trace)
    if not IsValid(trace.Entity) then
        return
    end

    if controller.StrafeAngle == 1 then
        mv:SetSideSpeed(1500)
    elseif controller.StrafeAngle == 2 then
        mv:SetSideSpeed(-1500)
    end
end

function SM.Retreat(bot, controller, mv, distanceSqr, strategy, now)
    if controller.NextRetreatTrace < now then
        controller.NextRetreatTrace = now + 0.5
        controller.RetreatTrace = TraceIgnoringProps(bot:EyePos(), bot:EyePos() + bot:GetAimVector() * 100000, controller, bot)
    end

    local trace = controller.RetreatTrace

    if not IsValid(controller.Target) or (not controller.Target:IsPlayer() and not controller.Target:IsNPC()) then
        mv:SetForwardSpeed(1200)
        return
    end

    if bot:Team() == TEAM_ZOMBIE then
        mv:SetForwardSpeed(1200)

        if distanceSqr > 45000 and bot:LBGetzomSkill() == 1 and IsValid(trace.Entity) then
            if controller.StrafeAngle == 1 then
                mv:SetSideSpeed(1500)
            elseif controller.StrafeAngle == 2 then
                mv:SetSideSpeed(-1500)
            end
        end

        return
    end

    if bot:Team() == TEAM_SURVIVORS and IsValid(controller.Target) then
        if controller.ConserveAmmoWithKnife then
            if (controller.MeleeRetreatUntil or 0) > CurTime() then
                if distanceSqr <= 150 * 150 then
                    mv:SetForwardSpeed(-1200)
                    ApplyRetreatStrafe(controller, mv, trace)
                else
                    controller.MeleeRetreatUntil = 0
                    mv:SetForwardSpeed(0)
                end

                return
            end

            if distanceSqr > 72 * 72 then
                mv:SetForwardSpeed(1200)
            else
                mv:SetForwardSpeed(0)
            end

            return
        end
    end

    if strategy == 0 or bot.freeRoam then
        if bot:Health() > 70 then
            if distanceSqr <= 45000 then
                mv:SetForwardSpeed(-1200)
            end
        elseif bot:Health() > 40 then
            if distanceSqr <= 90000 then
                mv:SetForwardSpeed(-1200)
            end
        elseif bot:Health() > 10 then
            if distanceSqr <= 135000 then
                mv:SetForwardSpeed(-1200)
            end
        elseif distanceSqr <= 180000 then
            mv:SetForwardSpeed(-1200)
        end

        if bot:LBGetsurvSkill() == 0 and IsValid(trace.Entity) then
            if controller.StrafeAngle == 1 then
                mv:SetSideSpeed(1500)
            elseif controller.StrafeAngle == 2 then
                mv:SetSideSpeed(-1500)
            end
        end

        return
    end

    if distanceSqr <= 45000 and IsValid(trace.Entity) then
        mv:SetForwardSpeed(-1200)

        if controller.StrafeAngle == 1 then
            mv:SetSideSpeed(1500)
        elseif controller.StrafeAngle == 2 then
            mv:SetSideSpeed(-1500)
        end
    end

    if bot:Health() <= 40 and IsValid(trace.Entity) then
        local target = controller.Target
        local isDangerousZombie = target:IsPlayer()
            and (target:GetZombieClass() == 2 or (target:GetZombieClass() > 5 and target:GetZombieClass() < 9))

        if isDangerousZombie or target:IsNPC() then
            if controller.StrafeAngle == 1 then
                mv:SetSideSpeed(1500)
            elseif controller.StrafeAngle == 2 then
                mv:SetSideSpeed(-1500)
            end
        end
    end
end
