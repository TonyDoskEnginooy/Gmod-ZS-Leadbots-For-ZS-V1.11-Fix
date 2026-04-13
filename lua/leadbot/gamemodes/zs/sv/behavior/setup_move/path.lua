ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local function AreaHasAttribute(area, attribute)
    return area ~= nil and area:IsValid() and area:HasAttributes(attribute)
end

local function IsStairSegment(bot, segments, segmentIndex)
    local currentGoal = segments[segmentIndex]

    if not currentGoal then return false end

    if AreaHasAttribute(currentGoal.area, NAV_MESH_STAIRS) then
        return true
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
    local segmentIndex = controller.CurSegmentIndex
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
        controller.CurSegmentIndex = segmentIndex
        currentGoal = segments[segmentIndex]
    end

    return currentGoal, reachedFinalGoal
end

local function HandleStop(mv, controller)
    SM.ClearCompletedGoal(controller)
    mv:SetForwardSpeed(0)
end

local function HandleStrafe(mv, bot, controller, currentGoal)
    local usingStairs = controller.IsTraversingStairs
    local isFrozen = bot:IsFrozen()
    local now = CurTime()
    local isJumpArea = AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)

    if controller.NextStrafe < now then
        if not usingStairs
            and not isFrozen
            and not isJumpArea
        then
            if bot:GetVelocity():Length2DSqr() <= 225 or hasTarget then
                controller.StrafeAngle = controller.StrafeAngle == 1 and 2 or 1
                controller.NextStrafe = now + math.Rand(0.3, 2)
            else
                mv:SetSideSpeed(0)
            end
        end
    end

    if controller.NextStrafe > now then
        local canStrafe = not usingStairs and not isJumpArea

        if canStrafe and not isFrozen then
            if controller.StrafeAngle == 1 then
                mv:SetSideSpeed(1500)
            elseif controller.StrafeAngle == 2 then
                mv:SetSideSpeed(-1500)
            end
        end
    end
end

local function HandleMoveAngles(mv, bot, controller, currentGoal, usingStairs)
    local moveTarget
    local shootPos = bot:GetShootPos()
    local usingStairs = controller.IsTraversingStairs

    if usingStairs then
        moveTarget = Vector(currentGoal.pos.x, currentGoal.pos.y, shootPos.z)
    else
        moveTarget = currentGoal.pos + bot:GetCurrentViewOffset()
    end

    local moveAngles = (moveTarget - shootPos):Angle()
    mv:SetMoveAngles(moveAngles)

    return moveAngles
end

function SM.UpdateMovement(bot, controller, mv)
    if not controller.Path then
        return nil, nil
    end

    local segments = controller.Path:GetAllSegments()
    if not segments then
        HandleStop(mv, controller)
        return nil, nil
    end

    local hasTarget = IsValid(controller.Target)

    local currentGoal, reachedFinalGoal =
        AdvanceSegment(bot, controller, segments)

    if reachedFinalGoal and not hasTarget or not currentGoal then
        HandleStop(mv, controller)
        return nil, nil
    end

    HandleStrafe(mv, bot, controller, currentGoal)

    local moveAngles = 
        HandleMoveAngles(mv, bot, controller, currentGoal)

    return currentGoal, moveAngles
end