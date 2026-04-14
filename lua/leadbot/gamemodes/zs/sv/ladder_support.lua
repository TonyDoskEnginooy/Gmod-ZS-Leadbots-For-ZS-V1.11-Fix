local ATTACH_PAD = 96
local Z_ATTACH_PAD = 128
local AXIS_TOL = 3

local function CenterFromAABB(mins, maxs)
    return (mins + maxs) * 0.5
end

local function PointToAABB2DDistance(pos, mins, maxs)
    local dx = 0
    local dy = 0

    if pos.x < mins.x then
        dx = mins.x - pos.x
    elseif pos.x > maxs.x then
        dx = pos.x - maxs.x
    end

    if pos.y < mins.y then
        dy = mins.y - pos.y
    elseif pos.y > maxs.y then
        dy = pos.y - maxs.y
    end

    return math.sqrt(dx * dx + dy * dy)
end

local function DistanceToZRange(z, minZ, maxZ)
    if z < minZ then
        return minZ - z
    end

    if z > maxZ then
        return z - maxZ
    end

    return 0
end

local function ClassifyUpDown(ladder, pos)
    local mins, maxs = ladder:WorldSpaceAABB()

    local dzDown = math.abs(pos.z - mins.z)
    local dzUp = math.abs(pos.z - maxs.z)

    if dzDown <= dzUp then
        return "DOWN"
    end

    return "UP"
end

local function FindBestLadderForPoint(ladders, pointPos)
    local bestLadder = nil
    local bestScore = nil

    -- Pass 2: XY fallback when Z is slightly outside the ladder bounds
    for _, ladder in ipairs(ladders) do
        local mins, maxs = ladder:WorldSpaceAABB()
        local dxy = PointToAABB2DDistance(pointPos, mins, maxs)
        local dz = DistanceToZRange(pointPos.z, mins.z, maxs.z)

        if dxy <= ATTACH_PAD and dz <= Z_ATTACH_PAD then
            local score = dxy + (dz * 0.25)

            if not bestScore or score < bestScore then
                bestScore = score
                bestLadder = ladder
            end
        end
    end

    return bestLadder
end

local function CardinalFromVector(v)
    if math.abs(v.x) > math.abs(v.y) then
        return (v.x >= 0) and "EAST" or "WEST"
    end

    return (v.y >= 0) and "NORTH" or "SOUTH"
end

local function GetDirection(ladder, downs, ups)
    local invalidPos = {} -- The mapper sometimes misplace ladder dismounts

    for _, down in ipairs(downs) do
        for _, up in ipairs(ups) do
            local dx = down.x - up.x
            local dy = down.y - up.y

            local sameX = math.abs(dx) <= AXIS_TOL
            local sameY = math.abs(dy) <= AXIS_TOL

            if sameX and sameY then
                invalidPos[up] = true
                invalidPos[down] = true
                break
            end
        end
    end

    for _, down in ipairs(downs) do
        if invalidPos[down] then
            continue
        end

        for _, up in ipairs(ups) do
            if invalidPos[up] then
                continue
            end

            local dx = down.x - up.x
            local dy = down.y - up.y

            local sameX = math.abs(dx) <= AXIS_TOL
            local sameY = math.abs(dy) <= AXIS_TOL

            if sameX or sameY then
                local seg = down - up
                seg.z = 0

                if seg:Length2D() > 0 then
                    local normal = seg:GetNormalized()
                    normal = Vector(math.Round(normal.x, 0), math.Round(normal.y, 0), 0):GetNormalized()

                    return {
                        normal = normal,
                        normalStr = CardinalFromVector(normal)
                    }
                end
            end
        end
    end
end

function ZSB.BuildLadderMap()
    local ladders = ents.FindByClass("func_useableladder")
    local dismounts = ents.FindByClass("info_ladder_dismount")

    local ladderPoints = {}

    for _, ladder in ipairs(ladders) do
        ladderPoints[ladder] = {
            ent = ladder,
            downs = {},
            ups = {},
            normalStr = "UNKNOWN",
            normal = vector_origin
        }
    end

    -- Attach each dismount to the nearest ladder
    for _, point in ipairs(dismounts) do
        local ladder = FindBestLadderForPoint(ladders, point:GetPos())

        if IsValid(ladder) then
            local kind = ClassifyUpDown(ladder, point:GetPos())
            local data = ladderPoints[ladder]

            if kind == "DOWN" then
                data.downs[#data.downs + 1] = point:GetPos()
            else
                data.ups[#data.ups + 1] = point:GetPos()
            end
        end
    end

    for _, ladder in ipairs(ladders) do
        local data = ladderPoints[ladder]
        local dir = GetDirection(ladder, data.downs, data.ups)

        if dir then
            data.normalStr = dir.normalStr
            data.normal = dir.normal
        end
    end

    return ladderPoints
end

function ZSB.GetPlayerActiveLadderData(ply, ladderMap)
    if not IsValid(ply) or not ply:IsPlayer() then
        return nil
    end

    ladderMap = ladderMap or ZSB.ladderMap or ZSB.BuildLadderMap()

    local pos = ply:GetPos()
    local bestData = nil
    local bestScore = nil

    for ladder, data in pairs(ladderMap) do
        if IsValid(ladder) then
            local mins, maxs = ladder:WorldSpaceAABB()
            local dxy = PointToAABB2DDistance(pos, mins, maxs)
            local dz = DistanceToZRange(pos.z, mins.z, maxs.z)
            local center = CenterFromAABB(mins, maxs)
            local dc = pos:Distance(center)

            if dxy <= ATTACH_PAD then
                local score = dxy + (dz * 2) + (dc * 0.01)

                if not bestScore or score < bestScore then
                    bestScore = score
                    bestData = data
                end
            end
        end
    end

    return bestData
end

function ZSB.ExitLadder(ply)
    local ladder = ZSB.GetPlayerActiveLadderData(ply)

    if ladder and ladder.normal then
        ply:ExitLadder()
        ply:SetVelocity(ladder.normal * 300)

        return true
    end

    return false
end