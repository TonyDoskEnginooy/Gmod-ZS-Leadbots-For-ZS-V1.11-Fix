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

    local shootPos = attacker:GetShootPos()

    if not target:IsPlayer() then
        local leadTime = math.Clamp(shootPos:Distance(bodyCenter) / 2600, 0.015, 0.09)
        return bodyCenter + target:GetVelocity() * leadTime
    end

    local aimPoint = bodyCenter
    local distanceSqr = shootPos:DistToSqr(bodyCenter)

    if target:Crouching() then
        aimPoint = aimPoint - Vector(0, 0, 6)
    end

    if attacker:IsPlayer() and attacker:Team() == TEAM_SURVIVORS and target:Team() == TEAM_ZOMBIE then
        if not IsTorsoZombie(target) then
            if distanceSqr > 260 * 260 then
                local headOffset = target:EyePos() - aimPoint
                aimPoint = aimPoint + headOffset * 0.18
            elseif distanceSqr > 120 * 120 then
                aimPoint = aimPoint + Vector(0, 0, 3)
            end
        end

        local shootSkill = math.max(attacker:LBGetshootSkill(), 1)
        local normalizedSkill = math.Clamp((shootSkill - 1) / 5, 0, 1)
        local jitterRadius = 10 - normalizedSkill * 4

        if distanceSqr > 240 * 240 then
            jitterRadius = jitterRadius * 1.35
        end

        local jitter = VectorRand() * jitterRadius
        jitter.z = jitter.z * 0.35
        aimPoint = aimPoint + jitter
    else
        aimPoint = target:EyePos()
    end

    local leadTime = math.Clamp(shootPos:Distance(aimPoint) / 3600, 0.006, 0.05)
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

local BOT_SCAN_RANGE = Vector(1200, 1200, 1200)
local BOT_SCAN_DELAY = 0.5
local NEAR_DISTANCE = 110
local NEAR_DISTANCE_SQR = NEAR_DISTANCE * NEAR_DISTANCE
local FACING_DOT_THRESHOLD = 0.72

local entsFindInBox = ents.FindInBox
local ipairs = ipairs
local isvector = isvector
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
    local botForward = bot:EyeAngles():Forward()
    local nearEnts = entsFindInBox(botPos - BOT_SCAN_RANGE, botPos + BOT_SCAN_RANGE)

    local foundEnts = {
        area = CreateWantedEntBuckets(),
        near = CreateWantedEntBuckets(),
        facing = CreateWantedEntBuckets()
    }

    local areaBuckets = foundEnts.area
    local nearBuckets = foundEnts.near
    local facingBuckets = foundEnts.facing

    for _, ent in ipairs(nearEnts) do
        if IsValid(ent) then
            local isNPC = ent:IsNPC()
            local className = ent:GetClass()

            if wantedCmdClasses[className] or isNPC then
                local shouldScan = true

                if not isNPC and ent:IsPlayer() and not self:CanPerceiveTarget(bot, ent) then
                    shouldScan = false
                end

                if shouldScan then
                    local entPos = GetEntityScanPoint(ent, botEyePos)

                    if isvector(entPos) then
                        local canNotice = true

                        if ent:IsPlayer() then
                            local awarenessFailChance = bot:Team() == TEAM_SURVIVORS and 12 or 8
                            canNotice = math.random(1, 100) > awarenessFailChance
                        end

                        if canNotice and bot:VisibleVec(entPos) then
                            local bucketName = isNPC and "NPCs" or className
                            local areaBucket = areaBuckets[bucketName]
                            local nearBucket = nearBuckets[bucketName]
                            local facingBucket = facingBuckets[bucketName]

                            areaBucket[#areaBucket + 1] = ent

                            local toEnt = entPos - botEyePos
                            toEnt:Normalize()

                            if botForward:Dot(toEnt) > FACING_DOT_THRESHOLD then
                                facingBucket[#facingBucket + 1] = ent
                            end

                            if entPos:DistToSqr(botPos) < NEAR_DISTANCE_SQR then
                                nearBucket[#nearBucket + 1] = ent
                            end
                        end
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