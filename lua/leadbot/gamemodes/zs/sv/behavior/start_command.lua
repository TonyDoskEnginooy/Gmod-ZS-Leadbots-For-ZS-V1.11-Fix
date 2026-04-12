local function includeStartCommandModule(fileName)
    include("start_command/" .. fileName)
end

includeStartCommandModule("shared.lua")
includeStartCommandModule("zombie_targeting.lua")
includeStartCommandModule("zombie_prop_throw.lua")
includeStartCommandModule("map_interactions.lua")
includeStartCommandModule("survivor_breaking.lua")
includeStartCommandModule("movement_to_sigil.lua")
includeStartCommandModule("movement_without_target.lua")
includeStartCommandModule("combat_buttons.lua")
includeStartCommandModule("survival_weapon_selection.lua")

local SC = ZSB.StartCommand

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    local now = CurTime()
    local teamId = bot:Team()

    SC.EnsureControllerState(controller)
    SC.KillLonelyHordeBot(bot)
    SC.ForgetInvalidTarget(bot, controller)

    local foundEnts = ZSB.Util:FindEnts(bot)

    SC.ToggleMovingBrush(bot, foundEnts.near["func_movelinear"])

    if teamId == TEAM_SURVIVORS then
        SC.SetRoamState(bot, now)
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
