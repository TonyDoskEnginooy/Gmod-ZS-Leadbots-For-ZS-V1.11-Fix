ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local function SetJumpPower(bot)
    local jumpPower = bot:GetZombieClass() > 5 and 300 or 200

    if bot.LeadBot_LastJumpPower ~= jumpPower then
        bot:SetJumpPower(jumpPower)
        bot.LeadBot_LastJumpPower = jumpPower
    end
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

local function ShouldRecomputePath(controller)
    if not isvector(controller.PosGen) then
        return false
    end

    if controller.TPos ~= controller.PosGen then
        return true
    end

    if not controller.Path or not controller.Path.IsValid then
        return true
    end

    return not controller.Path:IsValid()
end

local function ForceControllerRecompute(controller)
    if ShouldRecomputePath(controller) then
        controller.TPos = controller.PosGen
        controller:ComputePath()
    end
end

local function UpdateControllerTransform(bot, controller)
    local botPos = bot:GetPos()
    local botAngles = bot:EyeAngles()

    if controller:GetPos() ~= botPos then
        controller:SetPos(botPos)
    end

    if controller:GetAngles() ~= botAngles then
        controller:SetAngles(botAngles)
    end
end

function SM.ClearCompletedGoal(controller)
    controller.PosGen = nil
    controller.TPos = nil
    controller.ForgetTarget = 0
    controller.CurSegmentIndex = 2
    controller.GoalPos = vector_origin
end

function SM.PrepareControllerForMove(bot, controller, mv)
    SetJumpPower(bot)
    SetBaseForwardSpeed(bot, controller, mv)
    ForceControllerRecompute(controller)
    UpdateControllerTransform(bot, controller)
end
