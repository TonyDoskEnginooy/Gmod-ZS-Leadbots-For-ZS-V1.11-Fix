-- Cache cvars
local leadbot_zcheats = GetConVar("leadbot_zcheats")
local leadbot_hordes = GetConVar("leadbot_hordes")
local leadbot_quota = GetConVar("leadbot_quota")
local leadbot_skill = GetConVar("leadbot_skill")
local leadbot_hinfammo = GetConVar("leadbot_hinfammo")

local function SetCampingEyeAngles(bot, controller)
    local strategy = bot:LBGetStrategy()
    local sigil1 = ZSB.Map:GetValue("sigil1")
    local sigil2 = ZSB.Map:GetValue("sigil2")
    local sigil3 = ZSB.Map:GetValue("sigil3")

    if not IsValid(controller.Target) and bot:Team() == TEAM_SURVIVORS then
        if strategy == 1 and sigil3 and bot:GetPos():DistToSqr(sigil3:GetPos()) <= 5000 or
            strategy == 2 and sigil2 and bot:GetPos():DistToSqr(sigil2:GetPos()) <= 5000 or
            strategy == 3 and sigil1 and bot:GetPos():DistToSqr(sigil1:GetPos()) <= 5000
        then
            local openVar = math.random(-90, 90)
            local hallVar = math.random(-45, 45)
            local doorVar = math.random(-15, 15)
            local eyeAngles = ZSB.Map:GetValue("eyeAngles", nil, strategy, doorVar, hallVar, openVar)

            bot:SetEyeAngles(eyeAngles)
        end
    end
end

local function Cheat(bot)
    if not (bot:Team() == TEAM_ZOMBIE) or not leadbot_zcheats:GetBool() then return end

    if bot:GetZombieClass() == 8 then 
        bot:Freeze(false)
    end

    if bot:GetZombieClass() == 3 or bot:GetZombieClass() == 5 then 
        GAMEMODE:SetPlayerSpeed(bot, ZombieClasses[bot:GetZombieClass()].Speed)
    end
end

local function KillAloneHordeBot(bot)
    if leadbot_hordes:GetInt() >= 1 and bot:Team() == TEAM_SURVIVORS and leadbot_quota:GetInt() < 2 then 
        bot:Kill()
    end
end

local function SetJumpPower(bot)
    if bot:GetZombieClass() > 5 then 
        bot:SetJumpPower(300)
    else
        bot:SetJumpPower(200)
    end
end

local function DebugBot(bot)
    if not ZSB.DEBUG then return end

    local min, max = bot:GetHull()

    debugoverlay.Text(bot:EyePos(), bot:Nick(), 0.03, false)
    debugoverlay.Box(bot:GetPos(), min, max, 0.03, Color(255, 255, 255, 0))
end

local function SetBaseForwardSpeed(bot, controller, mv)
    if bot:Team() == TEAM_SURVIVORS then 
        if controller.Target == nil then 
            mv:SetForwardSpeed(1200)
        end
    else
        mv:SetForwardSpeed(1200)
    end
end

local function SetRoam(bot)
    if bot:Team() == TEAM_SURVIVORS then 
        if bot:Health() <= 50 or team.NumPlayers(TEAM_SURVIVORS) <= team.NumPlayers(TEAM_ZOMBIE) then
            bot.freeRoam = false
        end
    end
end

local function ForceControllerRecompute(controller)
    if controller.PosGen and controller.P and controller.TPos ~= controller.PosGen then
        controller.TPos = controller.PosGen
        controller.P:Compute(controller, controller.PosGen)
    end
end

local function ForgetTarget(controller)
    if not IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end
end

local function TargetEnemyInFrontNext(bot, controller)
    if not IsValid(controller.Target) then
        for _, ent in ipairs(ents.FindInSphere(bot:GetShootPos() + bot:GetAimVector() * 50, 20)) do
            if IsValid(ent) and ent:IsPlayer() and ent ~= bot and ent:Team() ~= bot:Team() and ent:Alive() and not ent:IsWorld() then 
                controller.Target = ent
            end
        end
    end
end

local function RememberTarget(bot, controller)
    if IsValid(controller.Target) then
        local feet = Vector(0, 0, -29)
        local filterList = {controller, bot, function( ent ) return ( ent:GetClass() == "prop_physics" ) end}
        local pet = util.QuickTrace(bot:GetPos() + feet, bot:GetForward() * 10000000000, filterList)

        if controller.ForgetTarget < CurTime() and pet.Entity == controller.Target then
            controller.ForgetTarget = CurTime() + 4
        end
    end
end

local function UpdateControllerPos(bot, controller)
    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end
end

local function UpdateControllerAngles(bot, controller)
    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
    end
end

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
            if not IsValid(newNearTarget) then
                controller.Target = newNearTarget
                controller.ForgetTarget = CurTime() + math.random(2, 6)
            else
                if bot:Team() == TEAM_SURVIVORS then
                    if newNearTarget:GetPos():DistToSqr(bot:GetPos()) > newNearTarget:GetPos():DistToSqr(bot:GetPos()) then  
                        controller.Target = newNearTarget
                        controller.ForgetTarget = CurTime() + math.random(2, 6)
                    end
                else
                    if newNearTarget:Health() > newNearTarget:Health() then  
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

local function SetMovementWithoutTarget(bot, controller, strategy)
    if bot:Team() == TEAM_SURVIVORS then
        local sigil1 = ZSB.Map:GetValue("sigil1")
        local sigil2 = ZSB.Map:GetValue("sigil2")
        local sigil3 = ZSB.Map:GetValue("sigil3")

        -- find a random spot on the map if human, and then do it again in 5 seconds!
        if bot.freeRoam or strategy == 0 then
            if bot:LBGetSurvSkill() == 0 then 
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
            if strategy <= 2 then 
                controller.PosGen = controller:FindSpot("random", {radius = 1000000})
                controller.LastSegmented = CurTime() + 1000000
            else
                if team.NumPlayers(TEAM_ZOMBIE) > 0 then 
                    for k, plyOrBot in RandomPairs(player.GetAll()) do 
                        if IsValid(plyOrBot) and plyOrBot:Team() == TEAM_ZOMBIE and not plyOrBot:HasGodMode() and plyOrBot:Alive() then 
                            controller.PosGen = plyOrBot:GetPos()
                            controller.LastSegmented = CurTime() + 10
                            break
                        end
                    end
                else
                    controller.PosGen = controller:FindSpot("random", {radius = 1000000})
                    controller.LastSegmented = CurTime() + 1000000
                end
            end
        elseif strategy == 1 then 
            -- camping ai 
            if sigil3Valid then
                local dist = bot:GetPos():DistToSqr(sigil3:GetPos())
                    if dist <= 2500 then -- we're here
                        controller.PosGen = nil
                    else -- we need to run...
                        controller.PosGen = sigil3:GetPos()
                    end

                controller.LastSegmented = CurTime() + 1
            else
                if bot:LBGetSurvSkill() == 0 then 
                    bot:SelectWeapon("weapon_zs_swissarmyknife")
                end
                controller.PosGen = controller:FindSpot("random", {radius = 1000000})
                controller.LastSegmented = CurTime() + 5
            end
        elseif strategy == 2 then
            if sigil2Valid then 
                local dist = bot:GetPos():DistToSqr(sigil2:GetPos())
                    if dist <= 2500 then
                        controller.PosGen = nil
                    else
                        controller.PosGen = sigil2:GetPos()
                    end

                controller.LastSegmented = CurTime() + 1
            else
                if bot:LBGetSurvSkill() == 0 then 
                    bot:SelectWeapon("weapon_zs_swissarmyknife")
                end
                for k, plyOrBot in RandomPairs(player.GetAll()) do 
                    if IsValid(plyOrBot) and plyOrBot:Team() == TEAM_SURVIVORS then 
                        controller.PosGen = plyOrBot:GetPos()
                        controller.LastSegmented = CurTime() + 10
                        break
                    end
                end
            end
        elseif strategy == 3 then
            if sigil1Valid then 
                local dist = bot:GetPos():DistToSqr(sigil1:GetPos())
                    if dist <= 2500 then
                        controller.PosGen = nil
                    else
                        controller.PosGen = sigil1:GetPos()
                    end
                controller.LastSegmented = CurTime() + 1
            else
                if bot:LBGetSurvSkill() == 0 then 
                    bot:SelectWeapon("weapon_zs_swissarmyknife")
                end
                for k, plyOrBot in RandomPairs(player.GetAll()) do 
                    if IsValid(plyOrBot) and plyOrBot:Team() == TEAM_ZOMBIE and not plyOrBot:HasGodMode() then 
                        controller.PosGen = plyOrBot:GetPos()
                        controller.LastSegmented = CurTime() + 10
                        break
                    end
                end
            end
        end
    end

    if bot:Team() == TEAM_ZOMBIE then
        -- find survivor position
        if team.NumPlayers(TEAM_SURVIVORS) ~= 0 then
            for k, plyOrBot in RandomPairs(player.GetAll()) do 
                if IsValid(plyOrBot) and plyOrBot:Team() == TEAM_SURVIVORS then 
                    controller.PosGen = plyOrBot:GetPos()
                    controller.LastSegmented = CurTime() + 1000000
                    break
                end
            end
        end
    end
end

local function SetMoveToTarget(bot, controller)
    -- move to our target
    if bot:IsPlayer() and controller.Target:IsPlayer() and bot:Team() ~= controller.Target:Team() or bot:Team() == TEAM_SURVIVORS and controller.Target:IsNPC() then 
        controller.PosGen = controller.Target:GetPos()
        controller.LastSegmented = CurTime() + 0.1
    end
end

local function Retreat(bot, controller, mv, distance, strategy)
    -- back up if the target is really close
    -- TODO: find a random spot rather than trying to back up into what could just be a wall
    -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
    local filterList = {controller, bot, function( ent ) return ( ent:GetClass() == "prop_physics" ) end}
    local prt = util.QuickTrace(bot:EyePos(), bot:GetAimVector() * 10000000000, filterList)

    if controller.Target:IsPlayer() or controller.Target:IsNPC() then
        if bot:Team() == TEAM_ZOMBIE then 
            mv:SetForwardSpeed(1200)
            if distance > 45000 and bot:LBGetZomSkill() == 1 and IsValid(prt.Entity) then
                if controller.strafeAngle == 1 then
                    mv:SetSideSpeed(1500)
                elseif controller.strafeAngle == 2 then
                    mv:SetSideSpeed(-1500)
                end
            end
        else
            if strategy == 0 or bot.freeRoam then 
                if bot:Health() > 70 then 
                    if distance <= 45000 then
                        mv:SetForwardSpeed(-1200)
                    end
                elseif bot:Health() <= 70 and bot:Health() > 40 then 
                    if distance <= 90000 then
                        mv:SetForwardSpeed(-1200)
                    end
                elseif bot:Health() <= 40 and bot:Health() > 10 then 
                    if distance <= 135000 then
                        mv:SetForwardSpeed(-1200)
                    end
                elseif bot:Health() <= 10 then 
                    if distance <= 180000 then
                        mv:SetForwardSpeed(-1200)
                    end
                end
                if bot:LBGetSurvSkill() == 0 and IsValid(prt.Entity) then
                    if controller.strafeAngle == 1 then
                        mv:SetSideSpeed(1500)
                    elseif controller.strafeAngle == 2 then
                        mv:SetSideSpeed(-1500)
                    end
                end
            else
                if distance <= 45000 and IsValid(prt.Entity) then 
                    mv:SetForwardSpeed(-1200)
                    if controller.strafeAngle == 1 then
                        mv:SetSideSpeed(1500)
                    elseif controller.strafeAngle == 2 then
                        mv:SetSideSpeed(-1500)
                    end
                end
                if bot:Health() <= 40 and IsValid(prt.Entity) then 
                    if controller.Target:IsPlayer() and ( controller.Target:GetZombieClass() == 2 or controller.Target:GetZombieClass() > 5 and controller.Target:GetZombieClass() < 9 ) or controller.Target:IsNPC() then                                 if controller.strafeAngle == 1 then
                            mv:SetSideSpeed(1500)
                        elseif controller.strafeAngle == 2 then
                            mv:SetSideSpeed(-1500)
                        end
                    end
                end
            end
        end
    else
        mv:SetForwardSpeed(1200)
    end
end

local function SelectWeapon(bot, distance)
    if not (bot:Team() == TEAM_SURVIVORS) then return end

    local tier2 = GetConVar("zs_rewards_1"):GetInt()
    local tier3 = GetConVar("zs_rewards_3"):GetInt()
    local tier4 = GetConVar("zs_rewards_4"):GetInt()
    local botwep = bot:GetActiveWeapon()
    local botclip = botwep.Clip1 and botwep:Clip1() or 0

    if distance > 30000 then 
        if bot:Frags() < tier2 then
            if bot:GetAmmoCount("Pistol") > 0 then 
                bot:SelectWeapon("weapon_zs_battleaxe")
                bot:SelectWeapon("weapon_zs_peashooter")
            elseif botclip <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        elseif bot:Frags() >= tier2 and bot:Frags() < tier3 then
            if bot:GetAmmoCount("Pistol") > 0 then 
                bot:SelectWeapon("weapon_zs_deagle")
                bot:SelectWeapon("weapon_zs_glock3")
                bot:SelectWeapon("weapon_zs_magnum")
            elseif botclip <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        elseif bot:Frags() >= tier3 then
            if bot:GetAmmoCount("SMG1") > 0 then 
                bot:SelectWeapon("weapon_zs_uzi")
                bot:SelectWeapon("weapon_zs_smg")
            elseif bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") > 0 then 
                bot:SelectWeapon("weapon_zs_deagle")
                bot:SelectWeapon("weapon_zs_glock3")
                bot:SelectWeapon("weapon_zs_magnum")
            elseif botclip <= 0 and bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") <= 0 then 
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        end
    else
        if bot:Frags() < tier2 then
            if bot:GetAmmoCount("Pistol") > 0 then 
                bot:SelectWeapon("weapon_zs_battleaxe")
                bot:SelectWeapon("weapon_zs_peashooter")
            elseif botclip <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        elseif bot:Frags() >= tier2 and bot:Frags() < tier3 then
            if bot:GetAmmoCount("Pistol") > 0 then 
                bot:SelectWeapon("weapon_zs_deagle")
                bot:SelectWeapon("weapon_zs_glock3")
                bot:SelectWeapon("weapon_zs_magnum")
            elseif botclip <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        elseif bot:Frags() >= tier3 and bot:Frags() < tier4 then
            if bot:GetAmmoCount("SMG1") > 0 then 
                bot:SelectWeapon("weapon_zs_uzi")
                bot:SelectWeapon("weapon_zs_smg")
            elseif bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") > 0 then 
                bot:SelectWeapon("weapon_zs_deagle")
                bot:SelectWeapon("weapon_zs_glock3")
                bot:SelectWeapon("weapon_zs_magnum")
            elseif botclip <= 0 and bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        elseif bot:Frags() >= tier4 then
            if bot:GetAmmoCount("Buckshot") > 0 then 
                bot:SelectWeapon("weapon_zs_sweepershotgun")
            elseif bot:GetAmmoCount("Buckshot") <= 0 and bot:GetAmmoCount("SMG1") > 0 then
                bot:SelectWeapon("weapon_zs_uzi")
                bot:SelectWeapon("weapon_zs_smg")
            elseif bot:GetAmmoCount("Buckshot") <= 0 and bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") > 0 then 
                bot:SelectWeapon("weapon_zs_deagle")
                bot:SelectWeapon("weapon_zs_glock3")
            elseif botclip <= 0 and bot:GetAmmoCount("Buckshot") <= 0 and bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        end
    end
end

local function GetLerp(bot, controller, strategy, aimskill)
    local lerp
    local lerpc

    if leadbot_skill:GetInt() ~= 4 then
        if bot:Team() == TEAM_SURVIVORS and IsValid(controller.Target) then
            if strategy > 0 and not bot.freeRoam then 
                lerp = FrameTime() * aimskill / 2
                lerpc = FrameTime() * aimskill / 2
            else
                lerp = FrameTime() * aimskill
                lerpc = FrameTime() * aimskill
            end
        end
        if bot:Team() == TEAM_SURVIVORS and not IsValid(controller.Target) or bot:Team() == TEAM_ZOMBIE then
            lerp = FrameTime() * (aimskill / 4)
            lerpc = FrameTime() * (aimskill / 4)
        end
    else
        if bot:Team() == TEAM_SURVIVORS and IsValid(controller.Target) then
            if strategy > 0 and not bot.freeRoam then 
                lerp = FrameTime() * bot:LBGetShootSkill() / 2
                lerpc = FrameTime() * bot:LBGetShootSkill() / 2
            else
                lerp = FrameTime() * bot:LBGetShootSkill()
                lerpc = FrameTime() * bot:LBGetShootSkill()
            end
        end
        if bot:Team() == TEAM_SURVIVORS and not IsValid(controller.Target) or bot:Team() == TEAM_ZOMBIE then
            lerp = FrameTime() * (bot:LBGetShootSkill() / 4)
            lerpc = FrameTime() * (bot:LBGetShootSkill() / 4)
        end
    end

    return lerp, lerpc
end

local function GetAimSkill()
    local aimskill

    if leadbot_skill:GetInt() == 0 then
        aimskill = 4
    elseif leadbot_skill:GetInt() == 1 then
        aimskill = 8
    elseif leadbot_skill:GetInt() == 2 then
        aimskill = 12
    else
        aimskill = 16
    end

    return aimskill
end

local function UpdateMovement(bot, controller, mv, strategy, aimskill, lerp, lerpc)
    -- movement also has a similar issue, but it's more severe...
    if not controller.P then
        return
    end

    local segments = controller.P:GetAllSegments()

    if not segments then return end

    local cur_segment = controller.cur_segment
    local curGoal = (controller.PosGen and segments[cur_segment])

    local mva

    -- got nowhere to go, why keep moving?
    if curGoal then
        -- think every step of the way!
        if segments[cur_segment + 1] and Vector(bot:GetPos().x, bot:GetPos().y, 0):DistToSqr(Vector(curGoal.pos.x, curGoal.pos.y)) < 100 then
            controller.cur_segment = controller.cur_segment + 1
            curGoal = segments[controller.cur_segment]
        end

        local goalpos = curGoal.pos

        if bot:GetVelocity():Length2DSqr() <= 225 then
            if not bot:IsFrozen() then 
                if not IsValid(controller.Target) and (bot:Team() == TEAM_SURVIVORS or bot:Team() == TEAM_ZOMBIE) then
                    if controller.nextStuckJump < CurTime() then
                        if not bot:Crouching() then
                            controller.NextJump = 0
                        end
                        controller.nextStuckJump = CurTime() + math.Rand(1, 2)
                    end
                end
            end
        end

        if controller.NextCenter < CurTime() then
            if curGoal.area:GetAttributes() ~= NAV_MESH_JUMP and (bot:GetVelocity():Length2DSqr() <= 225 or IsValid(controller.Target)) then
                if not bot:IsFrozen() then 
                    controller.strafeAngle = ((controller.strafeAngle == 1 and 2) or 1)
                    controller.NextCenter = CurTime() + math.Rand(0.3, 0.9)
                end
            end
        end

        if controller.NextCenter > CurTime() then
            if curGoal.area:GetAttributes() ~= NAV_MESH_JUMP and
               bot:GetVelocity():Length2DSqr() <= 10000 and
               (
                    not IsValid(controller.Target) and
                    bot:GetMoveType() ~= MOVETYPE_LADDER or
                    bot:Team() == TEAM_SURVIVORS and
                    IsValid(controller.Target) and
                    (
                        strategy == 0 or
                        bot.freeRoam
                    ) or
                    bot:Team() == TEAM_ZOMBIE and
                    IsValid(controller.Target) and
                    strategy > 1
                ) 
            then
                if not bot:IsFrozen() then 
                    if controller.strafeAngle == 1 then
                        mv:SetSideSpeed(1500)
                        if bot:LBGetSurvSkill() == 1 then 
                            mv:SetForwardSpeed(0)
                        end
                    elseif controller.strafeAngle == 2 then
                        mv:SetSideSpeed(-1500)
                        if bot:LBGetSurvSkill() == 1 then 
                            mv:SetForwardSpeed(0)
                        end
                    end
                end
            end
        end

        -- jump
        if not bot:IsFrozen() and
            (
                controller.NextJump ~= 0
                and curGoal.type > 1
                and controller.NextJump < CurTime() or
                controller.NextJump ~= 0 and
                curGoal.area:GetAttributes() == NAV_MESH_JUMP and
                controller.NextJump < CurTime()
            )
        then
            controller.NextJump = 0
        end

        -- duck
        local dtnse = util.QuickTrace(bot:EyePos(), bot:GetForward() * 90 - ( bot:GetViewOffsetDucked() * 3 ), bot)
        if curGoal.area:GetAttributes() == NAV_MESH_CROUCH or IsValid(dtnse.Entity) then
            controller.NextDuck = CurTime() + 0.1
        end

        controller.goalPos = goalpos

        mva = ((goalpos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        mv:SetMoveAngles(mva)
    else
        if bot:Team() == TEAM_SURVIVORS then
            mv:SetForwardSpeed(-1200)
        end
        if bot:Team() == TEAM_ZOMBIE then
            mv:SetForwardSpeed(1200)
        end
    end
end

local function DebugPath(controller)
    if ZSB.DEBUG and controller.P then
        controller.P:Draw()
    end
end

local function SetEyeAngles(bot, controller, curGoal, lerp, lerpc)
    if IsValid(controller.Target) and controller.Target:IsPlayer() then
        if bot:Team() == TEAM_SURVIVORS then
            if controller.Target:GetZombieClass() >= 2 and controller.Target:GetZombieClass() < 5 or controller.Target:GetZombieClass() < 2 or controller.Target:GetZombieClass() == 5 or controller.Target:GetZombieClass() >= 10 then
                if not controller.Target:Crouching() then 
                    bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - controller.Target:GetViewOffsetDucked() - bot:GetShootPos()):Angle()))
                else
                    bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
                end
            end
            if controller.Target:GetZombieClass() >= 6 then
                if controller.Target:GetZombieClass() >= 6 and controller.Target:GetZombieClass() < 10 then
                    bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - controller.Target:GetViewOffsetDucked() - controller.Target:GetViewOffsetDucked() - bot:GetShootPos()):Angle()))
                else
                    bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - controller.Target:GetViewOffsetDucked() - bot:GetShootPos()):Angle()))
                end
            end
        else 
            if not bot:IsFrozen() then 
                bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
            end
        end
        return
    elseif IsValid(controller.Target) and not controller.Target:IsPlayer() then
        if not bot:IsFrozen() then 
            bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:WorldSpaceCenter() - bot:GetShootPos()):Angle()))
        end
    elseif curGoal then
        if controller.LookAtTime > CurTime() then
            local ang = LerpAngle(lerpc, bot:EyeAngles(), controller.LookAt)
            if not bot:IsFrozen() then 
                bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
            end
        else
            local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
            if not bot:IsFrozen() then 
                bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
            end
        end
    end
end

-- Called before the engine process movements. 
function LeadBot.SetupMove(bot, cmd, mv)
    local controller = bot:GetController()
    local strategy = bot:LBGetStrategy()

    if not IsValid(controller) then return end

    SetCampingEyeAngles(bot, controller)
    SetJumpPower(bot)
    SetBaseForwardSpeed(bot, controller, mv)

    KillAloneHordeBot(bot)
    SetRoam(bot)

    Cheat(bot)

    ForceControllerRecompute(controller)
    UpdateControllerPos(bot, controller)
    UpdateControllerAngles(bot, controller)

    DebugBot(bot)

    ForgetTarget(controller)
    TargetEnemyInFrontNext(bot, controller)
    RememberTarget(bot, controller)

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

    if IsValid(controller.Target) then
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())

        SetMoveToTarget(bot, controller)
        Retreat(bot, controller, mv, distance, strategy)
        SelectWeapon(bot, distance)
    elseif not controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime() then
        SetMovementWithoutTarget(bot, controller, strategy)
    end

    local aimskill = GetAimSkill()
    local lerp, lerpc = GetLerp(bot, controller, strategy, aimskill)
    local curGoal = UpdateMovement(bot, controller, mv, strategy, aimskill, lerp, lerpc)

    DebugPath(controller)

    SetEyeAngles(bot, controller, curGoal, lerp, lerpc)
end