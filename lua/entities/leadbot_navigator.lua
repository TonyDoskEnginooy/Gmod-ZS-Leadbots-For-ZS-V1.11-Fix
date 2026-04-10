if SERVER then
	AddCSLuaFile()
end

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"

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

	if deltaZ >= bot.loco:GetStepHeight() then
		if deltaZ >= bot.loco:GetMaxJumpHeight() then
			return -1
		end

		cost = cost + (5 * dist)
	elseif deltaZ < -bot.loco:GetDeathDropHeight() then
		return -1
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