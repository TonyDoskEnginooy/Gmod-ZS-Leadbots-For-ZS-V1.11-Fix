-- Cache cvars
local leadbot_hinfammo = GetConVar("leadbot_hinfammo")

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()

    if not IsValid(controller) then return end

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
                            target:IsNPC() and IsValid(target) or
                            target:IsPlayer() and not target:HasGodMode() and (
                                IsValid(target) or
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
                    if IsValid(target) or not target:IsPlayer() and not target:IsNPC() then 
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
                if target:IsPlayer() and IsValid(target) and bot:LBGetZomSkill() == 1 then 
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