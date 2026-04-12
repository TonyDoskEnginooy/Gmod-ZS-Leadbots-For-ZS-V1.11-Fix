if SERVER then
	AddCSLuaFile()
end

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"

local function AreaHasAttributes(area, attributes)
    return area and area:IsValid() and area:HasAttributes(attributes)
end

local function GetLadderCostAdjustment(bot, fromArea, ladder)
    if not IsValid(ladder) or not isvector(bot.PosGen) or not IsValid(fromArea) then
        return 0
    end

    local currentZ = fromArea:GetCenter().z
    local goalZ = bot.PosGen.z
    local remainingVertical = math.abs(goalZ - currentZ)

    -- Do not bias toward ladders when the goal is almost on the same level.
    if remainingVertical < 96 then
        return 0
    end

    local ladderBottom = ladder:GetBottom()
    local ladderTop = ladder:GetTop()
    local bestExitZ

    if goalZ > currentZ then
        bestExitZ = math.max(ladderBottom.z, ladderTop.z)
    else
        bestExitZ = math.min(ladderBottom.z, ladderTop.z)
    end

    local improvedVertical = remainingVertical - math.abs(goalZ - bestExitZ)

    -- Ignore ladders that do not meaningfully help vertical progress.
    if improvedVertical < 32 then
        return 0
    end

    -- Lower cost means the pathfinder will prefer this transition.
    return -math.Clamp(60 + improvedVertical * 0.55, 60, 240)
end

local function ComputePathCost(bot, area, fromArea, ladder, elevator, length)
    if not IsValid(fromArea) then
        return 0
    end

    if not bot.loco:IsAreaTraversable(area) then
        return -1
    end

    local dist
    if IsValid(ladder) then
        dist = ladder:GetLength()
    elseif length > 0 then
        dist = length
    else
        dist = (area:GetCenter() - fromArea:GetCenter()):Length()
    end

    local cost = dist + fromArea:GetCostSoFar()
    local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange(area)
    local isStairs = AreaHasAttributes(area, NAV_MESH_STAIRS)
        or AreaHasAttributes(fromArea, NAV_MESH_STAIRS)

    if deltaZ >= bot.loco:GetStepHeight() then
        if not isStairs and deltaZ >= bot.loco:GetMaxJumpHeight() then
            return -1
        end

        if not isStairs then
            cost = cost + (5 * dist)
        end
    elseif deltaZ < -bot.loco:GetDeathDropHeight() then
        if not isStairs then
            return -1
        end
    end

    if IsValid(ladder) then
		print(ladder, "AQUI")
        cost = cost + GetLadderCostAdjustment(bot, fromArea, ladder)
    elseif isvector(bot.PosGen) then
        local currentGap = math.abs(bot.PosGen.z - fromArea:GetCenter().z)
        local nextGap = math.abs(bot.PosGen.z - area:GetCenter().z)

        -- Slightly discourage long flat wandering when the goal is on another level.
        if currentGap > 96 and math.abs(deltaZ) <= bot.loco:GetStepHeight() and nextGap >= (currentGap - 8) then
            cost = cost + 18
        end
    end

    return cost
end

function ENT:Initialize()
	if CLIENT then return end

	self:SetModel("models/player.mdl")
	self:SetNoDraw(not GetConVar("developer"):GetBool())
	self:SetSolid(SOLID_NONE)

	self.PosGen = nil
	self.NextJump = -1
	self.NextDuck = 0
	self.cur_segment = 2
	self.Target = nil
	self.LastSegmented = 0
	self.ForgetTarget = 0
	self.NextCenter = 0
	self.LookAt = angle_zero
	self.LookAtTime = 0
	self.goalPos = vector_origin
	self.strafeAngle = 0
	self.nextStuckJump = 0

	if LeadBot and LeadBot.AddControllerOverride then
		LeadBot.AddControllerOverride(self)
	end
end

function ENT:CreatePath()
	local path = Path("Follow")
	path:SetMinLookAheadDistance(10)
	path:SetGoalTolerance(20)
	return path
end

function ENT:ComputePath()
	if not self.PosGen then
		return false
	end

	self.P = self.P or self:CreatePath()

	self.P:Compute(self, self.PosGen, function(area, fromArea, ladder, elevator, length)
		return ComputePathCost(self, area, fromArea, ladder, elevator, length)
	end)

	if not self.P:IsValid() then
		return false
	end

	self.cur_segment = 2
	return true
end

function ENT:ChasePos()
	while self.PosGen do
		self:ComputePath()
		coroutine.wait(1)
	end
end

function ENT:OnInjured()
end

function ENT:OnKilled()
end

function ENT:IsNPC()
	return false
end

function ENT:RunBehaviour()
	while true do
		if self.PosGen then
			self:ChasePos()
		end

		coroutine.yield()
	end
end