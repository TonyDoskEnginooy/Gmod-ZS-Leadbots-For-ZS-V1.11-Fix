local function includeSetupMoveModule(fileName)
    include("setup_move/" .. fileName)
end

includeSetupMoveModule("shared.lua")
includeSetupMoveModule("debug.lua")
includeSetupMoveModule("temperament.lua")
includeSetupMoveModule("retreat.lua")
includeSetupMoveModule("path_following.lua")
includeSetupMoveModule("aim.lua")

local SM = ZSB.SetupMove

-- Called before the engine processes movement.
function LeadBot.SetupMove(bot, cmd, mv)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    SM.EnsureControllerState(controller)

    controller.strategy = bot:LBGetStrategy()

    SM.PrepareControllerForMove(bot, controller, mv)

    SM.DebugBot(bot)

    if IsValid(controller.Target) then
        local distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())
        SM.Retreat(bot, controller, mv, distanceSqr, controller.strategy)
    end

    local lerp, lerpLook = SM.GetAimLerp(bot, controller, controller.strategy)
    local currentGoal, moveAngles = SM.UpdateMovement(bot, controller, mv)

    SM.ApplyTemperamentMovement(bot, controller, mv)

    SM.DebugPath(controller)
    SM.SetEyeAngles(bot, controller, currentGoal, moveAngles, lerp, lerpLook)
end
