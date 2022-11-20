-- This file is autogenerated out of the Settings/SettingsDefinition.lua file.
-- For permanent changes, use this file and regenerate the Config.lua file.

---@class Config
Config = {
	-- GENERAL
	BotWeapon = BotWeapons.Auto, -- Select the weapon the bots use
	BotKit = BotKits.RANDOM_KIT, -- The Kit of the Bots
	BotColor = BotColors.RANDOM_COLOR, -- The Color of the Bots
	ZombieMode = false, -- Zombie Bot Mode

	-- DIFFICULTY
	BotAimWorsening = 0.3, -- Make bots aim worse: for difficulty: 0 = no offset (hard), 1 or even greater = more sway (easy)
	BotSniperAimWorsening = 0.2, -- See botAimWorsening, only for Sniper-rifles
	BotSupportAimWorsening = 0.3, -- See botAimWorsening, only for LMGs
	BotWorseningSkill = 0.50, -- Variation of the skill of a single bot. The higher, the worse the bots can get compared to the original settings
	BotSniperWorseningSkill = 0.50, -- See BotWorseningSkill - only for BOTs using sniper bolt-action rifles
	DamageFactorAssault = 1.0, -- Original Damage from bots gets multiplied by this
	DamageFactorCarabine = 1.0, -- Original Damage from bots gets multiplied by this
	DamageFactorLMG = 1.0, -- Original Damage from bots gets multiplied by this
	DamageFactorPDW = 1.0, -- Original Damage from bots gets multiplied by this
	DamageFactorSniper = 1.0, -- Original Damage from bots gets multiplied by this
	DamageFactorShotgun = 1.0, -- Original Damage from bots gets multiplied by this
	DamageFactorPistol = 1.0, -- Original Damage from bots gets multiplied by this
	DamageFactorKnife = 1.5, -- Original Damage from bots gets multiplied by this

	-- SPAWN
	SpawnMode = SpawnModes.balanced_teams, -- Mode the bots spawn with
	BalancePlayersIgnoringBots = false, -- Counts players in each team to decide which team a player joins
	TeamSwitchMode = TeamSwitchModes.SwitchForRoundTwo, -- Mode to switch the team
	SpawnInBothTeams = true, -- Bots spawn in both teams
	InitNumberOfBots = 10, -- Bots for spawnmode
	NewBotsPerNewPlayer = 1.6, -- Number to increase Bots by when new players join
	FactorPlayerTeamCount = 0.9, -- Reduce player team in balanced_teams or fixed_number mode
	BotTeam = 0, -- Default bot team (0 = neutral / auto, 1 = US, 2 = RU) TeamId.Team2
	BotNewLoadoutOnSpawn = true, -- Bots get a new kit and color, if they respawn
	MaxAssaultBots = -1, -- Maximum number of Bots with Assault Kit. -1 = no limit
	MaxEngineerBots = -1, -- Maximum number of Bots with Engineer Kit. -1 = no limit
	MaxSupportBots = -1, -- Maximum number of Bots with Support Kit. -1 = no limit
	MaxReconBots = -1, -- Maximum number of Bots with Recon Kit. -1 = no limit
	AdditionalBotSpawnDelay = 0.5, -- Additional time a bot waits to respawn
	BotMaxHealth = 100.0, -- Max health of bot (default 100.0)

	-- SPAWNLIMITS
	MaxBotsPerTeamDefault = 32, -- Max number of bots in one team, if no other mode fits
	MaxBotsPerTeamTdm = 32, -- Max number of bots in one team for TDM
	MaxBotsPerTeamTdmc = 8, -- Max number of bots in one team for TDM-CQ
	MaxBotsPerTeamSdm = 5, -- Max number of bots in one team for Squad-DM
	MaxBotsPerTeamCl = 32, -- Max number of bots in one team for CQ-Large
	MaxBotsPerTeamCs = 16, -- Max number of bots in one team for CQ-Small
	MaxBotsPerTeamCal = 32, -- Max number of bots in one team for CQ-Assault-Large
	MaxBotsPerTeamCas = 16, -- Max number of bots in one team for CQ-Assault-Small
	MaxBotsPerTeamRl = 24, -- Max number of bots in one team for Rush
	MaxBotsPerTeamCtf = 24, -- Max number of bots in one team for CTF
	MaxBotsPerTeamD = 12, -- Max number of bots in one team for Domination
	MaxBotsPerTeamGm = 12, -- Max number of bots in one team for Gunmaster
	MaxBotsPerTeamS = 12, -- Max number of bots in one team for Scavenger

	-- BEHAVIOUR
	FovForShooting = 180, -- Degrees of FOV of Bot
	FovVerticleForShooting = 90, -- Degrees of FOV of Bot in vertical direction
	MaxShootDistance = 70, -- Meters before bots (not sniper) will start shooting at players
	MaxShootDistanceSniper = 150, -- Meters before bots will start shooting at players
	MaxDistanceShootBack = 150, -- Meters until bots (not sniper) shoot back if hit
	MaxDistanceShootBackSniper = 400, -- Meters until snipers shoot back if hit
	MaxShootDistancePistol = 20, -- The distance before a bot switches to pistol if his magazine is empty (Only in auto-weapon-mode)
	BotAttackMode = BotAttackModes.RandomNotSet, -- Mode the Bots attack with. Random, Crouch or Stand
	ShootBackIfHit = true, -- Bot shoots back if hit
	BotsAttackBots = true, -- Bots attack bots from other team
	BotsAttackPlayers = true, -- Bots attack Players from other team
	MeleeAttackIfClose = true, -- Bot attacks with melee if close
	BotCanKillHimself = false, -- Bot takes fall damage or explosion-damage from own frags
	TeleportIfStuck = true, -- Bot teleport to their target if they are stuck
	BotsRevive = true, -- Bots revive other players
	BotsThrowGrenades = true, -- Bots throw grenades at enemies
	BotsDeploy = true, -- Bots deploy ammo and medkits
	DeployCycle = 60, -- Time between deployment of bots in seconds
	SnipersAttackChoppers = false, -- Bots with sniper-rifels attack choppers

	-- VEHICLE
	UseVehicles = true, -- Bots can use vehicles
	UseAirVehicles = true, -- Bots can use air-vehicles
	MaxBotsPerVehicle = 3, -- Maximum number of Bots in a vehicle
	FovVehicleForShooting = 180, -- Degrees of FOV of Non AA - Vehicles
	FovVerticleVehicleForShooting = 60, -- Degrees of vertical FOV of Non AA - Vehicles
	FovVerticleChopperForShooting = 80, -- Degrees of pitch a chopper attacks
	FovVehicleAAForShooting = 360, -- Degrees of FOV of AA - Vehicles
	FovVerticleVehicleAAForShooting = 160, -- Degrees of FOV of AA - Vehicles
	MaxShootDistanceVehicles = 250, -- Meters bots in Vehicles start shooting at players
	MaxShootDistanceNoAntiAir = 150, -- Meters bots in vehicle (no Anti-Air) starts shooting at players
	VehicleWaitForPassengersTime = 7.0, -- Seconds to wait for other passengers
	ChopperDriversAttack = false, -- If false, choppers only attack without gunner on board
	AABots = false, -- Enable Auto-AA by NyScorpy
	MaxDistanceAABots = 300, -- Max Range of Stationary AA

	-- WEAPONS
	UseRandomWeapon = true, -- Use a random weapon out of the Weapon Set
	AssaultWeaponSet = WeaponSets.Custom, -- Weaponset of Assault class. Custom uses the Shared/WeaponLists
	EngineerWeaponSet = WeaponSets.Custom, -- Weaponset of Engineer class. Custom uses the Shared/WeaponLists
	SupportWeaponSet = WeaponSets.Custom, -- Weaponset of Support class. Custom uses the Shared/WeaponLists
	ReconWeaponSet = WeaponSets.Custom, -- Weaponset of Recon class. Custom uses the Shared/WeaponLists
	AssaultWeapon = "M416", -- Primary weapon of Assault class, if random-weapon == false
	EngineerWeapon = "M4A1", -- Primary weapon of Engineer class, if random-weapon == false
	SupportWeapon = "M249", -- Primary weapon of Support class, if random-weapon == false
	ReconWeapon = "L96", -- Primary weapon of Recon class, if random-weapon == false
	Pistol = "MP412Rex", -- Pistol of Bots, if random-weapon == false
	Knife = "Razor", -- Knife of Bots, if random-weapon == false

	-- TRACE
	DebugTracePaths = false, -- Shows the trace line and search area from Commo Rose selection
	WaypointRange = 50, -- Set how far away waypoints are visible (meters)
	DrawWaypointLines = true, -- Draw waypoint connection lines
	LineRange = 25, -- Set how far away waypoint lines are visible (meters)
	DrawWaypointIDs = true, -- Draw the IDs of the waypoints
	TextRange = 7, -- Set how far away waypoint text is visible (meters)
	DrawSpawnPoints = false, -- Draw the Points where players can spawn
	SpawnPointRange = 100, -- Set how far away spawn points are visible (meters)
	TraceDelta = 0.3, -- Update interval of trace
	NodesPerCycle = 400, -- Set how many nodes get drawn per cycle. Affects performance

	-- ADVANCED
	DistanceForDirectAttack = 8, -- Distance bots can hear you at
	MeleeAttackCoolDown = 3.5, -- The time a bot waits before attacking with melee again
	AimForHead = false, -- Bots without sniper aim for the head. A more experimental config
	AimForHeadSniper = false, -- Bots with sniper aim for the head. A more experimental config
	AimForHeadSupport = false, -- Bots with support LMGs aim for the head. A more experimental config
	JumpWhileShooting = true, -- Bots jump over obstacles while shooting if needed
	JumpWhileMoving = true, -- Bots jump while moving. If false, only on obstacles!
	OverWriteBotSpeedMode = BotMoveSpeeds.NoMovement, -- 0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run
	OverWriteBotAttackMode = BotMoveSpeeds.NoMovement, -- Affects Aiming!!! 0 = no overwrite. 1 = prone, 2 = crouch (good aim), 3 = walk (good aim), 4 = run
	SpeedFactor = 1.0, -- Reduces the movement speed. 1 = normal, 0 = standing
	SpeedFactorAttack = 0.6, -- Reduces the movement speed while attacking. 1 = normal, 0 = standing
	UseRandomNames = false, -- Changes names of the bots on every new round. Experimental right now...
	MoveSidewards = true, -- Bots move sidewards
	MaxStraigtCycle = 10.0, -- Max time bots move straight, before sidewards-movement (in sec)
	MaxSideCycle = 5.0, -- Max time bots move sidewards, before straight-movement (in sec)
	MinMoveCycle = 0.3, -- Min time bots move sidewards or straight before switching (in sec)

	-- EXPERT
	BotFirstShotDelay = 0.25, -- Delay for first shot. If too small, there will be great spread in first cycle because it is not compensated yet
	BotMinTimeShootAtPlayer = 2.5, -- The minimum time a bot shoots at one player for - recommended minimum 1.5, below this you will have issues
	BotVehicleMinTimeShootAtPlayer = 4.0, -- The minimum time a bot shoots at one player if in vehicle - recommended minimum 2.5, below this you will have issues
	BotFireModeDuration = 4.5, -- The minimum time a bot tries to shoot a player - recommended minimum 3.0, below this you will have issues
	BotVehicleFireModeDuration = 9.0, -- The minimum time a bot tries to shoot a player or vehicle, when in a vehicle - recommended minimum 7.0
	MaximunYawPerSec = 450, -- In Degrees. Rotation Movement per second
	TargetDistanceWayPoint = 0.8, -- The distance the bots have to reach to continue with the next Waypoint
	KeepOneSlotForPlayers = true, -- Always keep one slot for free new Players to join
	DistanceToSpawnBots = 30, -- Distance to spawn Bots away from players
	HeightDistanceToSpawn = 2.8, -- Distance vertically, Bots should spawn away, if closer than distance
	DistanceToSpawnReduction = 5, -- Reduce distance if not possible
	MaxTrysToSpawnAtDistance = 3, -- Try this often to spawn a bot away from players
	AttackWayBots = true, -- Bots on paths attack player
	RespawnWayBots = true, -- Bots on paths respawn if killed
	SpawnMethod = SpawnMethod.SpawnSoldierAt, -- Method the bots spawn with. Careful, not supported on most of the maps!!

	-- OTHER
	DisableUserInterface = false, -- If true, the complete UI will be disabled (not available in the UI)
	AllowCommForAll = true, -- If true, all Players can access the Comm-Screen
	DisableChatCommands = false, -- If true, no chat commands can be used
	DisableRCONCommands = false, -- If true, no RCON commands can be used
	IgnorePermissions = false, -- If true, all permissions are ignored --> everyone can do everything
	Language = nil, -- de_DE as sample (default is English, when language file does not exist)
}
