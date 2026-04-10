local FALLBACK_ZOMBIE_TEMPERAMENT = {
    name = "rusher",
    flankBias = 0.15,
    moveSpeedMul = 1.0
}

-- Cache cvars
local leadbot_skill = GetConVar("leadbot_skill")

local STAIR_EXIT_GRACE = 0.45

local function GetZombieTemperament(bot)
    return bot.LeadBot_ZombieTemperament or FALLBACK_ZOMBIE_TEMPERAMENT
end

local function ApplyZombieTemperamentMovement(bot, controller, mv)
    if bot:Team() ~= TEAM_ZOMBIE then return end
    if not IsValid(controller.Target) or not controller.Target:IsPlayer() then return end

    local temperament = GetZombieTemperament(bot)
    local distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())

    if temperament.name == "flanker" then
        if distanceSqr > 6000 and distanceSqr < 100000 then
            local side = controller.strafeAngle == 1 and 750 or -750
            mv:SetSideSpeed(side)
        end
    elseif temperament.name == "drifter" then
        local rhythm = math.floor(CurTime() * 2 + (bot.LeadBot_PersonalitySeed or 0)) % 4

        if rhythm == 0 then
            mv:SetForwardSpeed(800)
        elseif rhythm == 1 then
            mv:SetSideSpeed(controller.strafeAngle == 1 and 350 or -350)
        end
    elseif temperament.name == "berserker" then
        if distanceSqr < 160000 then
            mv:SetForwardSpeed(1400)
        end
    elseif temperament.name == "rusher" then
        mv:SetForwardSpeed(1200 * temperament.moveSpeedMul)
    end
end

local function EnsureControllerState(controller)
    controller.LastSegmented = controller.LastSegmented or 0
    controller.NextJump = controller.NextJump or 0
    controller.NextCenter = controller.NextCenter or 0
    controller.nextStuckJump = controller.nextStuckJump or 0
    controller.LastStairTime = controller.LastStairTime or 0
    controller.strafeAngle = controller.strafeAngle or 1
    controller.LookAtTime = controller.LookAtTime or 0
    controller.cur_segment = controller.cur_segment or 2
end

local function GetCampingLookAngles(bot, strategy)
    if bot:Team() ~= TEAM_SURVIVORS then return nil end

    local sigil1 = ZSB.Map:GetValue("sigil1")
    local sigil2 = ZSB.Map:GetValue("sigil2")
    local sigil3 = ZSB.Map:GetValue("sigil3")
    local position = bot:GetPos()

    if strategy == 1 and IsValid(sigil3) and position:DistToSqr(sigil3:GetPos()) <= 5000 then
        return ZSB.Map:GetValue("eyeAngles", nil, strategy, math.random(-15, 15), math.random(-45, 45), math.random(-90, 90))
    end

    if strategy == 2 and IsValid(sigil2) and position:DistToSqr(sigil2:GetPos()) <= 5000 then
        return ZSB.Map:GetValue("eyeAngles", nil, strategy, math.random(-15, 15), math.random(-45, 45), math.random(-90, 90))
    end

    if strategy == 3 and IsValid(sigil1) and position:DistToSqr(sigil1:GetPos()) <= 5000 then
        return ZSB.Map:GetValue("eyeAngles", nil, strategy, math.random(-15, 15), math.random(-45, 45), math.random(-90, 90))
    end

    return nil
end

local function SetJumpPower(bot)
    if bot:GetZombieClass() > 5 then
        bot:SetJumpPower(300)
    else
        bot:SetJumpPower(200)
    end
end

local function DebugBot(bot)
    if not ZSB.DEBUG then return end

    local mins, maxs = bot:GetHull()

    debugoverlay.Text(bot:EyePos(), bot:Nick(), 0.03, false)
    debugoverlay.Box(bot:GetPos(), mins, maxs, 0.03, Color(255, 255, 255, 0))
end

local function SetBaseForwardSpeed(bot, controller, mv)
    if bot:Team() == TEAM_SURVIVORS then
        if not IsValid(controller.Target) then
            mv:SetForwardSpeed(1200)
        end

        return
    end

    mv:SetForwardSpeed(1200)
end

local function ForceControllerRecompute(controller)
    if controller.PosGen and controller.P and controller.TPos ~= controller.PosGen then
        controller.TPos = controller.PosGen
        controller.P:Compute(controller, controller.PosGen)
    end
end

local function UpdateControllerTransform(bot, controller)
    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
    end
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

local function Retreat(bot, controller, mv, distanceSqr, strategy)
    local trace = TraceIgnoringProps(bot:EyePos(), bot:EyePos() + bot:GetAimVector() * 100000, controller, bot)

    if not IsValid(controller.Target) or (not controller.Target:IsPlayer() and not controller.Target:IsNPC()) then
        mv:SetForwardSpeed(1200)
        return
    end

    if bot:Team() == TEAM_ZOMBIE then
        mv:SetForwardSpeed(1200)

        if distanceSqr > 45000 and bot:LBGetZomSkill() == 1 and IsValid(trace.Entity) then
            if controller.strafeAngle == 1 then
                mv:SetSideSpeed(1500)
            elseif controller.strafeAngle == 2 then
                mv:SetSideSpeed(-1500)
            end
        end

        return
    end

    if bot:Team() == TEAM_SURVIVORS and controller.ConserveAmmoWithKnife and IsValid(controller.Target) then
        if distanceSqr > 90 * 90 then
            mv:SetForwardSpeed(1200)
        else
            mv:SetForwardSpeed(0)
        end

        return
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

        if bot:LBGetSurvSkill() == 0 and IsValid(trace.Entity) then
            if controller.strafeAngle == 1 then
                mv:SetSideSpeed(1500)
            elseif controller.strafeAngle == 2 then
                mv:SetSideSpeed(-1500)
            end
        end

        return
    end

    if distanceSqr <= 45000 and IsValid(trace.Entity) then
        mv:SetForwardSpeed(-1200)

        if controller.strafeAngle == 1 then
            mv:SetSideSpeed(1500)
        elseif controller.strafeAngle == 2 then
            mv:SetSideSpeed(-1500)
        end
    end

    if bot:Health() <= 40 and IsValid(trace.Entity) then
        local target = controller.Target
        local isDangerousZombie = target:IsPlayer()
            and (target:GetZombieClass() == 2 or (target:GetZombieClass() > 5 and target:GetZombieClass() < 9))

        if isDangerousZombie or target:IsNPC() then
            if controller.strafeAngle == 1 then
                mv:SetSideSpeed(1500)
            elseif controller.strafeAngle == 2 then
                mv:SetSideSpeed(-1500)
            end
        end
    end
end

local function GetAimLerp(bot, controller, strategy)
    local aimSkill

    if leadbot_skill:GetInt() == 0 then
        aimSkill = 4
    elseif leadbot_skill:GetInt() == 1 then
        aimSkill = 8
    elseif leadbot_skill:GetInt() == 2 then
        aimSkill = 12
    elseif leadbot_skill:GetInt() == 4 then
        aimSkill = bot:LBGetShootSkill()
    else
        aimSkill = 16
    end

    if bot:Team() == TEAM_SURVIVORS and IsValid(controller.Target) then
        if strategy > 0 and not bot.freeRoam then
            return FrameTime() * (aimSkill / 2), FrameTime() * (aimSkill / 2)
        end

        return FrameTime() * aimSkill, FrameTime() * aimSkill
    end

    return FrameTime() * (aimSkill / 4), FrameTime() * (aimSkill / 4)
end

local function AreaHasAttribute(area, attribute)
    return area ~= nil and area:IsValid() and area:HasAttributes(attribute)
end

local function IsStairSegment(bot, segments, segmentIndex)
    local currentGoal = segments[segmentIndex]
    if not currentGoal then return false end

    local currentArea = currentGoal.area
    local previousGoal = segments[segmentIndex - 1]
    local nextGoal = segments[segmentIndex + 1]

    if AreaHasAttribute(currentArea, NAV_MESH_STAIRS) then
        return true
    end

    if previousGoal and AreaHasAttribute(previousGoal.area, NAV_MESH_STAIRS) then
        return true
    end

    if nextGoal and AreaHasAttribute(nextGoal.area, NAV_MESH_STAIRS) then
        return true
    end

    -- Fallback for maps where stairs are not flagged correctly in the navmesh.
    if nextGoal then
        local currentDelta = math.abs(currentGoal.pos.z - bot:GetPos().z)
        local nextDelta = math.abs(nextGoal.pos.z - currentGoal.pos.z)
        return currentDelta > 6 and nextDelta <= 32
    end

    return false
end

local function AdvanceSegment(bot, controller, segments)
    local segmentIndex = controller.cur_segment
    local currentGoal = controller.PosGen and segments[segmentIndex] or nil

    while currentGoal and segments[segmentIndex + 1] do
        local isStairs = IsStairSegment(bot, segments, segmentIndex)
        local tolerance = isStairs and 48 or 16
        local overlapTolerance = isStairs and 24 or 4

        local botPos2D = Vector(bot:GetPos().x, bot:GetPos().y, 0)
        local goalPos2D = Vector(currentGoal.pos.x, currentGoal.pos.y, 0)

        local reached = botPos2D:DistToSqr(goalPos2D) <= (tolerance * tolerance)

        if not reached and currentGoal.area and currentGoal.area:IsValid() then
            reached = currentGoal.area:IsOverlapping(bot:GetPos(), overlapTolerance)
        end

        if not reached then
            break
        end

        segmentIndex = segmentIndex + 1
        controller.cur_segment = segmentIndex
        currentGoal = segments[segmentIndex]
    end

    return currentGoal
end

local function UpdateMovement(bot, controller, mv)
    controller.IsTraversingStairs = false
    controller.IsDescendingStairs = false

    if not controller.P then
        return nil, nil
    end

    local segments = controller.P:GetAllSegments()
    if not segments then
        return nil, nil
    end

    local currentGoal = AdvanceSegment(bot, controller, segments)

    if not currentGoal then
        if bot:Team() == TEAM_SURVIVORS then
            mv:SetForwardSpeed(-1200)
        elseif bot:Team() == TEAM_ZOMBIE then
            mv:SetForwardSpeed(1200)
        end

        return nil, nil
    end

    local goalPosition = currentGoal.pos
    local isStairs = IsStairSegment(bot, segments, controller.cur_segment)

    if isStairs then
        controller.LastStairTime = CurTime()
    end

    local treatAsStairs = isStairs or (controller.LastStairTime + STAIR_EXIT_GRACE > CurTime())
    local isDescending = treatAsStairs and goalPosition.z < (bot:GetPos().z - 8)

    controller.IsTraversingStairs = treatAsStairs
    controller.IsDescendingStairs = isDescending

    if treatAsStairs then
        controller.NextCenter = 0
        controller.NextJump = -1
    end

    if not treatAsStairs and bot:GetVelocity():Length2DSqr() <= 225 and not bot:IsFrozen() and not IsValid(controller.Target) then
        if controller.nextStuckJump < CurTime() then
            if not bot:Crouching() then
                controller.NextJump = 0
            end

            controller.nextStuckJump = CurTime() + math.Rand(1, 2)
        end
    end

    if controller.NextCenter < CurTime() then
        if not treatAsStairs
            and not AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)
            and (bot:GetVelocity():Length2DSqr() <= 225 or IsValid(controller.Target))
        then
            if not bot:IsFrozen() then
                controller.strafeAngle = controller.strafeAngle == 1 and 2 or 1
                controller.NextCenter = CurTime() + math.Rand(0.3, 0.9)
            end
        end
    end

    if controller.NextCenter > CurTime() then
        local canStrafe = not treatAsStairs
            and not AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)
            and bot:GetVelocity():Length2DSqr() <= 10000
            and ((not IsValid(controller.Target) and bot:GetMoveType() ~= MOVETYPE_LADDER)
                or (bot:Team() == TEAM_SURVIVORS and IsValid(controller.Target) and (controller.strategy == 0 or bot.freeRoam))
                or (bot:Team() == TEAM_ZOMBIE and IsValid(controller.Target) and controller.strategy > 1))

        if canStrafe and not bot:IsFrozen() then
            if controller.strafeAngle == 1 then
                mv:SetSideSpeed(1500)
                if bot:LBGetSurvSkill() == 1 then
                    mv:SetForwardSpeed(0)
                end
            elseif controller.strafeAngle == 2 then
                mv:SetSideSpeed(-1500)
                if bot:LBGetSurvSkill() == 1 then
                    mv:SetForwardSpeed(0)
                end
            end
        end
    end

    if not bot:IsFrozen() and not treatAsStairs and controller.NextJump ~= 0 and controller.NextJump < CurTime() then
        local isJumpGoal = currentGoal.type > 1 or AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)
        if isJumpGoal then
            controller.NextJump = 0
        end
    end

    local crouchTrace = util.QuickTrace(bot:EyePos(), bot:GetForward() * 90 - (bot:GetViewOffsetDucked() * 3), bot)
    if AreaHasAttribute(currentGoal.area, NAV_MESH_CROUCH) or IsValid(crouchTrace.Entity) then
        controller.NextDuck = CurTime() + 0.1
    end

    controller.goalPos = goalPosition

    local moveTarget
    if treatAsStairs then
        moveTarget = Vector(goalPosition.x, goalPosition.y, bot:GetShootPos().z)
    else
        moveTarget = goalPosition + bot:GetCurrentViewOffset()
    end

    local moveAngles = (moveTarget - bot:GetShootPos()):Angle()
    mv:SetMoveAngles(moveAngles)

    return currentGoal, moveAngles
end

local function DebugPath(controller)
    if ZSB.DEBUG and controller.P then
        controller.P:Draw()
    end
end

local function SetEyeAngles(bot, controller, currentGoal, moveAngles, lerp, lerpLook)
    if IsValid(controller.Target) and controller.Target:IsPlayer() then
        if bot:Team() == TEAM_SURVIVORS then
            local targetClass = controller.Target:GetZombieClass()

            if targetClass >= 2 and targetClass < 5 or targetClass < 2 or targetClass == 5 or targetClass >= 10 then
                if not controller.Target:Crouching() then
                    bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - controller.Target:GetViewOffsetDucked() - bot:GetShootPos()):Angle()))
                else
                    bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
                end
            elseif targetClass >= 6 then
                if targetClass < 10 then
                    bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - controller.Target:GetViewOffsetDucked() - controller.Target:GetViewOffsetDucked() - bot:GetShootPos()):Angle()))
                else
                    bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - controller.Target:GetViewOffsetDucked() - bot:GetShootPos()):Angle()))
                end
            end
        elseif not bot:IsFrozen() then
            bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
        end

        return
    end

    if IsValid(controller.Target) and not controller.Target:IsPlayer() then
        if not bot:IsFrozen() then
            bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:WorldSpaceCenter() - bot:GetShootPos()):Angle()))
        end

        return
    end

    if currentGoal and moveAngles then
        if controller.LookAtTime > CurTime() and controller.LookAt then
            local lookAngles = LerpAngle(lerpLook, bot:EyeAngles(), controller.LookAt)
            if not bot:IsFrozen() then
                bot:SetEyeAngles(Angle(lookAngles.p, lookAngles.y, 0))
            end
        else
            local goalAngles = LerpAngle(lerpLook, bot:EyeAngles(), moveAngles)
            if not bot:IsFrozen() then
                bot:SetEyeAngles(Angle(goalAngles.p, goalAngles.y, 0))
            end
        end

        return
    end

    local campingAngles = GetCampingLookAngles(bot, controller.strategy)
    if campingAngles and not bot:IsFrozen() then
        bot:SetEyeAngles(campingAngles)
    end
end

-- Called before the engine processes movement.
function LeadBot.SetupMove(bot, cmd, mv)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    EnsureControllerState(controller)

    controller.strategy = bot:LBGetStrategy()

    SetJumpPower(bot)
    SetBaseForwardSpeed(bot, controller, mv)
    ForceControllerRecompute(controller)
    UpdateControllerTransform(bot, controller)

    DebugBot(bot)

    if IsValid(controller.Target) then
        local distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())
        Retreat(bot, controller, mv, distanceSqr, controller.strategy)
    end

    local lerp, lerpLook = GetAimLerp(bot, controller, controller.strategy)
    local currentGoal, moveAngles = UpdateMovement(bot, controller, mv)

    ApplyZombieTemperamentMovement(bot, controller, mv)

    DebugPath(controller)
    SetEyeAngles(bot, controller, currentGoal, moveAngles, lerp, lerpLook)
end
