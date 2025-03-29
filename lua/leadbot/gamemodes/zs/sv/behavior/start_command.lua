-- Cache cvars
local leadbot_hinfammo = GetConVar("leadbot_hinfammo")

-- Practire attacking enemies (players or bots)
local function TargetFacingEnemy(bot, facingPlysOrBots, controller)
    local newTarget = facingPlysOrBots and facingPlysOrBots[math.random(0, #facingPlysOrBots)]

    if not IsValid(newTarget) or not newTarget:IsPlayer() and not newTarget:IsNPC() then return end
    if not newTarget.Alive or not newTarget:Alive() then return end

    if newTarget:IsPlayer() and newTarget:Team() ~= bot:Team() or newTarget:IsNPC() and bot:Team() == TEAM_SURVIVORS then
        local lastTarget = controller.Target

        -- Do not kill chem zombies if they are too near (most times)
        if newTarget:IsPlayer() and newTarget:GetZombieClass() == 4 and (ZSB.Util:Odds(25) or newTarget:GetPos():DistToSqr(bot:GetPos()) > 67500) then
            return
        end

        -- No target = get target
        if not IsValid(lastTarget) then
            controller.Target = newTarget
            controller.ForgetTarget = CurTime() + math.random(2, 6)
        -- Older target = ...
        else
            -- Survivor
            if bot:Team() == TEAM_SURVIVORS then
                local targetDistance = lastTarget:GetPos():DistToSqr(bot:GetPos())
                local newTargetDistance = newTarget:GetPos():DistToSqr(bot:GetPos())

                -- "Another enemy is near me!"
                if targetDistance > newTargetDistance then  
                    controller.Target = newTarget
                    controller.ForgetTarget = CurTime() + math.random(2, 6)
                end
            -- Zombie
            else
                -- "That enemy is almost dead!"
                if newTarget:Health() < lastTarget:Health() then
                    controller.Target = newTarget
                    controller.ForgetTarget = CurTime() + math.random(2, 6)
                end
            end
        end
    end
end

local function TargetPredictViewmodel(bot, predictedViewmodelList, controller)
    for k, ent in ipairs(predictedViewmodelList) do
        if bot:Team() == TEAM_ZOMBIE and IsValid(ent) and not ent:IsWorld() and not ent:IsPlayer() and not (ent.IsLBot and ent:IsLBot()) and not ent:IsWeapon() and ent:GetClass() ~= "predicted_viewmodel" then 
            controller.Target = ent
            controller.ForgetTarget = CurTime() + math.random(2, 6)
            break
        end
    end
end

local function BreakFuncPropDoorRotating(bot, propDoorRotatingList)
    if propDoorRotatingList then
        if game.GetMap() == "zs_jail_v1" or game.GetMap() == "zs_placid" then
            local door = propDoorRotatingList[math.random(1, #propDoorRotatingList)]

            if IsValid(door) and door:GetClass() == "prop_door_rotating" then
                door:Fire("Break", bot, 0)
            end
        end
    end
end

local function ToggleFuncMoveLinear(bot, funcMovelinearList)
    if funcMovelinearList then
        local movelinear = funcMovelinearList[math.random(1, #funcMovelinearList)]

        if IsValid(movelinear) then
            if movelinear:GetName() ~= "BunkerDoor" then
                movelinear:Fire("Open", bot, 0)
            else
                movelinear:Fire("Close", bot, 0)
            end
        end
    end
end

local function TargetFuncBreakable(bot, funcBreakableList, controller)
    if funcBreakableList then
        local breakable = funcBreakableList[math.random(1, #funcBreakableList)]

        if IsValid(breakable) and breakable:GetMaxHealth() > 1 then
            local survivorBreak = ZSB.Map:GetValue("survivorBreak", false)
            local zombieBreakCheck = ZSB.Map:GetValue("zombieBreakCheck", false)
    
            if bot:Team() == TEAM_SURVIVORS and survivorBreak then
                controller.Target = breakable
                controller.ForgetTarget = CurTime() + math.random(2, 6)
            end

            if bot:Team() == TEAM_ZOMBIE and zombieBreakCheck then
                controller.Target = breakable
                controller.ForgetTarget = CurTime() + math.random(2, 6)
            end
        end
    end
end

local function TargetPhysbox(bot, funcPhysboxList, controller)
    if funcPhysboxList then
        local physbox = funcPhysboxList[math.random(1, #funcPhysboxList)]

        if IsValid(physbox) then
            local survivorBoxBreak = ZSB.Map:GetValue("survivorBoxBreak", false)

            if (bot:Team() == TEAM_ZOMBIE or survivorBoxBreak) and physbox:GetMaxHealth() > 1 then
                controller.Target = physbox
                controller.ForgetTarget = CurTime() + math.random(2, 6)
            end
        end
    end
end

local function TargetPropPhys(bot, propPhysicsList, controller)
    if propPhysicsList then
        local pphysics = propPhysicsList[math.random(1, #propPhysicsList)]
        local zombiePropCheck = ZSB.Map:GetValue("zombiePropCheck", false)

        if IsValid(pphysics) then
            if bot:Team() == TEAM_ZOMBIE or
                bot:Team() == TEAM_SURVIVORS and
                pphysics:Health() <= 50 and (
                    pphysics:GetModel() ~= "models/props_debris/wood_board04a.mdl" or
                    pphysics:GetModel() ~= "models/props_debris/wood_board05a.mdl" or
                    pphysics:GetModel() ~= "models/props_debris/wood_board06a.mdl"
                ) and
                pphysics:GetMaxHealth() > 1
            then
                if pphysics:GetModel() ~= "models/props_c17/playground_carousel01.mdl" then 
                    if pphysics:GetModel() ~= "models/props_wasteland/prison_lamp001a.mdl" then
                        if zombiePropCheck then
                            controller.Target = pphysics
                            controller.ForgetTarget = CurTime() + math.random(2, 6)
                        end
                    end
                end
            end

            if bot:GetMoveType() == MOVETYPE_LADDER then 
                if bot:Team() == TEAM_ZOMBIE and (
                        IsValid(controller.Target) and not
                        controller.Target:IsPlayer() and
                        controller.Target:GetClass() ~= "func_breakable" or
                        controller.Target == nil
                    ) or (
                        bot:Team() == TEAM_SURVIVORS and
                        pphysics:Health() <= 50 and (
                            pphysics:GetModel() ~= "models/props_debris/wood_board04a.mdl" or
                            pphysics:GetModel() ~= "models/props_debris/wood_board05a.mdl" or
                            pphysics:GetModel() ~= "models/props_debris/wood_board06a.mdl"
                        ) or
                        bot:Team() == TEAM_ZOMBIE
                    ) and
                    pphysics:GetMaxHealth() > 1
                then
                    if pphysics:GetModel() ~= "models/props_c17/playground_carousel01.mdl" then 
                        if pphysics:GetModel() ~= "models/props_wasteland/prison_lamp001a.mdl" then
                            if zombiePropCheck then
                                controller.Target = pphysics
                                controller.ForgetTarget = CurTime() + math.random(2, 6)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function BreakFuncBreakableSurt(bot, funcBreakableSurfList, controller)
    if funcBreakableSurfList then
        local breakableSurf = funcBreakableSurfList[math.random(1, #funcBreakableSurfList)]

        if IsValid(breakableSurf) then
            breakableSurf:Fire("Break")
            -- controller.Target = breakableSurf
        end
    end
end

local function TargetPropDynamic(bot, propDynamicList, controller)
    if propDynamicList then
        local dynamic = propDynamicList[math.random(1, #propDynamicList)]

        if IsValid(dynamic) and dynamic:GetMaxHealth() > 1 then
            controller.Target = dynamic
            controller.ForgetTarget = CurTime() + math.random(2, 6)
        end
    end
end

local function TargetNearEnemy(bot, nearPlysOrBots, controller)
    local newNearTarget = nearPlysOrBots and nearPlysOrBots[math.random(0, #nearPlysOrBots)]

    if IsValid(newNearTarget) and newNearTarget:IsPlayer() and newNearTarget:Team() ~= bot:Team() then
        if newNearTarget:GetZombieClass() ~= 4 or newNearTarget:GetZombieClass() == 4 and newNearTarget:GetPos():DistToSqr(bot:GetPos()) > 67500 then
            if not IsValid(target) then
                controller.Target = newNearTarget
                controller.ForgetTarget = CurTime() + math.random(2, 6)
            else
                if bot:Team() == TEAM_SURVIVORS then
                    if target:GetPos():DistToSqr(bot:GetPos()) > newNearTarget:GetPos():DistToSqr(bot:GetPos()) then  
                        controller.Target = newNearTarget
                        controller.ForgetTarget = CurTime() + math.random(2, 6)
                    end
                else
                    if target:Health() > newNearTarget:Health() then  
                        controller.Target = newNearTarget
                        controller.ForgetTarget = CurTime() + math.random(2, 6)
                    end
                end
                if math.random(1, 100) == 1 and bot:GetZombieClass() > 5 and bot:GetZombieClass() < 9 then 
                    buttons = buttons + IN_ATTACK
                end
            end
        end
    end
end

local function SetButtonPresses(bot, controller, cmd)
    local buttons = 0
    local target = controller.Target

    if bot:Team() == TEAM_SURVIVORS then 
        local botWeapon = bot:GetActiveWeapon()

        if IsValid(botWeapon) then 
            if not IsValid(target) then
                if botWeapon:Clip1() <= (botWeapon:GetMaxClip1() / 4) and leadbot_hinfammo:GetInt() < 1 then 
                    buttons = buttons + IN_RELOAD
                end
            else
                if botWeapon:Clip1() > 0 then 
                    if math.random(1, 2) == 1 then 
                        local distance = target:GetPos():DistToSqr(bot:GetPos())
 
                        if not target:IsPlayer() and not target:IsNPC() or
                            target:IsNPC() and IsValid(newTarget) or
                            target:IsPlayer() and not target:HasGodMode() and (
                                IsValid(newTarget) or
                                distance <= 5625
                            ) and (
                                distance > 67500 and target:GetZombieClass() == 4 or
                                target:GetZombieClass() > 4 or
                                target:GetZombieClass() < 4
                            )
                        then 
                            buttons = buttons + IN_ATTACK
                        end
                    end
                else
                    if leadbot_hinfammo:GetInt() < 1 then 
                        buttons = buttons + IN_RELOAD
                    end
                end
            end
        end
    end

    if bot:Team() == TEAM_ZOMBIE then
        if IsValid(target) then
            if math.random(1, 2) == 1 then 
                if bot:GetZombieClass() > 5 and bot:GetZombieClass() < 9 then 
                    if IsValid(newTarget) or not target:IsPlayer() and not target:IsNPC() then 
                        buttons = buttons + IN_ATTACK
                    end
                else
                    if not target:IsPlayer() and not target:IsNPC() then
                        buttons = buttons + IN_ATTACK
                    end
                    for _, fin in ipairs(ents.FindInSphere(bot:GetShootPos() + bot:GetAimVector() * 50, 20)) do
                        if IsValid(fin) and not fin:IsWorld() and not (fin.IsLBot and fin:IsLBot()) then 
                            buttons = buttons + IN_ATTACK
                        end
                    end
                end
                if target:IsPlayer() and IsValid(newTarget) and bot:LBGetZomSkill() == 1 then 
                    if bot:GetZombieClass() == 3 or bot:GetZombieClass() == 8 then
                        local distance = target:GetPos():DistToSqr(bot:GetPos())
                        if distance <= 90000 then 
                            buttons = buttons + IN_ATTACK2
                        end
                    elseif bot:GetZombieClass() == 2 then 
                        if bot:IsOnGround() then 
                            buttons = buttons + IN_ATTACK2
                        end
                    else
                        buttons = buttons + IN_ATTACK2
                    end
                end
            end
        end
        if not IsValid(target) and bot:LBGetZomSkill() == 1 then
            if math.random(1, 100) == 1 then 
                if bot:IsOnGround() and bot:GetZombieClass() ~= 4 and bot:GetZombieClass() ~= 9 then
                    buttons = buttons + IN_ATTACK2
                end
            end
        end
    end

    if bot:GetMoveType() == MOVETYPE_LADDER then
        local pos = controller.goalPos
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        if pos.z > controller:GetPos().z then
            if not bot:IsFrozen() then 
                controller.LookAt = Angle(-30, ang.y, 0)
            end
        else
            if not bot:IsFrozen() then 
                controller.LookAt = Angle(30, ang.y, 0)
            end
        end

        controller.LookAtTime = CurTime() + 0.1
        controller.NextJump = -1
        buttons = buttons + IN_FORWARD
    end

    if not IsValid(controller.Target) and bot:Team() == TEAM_SURVIVORS or bot:Team() == TEAM_ZOMBIE then
        if not bot:IsFrozen() then 
            if controller.NextJump == 0 then
                controller.NextJump = CurTime() + 1
                buttons = buttons + IN_JUMP
            end
            if controller.NextDuck > CurTime() or controller.NextJump > CurTime() and not bot:IsOnGround() and bot:WaterLevel() == 0 then
                buttons = buttons + IN_DUCK
            end
        end
    end

    if not IsValid(controller.Target) and bot:Team() == TEAM_SURVIVORS and controller.PosGen == nil then 
        buttons = buttons + IN_DUCK
    end

    if bot:GetVelocity():Length2DSqr() <= 225 and bot:GetMoveType() ~= MOVETYPE_LADDER and controller.PosGen ~= nil then 
        if target == nil or IsValid(target) and not target:IsPlayer() and target:Health() <= 0 and controller.PosGen ~= nil then 
            if not bot:IsFrozen() then 
                if math.random(1, 2) == 1 then 
                    controller.NextJump = 0
                end
                if bot:Team() == TEAM_ZOMBIE then 
                    if bot:GetZombieClass() > 5 or bot:GetZombieClass() < 5 then
                        if math.random(1, 2) == 1 then 
                            buttons = buttons + IN_ATTACK
                        end
                    end
                end
            end
        end
    end

    cmd:SetButtons(buttons)
    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

-- https://wiki.facepunch.com/gmod/GM:StartCommand
-- "the best solution to control" bots
function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()

    if not IsValid(controller) then return end

    local foundEnts = ZSB.Util:FindEnts(bot)
    local facingPlysOrBots = foundEnts.facing["player"]
    local nearPlysOrBots = foundEnts.near["player"]

    TargetFacingEnemy(bot, facingPlysOrBots, controller)
    TargetNearEnemy(bot, nearPlysOrBots, controller)
    TargetPredictViewmodel(bot, foundEnts.near['predicted_viewmodel'], controller)
    TargetFuncBreakable(bot, foundEnts.near['func_breakable'], controller)
    TargetPhysbox(bot, foundEnts.near['func_physbox'], controller)
    TargetPropPhys(bot, foundEnts.near['prop_physics'], controller)
    TargetPropDynamic(bot, foundEnts.near['prop_dynamic'], controller)

    BreakFuncPropDoorRotating(bot, foundEnts.near['prop_door_rotating'])
    BreakFuncBreakableSurt(bot, foundEnts.near['func_breakable_surf'], controller)

    ToggleFuncMoveLinear(bot, foundEnts.near['func_movelinear'])

    SetButtonPresses(bot, controller, cmd)
end