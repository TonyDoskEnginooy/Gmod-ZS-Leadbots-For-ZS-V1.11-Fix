function ZSB.Util:Odds(probability)
    probability = math.Clamp(probability or 0, 0, 100)
    return math.random(1, 100) <= probability
end

-- ----------------------------------------------

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
        return target:WorldSpaceCenter()
    end

    if target:IsNPC() then
        return target:WorldSpaceCenter()
    end

    return target:LocalToWorld(target:OBBCenter())
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
        if distanceSqr > 260 * 260 then
            local headOffset = target:EyePos() - aimPoint
            aimPoint = aimPoint + headOffset * 0.35
        elseif distanceSqr > 120 * 120 then
            aimPoint = aimPoint + Vector(0, 0, 6)
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

local BOT_SCAN_RANGE = Vector(1500, 1500, 1500)
local BOT_SCAN_DELAY = 0.5
local NEAR_DISTANCE = 90
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
                local entPos = ent:GetPos()

                if bot:VisibleVec(entPos) then
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