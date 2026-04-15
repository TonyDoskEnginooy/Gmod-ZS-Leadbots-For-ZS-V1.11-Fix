local function includeSetupMoveModule(fileName)
    include("setup_move/" .. fileName)
end

includeSetupMoveModule("base.lua")
includeSetupMoveModule("temperament.lua")
includeSetupMoveModule("retreat.lua")
includeSetupMoveModule("path.lua")
includeSetupMoveModule("aim.lua")
includeSetupMoveModule("debug.lua")

local SM = ZSB.SetupMove

function LeadBot.SetupMove(bot, cmd, mv)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    local strategy = bot:LBGetStrategy()
    local now = CurTime()

    -- Movement base

    SM.PrepareControllerForMove(bot, controller, mv)

    -- Start normal movement

    local currentGoal, moveAngles =
        SM.UpdateMovement(bot, controller, mv)

    SM.SetEyeAngles(bot, controller, currentGoal, moveAngles, strategy)

    local distanceSqr = nil

    if IsValid(controller.Target) then
        distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())
    end

    -- Apply movement specializations

    SM.ApplyTemperamentMovement(bot, controller, mv)

    -- Safety, at last

    SM.Retreat(bot, controller, mv, distanceSqr, strategy, now)

    -- Debug

    --SM.DebugBot(bot)
    --SM.DebugPath(controller)
end
