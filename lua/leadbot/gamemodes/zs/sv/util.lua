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

function ZSB.Util:IsWraithInvisibleToSurvivor(botZombie)
    if GetZombieClassName(botZombie) ~= "Wraith" then
        return false
    end

    local color = botZombie:GetColor()
    local alpha = color and color.a or 255

    return alpha <= WRAITH_INVISIBLE_ALPHA_THRESHOLD
end

function ZSB.Util:CanPerceiveTarget(botZombie)
    return not self:IsWraithInvisibleToSurvivor(botZombie)
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
        local normalizedSkill = math.Clamp((shootSkill) / 7, 0, 1)
        local jitterRadius = 12 - normalizedSkill * 4

        if distanceSqr < 260 * 260 then
            jitterRadius = jitterRadius * (1.35 - normalizedSkill)
        end

        local jitter = VectorRand() * jitterRadius
        jitter.z = jitter.z * 0.4 + normalizedSkill
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
local wantedCmdClassesSeq = table.GetKeys(wantedCmdClasses)

local MAX_SCAN_RANGE = 1200
local BOT_SCAN_RANGE = Vector(MAX_SCAN_RANGE, MAX_SCAN_RANGE, MAX_SCAN_RANGE)
local BOT_SCAN_DELAY = 0.5
local BOT_SCAN_JITTER_MIN = -0.1
local BOT_SCAN_JITTER_MAX = 0.1
local NEAR_DISTANCE = 250
local NEAR_DISTANCE_SQR = NEAR_DISTANCE * NEAR_DISTANCE
local FACING_DISTANCE = MAX_SCAN_RANGE
local FACING_DISTANCE_SQR = FACING_DISTANCE * FACING_DISTANCE
local FACING_DOT_THRESHOLD = 0.72

local entsFindInBox = ents.FindInBox
local ipairs = ipairs
local IsValid = IsValid
local CurTime = CurTime
local foundEnts = {
    -- [bot] = { area = { [1] = ent, ... }, ... }
}
local nextBotEntsScan = {
    -- [bot] = { next = time, foundEnts = table }
}

local function CreateWantedEntBuckets()
    local buckets = {
        ["NPCs"] = {}
    }

    for i=1, #wantedCmdClassesSeq, 1 do
        buckets[wantedCmdClassesSeq[i]] = {}
    end

    return buckets
end

local function RereateWantedEntBuckets(buckets)
    if #buckets["NPCs"] > 0 then
        buckets["NPCs"] = {}
    end

    for i=1, #wantedCmdClassesSeq, 1 do
        if #buckets[wantedCmdClassesSeq[i]] > 0 then
            buckets[wantedCmdClassesSeq[i]] = {}
        end
    end

    return buckets
end

local function CreateFoundEntsTable(bot)
    -- Micro optimization to recreate less tables
    if not foundEnts[bot] then
        foundEnts[bot] = {
            area = CreateWantedEntBuckets(),
            near = CreateWantedEntBuckets(),
            facing = CreateWantedEntBuckets()
        }
    else
        foundEnts[bot].area = RereateWantedEntBuckets(foundEnts[bot].area)
        foundEnts[bot].near = RereateWantedEntBuckets(foundEnts[bot].near)
        foundEnts[bot].facing = RereateWantedEntBuckets(foundEnts[bot].facing)
    end

    return foundEnts[bot]
end

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
    local scannedEnts = entsFindInBox(botPos - BOT_SCAN_RANGE, botPos + BOT_SCAN_RANGE)

    local foundEnts = CreateFoundEntsTable(bot)

    local areaBuckets = foundEnts.area
    local nearBuckets = foundEnts.near
    local facingBuckets = foundEnts.facing

    for _, ent in ipairs(scannedEnts) do
        if not IsValid(ent) then
            continue
        end

        local isNPC = ent:IsNPC()
        local className = ent:GetClass()

        if not wantedCmdClasses[className] and not isNPC then
            continue
        end

        if ent:IsPlayer() and not self:CanPerceiveTarget(bot, ent) then
            continue
        end

        local bucketName = isNPC and "NPCs" or className
        local areaBucket = areaBuckets[bucketName]
        local nearBucket = nearBuckets[bucketName]
        local facingBucket = facingBuckets[bucketName]

        areaBucket[#areaBucket + 1] = ent

        local entPos = ent:GetPos()
        local delta = entPos - botPos
        local distSqr = delta:LengthSqr()

        if distSqr < NEAR_DISTANCE_SQR then
            nearBucket[#nearBucket + 1] = ent
        end

        if distSqr < FACING_DISTANCE_SQR then
            local eyeDelta = entPos - botEyePos
            local eyeDistSqr = eyeDelta:LengthSqr()

            -- Avoid division-by-zero and skip entities at the exact eye position.
            if eyeDistSqr > 0 then
                local dot = botForward:Dot(eyeDelta)

                -- dot > 0 means the entity is in front of the bot.
                -- The squared comparison avoids sqrt/normalization while checking
                -- whether the entity is inside the facing threshold cone.
                if dot > 0 and (dot * dot) > (FACING_DOT_THRESHOLD * FACING_DOT_THRESHOLD * eyeDistSqr) then
                    -- Only add entities that are actually visible from the bot's view.
                    if bot:VisibleVec(entPos) then
                        facingBucket[#facingBucket + 1] = ent
                    end
                end
            end
        end
    end

    nextBotEntsScan[bot] = {
        next = now + BOT_SCAN_DELAY + math.Rand(BOT_SCAN_JITTER_MIN, BOT_SCAN_JITTER_MAX),
        foundEnts = foundEnts
    }
--PrintTable(foundEnts)
    return foundEnts
end