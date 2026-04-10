-- Cache cvars
local leadbot_hinfammo = GetConVar("leadbot_hinfammo")

local function HasInfiniteAmmo()
    return leadbot_hinfammo:GetInt() >= 1
end

local function ShouldSurvivorAttack(bot, target)
    if not IsValid(target) then return false end

    if target:IsNPC() then
        return true
    end

    if not target:IsPlayer() then
        return true
    end

    if target:HasGodMode() then
        return false
    end

    local zombieClass = target.GetZombieClass and target:GetZombieClass() or nil
    local distance = target:GetPos():DistToSqr(bot:GetPos())

    -- Mantém a lógica útil do código original:
    -- zumbi classe 4 só é alvo "liberado" se estiver mais longe.
    return zombieClass ~= 4 or distance > 67500
end

local function ShouldZombiePrimaryAttack(bot, target)
    local zombieClass = bot:GetZombieClass()

    -- Classes 6, 7 e 8
    if zombieClass > 5 and zombieClass < 9 then
        return true
    end

    if not target:IsPlayer() and not target:IsNPC() then
        return true
    end

    for _, ent in ipairs(ents.FindInSphere(bot:GetShootPos() + bot:GetAimVector() * 50, 20)) do
        if IsValid(ent) and not ent:IsWorld() and not (ent.IsLBot and ent:IsLBot()) then
            return true
        end
    end

    return false
end

local function ShouldZombieSecondaryAttack(bot, target)
    if bot:LBGetZomSkill() ~= 1 then return false end
    if not IsValid(target) or not target:IsPlayer() then return false end

    local zombieClass = bot:GetZombieClass()

    if zombieClass == 3 or zombieClass == 8 then
        local distance = target:GetPos():DistToSqr(bot:GetPos())
        return distance <= 90000
    end

    if zombieClass == 2 then
        return bot:IsOnGround()
    end

    return true
end

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    local buttons = 0
    local target = controller.Target
    local hasTarget = IsValid(target)
    local teamID = bot:Team()
    local zombieClass = teamID == TEAM_ZOMBIE and bot:GetZombieClass() or nil
    local infiniteAmmo = HasInfiniteAmmo()

    if teamID == TEAM_SURVIVORS then
        local botWeapon = bot:GetActiveWeapon()

        if IsValid(botWeapon) then
            local clip1 = botWeapon:Clip1()
            local maxClip1 = botWeapon:GetMaxClip1()

            if not hasTarget then
                if clip1 <= (maxClip1 / 4) and not infiniteAmmo then
                    buttons = buttons + IN_RELOAD
                end
            else
                if clip1 > 0 then
                    if math.random(1, 2) == 1 and ShouldSurvivorAttack(bot, target) then
                        buttons = buttons + IN_ATTACK
                    end
                elseif not infiniteAmmo then
                    buttons = buttons + IN_RELOAD
                end
            end
        end
    elseif teamID == TEAM_ZOMBIE then
        if hasTarget then
            if math.random(1, 2) == 1 then
                if ShouldZombiePrimaryAttack(bot, target) then
                    buttons = buttons + IN_ATTACK
                end

                if ShouldZombieSecondaryAttack(bot, target) then
                    buttons = buttons + IN_ATTACK2
                end
            end
        elseif bot:LBGetZomSkill() == 1 and math.random(1, 100) == 1 then
            if bot:IsOnGround() and zombieClass ~= 4 and zombieClass ~= 9 then
                buttons = buttons + IN_ATTACK2
            end
        end
    end

    if bot:GetMoveType() == MOVETYPE_LADDER then
        local pos = controller.goalPos
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        if not bot:IsFrozen() then
            local pitch = pos.z > controller:GetPos().z and -30 or 30
            controller.LookAt = Angle(pitch, ang.y, 0)
        end

        controller.LookAtTime = CurTime() + 0.1
        controller.NextJump = -1
        buttons = buttons + IN_FORWARD
    end

    if not hasTarget then
        if not bot:IsFrozen() then
            if controller.NextJump == 0 then
                controller.NextJump = CurTime() + 1
                buttons = buttons + IN_JUMP
            end

            if controller.NextDuck > CurTime()
            or (controller.NextJump > CurTime() and not bot:IsOnGround() and bot:WaterLevel() == 0) then
                buttons = buttons + IN_DUCK
            end
        end

        if teamID == TEAM_SURVIVORS and controller.PosGen == nil then
            buttons = buttons + IN_DUCK
        end
    end

    if bot:GetVelocity():Length2DSqr() <= 225
    and bot:GetMoveType() ~= MOVETYPE_LADDER
    and controller.PosGen ~= nil then
        local shouldUnstuck = not hasTarget
            or (not target:IsPlayer() and target:Health() <= 0)

        if shouldUnstuck and not bot:IsFrozen() then
            if math.random(1, 2) == 1 then
                controller.NextJump = 0
            end

            if teamID == TEAM_ZOMBIE and zombieClass ~= 5 and math.random(1, 2) == 1 then
                buttons = buttons + IN_ATTACK
            end
        end
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end