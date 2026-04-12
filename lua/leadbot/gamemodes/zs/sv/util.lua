function ZSB.Util:Odds(probability)
    probability = math.Clamp(probability or 0, 0, 100)
    return math.random(1, 100) <= probability
end

-- ----------------------------------------------

local WRAITH_INVISIBLE_ALPHA_THRESHOLD = math.Round(255 * 0.25)
local TORSO_ZOMBIE_CLASS = 9
local TORSO_AIM_OFFSET = Vector(0, 0, -20)

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

local function IsTorsoZombie(target)
    if not IsValid(target) or not target:IsPlayer() or target:Team() ~= TEAM_ZOMBIE then
        return false
    end

    if target.GetZombieClass and target:GetZombieClass() == TORSO_ZOMBIE_CLASS then
        return true
    end

    local zombieClassName = GetZombieClassName(target)
    if not isstring(zombieClassName) then
        return false
    end

    return string.find(string.lower(zombieClassName), "torso", 1, true) ~= nil
end

function ZSB.Util:GetZombieClassName(bot)
    return GetZombieClassName(bot)
end

function ZSB.Util:IsWraithInvisibleToSurvivor(bot, target)
    if not IsValid(bot) or not IsValid(target) then
        return false
    end

    if bot:Team() ~= TEAM_SURVIVORS or not target:IsPlayer() or target:Team() ~= TEAM_ZOMBIE then
        return false
    end

    if GetZombieClassName(target) ~= "Wraith" then
        return false
    end

    local color = target:GetColor()
    local alpha = color and color.a or 255

    return alpha <= WRAITH_INVISIBLE_ALPHA_THRESHOLD
end

function ZSB.Util:CanPerceiveTarget(bot, target)
    if not IsValid(bot) or not IsValid(target) then
        return false
    end

    return not self:IsWraithInvisibleToSurvivor(bot, target)
end

function ZSB.Util:IsFacingEnt(ent1, ent2)
    if not IsValid(ent1) or not IsValid(ent2) then
        return false
    end

    local eyePos = ent1:EyePos()
    local forward = ent1:EyeAngles():Forward()
    local toEnt = ent2:GetPos() - eyePos

    toEnt:Normalize()

    return forward:Dot(toEnt) > 0.55
end

-- ----------------------------------------------

local function GetTargetBodyCenter(target)
    if not IsValid(target) then
        return nil
    end

    if target:IsPlayer() then
        local bodyCenter = target:WorldSpaceCenter()

        if IsTorsoZombie(target) then
            bodyCenter = bodyCenter + TORSO_AIM_OFFSET
        end

        return bodyCenter
    end

    if target:IsNPC() then
        return target:WorldSpaceCenter()
    end

    return target:LocalToWorld(target:OBBCenter())
end

function ZSB.Util:GetTargetBodyCenter(target)
    return GetTargetBodyCenter(target)
end

function ZSB.Util:GetCombatAimPoint(attacker, target)
    if not IsValid(attacker) or not IsValid(target) then
        return nil
    end

    local bodyCenter = GetTargetBodyCenter(target)
    if not bodyCenter then
        return nil
    end

    if not target:IsPlayer() then
        local leadTime = math.Clamp(attacker:GetShootPos():Distance(bodyCenter) / 2600, 0.015, 0.09)
        return bodyCenter + target:GetVelocity() * leadTime
    end

    local aimPoint = bodyCenter
    local distanceSqr = attacker:GetShootPos():DistToSqr(bodyCenter)

    if target:Crouching() then
        aimPoint = aimPoint - Vector(0, 0, 6)
    end

    if attacker:IsPlayer() and attacker:Team() == TEAM_SURVIVORS and target:Team() == TEAM_ZOMBIE then
        if not IsTorsoZombie(target) then
            if distanceSqr > 260 * 260 then
                local headOffset = target:EyePos() - aimPoint
                aimPoint = aimPoint + headOffset * 0.35
            elseif distanceSqr > 120 * 120 then
                aimPoint = aimPoint + Vector(0, 0, 6)
            end
        end
    else
        aimPoint = target:EyePos()
    end

    local leadTime = math.Clamp(attacker:GetShootPos():Distance(aimPoint) / 3000, 0.01, 0.075)

    return aimPoint + target:GetVelocity() * leadTime
end

-- ----------------------------------------------

local wantedCmdClasses = {
    ["prop_door_rotating"] = true,
    ["func_movelinear"] = true,
    ["func_breakable"] = true,
    ["func_physbox"] = true,
    ["prop_physics"] = true,
    ["func_breakable_surf"] = true,
    ["prop_dynamic"] = true,
    ["player"] = true,
    ["predicted_viewmodel"] = true
}

local function CreateWantedEntBuckets()
    local buckets = {
        ["NPCs"] = {}
    }

    for className in pairs(wantedCmdClasses) do
        buckets[className] = {}
    end

    return buckets
end

local function GetEntityScanPoint(ent, referencePos)
    if not IsValid(ent) then
        return nil
    end

    if ent:IsPlayer() or ent:IsNPC() then
        return GetTargetBodyCenter(ent)
    end

    if isvector(referencePos) and ent.NearestPoint then
        local ok, nearestPoint = pcall(ent.NearestPoint, ent, referencePos)

        if ok and isvector(nearestPoint) then
            return nearestPoint
        end
    end

    if ent.WorldSpaceCenter then
        local ok, worldCenter = pcall(ent.WorldSpaceCenter, ent)

        if ok and isvector(worldCenter) then
            return worldCenter
        end
    end

    if ent.OBBCenter and ent.LocalToWorld then
        local ok, localCenter = pcall(ent.OBBCenter, ent)

        if ok and isvector(localCenter) then
            local okWorld, worldCenter = pcall(ent.LocalToWorld, ent, localCenter)

            if okWorld and isvector(worldCenter) then
                return worldCenter
            end
        end
    end

    return ent:GetPos()
end

local BOT_SCAN_RANGE = Vector(1500, 1500, 1500)
local BOT_SCAN_DELAY = 0.2
local NEAR_DISTANCE = 140
local NEAR_DISTANCE_SQR = NEAR_DISTANCE * NEAR_DISTANCE

local nextBotEntsScan = {
    -- [bot] = { next = time, foundEnts = table }
}

function ZSB.Util:FindEnts(bot)
    if not IsValid(bot) then
        return nil
    end

    local lastScan = nextBotEntsScan[bot]
    local now = CurTime()

    if lastScan and lastScan.next > now then
        return lastScan.foundEnts
    end

    local botPos = bot:GetPos()
    local botEyePos = bot:EyePos()
    local nearEnts = ents.FindInBox(botPos - BOT_SCAN_RANGE, botPos + BOT_SCAN_RANGE)

    local foundEnts = {
        area = CreateWantedEntBuckets(),
        near = CreateWantedEntBuckets(),
        facing = CreateWantedEntBuckets()
    }

    for _, ent in ipairs(nearEnts) do
        if IsValid(ent) then
            local isNPC = ent:IsNPC()
            local className = ent:GetClass()

            if wantedCmdClasses[className] or isNPC then
                if not isNPC and ent:IsPlayer() and not self:CanPerceiveTarget(bot, ent) then
                    continue
                end

                local entPos = GetEntityScanPoint(ent, botEyePos)

                if isvector(entPos) and bot:VisibleVec(entPos) then
                    local bucketName = isNPC and "NPCs" or className

                    table.insert(foundEnts.area[bucketName], ent)

                    if self:IsFacingEnt(bot, ent) then
                        table.insert(foundEnts.facing[bucketName], ent)
                    end

                    if entPos:DistToSqr(botPos) < NEAR_DISTANCE_SQR then
                        table.insert(foundEnts.near[bucketName], ent)
                    end
                end
            end
        end
    end

    nextBotEntsScan[bot] = {
        next = now + BOT_SCAN_DELAY,
        foundEnts = foundEnts
    }

    return foundEnts
end