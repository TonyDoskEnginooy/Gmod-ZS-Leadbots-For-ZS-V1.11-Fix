ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

if SM._SharedLoaded then
    return
end

SM._SharedLoaded = true

local function SetJumpPower(bot)
    if bot:GetZombieClass() > 5 then
        bot:SetJumpPower(300)
    else
        bot:SetJumpPower(200)
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
    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
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
