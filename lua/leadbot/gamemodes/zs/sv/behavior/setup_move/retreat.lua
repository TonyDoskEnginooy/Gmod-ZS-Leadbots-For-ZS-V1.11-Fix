ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local GODMODE_RETREAT_MAX_DISTANCE_SQR = 550 * 550
local GODMODE_RETREAT_IMMEDIATE_DISTANCE_SQR = 190 * 190
local GODMODE_RETREAT_APPROACH_SPEED = 55

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

local function ApplyRetreatSideSpeed(controller, mv)
    if controller.StrafeAngle == 1 then
        mv:SetSideSpeed(1500)
    elseif controller.StrafeAngle == 2 then
        mv:SetSideSpeed(-1500)
    end
end

local function GetZombieThreats(bot)
    if bot:Team() ~= TEAM_SURVIVORS then
        return nil, 0
    end

    local foundEnts = ZSB.Util:FindEnts(bot)
    if not foundEnts then
        return nil, 0
    end

    local nearbyPlayers = foundEnts.near["player"]
    local threatGodMode
    local totalThreats = 0
    for _, candidate in RandomPairs(nearbyPlayers) do
        if ZSB.Util.IsValidEnemyZombie(bot, candidate, true) then
            totalThreats = totalThreats + 1
            if candidate:HasGodMode() then
                threatGodMode = candidate
                break
            end
        end
    end

    if not threatGodMode then
        return nil, totalThreats
    end

    local delta = bot:GetPos() - threatGodMode:GetPos()
    local distanceSqr = delta:LengthSqr()

    if distanceSqr > GODMODE_RETREAT_MAX_DISTANCE_SQR then
        return nil, totalThreats
    end

    if distanceSqr <= GODMODE_RETREAT_IMMEDIATE_DISTANCE_SQR then
        return threatGodMode, totalThreats
    end

    local velocity = threatGodMode:GetVelocity()
    local velocitySqr = velocity:LengthSqr()

    if velocitySqr <= 1 then
        return nil, totalThreats
    end

    local dot = velocity:Dot(delta)

    if dot <= 0 then
        return nil, totalThreats
    end

    if distanceSqr <= 0 then
        return threatGodMode, totalThreats
    end
    
    if (dot * dot) >= (GODMODE_RETREAT_APPROACH_SPEED * GODMODE_RETREAT_APPROACH_SPEED * distanceSqr) then
        return threatGodMode, totalThreats
    end

    return nil, totalThreats
end

function SM.Retreat(bot, controller, mv, distanceSqr, strategy, now)
    if controller.NextRetreatScans < now then
        controller.NextRetreatScans = now + 0.5
        controller.RetreatTrace = TraceIgnoringProps(bot:EyePos(), bot:EyePos() + bot:GetAimVector() * 100000, controller, bot)
        controller.RetreatGodModeThread, controller.RetreatTotalThreats = GetZombieThreats(bot)
    end

    local target = controller.Target
    local threatGodMode = controller.RetreatGodModeThread
    local totalThreats = controller.RetreatTotalThreats
    local trace = controller.RetreatTrace

    if bot:Team() == TEAM_SURVIVORS and (
        IsValid(threatGodMode)
        or totalThreats > 2 
    ) then
        mv:SetForwardSpeed(-1200)
        ApplyRetreatSideSpeed(controller, mv)
        return
    end

    if bot:Team() == TEAM_SURVIVORS and totalThreats == 1 then
        ApplyRetreatSideSpeed(controller, mv)
        return
    end

    if not IsValid(target) or (not target:IsPlayer() and not target:IsNPC()) then
        return
    end

    if bot:Team() == TEAM_ZOMBIE then
        mv:SetForwardSpeed(1200)

        if distanceSqr > 45000 and bot:LBGetzomSkill() == 1 and IsValid(trace.Entity) then
            ApplyRetreatSideSpeed(controller, mv)
        end

        return
    end

    if bot:Team() == TEAM_SURVIVORS then
        if controller.ConserveAmmoWithKnife then
            if (controller.MeleeRetreatUntil or 0) > now then
                if distanceSqr <= 150 * 150 then
                    mv:SetForwardSpeed(-1200)
                    if IsValid(trace.Entity) then
                        ApplyRetreatSideSpeed(controller, mv)
                    end
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
            ApplyRetreatSideSpeed(controller, mv)
        end

        return
    end

    if distanceSqr <= 45000 and IsValid(trace.Entity) then
        mv:SetForwardSpeed(-1200)
        ApplyRetreatSideSpeed(controller, mv)
    end

    if bot:Health() <= 40 and IsValid(trace.Entity) then
        local isDangerousZombie = target:IsPlayer()
            and (target:GetZombieClass() == 2 or (target:GetZombieClass() > 5 and target:GetZombieClass() < 9))

        if isDangerousZombie or target:IsNPC() then
            ApplyRetreatSideSpeed(controller, mv)
        end
    end
end
