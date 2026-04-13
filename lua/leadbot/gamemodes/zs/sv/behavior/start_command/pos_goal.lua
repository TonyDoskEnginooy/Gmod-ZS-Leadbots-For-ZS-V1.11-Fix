ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

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