ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local SURVIVOR_SPEEDS = {
    advance = 950,
    retreat = -1200,
    circle = 900,
    juke = 1200
}

local ZOMBIE_SPEEDS = {
    advance = 1200,
    retreat = -250,
    circle = 800,
    juke = 1000
}

local GODMODE_RETREAT_MAX_DISTANCE_SQR = 550 * 550
local GODMODE_RETREAT_IMMEDIATE_DISTANCE_SQR = 190 * 190
local GODMODE_RETREAT_APPROACH_SPEED = 55
local KNIFE_HIT_AND_RUN_DISTANCE_SQR = 150 * 150
local KNIFE_APPROACH_DISTANCE_SQR = 72 * 72
local CROWD_RETREAT_COUNT = 3

local function ShallowCopy(tbl)
    local out = {}

    if not istable(tbl) then
        return out
    end

    for key, value in pairs(tbl) do
        out[key] = value
    end

    return out
end

local function GetSideDirection(controller)
    return controller.StrafeAngle == 2 and -1 or 1
end

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

local function IsObstacleAhead(trace, target)
    return trace ~= nil and trace.Hit and trace.Entity ~= target
end

local function GetZombieThreats(bot)
    -- Survivors only need the extra panic scan.
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

    if not istable(nearbyPlayers) then
        return nil, 0
    end

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

local function RefreshRetreatContext(bot, controller, now)
    if (controller.NextRetreatScan or 0) > now then
        return
    end

    controller.NextRetreatScan = now + 0.35
    controller.RetreatTrace = TraceIgnoringProps(bot:EyePos(), bot:EyePos() + bot:GetAimVector() * 100000, controller, bot)
    controller.RetreatGodModeThreat, controller.RetreatThreatCount = GetZombieThreats(bot)
end

local function GetHealthRetreatDistanceSqr(bot, strategy)
    local retreatDistanceSqr

    if bot:Health() > 70 then
        retreatDistanceSqr = 150 * 150
    elseif bot:Health() > 40 then
        retreatDistanceSqr = 210 * 210
    elseif bot:Health() > 10 then
        retreatDistanceSqr = 280 * 280
    else
        retreatDistanceSqr = 340 * 340
    end

    if bot.freeRoam then
        retreatDistanceSqr = retreatDistanceSqr * 1.2
    elseif strategy > 0 then
        retreatDistanceSqr = retreatDistanceSqr * 0.9
    end

    return retreatDistanceSqr
end

local function IsDangerousZombie(target)
    if not IsValid(target) or not target:IsPlayer() or not target.GetZombieClass then
        return target and target:IsNPC() or false
    end

    local zombieClass = target:GetZombieClass()
    return zombieClass == 2 or zombieClass == 6 or zombieClass == 7 or zombieClass == 8
end

local function GetFallbackMove(bot, distanceSqr)
    if bot:Team() == TEAM_ZOMBIE then
        if distanceSqr and distanceSqr <= 30 * 30 then
            return {
                forwardMode = "circle",
                sideMode = "juke"
            }
        end

        return {
            forwardMode = "advance",
            sideMode = "none"
        }
    end

    if not distanceSqr then
        return {
            forwardMode = "hold",
            sideMode = "none"
        }
    end

    if distanceSqr <= 135 * 135 then
        return {
            forwardMode = "retreat",
            sideMode = "juke"
        }
    end

    if distanceSqr >= 260 * 260 then
        return {
            forwardMode = "advance",
            sideMode = "none"
        }
    end

    return {
        forwardMode = "hold",
        sideMode = "circle"
    }
end

local function GetKnifeMove(controller, distanceSqr, now)
    if not controller.ConserveAmmoWithKnife then
        return nil
    end

    if (controller.MeleeRetreatUntil or 0) > now then
        if distanceSqr and distanceSqr <= KNIFE_HIT_AND_RUN_DISTANCE_SQR then
            return {
                forwardMode = "retreat",
                sideMode = "juke"
            }
        end

        controller.MeleeRetreatUntil = 0
        return {
            forwardMode = "hold",
            sideMode = "none"
        }
    end

    if distanceSqr and distanceSqr > KNIFE_APPROACH_DISTANCE_SQR then
        return {
            forwardMode = "advance",
            sideMode = "circle"
        }
    end

    return {
        forwardMode = "hold",
        sideMode = "none"
    }
end

local function GetSurvivorEmergencyMove(bot, controller, target, distanceSqr, strategy)
    local threatCount = controller.RetreatThreatCount or 0

    if IsValid(controller.RetreatGodModeThreat) or threatCount >= CROWD_RETREAT_COUNT then
        return {
            forwardMode = "retreat",
            sideMode = "juke"
        }
    end

    if not distanceSqr then
        return nil
    end

    local retreatDistanceSqr = GetHealthRetreatDistanceSqr(bot, strategy)
    if distanceSqr > retreatDistanceSqr then
        return nil
    end

    if IsDangerousZombie(target) or threatCount >= 2 then
        return {
            forwardMode = "retreat",
            sideMode = "juke"
        }
    end

    return {
        forwardMode = "retreat",
        sideMode = "circle"
    }
end

local function ApplyMove(bot, controller, mv, move, forceSideStep)
    -- Temperament picks the intention. Retreat turns it into final speed values.
    local speeds = bot:Team() == TEAM_SURVIVORS and SURVIVOR_SPEEDS or ZOMBIE_SPEEDS
    local forwardSpeed = 0
    local sideSpeed = 0
    local sideDirection = GetSideDirection(controller)

    if move.forwardMode == "advance" then
        forwardSpeed = speeds.advance
    elseif move.forwardMode == "retreat" then
        forwardSpeed = speeds.retreat
    end

    if move.sideMode == "circle" then
        sideSpeed = speeds.circle * sideDirection
    elseif move.sideMode == "juke" then
        sideSpeed = speeds.juke * sideDirection
    elseif forceSideStep then
        sideSpeed = speeds.circle * sideDirection
    end

    mv:SetForwardSpeed(forwardSpeed)
    mv:SetSideSpeed(sideSpeed)
end

function SM.Retreat(bot, controller, mv, distanceSqr, strategy, now)
    RefreshRetreatContext(bot, controller, now)

    local target = controller.Target
    local trace = controller.RetreatTrace
    local forceSideStep = IsObstacleAhead(trace, target)

    if bot:Team() == TEAM_ZOMBIE then
        if not IsValid(target) or (not target:IsPlayer() and not target:IsNPC()) then
            return
        end

        local move = ShallowCopy(controller.TemperamentMove or GetFallbackMove(bot, distanceSqr))

        if distanceSqr and distanceSqr > 280 * 280 and forceSideStep then
            move.sideMode = "circle"
        end

        ApplyMove(bot, controller, mv, move, forceSideStep)
        return
    end

    if not IsValid(target) or (not target:IsPlayer() and not target:IsNPC()) then
        if IsValid(controller.RetreatGodModeThreat) or (controller.RetreatThreatCount or 0) >= CROWD_RETREAT_COUNT then
            ApplyMove(bot, controller, mv, {
                forwardMode = "retreat",
                sideMode = "juke"
            }, true)
        end

        return
    end

    local move = GetKnifeMove(controller, distanceSqr, now)

    if not move then
        move = GetSurvivorEmergencyMove(bot, controller, target, distanceSqr, strategy)
    end

    if not move then
        move = ShallowCopy(controller.TemperamentMove or GetFallbackMove(bot, distanceSqr))
    end

    if forceSideStep and move.sideMode == "none" then
        move.sideMode = "juke"
    end

    ApplyMove(bot, controller, mv, move, forceSideStep)
end
