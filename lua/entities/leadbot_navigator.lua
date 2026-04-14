if SERVER then
    AddCSLuaFile()
end

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"

local function ComputePathCost(bot, area, fromArea, ladder, elevator, length)
    if not IsValid(fromArea) then
        -- first area in path, no cost
        return 0
    else
        if not bot.loco:IsAreaTraversable(area) then
            -- our locomotor says we can't move here
            return -1
        end
 
        -- compute distance traveled along path so far
        local dist = 0

        if IsValid(ladder) then
            dist = ladder:GetLength()
        elseif length > 0 then
            -- optimization to avoid recomputing length
            dist = length
        else
            dist = (area:GetCenter() - fromArea:GetCenter()):GetLength()
        end

        local cost = dist + fromArea:GetCostSoFar()

        -- check height change
        local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange(area)
        if deltaZ >= bot.loco:GetStepHeight() then
            if not IsValid(ladder) then
                if deltaZ >= bot.loco:GetMaxJumpHeight() then
                    -- too high to reach
                    return -1
                end

                -- jumping is slower than flat ground
                local jumpPenalty = 5
                cost = cost + jumpPenalty * dist
            end
        elseif deltaZ < -bot.loco:GetDeathDropHeight() then
            -- too far to drop
            return -1
        end

        return cost
    end
end

function ENT:Initialize()
    if CLIENT then return end

    self:SetModel("models/player.mdl")
    self:SetNoDraw(not GetConVar("developer"):GetBool())
    self:SetSolid(SOLID_NONE)
    self:Reset()

    if LeadBot and LeadBot.AddControllerOverride then
        LeadBot.AddControllerOverride(self)
    end
end

function ENT:Reset()
    self.Path = nil -- Path object
    self.PosGen = nil -- Final Path pos
    self.LastPosGen = nil
    self.ForgetPosGen = 0
    self.GoalPos = vector_origin -- Current pos in the path to self.PosGen
    self.Target = nil
    self.ForgetTarget = 0
    self.TPos = nil
    self.CurSegmentIndex = 2
    self.LookAt = angle_zero
    self.LookAtTime = 0
    self.NextPathRecompute = 0

    self.NextStrafe = 0
    self.NextJump = -1
    self.NextRandomJump = 0
    self.NextDuck = 0
    self.NextDuckCheck = 0
    self.StrafeAngle = 0

    self.RecentCloseThreat = nil
    self.RecentCloseThreatUntil = 0
    self.ConserveAmmoWithKnife = false
    self.MeleeRetreatUntil = 0

    self.ObstacleSwingCount = 0
    self.ObstacleSwingLimit = 0
    self.NextObstacleSwingCount = 0
    self.ActiveObstacleTarget = nil
    self.ObstacleTargetSince = 0
    self.LastObstacleTarget = 0
    self.ObstacleTargetRetryUntil = 0

    self.NextSurvivorBreakAttempt = 0
    self.NextPropThrow = 0

    self.NextPoisonZombieThrow = 0

    self.NextAimPoint = 0
    self.AimPoint = Vector(0, 0, 0)
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

    local now = CurTime()

    if self.NextPathRecompute > now then
        return true
    end

    if self.PosGen ~= self.LastPosGen then
        self.ForgetPosGen = now + 2
        self.LastPosGen = self.PosGen
    elseif self.ForgetPosGen ~= 0 and self.ForgetPosGen < now then
        self.PosGen = nil
        self.LastPosGen = nil
        self.ForgetPosGen = 0
        return
    end

    self.Path = self.Path or self:CreatePath()

    self.Path:Compute(self, self.PosGen, function(area, fromArea, ladder, elevator, length)
        return ComputePathCost(self, area, fromArea, ladder, elevator, length)
    end)

    if not self.Path:IsValid() then
        return false
    end

    self.NextPathRecompute = now + 0.65

    self.CurSegmentIndex = 2
    return true
end

function ENT:ChasePos()
    while self.PosGen do
        self:ComputePath()
        coroutine.wait(math.Rand(1, 1.5))
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