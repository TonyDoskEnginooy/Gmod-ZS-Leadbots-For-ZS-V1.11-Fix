local function includeSCModule(fileName)
    include("start_command/" .. fileName)
end

includeSCModule("attack.lua")
includeSCModule("buttons.lua")
includeSCModule("map_interactions.lua")
includeSCModule("pos_goal_no_target.lua")
includeSCModule("pos_goal.lua")
includeSCModule("shared.lua")
includeSCModule("survivor_destruction.lua")
includeSCModule("survivor_weapon.lua")
includeSCModule("target_obstacle.lua")
includeSCModule("target.lua")
includeSCModule("zombie_destruction.lua")
includeSCModule("zombie_prop_throw.lua")

ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    local now = CurTime()
    local teamId = bot:Team()

    SC.StartStair(bot, controller, now)

    if controller.Path then
        local segments = controller.Path:GetAllSegments()
        
        if segments then
            local currentGoal = controller.PosGen and segments[controller.CurSegmentIndex] or nil

            if currentGoal then
                SC.HandleJump(bot, controller, currentGoal, now)
                SC.HandleCrouch(bot, controller, currentGoal, now)
            end
        end
    end

    SC.KillLonelyHordeBot(bot)
    SC.ForgetInvalidTarget(bot, controller)

    local foundEnts = ZSB.Util:FindEnts(bot)

    SC.ToggleMovingBrush(bot, foundEnts.near["func_movelinear"])

    if teamId == TEAM_SURVIVORS then
        SC.SetRoamState(bot)
        SC.AcquireTemperamentTarget(bot, controller, foundEnts)

        if not IsValid(controller.Target) then
            SC.AcquireSurvivorBreakTarget(bot, controller, foundEnts)
        end

        if IsValid(controller.Target) then
            local botPos = bot:GetPos()
            local targetPos = controller.Target:GetPos()
            local distanceSqr = targetPos:DistToSqr(botPos)

            SC.SelectSurvivorWeapon(bot, distanceSqr, controller, foundEnts)
            SC.UpdateGoalFromTarget(bot, controller)
        elseif not controller.PosGen or controller.LastSegmented < now then
            SC.MoveWithoutTarget(bot, controller, bot:LBGetStrategy(), foundEnts)
        end
    elseif teamId == TEAM_ZOMBIE then
        SC.ApplyZombieCheats(bot)
        SC.BreakRotatingDoor(bot, foundEnts.near["prop_door_rotating"])
        SC.BreakBreakableSurface(foundEnts.near["func_breakable_surf"])
        SC.AcquireTemperamentTarget(bot, controller, foundEnts)

        if IsValid(controller.Target) then
            SC.TryThrowNearbyProp(bot, controller, foundEnts)
            SC.UpdateGoalFromTarget(bot, controller)
        elseif not controller.PosGen or controller.LastSegmented < now then
            SC.MoveWithoutTarget(bot, controller, bot:LBGetStrategy(), foundEnts)
        end
    end

    local buttons = SC.BuildActionButtons(bot, controller)

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end
