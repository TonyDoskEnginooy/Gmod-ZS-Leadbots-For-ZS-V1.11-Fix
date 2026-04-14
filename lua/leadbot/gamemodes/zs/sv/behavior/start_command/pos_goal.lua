ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

function SC.UpdateGoalFromTarget(bot, controller)
    if not IsValid(controller.Target) then return end

    if bot:IsPlayer() and controller.Target:IsPlayer() and (
        bot:Team() ~= controller.Target:Team()
        or (bot:Team() == TEAM_SURVIVORS and controller.Target:IsNPC())
    ) then
        controller.PosGen = controller.Target:GetPos()
    elseif bot:Team() == TEAM_SURVIVORS and SC.IsSurvivorBreakTarget(bot, controller.Target) then
        controller.PosGen = ZSB.Util.GetPos(controller.Target, bot:GetPos())
    end
end

function SC.ClearGoal(controller)
    if not IsValid(controller) then
        return
    end

    controller.PosGen = nil
    controller.TPos = nil
    controller.ForgetTarget = 0
    controller.CurSegmentIndex = 2
    controller.GoalPos = vector_origin
    controller.NextStrafe = 0
    controller.NextJump = -1
    controller.NextRandomJump = 0
    controller.NextDuck = 0
    controller.NextDuckCheck = 0
    controller.StrafeAngle = 0
end