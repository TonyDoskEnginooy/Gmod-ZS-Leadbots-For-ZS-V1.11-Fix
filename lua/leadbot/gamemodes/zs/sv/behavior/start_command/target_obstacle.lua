ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

SC.OBSTACLE_TARGET_TIMEOUT = SC.OBSTACLE_TARGET_TIMEOUT or 4
SC.OBSTACLE_TARGET_RETRY_DELAY = SC.OBSTACLE_TARGET_RETRY_DELAY or 6
SC.OBSTACLE_TARGET_SWING_LIMIT_MIN = SC.OBSTACLE_TARGET_SWING_LIMIT_MIN or 1
SC.OBSTACLE_TARGET_SWING_LIMIT_MAX = SC.OBSTACLE_TARGET_SWING_LIMIT_MAX or 2
SC.OBSTACLE_TARGET_SWING_DEBOUNCE = SC.OBSTACLE_TARGET_SWING_DEBOUNCE or 0.55

function SC.ResetObstacleSwingState(controller)
    controller.ObstacleSwingCount = 0
    controller.ObstacleSwingLimit = 0
    controller.NextObstacleSwingCount = 0
end

function SC.BeginObstacleTarget(controller, target)
    controller.ActiveObstacleTarget = target
    controller.ObstacleTargetSince = CurTime()
    controller.ObstacleSwingCount = 0
    controller.ObstacleSwingLimit = math.random(
        SC.OBSTACLE_TARGET_SWING_LIMIT_MIN,
        SC.OBSTACLE_TARGET_SWING_LIMIT_MAX
    )
    controller.NextObstacleSwingCount = 0
end

function SC.RegisterObstacleSwing(controller, target)
    if not IsValid(controller) or not IsValid(target) or controller.Target ~= target then
        return false
    end

    if controller.ActiveObstacleTarget ~= target then
        SC.BeginObstacleTarget(controller, target)
    end

    if controller.NextObstacleSwingCount > CurTime() then
        return false
    end

    controller.ObstacleSwingCount = (controller.ObstacleSwingCount or 0) + 1
    controller.NextObstacleSwingCount = CurTime() + SC.OBSTACLE_TARGET_SWING_DEBOUNCE

    if controller.ObstacleSwingCount >= math.max(controller.ObstacleSwingLimit or 0, 1) then
        SC.MarkObstacleTargetTimedOut(controller, target)
    end

    return true
end

function SC.ClearObstacleTargetState(controller)
    controller.ActiveObstacleTarget = nil
    controller.ObstacleTargetSince = 0
    SC.ResetObstacleSwingState(controller)
end

function SC.MarkObstacleTargetTimedOut(controller, target)
    controller.LastObstacleTarget = target
    controller.ObstacleTargetRetryUntil = CurTime() + SC.OBSTACLE_TARGET_RETRY_DELAY
    SC.ClearObstacleTargetState(controller)
    controller.Target = nil
    controller.LookAtTime = 0
    SC.ClearGoal(controller)
end

function SC.IsFragileMapBreakable(ent)
    if not IsValid(ent) or ent:GetClass() ~= "func_breakable" then
        return false
    end

    if not ZSB.Map:GetValue("zombieBreakCheck") then
        return false
    end

    if not ent.GetMaxHealth then
        return true
    end

    return ent:GetMaxHealth() <= 500
end

function SC.IsSimpleObstacleTarget(_, ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass()

    if class == "func_breakable" or class == "func_physbox" then
        if ent.GetMaxHealth and ent:GetMaxHealth() > 1 then
            return true
        end

        return class == "func_breakable" and SC.IsFragileMapBreakable(ent)
    end

    if class == "func_breakable_surf" then
        return true
    end

    if class == "prop_physics" then
        if not ent.GetMaxHealth then
            return false
        end

        local model = ent:GetModel()

        if SC.IsIgnoredPropModel(model) then
            return false
        end

        if SC.IsBoardModel(model) then
            return SC.IsMapBoardEntity(ent)
        end

        return true
    end

    if class == "prop_dynamic" then
        return ent.GetMaxHealth and ent:GetMaxHealth() > 1
    end

    if class == "func_physbox" then
        return ent.GetMaxHealth and ent:GetMaxHealth() > 1
    end

    return false
end