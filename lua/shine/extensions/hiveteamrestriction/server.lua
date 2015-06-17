--[[
    Shine Hive Team Restriction - Server
]]
Script.Load( "lua/shine/core/server/playerinfohub.lua" )

local Shine = Shine
local InfoHub = Shine.PlayerInfoHub

local StringFormat = string.format

local Plugin = Plugin

Plugin.Version = "1.0"
Plugin.NS2Only = true

Plugin.HasConfig = true
Plugin.ConfigName = "HiveTeamRestriction.json"

Plugin.DefaultConfig = {
    AllowSpectating = true,
    ShowSwitchAtBlock = false,
	CheckKD = {
		Enable = false,
		Min = 0.5,
		Max = 3,
	},
    CheckPlayTime = {
        Enable = true,
	    Min = 350,
	    Max = 0,
	    UseSteamPlayTime = true
    },
	CheckSkillRating = {
		Enable = true,
		Min = 1000,
		Max = 0
	},
	CheckLevel = {
		Enable = false,
		Min = 20,
		Max = 0
	},
	CheckWL = {
		Enable = false,
		Min = 1,
		Max = 3
	},
    ShowInform = true,
    InformMessage = "This server is Hive stats restricted",
    BlockMessage = "You don't fit to the Hive stats limits on this server:",
    KickMessage = "You will be kicked in %s seconds",
	WaitMessage = "Please wait while your Hive stats are getting fetched",
    Kick = true,
    Kicktime = 60,
}
Plugin.CheckConfig = true
Plugin.CheckConfigTypes = true

Plugin.Name = "Hive Team Restriction"

function Plugin:Initialise()
	self.Enabled = true

    self:CheckForSteamTime()
    self:BuildBlockMessage()

    return true
end

function Plugin:CheckForSteamTime()
	if self.Config.CheckPlayTime.Enable and self.Config.CheckPlayTime.UseSteamPlayTime then
		InfoHub:Request( self.Name, "STEAMPLAYTIME" )
	end
end

function Plugin:ClientConfirmConnect( Client )
    local Player = Client:GetControllingPlayer()
    if self.Config.ShowInform and Player then self:Notify( Player, self.Config.InformMessage ) end
end

function Plugin:ClientDisconnect( Client )
    local SteamId = Client:GetUserId()
    if not SteamId or SteamId <= 0 then return end

    self:DestroyTimer(StringFormat( "Kick_%s", SteamId ))
end

function Plugin:JoinTeam( _, Player, NewTeam, _, ShineForce )
    if ShineForce or self.Config.AllowSpectating and NewTeam == kSpectatorIndex or NewTeam == kTeamReadyRoom then
        self:DestroyTimer( StringFormat( "Kick_%s", Player:GetSteamId() ))
        return
    end

	return self:Check( Player )
end

function Plugin:OnReceiveSteamData( Client )
    self:AutoCheck( Client )
end

function Plugin:OnReceiveHiveData( Client )
    self:AutoCheck( Client )
end

function Plugin:AutoCheck( Client )
	if self.Config.AllowSpectating then return end

    local Player = Client:GetControllingPlayer()
    local SteamId = Client:GetUserId()

    if not Player or not InfoHub:GetIsRequestFinished( SteamId ) then return end

    self:Check( Player )
end

--The Extravalue might be usefull for childrens of this plugin
function Plugin:Check( Player, Extravalue )
    PROFILE("HiveTeamRestriction:Check()")
    if not Player then return end

	local Client = Player:GetClient()
    if not Shine:IsValidClient( Client ) or Shine:HasAccess( Client, "sh_ignorestatscheck" ) then return end
    
    local SteamId = Client:GetUserId()
    if not SteamId or SteamId < 1 then return end
	
    if not InfoHub:GetIsRequestFinished( SteamId ) then
        self:Notify( Player, self.Config.WaitMessage )
        return false
    end

    local Playerdata = InfoHub:GetHiveData( SteamId )

    --check hive timeouts
    if not Playerdata then return end

    if not self.Passed then self.Passed = {} end
	local passed = self.Passed[SteamId]

    if passed == nil then
		passed = self:CheckValues( Playerdata, SteamId, Extravalue ) -- returns nil = temporarily allowed
		self.Passed[SteamId] = passed
    end

    if passed == false then
	    self:Notify( Player, self.BlockMessage)
	    if self.Config.ShowSwitchAtBlock then
		    self:SendNetworkMessage( Client, "ShowSwitch", {}, true )
	    end
	    self:Kick( Player )
	    return false
    else
		self:DestroyTimer( StringFormat( "Kick_%s", SteamId ))
	    return true
    end
end

function Plugin:CheckValues( Playerdata, SteamId )
	local Config = self.Config

	--check if Player fits to the PlayTime
	if Config.CheckPlayTime.Enable then
		local Playtime = Playerdata.playTime
		--check if Player fits to the PlayTime

		if Config.CheckPlayTime.UseSteamTime then
			local SteamTime = InfoHub:GetSteamData( SteamId ).PlayTime
			if SteamTime and SteamTime > Playtime then
				Playtime = SteamTime
			end
		end


		if Playtime < Config.CheckPlayTime.Min * 3600 or
				(Config.CheckPlayTime.Max > 0 and Playtime > Config.CheckPlayTime.Max * 3600) then
			return false
		end
	end

	if Config.CheckSkillRating.Enable then
		local Skill = Playerdata.skill
		if Skill < Config.CheckSkillRating.Min or
				( Config.CheckSkillRating.Max > 0 and Skill > Config.CheckSkillRating.Max ) then
			return false
		end
	end

	if Config.CheckWL.Enable then
		local Wins = Playerdata.wins
		local Looses = Playerdata.loses
		if Looses < 1 then Looses = 1 end
		local WL = Wins / Looses

		if WL < Config.CheckWL.Min or
				( Config.CheckWL.Max > 0 and WL > Config.CheckWL.Max ) then
			return false
		end
	end

	if Config.CheckLevel.Enable then
		local Level = Playerdata.level
		if Level < Config.CheckLevel.Min or
				( Config.CheckLevel.Max > 0 and Level > Config.CheckLevel.Max ) then
			return false
		end
	end

	if Config.CheckKD.Enable then
		local Deaths = Playerdata.deaths
		local Kills = Playerdata.kills
		if Deaths < 1 then Deaths = 1 end
		local KD = Kills / Deaths

		if KD < Config.CheckKD.Min or
				( Config.CheckKD.Max > 0 and KD > Config.CheckKD.Max ) then
			return false
		end
	end

	return true
end

function Plugin:BuildBlockMessage()
	local MessageLines = {
		self.Config.BlockMessage
	}
	local Config = self.Config


	if Config.CheckPlayTime.Enable then
		MessageLines[#MessageLines + 1] = "Playtime (in hours):"
		MessageLines[#MessageLines + 1] = StringFormat("    Min: %s", Config.CheckPlayTime.Min)
		if Config.CheckPlayTime.Max > 0 then
			MessageLines[#MessageLines + 1] = StringFormat("    Max: %s", Config.CheckPlayTime.Max)
		end
	end

	if Config.CheckSkillRating.Enable then
		MessageLines[#MessageLines + 1] = "Hive rating:"
		MessageLines[#MessageLines + 1] = StringFormat("    Min: %s", Config.CheckSkillRating.Min)
		if Config.CheckSkillRating.Max > 0 then
			MessageLines[#MessageLines + 1] = StringFormat("    Max: %s", Config.CheckSkillRating.Max)
		end
	end

	if Config.CheckWL.Enable then
		MessageLines[#MessageLines + 1] = "Hive W/L ratio:"
		MessageLines[#MessageLines + 1] = StringFormat("    Min: %s", Config.CheckWL.Min)
		if Config.CheckWL.Max > 0 then
			MessageLines[#MessageLines + 1] = StringFormat("    Max: %s", Config.CheckWL.Max)
		end
	end

	if Config.CheckLevel.Enable then
		MessageLines[#MessageLines + 1] = "Hive level:"
		MessageLines[#MessageLines + 1] = StringFormat("    Min: %s", Config.CheckLevel.Min)
		if Config.CheckLevel.Max > 0 then
			MessageLines[#MessageLines + 1] = StringFormat("    Max: %s", Config.CheckLevel.Max)
		end
	end

	if Config.CheckKD.Enable then
		MessageLines[#MessageLines + 1] = "Hive K/D ratio:"
		MessageLines[#MessageLines + 1] = StringFormat("    Min: %s", Config.CheckKD.Min)
		if Config.CheckKD.Max > 0 then
			MessageLines[#MessageLines + 1] = StringFormat("    Max: %s", Config.CheckKD.Max)
		end
	end

	self.BlockMessage = MessageLines
end

function Plugin:Notify( Player, Message, Format, ... )
	if not Player or not Message then return end

	if type(Message) == "table" then
	   for i, line in ipairs(Message) do
		   if i == 1 then
			   Shine:NotifyDualColour( Player, 100, 255, 100, StringFormat("[%s]", self.Name),
				   255, 255, 255, line )
		   else
			   Shine:NotifyColour(Player, 255, 255, 255, line )
		   end
	   end
	else
		Shine:NotifyDualColour( Player, 100, 255, 100, StringFormat("[%s]", self.Name),
			255, 255, 255, Message, Format, ... )
	end

end

Plugin.DisconnectReason = "You didn't fit to the set hive stats restrictions"
function Plugin:Kick( Player )
    if not self.Config.Kick then return end
    
    local Client = Player:GetClient()
    if not Shine:IsValidClient( Client ) then return end
    
    local SteamId = Client:GetUserId() or 0
    if SteamId <= 0 then return end
    
    if self:TimerExists( StringFormat( "Kick_%s", SteamId )) then return end
    
    self:Notify( Player, StringFormat( self.Config.KickMessage, self.Config.Kicktime ))
        
    self:CreateTimer( StringFormat( "Kick_%s", SteamId ), 1, self.Config.Kicktime, function( Timer )
        if not Shine:IsValidClient( Client ) then
            Timer:Destroy()
            return
        end
		
		local Player = Client:GetControllingPlayer()
		
        local Kicktimes = Timer:GetReps()
        if Kicktimes == 10 then self:Notify( Player, StringFormat( self.Config.KickMessage, Kicktimes ) ) end
        if Kicktimes <= 5 then self:Notify( Player, StringFormat( self.Config.KickMessage, Kicktimes ) ) end
        if Kicktimes <= 0 then
            Shine:Print( "Client %s [ %s ] was kicked by %s. Kicking...", true, Player:GetName(), SteamId, self.Name)
            Client.DisconnectReason = self.DisconnectReason
            Server.DisconnectClient( Client )
        end    
    end)    
end

function Plugin:CleanUp()
    InfoHub:RemoveRequest(self.Name)

    self.BaseClass.Cleanup( self )

    self.Enabled = false
end