ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local THROW_PROP_ZOMBIE_CLASSES = {
    ["Zombie"] = true,
    ["Poison Zombie"] = true
}

local function PlayPropThrowAnimation(bot)
    if not IsValid(bot) or not bot.DoAnimationEvent then return end

    bot:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_1HAND)
end

local function GetZombieClassName(bot)
    if not IsValid(bot) or not bot.GetZombieClass then
        return nil
    end

    if bot.GetZombieClassTable then
        local zombieClass = bot:GetZombieClassTable()

        if zombieClass and zombieClass.Name then
            return zombieClass.Name
        end
    end

    if ZombieClasses then
        local zombieClass = ZombieClasses[bot:GetZombieClass()]

        if zombieClass and zombieClass.Name then
            return zombieClass.Name
        end
    end

    return nil
end

local function CanThrowNearbyProp(bot)
    return bot:Team() == TEAM_ZOMBIE and THROW_PROP_ZOMBIE_CLASSES[GetZombieClassName(bot)] == true
end

local function IsThrowableProp(ent)
    if not IsValid(ent) or ent:GetClass() ~= "prop_physics" then
        return false
    end

    if ent.IsNailed and ent:IsNailed() then
        return false
    end

    local model = ent:GetModel()
    if ZSB.Util.IsIgnoredPropModel(model) or ZSB.Util.IsBoardModel(model) then
        return false
    end

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then
        return false
    end

    if not phys:IsMoveable() or not phys:IsMotionEnabled() then
        return false
    end

    return phys:GetMass() <= 260 and phys:GetVelocity():LengthSqr() <= 250 * 250
end

local function SelectThrowableProp(bot, target, props)
    if not ZSB.Util.HasEntries(props) then return nil end

    local bestProp
    local bestScore = -math.huge
    local botPos = bot:GetPos()
    local targetDirection = (target:WorldSpaceCenter() - botPos):GetNormalized()

    for _, prop in ipairs(props) do
        if IsThrowableProp(prop) then
            local propPos = prop:WorldSpaceCenter()
            local toProp = propPos - botPos
            local distanceSqr = toProp:LengthSqr()

            if distanceSqr <= 120 * 120 then
                local alignment = toProp:GetNormalized():Dot(targetDirection)

                if alignment > 0.1 then
                    local score = (alignment * 1000) - distanceSqr

                    if score > bestScore then
                        bestScore = score
                        bestProp = prop
                    end
                end
            end
        end
    end

    return bestProp
end

function SC.TryThrowNearbyProp(bot, controller, foundEnts)
    if not CanThrowNearbyProp(bot) then return false end
    if controller.NextPropThrow > CurTime() then return false end
    if not IsValid(controller.Target) or not controller.Target:IsPlayer() then return false end
    if controller.Target:Team() == TEAM_ZOMBIE or not controller.Target:Alive() then return false end

    local distanceSqr = bot:GetPos():DistToSqr(controller.Target:GetPos())
    if distanceSqr <= 125 * 125 or distanceSqr >= 850 * 850 then return false end

    local prop = SelectThrowableProp(bot, controller.Target, foundEnts.near["prop_physics"])
    if not IsValid(prop) then return false end

    controller.NextPropThrow = CurTime() + math.Rand(1.8, 3.2)

    if not ZSB.Util:Odds(40) then
        return false
    end

    local phys = prop:GetPhysicsObject()
    if not IsValid(phys) then
        return false
    end

    local throwVector = controller.Target:WorldSpaceCenter() - prop:WorldSpaceCenter()
    throwVector.z = throwVector.z + 120
    throwVector:Normalize()

    PlayPropThrowAnimation(bot)

    phys:Wake()
    phys:ApplyForceCenter(throwVector * math.max(phys:GetMass(), 10) * 900)

    controller.NextDuck = CurTime() + 0.2
    controller.LookAt = (controller.Target:WorldSpaceCenter() - bot:GetShootPos()):Angle()
    controller.LookAtTime = CurTime() + 0.2

    return true
end
