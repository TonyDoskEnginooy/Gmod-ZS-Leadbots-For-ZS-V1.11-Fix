ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

if SM._PathFollowingLoaded then
    return
end

SM._PathFollowingLoaded = true

local STAIR_EXIT_GRACE = 0.45
local ZOMBIE_STUCK_JUMP_MIN = 0.35
local ZOMBIE_STUCK_JUMP_MAX = 0.85
local ZOMBIE_RANDOM_JUMP_MIN = 1.8
local ZOMBIE_RANDOM_JUMP_MAX = 3.6
local ALLY_SEPARATION_RADIUS = 56
local ALLY_SEPARATION_RADIUS_SQR = ALLY_SEPARATION_RADIUS * ALLY_SEPARATION_RADIUS

local function AreaHasAttribute(area, attribute)
    return area ~= nil and area:IsValid() and area:HasAttributes(attribute)
end

local function QueueJump(controller)
    controller.NextJump = 0
    controller.NextCenter = 0
end

local function CanQueueGroundJump(bot, controller, treatAsStairs)
    return controller.NextJump ~= 0
        and bot:IsOnGround()
        and not bot:IsFrozen()
        and not bot:Crouching()
        and not treatAsStairs
end

local function HandleZombieJumpLogic(bot, controller, currentGoal, treatAsStairs)
    if bot:Team() ~= TEAM_ZOMBIE then
        return
    end

    if not CanQueueGroundJump(bot, controller, treatAsStairs) then
        return
    end

    local speed2DSqr = bot:GetVelocity():Length2DSqr()
    local hasTarget = IsValid(controller.Target)
    local hasGoal = hasTarget or isvector(controller.PosGen)
    local heightToGoal = currentGoal.pos.z - bot:GetPos().z

    if heightToGoal > 20 then
        QueueJump(controller)
        controller.nextStuckJump = CurTime() + math.Rand(ZOMBIE_STUCK_JUMP_MIN, ZOMBIE_STUCK_JUMP_MAX)
        controller.NextRandomJump = CurTime() + math.Rand(ZOMBIE_RANDOM_JUMP_MIN, ZOMBIE_RANDOM_JUMP_MAX)
        return
    end

    if hasGoal and speed2DSqr <= 225 and controller.nextStuckJump < CurTime() then
        QueueJump(controller)
        controller.nextStuckJump = CurTime() + math.Rand(ZOMBIE_STUCK_JUMP_MIN, ZOMBIE_STUCK_JUMP_MAX)
        return
    end

    if AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP) then
        return
    end

    if controller.NextRandomJump < CurTime() then
        controller.NextRandomJump = CurTime() + math.Rand(ZOMBIE_RANDOM_JUMP_MIN, ZOMBIE_RANDOM_JUMP_MAX)

        if speed2DSqr >= 140 * 140 then
            local jumpChance = hasTarget and 24 or 10

            if math.random(1, 100) <= jumpChance then
                QueueJump(controller)
            end
        end
    end
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

local function HasReachedSegment(bot, currentGoal, isStairs)
    local tolerance = isStairs and 48 or 16
    local overlapTolerance = isStairs and 24 or 4

    local botPos2D = Vector(bot:GetPos().x, bot:GetPos().y, 0)
    local goalPos2D = Vector(currentGoal.pos.x, currentGoal.pos.y, 0)
    local reached = botPos2D:DistToSqr(goalPos2D) <= (tolerance * tolerance)

    if not reached and currentGoal.area and currentGoal.area:IsValid() then
        reached = currentGoal.area:IsOverlapping(bot:GetPos(), overlapTolerance)
    end

    return reached
end

local function AdvanceSegment(bot, controller, segments)
    local segmentIndex = controller.cur_segment
    local currentGoal = controller.PosGen and segments[segmentIndex] or nil
    local reachedFinalGoal = false

    while currentGoal do
        local isStairs = IsStairSegment(bot, segments, segmentIndex)

        if not HasReachedSegment(bot, currentGoal, isStairs) then
            break
        end

        if not segments[segmentIndex + 1] then
            reachedFinalGoal = true
            break
        end

        segmentIndex = segmentIndex + 1
        controller.cur_segment = segmentIndex
        currentGoal = segments[segmentIndex]
    end

    return currentGoal, reachedFinalGoal
end

local function ClearCompletedGoal(controller)
    controller.PosGen = nil
    controller.TPos = nil
    controller.LastSegmented = 0
    controller.cur_segment = 2
    controller.goalPos = vector_origin
    controller.NextCenter = 0
end

local function ApplySurvivorSeparation(bot, controller, mv, moveAngles, treatAsStairs)
    if bot:Team() ~= TEAM_SURVIVORS or treatAsStairs then
        return
    end

    local botPos = bot:GetPos()
    local push = Vector(0, 0, 0)
    local crowdCount = 0

    for _, ally in ipairs(player.GetAll()) do
        if ally ~= bot
        and IsValid(ally)
        and ally:Alive()
        and ally:Team() == TEAM_SURVIVORS
        then
            local delta = botPos - ally:GetPos()
            local distSqr = delta:LengthSqr()

            if distSqr > 0 and distSqr <= ALLY_SEPARATION_RADIUS_SQR then
                local dist = math.sqrt(distSqr)
                push = push + delta:GetNormalized() * ((ALLY_SEPARATION_RADIUS - dist) / ALLY_SEPARATION_RADIUS)
                crowdCount = crowdCount + 1
            end
        end
    end

    if crowdCount <= 0 or push:LengthSqr() <= 0.0001 then
        return
    end

    local separationAngles = push:Angle()
    local yawDiff = math.AngleDifference(separationAngles.y, moveAngles.y)
    local strength = math.Clamp(180 + (crowdCount * 140), 180, 680)
    local forwardAdjust = math.cos(math.rad(yawDiff)) * strength
    local sideAdjust = math.sin(math.rad(yawDiff)) * strength

    mv:SetForwardSpeed(math.Clamp(mv:GetForwardSpeed() + forwardAdjust, -1200, 1400))
    mv:SetSideSpeed(math.Clamp(mv:GetSideSpeed() + sideAdjust, -1500, 1500))

    if crowdCount >= 2 and bot:IsOnGround() and not IsValid(controller.Target) and controller.NextJump ~= 0 then
        controller.NextJump = 0
    end
end

function SM.UpdateMovement(bot, controller, mv)
    controller.IsTraversingStairs = false
    controller.IsDescendingStairs = false

    if not controller.P then
        return nil, nil
    end

    local segments = controller.P:GetAllSegments()
    if not segments then
        return nil, nil
    end

    local currentGoal, reachedFinalGoal = AdvanceSegment(bot, controller, segments)

    if reachedFinalGoal and not IsValid(controller.Target) then
        ClearCompletedGoal(controller)
        mv:SetForwardSpeed(0)
        return nil, nil
    end

    if not currentGoal then
        mv:SetForwardSpeed(0)
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

    HandleZombieJumpLogic(bot, controller, currentGoal, treatAsStairs)

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

    ApplySurvivorSeparation(bot, controller, mv, moveAngles, treatAsStairs)

    return currentGoal, moveAngles
end
