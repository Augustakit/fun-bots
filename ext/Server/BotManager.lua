class('BotManager')

require('Bot')

local m_Utilities = require('__shared/Utilities')
local m_Logger = Logger("BotManager", Debug.Server.BOT)
local m_Vehicles = require("Vehicles")

function BotManager:__init()
	self._Bots = {}
	self._BotsByName = {}
	self._BotsByTeam = {{}, {}, {}, {}, {}} -- neutral, team1, team2, team3, team4
	self._BotInputs = {}
	self._ShooterBots = {}
	self._ActivePlayers = {}
	self._BotAttackBotTimer = 0
	self._DestroyBotsTimer = 0
	self._BotsToDestroy = {}
	self._BotCheckState = {}
	self._PendingAcceptRevives = {}
	self._LastBotCheckIndex = 1
	self._InitDone = false
	self._CurrentPlayerList = {}

	self.tempCounter = 0
end

-- =============================================
-- Events
-- =============================================

function BotManager:OnLevelDestroy()
	m_Logger:Write("destroyLevel")

	self:ResetAllBots()
	self._ActivePlayers = {}
	self._InitDone = false
	--self:KillAll() -- this crashes when the server ended. do it on levelstart instead
end

function BotManager:OnEngineUpdate(p_DeltaTime)
	if self._InitDone then
		self:_CheckForBotAttack()
	end
end

function BotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	for _, l_Bot in pairs(self._Bots) do
		l_Bot:OnUpdatePassPostFrame(p_DeltaTime)
	end

	-- if Config.BotsAttackBots and self._InitDone then
	-- 	if self._BotAttackBotTimer >= Registry.BOT.BOT_ATTACK_BOT_CHECK_INTERVAL then
	-- 		self._BotAttackBotTimer = 0
	-- 		self:_CheckForBotBotAttack()
	-- 	end
	-- 	self._BotAttackBotTimer = self._BotAttackBotTimer + p_DeltaTime
	-- end

	if #self._BotsToDestroy > 0 then
		if self._DestroyBotsTimer >= 0.05 then
			self._DestroyBotsTimer = 0
			self:DestroyBot(table.remove(self._BotsToDestroy))
		end
		self._DestroyBotsTimer = self._DestroyBotsTimer + p_DeltaTime
	end

	-- accept revives
	for i, l_Botname in pairs(self._PendingAcceptRevives) do
		local s_BotPlayer = self:GetBotByName(l_Botname)

		if s_BotPlayer ~= nil and s_BotPlayer.m_Player.soldier ~= nil then
			if s_BotPlayer.m_Player.soldier.health == 20 then
				s_BotPlayer.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
				self._PendingAcceptRevives[i] = nil
			end
		else
			self._PendingAcceptRevives[i] = nil
		end
	end
end

function BotManager:OnPlayerLeft(p_Player)
	--remove all references of player
	if p_Player ~= nil then
		for _, l_Bot in pairs(self._Bots) do
			l_Bot:ClearPlayer(p_Player)
		end
	end
end

function BotManager:OnBotAbortWait(p_BotName)
	local s_Bot = self:GetBotByName(p_BotName)
	if s_Bot ~= nil then
		s_Bot:ResetVehicleTimer()
	end
end

function BotManager:OnBotExitVehicle(p_BotName)
	local s_Bot = self:GetBotByName(p_BotName)
	if s_Bot ~= nil then
		s_Bot:ExitVehicle()
	end
end

-- this is unused
function BotManager:OnSoldierHealthAction(p_Soldier, p_Action)
	if p_Action == HealthStateAction.OnRevive then -- 7
		if p_Soldier.player ~= nil then
			if m_Utilities:isBot(p_Soldier.player.name) then
				table.insert(self._PendingAcceptRevives, p_Soldier.player.name)
			end
		end
	end
end

-- this is unused
function BotManager:OnGunSway(p_GunSway, p_Weapon, p_WeaponFiring, p_DeltaTime)
	if p_Weapon == nil then
		return
	end

	local s_Soldier = nil

	for _, l_Entity in pairs(p_Weapon.bus.parent.entities) do
		if l_Entity:Is('ServerSoldierEntity') then
			s_Soldier = SoldierEntity(l_Entity)
			break
		end
	end

	if s_Soldier == nil or s_Soldier.player == nil then
		return
	end

	local s_Bot = self:GetBotByName(s_Soldier.player.name)

	if s_Bot ~= nil then
		local s_GunSwayData = GunSwayData(p_GunSway.data)

		if s_Soldier.pose == CharacterPoseType.CharacterPoseType_Stand then
			p_GunSway.dispersionAngle = s_GunSwayData.stand.zoom.baseValue.minAngle
		elseif s_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			p_GunSway.dispersionAngle = s_GunSwayData.crouch.zoom.baseValue.minAngle
		elseif s_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			p_GunSway.dispersionAngle = s_GunSwayData.prone.zoom.baseValue.minAngle
		else
			return
		end
	end
end

-- =============================================
-- Hooks
-- =============================================

function BotManager:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
	-- soldier -> soldier damage only
	if p_Soldier.player == nil then
		return
	end

	local s_SoldierIsBot = m_Utilities:isBot(p_Soldier.player)

	if s_SoldierIsBot and p_GiverInfo.giver ~= nil then
		--detect if we need to shoot back
		if Config.ShootBackIfHit and p_Info.damage > 0 then
			self:OnShootAt(p_GiverInfo.giver, p_Soldier.player.name, true)
		end

		-- prevent bots from killing themselves. Bad bot, no suicide.
		if not Config.BotCanKillHimself and p_Soldier.player == p_GiverInfo.giver then
			p_Info.damage = 0
		end
	end

	--find out, if a player was hit by the server:
	if not s_SoldierIsBot then
		if p_GiverInfo.giver == nil then
			local s_Bot = self:GetBotByName(self._ShooterBots[p_Soldier.player.name])

			if s_Bot ~= nil and s_Bot.m_Player.soldier ~= nil and p_Info.damage > 0 then
				p_Info.damage = self:_GetDamageValue(p_Info.damage, s_Bot, p_Soldier, true)
				p_Info.boneIndex = 0
				p_Info.isBulletDamage = true
				p_Info.position = Vec3(p_Soldier.worldTransform.trans.x, p_Soldier.worldTransform.trans.y + 1, p_Soldier.worldTransform.trans.z)
				p_Info.direction = p_Soldier.worldTransform.trans - s_Bot.m_Player.soldier.worldTransform.trans
				p_Info.origin = s_Bot.m_Player.soldier.worldTransform.trans
				if (p_Soldier.health - p_Info.damage) <= 0 then
					if Globals.IsTdm then
						local s_EnemyTeam = TeamId.Team1

						if p_Soldier.player.teamId == TeamId.Team1 then
							s_EnemyTeam = TeamId.Team2
						end

						TicketManager:SetTicketCount(s_EnemyTeam, (TicketManager:GetTicketCount(s_EnemyTeam) + 1))
					end
				end
			end
		else
			--valid bot-damage?
			local s_Bot = self:GetBotByName(p_GiverInfo.giver.name)

			if s_Bot ~= nil and s_Bot.m_Player.soldier ~= nil then
				-- giver was a bot
				p_Info.damage = self:_GetDamageValue(p_Info.damage, s_Bot, p_Soldier, false)
			end
		end
	end

	p_HookCtx:Pass(p_Soldier, p_Info, p_GiverInfo)
end

-- =============================================
-- Custom (Net-)Events
-- =============================================

function BotManager:OnServerDamagePlayer(p_PlayerName, p_ShooterName, p_MeleeAttack)
	local s_Player = PlayerManager:GetPlayerByName(p_PlayerName)

	if s_Player ~= nil then
		self:OnDamagePlayer(s_Player, p_ShooterName, p_MeleeAttack, false)
	end
end

function BotManager:OnDamagePlayer(p_Player, p_ShooterName, p_MeleeAttack, p_IsHeadShot)
	local s_Bot = self:GetBotByName(p_ShooterName)

	if p_Player.soldier == nil or s_Bot == nil then
		return
	end

	if p_Player.teamId == s_Bot.m_Player.teamId then
		return
	end

	local s_Damage = 1 --only trigger soldier-damage with this

	if p_IsHeadShot then
		s_Damage = 2 -- singal Headshot
	elseif p_MeleeAttack then
		s_Damage = 3 --signal melee damage with this value
	end

	--save potential killer bot
	self._ShooterBots[p_Player.name] = p_ShooterName

	if p_Player.soldier ~= nil then
		p_Player.soldier.health = p_Player.soldier.health - s_Damage
	end
end

function BotManager:OnShootAt(p_Player, p_BotName, p_IgnoreYaw)
	local s_Bot = self:GetBotByName(p_BotName)

	if s_Bot == nil or s_Bot.m_Player == nil or s_Bot.m_Player.soldier == nil or p_Player == nil then
		return
	end

	s_Bot:ShootAt(p_Player, p_IgnoreYaw)
end

function BotManager:OnRevivePlayer(p_Player, p_BotName)
	local s_Bot = self:GetBotByName(p_BotName)

	if s_Bot == nil or s_Bot.m_Player == nil or s_Bot.m_Player.soldier == nil or p_Player == nil then
		return
	end

	s_Bot:Revive(p_Player)
end

function BotManager:OnBotShootAtBot(p_Player, p_BotName1, p_BotName2)
	local s_Bot1 = self:GetBotByName(p_BotName1)
	local s_Bot2 = self:GetBotByName(p_BotName2)

	if s_Bot1 == nil or s_Bot1.m_Player == nil or s_Bot2 == nil or s_Bot2.m_Player == nil then
		return
	end

	if s_Bot1:ShootAt(s_Bot2.m_Player, false) or s_Bot2:ShootAt(s_Bot1.m_Player, false) then
		self._BotCheckState[s_Bot1.m_Player.name] = s_Bot2.m_Player.name
		self._BotCheckState[s_Bot2.m_Player.name] = s_Bot1.m_Player.name
	else
		self._BotCheckState[s_Bot1.m_Player.name] = nil
		self._BotCheckState[s_Bot2.m_Player.name] = nil
	end
end

function BotManager:OnRequestEnterVehicle(p_Player, p_BotName)
	local s_Bot = self:GetBotByName(p_BotName)
	if s_Bot ~= nil and s_Bot.m_Player.soldier ~= nil then
		s_Bot:EnterVehicleOfPlayer(p_Player)
	end
end

-- =============================================
-- Functions
-- =============================================

-- =============================================
-- Public Functions
-- =============================================

function BotManager:RegisterActivePlayer(p_Player)
	self._ActivePlayers[p_Player.name] = true
end

function BotManager:GetBotTeam()
	if Config.BotTeam ~= TeamId.TeamNeutral then
		return Config.BotTeam
	end

	local s_BotTeam
	local s_CountPlayers = {}

	for i = 1, Globals.NrOfTeams do
		s_CountPlayers[i] = 0
		local s_Players = PlayerManager:GetPlayersByTeam(i)

		for j = 1, #s_Players do
			if not m_Utilities:isBot(s_Players[j]) then
				s_CountPlayers[i] = s_CountPlayers[i] + 1
			end
		end
	end

	local s_LowestPlayerCount = 128

	for i = 1, Globals.NrOfTeams do
		if s_CountPlayers[i] < s_LowestPlayerCount then
			s_BotTeam = i
		end
	end

	return s_BotTeam
end

function BotManager:ConfigGlobals()
	Globals.RespawnWayBots = Config.RespawnWayBots
	Globals.AttackWayBots = Config.AttackWayBots
	Globals.SpawnMode = Config.SpawnMode
	Globals.YawPerFrame = self:CalcYawPerFrame()
	--self:KillAll()
	local s_MaxPlayers = RCON:SendCommand('vars.maxPlayers')
	s_MaxPlayers = tonumber(s_MaxPlayers[2])

	if s_MaxPlayers ~= nil and s_MaxPlayers > 0 then
		Globals.MaxPlayers = s_MaxPlayers

		m_Logger:Write("there are ".. s_MaxPlayers .." slots on this server")
	else
		Globals.MaxPlayers = 127 -- only fallback. Should not happens
		m_Logger:Error("No Playercount found")
	end

	self._InitDone = true
end

function BotManager:CalcYawPerFrame()
	local s_DeltaTime = 1.0/SharedUtils:GetTickrate()
	local s_DegreePerDeltaTime = Config.MaximunYawPerSec * s_DeltaTime
	return (s_DegreePerDeltaTime / 360.0) * 2 * math.pi
end

function BotManager:FindNextBotName()
	for _, l_Name in pairs(BotNames) do
		local s_Name = BOT_TOKEN .. l_Name
		local s_SkipName = false

		for _, l_IgnoreName in pairs(Globals.IgnoreBotNames) do
			if s_Name == l_IgnoreName then
				s_SkipName = true
				break
			end
		end

		if not s_SkipName then
			local s_Bot = self:GetBotByName(s_Name)

			if s_Bot == nil and PlayerManager:GetPlayerByName(s_Name) == nil then
				return s_Name
			elseif s_Bot ~= nil and s_Bot.m_Player.soldier == nil and s_Bot:GetSpawnMode() ~= BotSpawnModes.RespawnRandomPath then
				return s_Name
			end
		end
	end

	return nil
end

function BotManager:GetBots(p_TeamId)
	if p_TeamId ~= nil then
		return self._BotInfo.team[p_TeamId + 1]
	else
		return self._Bots
	end
end

function BotManager:GetBotCount()
	return #self._Bots
end

function BotManager:GetActiveBotCount(p_TeamId)
	local s_Count = 0

	for _, l_Bot in pairs(self._Bots) do
		if not l_Bot:IsInactive() then
			if p_TeamId == nil or l_Bot.m_Player.teamId == p_TeamId then
				s_Count = s_Count + 1
			end
		end
	end

	return s_Count
end

function BotManager:GetPlayers()
	local s_AllPlayers = PlayerManager:GetPlayers()
	local s_Players = {}

	for i = 1, #s_AllPlayers do
		if not m_Utilities:isBot(s_AllPlayers[i]) then
			table.insert(s_Players, s_AllPlayers[i])
		end
	end

	return s_Players
end

function BotManager:GetPlayerCount()
	return PlayerManager:GetPlayerCount() - #self._Bots
end

function BotManager:GetKitCount(p_Kit)
	local s_Count = 0

	for _, l_Bot in pairs(self._Bots) do
		if l_Bot.m_Kit == p_Kit then
			s_Count = s_Count + 1
		end
	end

	return s_Count
end

function BotManager:ResetAllBots()
	for _, l_Bot in pairs(self._Bots) do
		l_Bot:ResetVars()
	end
end

function BotManager:SetStaticOption(p_Player, p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			if l_Bot:IsStaticMovement() then
				if p_Option == "mode" then
					l_Bot:SetMoveMode(p_Value)
				elseif p_Option == "speed" then
					l_Bot:SetSpeed(p_Value)
				end
			end
		end
	end
end

function BotManager:SetOptionForAll(p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if p_Option == "shoot" then
			l_Bot:SetShoot(p_Value)
		elseif p_Option == "respawn" then
			l_Bot:SetRespawn(p_Value)
		elseif p_Option == "moveMode" then
			l_Bot:SetMoveMode(p_Value)
		end
	end
end

function BotManager:SetOptionForPlayer(p_Player, p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			if p_Option == "shoot" then
				l_Bot:SetShoot(p_Value)
			elseif p_Option == "respawn" then
				l_Bot:SetRespawn(p_Value)
			elseif p_Option == "moveMode" then
				l_Bot:SetMoveMode(p_Value)
			end
		end
	end
end

function BotManager:GetBotByName(p_Name)
	return self._BotsByName[p_Name]
end

function BotManager:CreateBot(p_Name, p_TeamId, p_SquadId)
	--m_Logger:Write('botsByTeam['..#self._BotsByTeam[2]..'|'..#self._BotsByTeam[3]..']')

	local s_Bot = self:GetBotByName(p_Name)

	if s_Bot ~= nil then
		s_Bot.m_Player.teamId = p_TeamId
		s_Bot.m_Player.squadId = p_SquadId
		s_Bot:ResetVars()
		return s_Bot
	end

	-- check for max-players
	local s_PlayerLimit = Globals.MaxPlayers

	if Config.KeepOneSlotForPlayers then
		s_PlayerLimit = s_PlayerLimit - 1
	end

	if s_PlayerLimit <= PlayerManager:GetPlayerCount() then
		m_Logger:Write("playerlimit reached")
		return
	end

	-- Create a player for this bot.
	local s_BotPlayer = PlayerManager:CreatePlayer(p_Name, p_TeamId, p_SquadId)

	if s_BotPlayer == nil then
		m_Logger:Write("can't create more players on this team")
		return
	end

	-- Create input for this bot.
	local s_BotInput = EntryInput()
	s_BotInput.deltaTime = 1.0 / SharedUtils:GetTickrate()
	s_BotInput.flags = EntryInputFlags.AuthoritativeAiming
	s_BotPlayer.input = s_BotInput

	s_Bot = Bot(s_BotPlayer)

	local teamLookup = s_Bot.m_Player.teamId + 1
	table.insert(self._Bots, s_Bot)
	self._BotsByTeam[teamLookup] = self._BotsByTeam[teamLookup] or {}
	table.insert(self._BotsByTeam[teamLookup], s_Bot)
	self._BotsByName[p_Name] = s_Bot
	self._BotInputs[s_BotPlayer.id] = s_BotInput -- bot inputs are stored to prevent garbage collection
	return s_Bot
end

function BotManager:SpawnBot(p_Bot, p_Transform, p_Pose, p_SoldierBp, p_Kit, p_Unlocks)
	if p_Bot.m_Player.soldier ~= nil then
		p_Bot.m_Player.soldier:Destroy()
	end

	if p_Bot.m_Player.corpse ~= nil then
		p_Bot.m_Player.corpse:Destroy()
	end

	p_Bot.m_Player:SelectUnlockAssets(p_Kit, p_Unlocks)
	local s_BotSoldier = p_Bot.m_Player:CreateSoldier(p_SoldierBp, p_Transform) -- Returns SoldierEntity

	-- Customisation of health of bot
	s_BotSoldier.maxHealth = Config.BotMaxHealth;

	p_Bot.m_Player:SpawnSoldierAt(s_BotSoldier, p_Transform, p_Pose)
	p_Bot.m_Player:AttachSoldier(s_BotSoldier)

	return s_BotSoldier
end

function BotManager:KillPlayerBots(p_Player)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			l_Bot:ResetVars()

			if l_Bot.m_Player.soldier ~= nil then
				l_Bot.m_Player.soldier:Kill()
			end
		end
	end
end

function BotManager:ResetAllBots()
	for _, l_Bot in pairs(self._Bots) do
		l_Bot:ResetVars()
	end
end

function BotManager:KillAll(p_Amount, p_TeamId)
	local s_BotTable = self._Bots

	if p_TeamId ~= nil then
		s_BotTable = self._BotsByTeam[p_TeamId + 1]
	end

	p_Amount = p_Amount or #s_BotTable

	for _, l_Bot in pairs(s_BotTable) do
		l_Bot:Kill()

		p_Amount = p_Amount - 1

		if p_Amount <= 0 then
			return
		end
	end
end

function BotManager:DestroyAll(p_Amount, p_TeamId, p_Force)
	local s_BotTable = self._Bots

	if p_TeamId ~= nil then
		s_BotTable = self._BotsByTeam[p_TeamId + 1]
	end

	p_Amount = p_Amount or #s_BotTable

	for _, l_Bot in pairs(s_BotTable) do
		if p_Force then
			self:DestroyBot(l_Bot)
		else
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end

		p_Amount = p_Amount - 1

		if p_Amount <= 0 then
			return
		end
	end
end

function BotManager:DestroyDisabledBots()
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:IsInactive() then
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end
	end
end

function BotManager:DestroyPlayerBots(p_Player)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end
	end
end

function BotManager:RefreshTables()
	local s_NewTeamsTable = {{},{},{},{},{}}
	local s_NewBotTable = {}
	local s_NewBotbyNameTable = {}

	for _,l_Bot in pairs(self._Bots) do
		if l_Bot.m_Player ~= nil then
			table.insert(s_NewBotTable, l_Bot)
			table.insert(s_NewTeamsTable[l_Bot.m_Player.teamId + 1], l_Bot)
			s_NewBotbyNameTable[l_Bot.m_Player.name] = l_Bot
		end
	end

	self._Bots = s_NewBotTable
	self._BotsByTeam = s_NewTeamsTable
	self._BotsByName = s_NewBotbyNameTable
end

function BotManager:DestroyBot(p_Bot)
	if type(p_Bot) == 'string' then
		p_Bot = self._BotsByName[p_Bot]
	end

	-- Bot was not found.
	if p_Bot == nil then
		return
	end

	-- Find index of this bot.
	local s_NewTable = {}

	for _, l_Bot in pairs(self._Bots) do
		if p_Bot.m_Name ~= l_Bot.m_Name then
			table.insert(s_NewTable, l_Bot)
		end

		l_Bot:ClearPlayer(p_Bot.m_Player)
	end

	self._Bots = s_NewTable

	local s_NewTeamsTable = {}

	for _, l_Bot in pairs(self._BotsByTeam[p_Bot.m_Player.teamId + 1]) do
		if p_Bot.m_Name ~= l_Bot.m_Name then
			table.insert(s_NewTeamsTable, l_Bot)
		end
	end

	self._BotsByTeam[p_Bot.m_Player.teamId+1] = s_NewTeamsTable
	self._BotsByName[p_Bot.m_Name] = nil
	self._BotInputs[p_Bot.m_Id] = nil

	p_Bot:Destroy()
	p_Bot = nil
end

-- =============================================
-- Private Functions
-- =============================================
function BotManager:_DoRaycast(p_BotPosition, p_EnemyPostition, p_NumberOfExpectedHits)
	local s_FlagsMaterial = 0 --MaterialFlags.MfPenetrable | MaterialFlags.MfClientDestructible | MaterialFlags.MfBashable | MaterialFlags.MfSeeThrough | MaterialFlags.MfNoCollisionResponse | MaterialFlags.MfNoCollisionResponseCombined
	local s_RaycastFlags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter
	local s_Results = RaycastManager:CollisionRaycast(p_BotPosition, p_EnemyPostition, p_NumberOfExpectedHits + 1, s_FlagsMaterial, s_RaycastFlags)

	if #s_Results > p_NumberOfExpectedHits then
		return false
	else
		return true
	end
end

function BotManager:_EvaluateAttackBotBot(p_Bot1, p_Bot2)
	
end

function BotManager:_EvaluateAttackBotPlayer(p_AttackinBot, p_Player)
	-- don't attack as driver in some vehicles
	if p_AttackinBot.m_InVehicle and p_AttackinBot.m_Player.controlledEntryId == 0 then
		if m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.Chopper) then
			if self.m_Player.controlledControllable:GetPlayerInEntry(1) ~= nil then
				if not Config.ChopperDriversAttack then
					return false
				end
			end
		end
		if m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.NoArmorVehicle) then
			return false
		end
		if m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.LightVehicle) then
			return false
		end
		-- if stationary AA targets get assigned in an other waay
		if m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.StationaryAA) then
			return false
		end
	end

	-- check for vehicles
	local s_Type = m_Vehicles:FindOutVehicleType(p_Player)

	-- don't shoot at stationary AA
	if s_Type == VehicleTypes.StationaryAA then
		return false
	end

	-- don't shoot if too far away
	local s_IgnoreFov = false
	local s_AttackingBotPos = p_AttackinBot.m_Player.soldier.worldTransform.trans:Clone()
	local s_EnemyPosition = Vec3()
	local s_CheckDistance = 0 
	local s_Distance = 0
	if s_Type == VehicleTypes.MavBot then
		s_EnemyPosition = p_Player.controlledControllable.transform.trans:Clone()
	else
		s_EnemyPosition = p_Player.soldier.worldTransform.trans:Clone()
	end
	s_Distance = s_EnemyPosition:Distance(s_AttackingBotPos)
	
	
	if s_Distance < Config.DistanceForDirectAttack then
		s_IgnoreFov = true -- because you are near
	end

	if not s_IgnoreFov then
		if not p_AttackinBot.m_InVehicle then
			if p_AttackinBot.m_ActiveWeapon.type == WeaponTypes.Sniper then
				s_CheckDistance = Config.MaxRaycastDistance
			else
				s_CheckDistance = Config.MaxShootDistanceNoSniper
			end
		else
			if m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.Plane) or m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.AntiAir) then
				s_CheckDistance = Config.MaxRaycastDistanceVehicles
			else
				s_CheckDistance = Config.MaxShootDistanceNoAntiAir
			end
		end
		if s_Distance > s_CheckDistance then
			return false
		end
	end


	if s_Type ~= VehicleTypes.NoVehicle and m_Vehicles:CheckForVehicleAttack(s_Type, s_Distance, p_AttackinBot.m_SecondaryGadget, p_AttackinBot.m_InVehicle) == VehicleAttackModes.NoAttack then
		return false
	end

	local s_DifferenceYaw = 0
	local s_Pitch = 0
	local s_FovHalf = 0
	local s_PitchHalf = 0

	-- if target is air-vehicle and bot is in AA --> ignore yaw
	if p_AttackinBot.m_InVehicle and (s_Type == VehicleTypes.Chopper or s_Type == VehicleTypes.Plane) and m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.AntiAir) then
		s_IgnoreFov = true
	end

	if not s_IgnoreFov then
		local s_OldYaw = p_AttackinBot.m_Player.input.authoritativeAimingYaw
		local s_DifferenceY = 0.0
		local s_DifferenceX = 0.0
		local s_DifferenceZ = 0.0
		if s_Type == VehicleTypes.MavBot then
			s_DifferenceY = p_Player.controlledControllable.transform.trans.z - p_AttackinBot.m_Player.soldier.worldTransform.trans.z
			s_DifferenceX = p_Player.controlledControllable.transform.trans.x - p_AttackinBot.m_Player.soldier.worldTransform.trans.x
			s_DifferenceZ = p_Player.controlledControllable.transform.trans.y - p_AttackinBot.m_Player.soldier.worldTransform.trans.y
		else
			s_DifferenceY = p_Player.soldier.worldTransform.trans.z - p_AttackinBot.m_Player.soldier.worldTransform.trans.z
			s_DifferenceX = p_Player.soldier.worldTransform.trans.x - p_AttackinBot.m_Player.soldier.worldTransform.trans.x
			s_DifferenceZ = p_Player.soldier.worldTransform.trans.y - p_AttackinBot.m_Player.soldier.worldTransform.trans.y
		end

		local s_AtanYaw = math.atan(s_DifferenceY, s_DifferenceX)
		local s_Yaw = (s_AtanYaw > math.pi / 2) and (s_AtanYaw - math.pi / 2) or (s_AtanYaw + 3 * math.pi / 2)

		local s_DistanceHoizontal = math.sqrt(s_DifferenceY^2 + s_DifferenceY^2)
		s_Pitch = math.abs(math.atan(s_DifferenceZ, s_DistanceHoizontal))

		s_DifferenceYaw = math.abs(s_OldYaw - s_Yaw)

		if s_DifferenceYaw > math.pi then
			s_DifferenceYaw = math.pi * 2 - s_DifferenceYaw
		end

		if p_AttackinBot.m_InVehicle then
			if m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.AntiAir) then
				s_FovHalf = Config.FovVehicleAAForShooting / 360 * math.pi
				s_PitchHalf = Config.FovVerticleVehicleAAForShooting / 360 * math.pi
			elseif (m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.Chopper) or m_Vehicles:IsVehicleType(p_AttackinBot.m_ActiveVehicle, VehicleTypes.Plane)) and p_AttackinBot.m_Player.controlledEntryId == 0 then -- chopper as driver
				s_FovHalf = Config.FovVehicleForShooting / 360 * math.pi
				s_PitchHalf = Config.FovVerticleChopperForShooting / 360 * math.pi
			else
				s_FovHalf = Config.FovVehicleForShooting / 360 * math.pi
				s_PitchHalf = Config.FovVerticleVehicleForShooting / 360 * math.pi
			end
		else
			s_FovHalf = Config.FovForShooting / 360 * math.pi
			s_PitchHalf = Config.FovVerticleForShooting / 360 * math.pi
		end
	end

	if s_IgnoreFov or (s_DifferenceYaw < s_FovHalf and s_Pitch < s_PitchHalf) then
		local s_NumberOfHits = 0
		if p_AttackinBot.m_InVehicle then
			s_NumberOfHits = s_NumberOfHits + 1
		end
		if s_Type ~= VehicleTypes.NoVehicle then
			s_NumberOfHits = s_NumberOfHits + 1
		end

		return true, s_AttackingBotPos, s_EnemyPosition, s_NumberOfHits
	end

	return false
end

function BotManager:_CheckForBotAttack()
	local s_Raycasts = 0
	local s_NextPlayerIndex = 1

	for i = self._LastBotCheckIndex, #self._Bots do
		local s_Bot = self._Bots[i]
		if s_Bot ~= nil and s_Bot.m_Player ~= nil and s_Bot.m_Player.soldier ~= nil and s_Bot._ActiveAction == BotActionFlags.NoActionActive then

			for l_TeamId = 1, Globals.NrOfTeams do
				if l_TeamId ~= s_Bot.m_Player.teamId then
					-- enemy team
					local s_AllPlayersOfTeam = PlayerManager:GetPlayersByTeam(l_TeamId)	-- TODO: use shuffled lists
					for _, l_Player in pairs(s_AllPlayersOfTeam) do
						local s_ConnectionValue = ""
						local s_Id1 = s_Bot.m_Player.id
						local s_Id2 = l_Player.id
						if s_Id1 > s_Id2 then
							s_ConnectionValue = tostring(s_Id2)..tostring(s_Id1)
						else
							s_ConnectionValue = tostring(s_Id1)..tostring(s_Id2)
						end
						if l_Player ~= nil and l_Player.soldier ~= nil and not self._BotCheckState[s_ConnectionValue] then
							-- connection has not been checked yet
							self._BotCheckState[s_ConnectionValue] = true
							local s_EnemyBot = self:GetBotByName(l_Player.name)
							if s_EnemyBot ~= nil then
								-- Bot on Bot Attack
								local s_Attack1, s_Attack2, s_BotPosition, s_EnemyPostition, s_NumberOfExpectedHits = self:_EvaluateAttackBotBot(s_Bot, s_EnemyBot)
								if s_Attack1 or s_Attack2 then
									if self:_DoRaycast(s_BotPosition, s_EnemyPostition, s_NumberOfExpectedHits) then
										if s_Attack1 then
											-- notify bot to attack
										end
										if s_Attack2 then
											-- notify bot2 to attack
										end
									end
								end
							else
								-- Bot on Player Attack
								local s_Attack, s_BotPosition, s_EnemyPostition, s_NumberOfExpectedHits = self:_EvaluateAttackBotPlayer(s_Bot, l_Player)
								if s_Attack then
									if self:_DoRaycast(s_BotPosition, s_EnemyPostition, s_NumberOfExpectedHits) then
										-- notify bot to attack player (no more check needed)
									end
								end
							end
						end				
					end
				end
			end
		end
	end
end



function BotManager:_CheckForBotBotAttack()
	-- not enough on either team and no players to use
	local s_TeamsWithPlayers = 0

	for i = 1, Globals.NrOfTeams do
		if #self._BotsByTeam[i + 1] > 0 then
			s_TeamsWithPlayers = s_TeamsWithPlayers + 1
		end
	end

	if s_TeamsWithPlayers < 2 then
		return
	end

	local s_Players = self:GetPlayers()
	local s_PlayerCount = #s_Players

	if s_PlayerCount < 1 then
		return
	end

	local s_Raycasts = 0
	local s_NextPlayerIndex = 1

	for i = self._LastBotCheckIndex, #self._Bots do
		local s_Bot = self._Bots[i]

		-- bot has player, is alive, and hasn't found that special someone yet
		if s_Bot ~= nil and s_Bot.m_Player ~= nil and s_Bot.m_Player.soldier ~= nil and not self._BotCheckState[s_Bot.m_Player.name] then
			local s_OpposingTeams = {}

			for l_TeamId = 1, Globals.NrOfTeams do
				if s_Bot.m_Player.teamId ~= l_TeamId then
					table.insert(s_OpposingTeams, l_TeamId)
				end
			end

			for _, s_OpposingTeam in pairs(s_OpposingTeams) do
				-- search only opposing team
				-- first check for real players? Or jsut use a random table?
				for _, l_Player in pairs(s_Players) do
					if l_Player ~= nil and l_Player.teamId == s_OpposingTeam and l_Player.soldier ~= nil then
						-- real Player
						local s_BotPosition = s_Bot.m_Player.soldier.worldTransform.trans:Clone()
						local l_EnemyPosition = l_Player.soldier.worldTransform.trans:Clone()
						local s_Distance = s_BotPosition:Distance(l_EnemyPosition)
						if (s_Distance < Config.MaxRaycastDistance) or (s_Bot.m_InVehicle and Config.MaxRaycastDistanceVehicles) then

							if l_Player.controlledControllable ~= nil or s_Bot.m_InVehicle then
								local s_DeltaPos = s_BotPosition - l_EnemyPosition
								s_DeltaPos = s_DeltaPos:Normalize()
								if l_Player.controlledControllable ~= nil and not l_Player.controlledControllable:Is("ServerSoldierEntity") then -- Start Raycast outside of vehicle?
									l_EnemyPosition = l_EnemyPosition + (s_DeltaPos * 4.0)
								end
								if s_Bot.m_InVehicle then
									s_BotPosition = s_BotPosition - (s_DeltaPos * 4.0)
								end
							end

							local s_FlagsMaterial = 0 --MaterialFlags.MfPenetrable | MaterialFlags.MfClientDestructible | MaterialFlags.MfBashable | MaterialFlags.MfSeeThrough | MaterialFlags.MfNoCollisionResponse | MaterialFlags.MfNoCollisionResponseCombined
							local s_RaycastFlags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter
							local s_Result = RaycastManager:CollisionRaycast(s_BotPosition, l_EnemyPosition, 1, s_FlagsMaterial, s_RaycastFlags)
							s_Raycasts = s_Raycasts + 1

							if s_Result[1] == nil or s_Result[1].rigidBody == nil then
								-- we found a valid bot in Sight (either no hit, or player-hit). Signal Server with players
								local s_IgnoreYaw = false
			
								if s_Distance < Config.DistanceForDirectAttack then
									s_IgnoreYaw = true -- shoot, because you are near
								end

								s_Bot:ShootAt(l_Player, s_IgnoreYaw)
								self._BotCheckState[s_Bot.m_Player.name] = l_Player.name
								break
							end
						end
						if s_Raycasts >= Registry.BOT.MAX_RAYCASTS_PER_CYCLE then
							-- leave the function early for this cycle
							self._LastBotCheckIndex = i
							return
						end
					end
				end
				-- then chek for enemy bots
				for _, l_EnemyBot in pairs(self._BotsByTeam[s_OpposingTeam + 1]) do
					if l_EnemyBot ~= nil and l_EnemyBot.m_Player ~= nil and l_EnemyBot.m_Player.soldier ~= nil and not self._BotCheckState[l_EnemyBot.m_Player.name] then
						local s_EnemyBot = l_EnemyBot
						local s_BotPosition = s_Bot.m_Player.soldier.worldTransform.trans:Clone()
						local l_EnemyPosition = l_EnemyBot.m_Player.soldier.worldTransform.trans:Clone()
						local s_Distance = s_BotPosition:Distance(l_EnemyPosition)
						-- other Bot
						if s_Distance <= Config.MaxBotAttackBotDistance then

							if s_EnemyBot.m_InVehicle or s_Bot.m_InVehicle then
								local s_DeltaPos = s_BotPosition - l_EnemyPosition
								s_DeltaPos = s_DeltaPos:Normalize()
								if s_Bot.m_InVehicle then -- Start Raycast outside of vehicle?
									l_EnemyPosition = l_EnemyPosition + (s_DeltaPos * 4.0)
								end
								if s_EnemyBot.m_InVehicle then
									s_BotPosition = s_BotPosition - (s_DeltaPos * 4.0)
								end
							end

							local s_FlagsMaterial = 0 -- MaterialFlags.MfPenetrable | MaterialFlags.MfClientDestructible | MaterialFlags.MfBashable | MaterialFlags.MfSeeThrough | MaterialFlags.MfNoCollisionResponse | MaterialFlags.MfNoCollisionResponseCombined
							local s_RaycastFlags = RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter
							local s_Result = RaycastManager:CollisionRaycast(s_BotPosition, l_EnemyPosition, 1, s_FlagsMaterial, s_RaycastFlags)
							s_Raycasts = s_Raycasts + 1
							self.tempCounter = self.tempCounter + 1
							if s_Result[1] == nil or s_Result[1].rigidBody == nil then
								if s_Bot:ShootAt(l_EnemyBot.m_Player, false) or s_EnemyBot:ShootAt(s_Bot.m_Player, false) then
									self._BotCheckState[s_Bot.m_Player.name] = l_EnemyBot.m_Player.name
									self._BotCheckState[l_EnemyBot.m_Player.name] = s_Bot.m_Player.name
								else
									self._BotCheckState[s_Bot.m_Player.name] = nil
									self._BotCheckState[l_EnemyBot.m_Player.name] = nil
								end
							end
						end
						if s_Raycasts >= Registry.BOT.MAX_RAYCASTS_PER_CYCLE then
							-- leave the function early for this cycle
							self._LastBotCheckIndex = i
							return
						end
					end
				end
			end
		end

		self._LastBotCheckIndex = i
	end

	-- should only reach here if every connection has been checked
	-- clear the cache and start over
	self._LastBotCheckIndex = 1
	print(self.tempCounter)
	self.tempCounter = 0
	self._BotCheckState = {}
end

function BotManager:_GetDamageValue(p_Damage, p_Bot, p_Soldier, p_Fake)
	local s_ResultDamage = 0
	local s_DamageFactor = 1.0

	if p_Bot.m_ActiveWeapon.type == WeaponTypes.Shotgun then
		s_DamageFactor = Config.DamageFactorShotgun
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Assault then
		s_DamageFactor = Config.DamageFactorAssault
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Carabine then
		s_DamageFactor = Config.DamageFactorCarabine
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.PDW then
		s_DamageFactor = Config.DamageFactorPDW
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.LMG then
		s_DamageFactor = Config.DamageFactorLMG
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Sniper then
		s_DamageFactor = Config.DamageFactorSniper
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Pistol then
		s_DamageFactor = Config.DamageFactorPistol
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Knife then
		s_DamageFactor = Config.DamageFactorKnife
	end

	if not p_Fake then -- frag mode
		s_ResultDamage = p_Damage * s_DamageFactor
	else
		if p_Damage <= 2 then
			local s_Distance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Soldier.worldTransform.trans)

			if s_Distance >= p_Bot.m_ActiveWeapon.damageFalloffEndDistance then
				s_ResultDamage = p_Bot.m_ActiveWeapon.endDamage
			elseif s_Distance <= p_Bot.m_ActiveWeapon.damageFalloffStartDistance then
				s_ResultDamage = p_Bot.m_ActiveWeapon.damage
			else -- extrapolate damage
				local s_RelativePosition = (s_Distance - p_Bot.m_ActiveWeapon.damageFalloffStartDistance) / (p_Bot.m_ActiveWeapon.damageFalloffEndDistance - p_Bot.m_ActiveWeapon.damageFalloffStartDistance)
				s_ResultDamage = p_Bot.m_ActiveWeapon.damage - (s_RelativePosition * (p_Bot.m_ActiveWeapon.damage - p_Bot.m_ActiveWeapon.endDamage))
			end

			if p_Damage == 2 then
				s_ResultDamage = s_ResultDamage * Config.HeadShotFactorBots
			end

			s_ResultDamage = s_ResultDamage * s_DamageFactor
		elseif p_Damage == 3 then -- melee
			s_ResultDamage = p_Bot.m_Knife.damage * Config.DamageFactorKnife
		end
	end

	return s_ResultDamage
end

if g_BotManager == nil then
	g_BotManager = BotManager()
end

return g_BotManager
