local meta = FindMetaTable("Player")
local oldPing = meta.Ping

local convar = CreateConVar(
    "leadbot_fakeping",
    "0",
    {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED},
    "Enables fake ping for bots. 2 shows BOT in custom UI."
)

function meta:Ping()
    if not convar or not convar:GetBool() or not self:IsBot() then
        return oldPing(self)
    end

    self.FakePing = self.FakePing or math.random(35, 105)
    self.OFakePing = self.OFakePing or self.FakePing

    if convar:GetInt() ~= 2 then
        if math.random(125) == 1 then
            self.FakePing = self.OFakePing + math.random(3)
        elseif math.random(125) == 1 then
            self.FakePing = self.OFakePing - math.random(3)
        end
    end

    if isnumber(self.FakePing) then
        return self.FakePing
    end

    return self.OFakePing or 0
end

function meta:GetDisplayedPing()
    if convar and convar:GetInt() == 2 and self:IsBot() then
        return "BOT"
    end

    return self:Ping()
end