ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local STAIR_EXIT_GRACE = 0.45
local STUCK_JUMP_MIN = 0.35
local STUCK_JUMP_MAX = 0.85
local RANDOM_JUMP_MIN = 1.8
local RANDOM_JUMP_MAX = 10

local function AreaHasAttribute(area, attribute)
    return area ~= nil and area:IsValid() and area:HasAttributes(attribute)
end

function SC.StartStair(bot, controller, now)
    local isStairs = controller.IsTraversingStairs 

    if isStairs then
        controller.LastStairTime = now
    end

    local usingStairs = isStairs or (controller.LastStairTime + STAIR_EXIT_GRACE > now)

    if usingStairs then
        controller.NextStrafe = 0
        controller.NextJump = -1
    end

    if not usingStairs and bot:GetVelocity():Length2DSqr() <= 225 and not isFrozen and not hasTarget then
        if controller.NextStuckJump < now then
            if not bot:Crouching() then
                controller.NextJump = 0
            end

            controller.NextStuckJump = now + math.Rand(1, 2)
        end
    end

    return usingStairs
end

function SC.HandleJump(bot, controller, currentGoal, now)
    local isJumpArea = AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)

    if not (controller.NextJump ~= 0 or controller.NextRandomJump < now)
        or AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)
        or not bot:IsOnGround()
        or bot:IsFrozen()
        or bot:Crouching()
    then
        return
    end

    local speed2DSqr = bot:GetVelocity():Length2DSqr()
    local hasTarget = IsValid(controller.Target)

    if controller.NextJump ~= 0 then
        local hasGoal = hasTarget or isvector(controller.PosGen)
        local heightToGoal = currentGoal.pos.z - bot:GetPos().z

        -- controller.NextJump = 0
        -- controller.NextStrafe = 0
        -- controller.NextStuckJump = 0

        if heightToGoal > 20
            or (hasGoal
                and speed2DSqr <= 225
                and controller.NextStuckJump < now
            )
        then
            controller.NextStuckJump = now + math.Rand(STUCK_JUMP_MIN, STUCK_JUMP_MAX)
            return
        end

        if AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP) then
            return
        end

        if controller.NextJump < now then
            local isJumpGoal = currentGoal.type > 1 or isJumpArea
            if isJumpGoal then
                controller.NextJump = 0
            end
        end
    end

    if controller.NextRandomJump < now then
        controller.NextRandomJump = now + math.Rand(RANDOM_JUMP_MIN, RANDOM_JUMP_MAX)

        if speed2DSqr >= 140 * 140 then
            local jumpChance = hasTarget and 24 or 10

            if math.random(1, 100) <= jumpChance then
                controller.NextJump = 0
                controller.NextStrafe = 0
            end
        end
    end
end

function SC.HandleCrouch(bot, controller, currentGoal, now)
    local crouchTrace = util.QuickTrace(
        bot:EyePos(),
        bot:GetForward() * 90 - (bot:GetViewOffsetDucked() * 3),
        bot
    )

    if AreaHasAttribute(currentGoal.area, NAV_MESH_CROUCH)
        or IsValid(crouchTrace.Entity)
    then
        controller.NextDuck = now + 0.1
    end
end

function SC.UpdateGoalFromTarget(bot, controller)
    if not IsValid(controller.Target) then return end

    if (bot:IsPlayer() and controller.Target:IsPlayer() and bot:Team() ~= controller.Target:Team())
        or (bot:Team() == TEAM_SURVIVORS and controller.Target:IsNPC())
    then
        controller.PosGen = controller.Target:GetPos()
        controller.LastSegmented = CurTime() + 0.1
        return
    end

    if bot:Team() == TEAM_SURVIVORS and SC.IsSurvivorBreakTarget(bot, controller.Target) then
        controller.PosGen = SC.GetSurvivorBreakTargetPos(controller.Target, bot:GetPos()) or controller.Target:GetPos()
        controller.LastSegmented = CurTime() + 0.1
    end
end

function SC.ClearGoal(controller)
    if not IsValid(controller) then
        return
    end

    controller.PosGen = nil
    controller.TPos = nil
    controller.LastSegmented = 0
    controller.CurSegmentIndex = 2
    controller.GoalPos = vector_origin
    controller.NextStrafe = 0
end