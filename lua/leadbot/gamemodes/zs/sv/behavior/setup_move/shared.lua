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

local function ForceControllerRecompute(controller)
    if controller.PosGen and controller.P and controller.TPos ~= controller.PosGen then
        controller.TPos = controller.PosGen
        controller.P:Compute(controller, controller.PosGen)
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

function SM.EnsureControllerState(controller)
    controller.LastSegmented = controller.LastSegmented or 0
    controller.NextJump = controller.NextJump or 0
    controller.NextCenter = controller.NextCenter or 0
    controller.nextStuckJump = controller.nextStuckJump or 0
    controller.NextRandomJump = controller.NextRandomJump or 0
    controller.LastStairTime = controller.LastStairTime or 0
    controller.strafeAngle = controller.strafeAngle or 1
    controller.LookAtTime = controller.LookAtTime or 0
    controller.cur_segment = controller.cur_segment or 2
    controller.MeleeRetreatUntil = controller.MeleeRetreatUntil or 0
    controller.LastMeleeAttackTime = controller.LastMeleeAttackTime or 0
end

function SM.PrepareControllerForMove(bot, controller, mv)
    SetJumpPower(bot)
    SetBaseForwardSpeed(bot, controller, mv)
    ForceControllerRecompute(controller)
    UpdateControllerTransform(bot, controller)
end
