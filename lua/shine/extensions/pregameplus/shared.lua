local Plugin = {}

local Shine = Shine
local SetupClassHook = Shine.Hook.SetupClassHook
local SetupGlobalHook = Shine.Hook.SetupGlobalHook

function Plugin:SetupDataTable()
	self:AddDTVar( "boolean", "Enabled", false )
	self:AddDTVar( "boolean", "AllowOnosExo", false )
	self:AddDTVar( "boolean", "AllowMines", false )
end

SetupGlobalHook( "LookupTechData", "LookupTechData", "ActivePre" )
function Plugin:LookupTechData(techId, fieldName, default)
	if self.dt.Enabled and ( fieldName == kTechDataUpgradeCost or fieldName == kTechDataCostKey ) then         
		if not self.dt.AllowOnosExo and ( techId == kTechId.Onos or techId == kTechId.Exosuit ) then
			return 999
		end
		
		if not self.dt.AllowMines and techId == kTechId.Mine then return 999 end
		
		return 0
	end
end

-- We need to use this as Player is not loaded up before shine
Shine.Hook.Add( "Think", "StartPGP", function( Deltatime )
		if Player then
			SetupClassHook("Player", "GetGameStarted", "GetGameStarted", "ActivePre")
			SetupClassHook("Player", "GetIsPlaying", "GetIsPlaying", "ActivePre")
			Shine.Hook.Remove( "Think", "StartPGP" )
		end	
	end )  
function Plugin:GetGameStarted()
	if self.dt.Enabled then return true end
end

function Plugin:GetIsPlaying( Player )
	return Player:GetGameStarted() and Player:GetIsOnPlayingTeam()
end

SetupClassHook( "AlienTeamInfo", "OnUpdate", "AlienTeamInfoUpdate", "PassivePost")
function Plugin:AlienTeamInfoUpdate( AlienTeamInfo )
	if not self.dt.Enabled then return end
	AlienTeamInfo.bioMassLevel = 9
	AlienTeamInfo.numHives = 3
	AlienTeamInfo.veilLevel = 3
	AlienTeamInfo.spurLevel = 3
	AlienTeamInfo.shellLevel = 3
end

Shine:RegisterExtension( "pregameplus", Plugin )