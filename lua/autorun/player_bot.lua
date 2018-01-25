include("player_bot_extend.lua")
include("player_bot_names.lua")

local cmd = nil -- Cmd for bot
local bot = nil -- Current player bot

----------------------------------------------------
-- Player bot global settings (All bots will use)
----------------------------------------------------
local options = {
	HittingRange 		= 92,
	FindRandomPosition 	= 5,
	MinIdleDelay		= 1,
	MaxIdleDelay		= 3,
	MinRandRange		= -500,
	MaxRandRange		= 500,
	WanderingMovingSpeed= 90,
	ChasingMovingSpeed	= 170,
	TargetRange			= 500
}

----------------------------------------------------
-- Finite State Machine ENUMS
-- 0 Nothing
-- 1 Idle
-- 2 Wandering
-- 3 Chase
-- 4 Attack
-- 5 Use Item
----------------------------------------------------
local FMS_STATE = {
	NOTHING = 0,
	IDLE = 1,
	WANDER = 2,
	CHASE = 3,
	ATTACK = 4,
	ACTIVATE = 5
}

----------------------------------------------------
-- Walking State ENUM
-- 0 Walking
-- 1 Running
----------------------------------------------------
local WALKING_STATE = {
	WALKING = 0,
	RUNNING = 1
}

----------------------------------------------------
-- Driving State ENUM
-- 0 Walking
-- 1 Driving
----------------------------------------------------
local DRIVING_STATE = {
	WALKING = 0,
	DRIVING = 1
}

----------------------------------------------------
-- get_distance_to_target()
-- Gets the distance to targeted entity
----------------------------------------------------
local function get_distance_to_target()
	return bot:GetPos():Distance(bot:GetTarget():GetPos())
end

----------------------------------------------------
-- get_within_hitting_range()
-- Checks if target is within hitting range
----------------------------------------------------
local function get_within_hitting_range()
	local dis = get_distance_to_target()
	if (dis < options.HittingRange) then return true else return false end
end

----------------------------------------------------
-- get_random_idle_delay()
-- Gets a random number given the idling delay settings
----------------------------------------------------
local function get_random_idle_delay()
	return math.random(options.MinIdleDelay, options.MaxIdleDelay)
end

----------------------------------------------------
-- get_random_range()
-- Gets a random number given the range settings
----------------------------------------------------
local function get_random_range()
	return math.random(options.MinRandRange, options.MaxRandRange)
end

----------------------------------------------------
-- get_random_position()
-- Get a random position near given position
----------------------------------------------------
local function get_random_position(pos)
	local newXPos = pos.x + get_random_range()
	local newYPos = pos.y + get_random_range()
	return Vector(newXPos, newYPos, pos.z)
end

----------------------------------------------------
-- get_players_within_radius()
-- Check for players within a given range at a certain position
-- @param pos Vector: Position to search from
-- @param pos Integer: Radius to search
-- @return players Table: Players within range
----------------------------------------------------
local function get_players_within_radius(pos, radius)
	local players = {}
	for ___, ply in pairs(ents.FindInSphere(pos, radius)) do 
		if ((ply:IsPlayer()) && (ply ~= bot)) then table.insert(players, ply) end
	end
	return players
end

----------------------------------------------------
-- set_key()
-- Sets the key press for the bot
----------------------------------------------------
local function set_key(IN_ENUM)
	local KeysPressed = cmd:GetButtons()
	KeysPressed = bit.bor(KeysPressed, IN_ENUM)
	cmd:SetButtons(KeysPressed)
end

----------------------------------------------------
-- look_at_pos()
-- Look in a certain position
-- @param pos Vector: Position to look in
----------------------------------------------------
local function look_at_pos(pos)
	local botPos = bot:GetPos()
	local newYPos = pos.y - botPos.y -- Get differences
	local newXPos = pos.x - botPos.x
	local newZPos = pos.z - botPos.z

	local radian = math.atan2(newYPos, newXPos) -- Conver to radian
	local degree = math.deg(radian) -- Convert radian to degree for bot to aim at

	local distance = botPos:Distance(pos) 
	local pitch = math.atan2(-newZPos, distance) -- Work out the pitch
	
	local newAimVector = Angle(pitch, degree, 0) -- Get the new aim vector

	bot:SetEyeAngles(newAimVector)
	cmd:SetViewAngles(newAimVector)
end

----------------------------------------------------
-- ENT:check_targeted_exists()
-- Check if targeted Entity is alive and exists
-- @param ent Entity: The Entity to check
-- @return Boolean: If the entity exists
----------------------------------------------------
local function check_targeted_exists(ent)
	if (ent ~= nil) && (ent:IsValid()) then
		if (ent:Health() < 0) then return false end
	else
		return false
	end
	return true
end

----------------------------------------------------
-- check_targeted_alive()
-- Check if target is alive
-- @return Boolean: If the target is alive or dead
----------------------------------------------------
local function check_targeted_alive()
	if (bot:GetTarget()) then return false else return true end
end

----------------------------------------------------
-- update_action()
-- Updates the action of the entity
----------------------------------------------------
local function update_action()
	----------------------------------------------------
	-- Nothing State
	----------------------------------------------------
	if (bot.AIState == FMS_STATE.NOTHING) then
	----------------------------------------------------
	-- Idle State
	----------------------------------------------------
	elseif (bot.AIState == FMS_STATE.IDLE) then
		if ((!bot.idleDelay) || (CurTime() > bot.idleDelay)) then
			bot.AIState = FMS_STATE.WANDER
			bot.idleDelay = CurTime() + get_random_idle_delay()
		end
	----------------------------------------------------
	-- Wandering State
	----------------------------------------------------
	elseif (bot.AIState == FMS_STATE.WANDER) then
		bot:SetTarget(table.Random(get_players_within_radius(bot:GetPos(), options.TargetRange)))
		if (bot:GetTarget()) then
			if (bot:GetTarget():Alive()) then 
				if (get_distance_to_target() < options.TargetRange) then -- Checks if target is within range to chase
					bot.AIState = FMS_STATE.CHASE
				end
			end
		end
		if ((!bot.findRandomPositionDelay) || (CurTime() > bot.findRandomPositionDelay)) then -- Pick a new random position
			bot.RandomPosition = get_random_position(bot:GetPos())
			bot.findRandomPositionDelay = CurTime() + options.FindRandomPosition
		else
			if (bot:GetPos():Distance(bot.RandomPosition) < 128) then -- If near the random position then idle
				bot.AIState = FMS_STATE.IDLE
			end
		end
	----------------------------------------------------
	-- Chase State
	----------------------------------------------------
	elseif (bot.AIState == FMS_STATE.CHASE) then
		if (bot:GetTarget()) then
			if (!bot:GetTarget():Alive()) then
				bot.AIState = FMS_STATE.WANDER
			else
				if (get_distance_to_target() > options.TargetRange) then -- Checks if target is within chasing range
					bot.AIState = FMS_STATE.WANDER
				else
					if (get_within_hitting_range()) then -- Check if the target is within range to hit
						bot.AIState = FMS_STATE.ATTACK
					end
				end
			end
		end
	----------------------------------------------------
	-- Attack State
	----------------------------------------------------
	elseif (bot.AIState == FMS_STATE.ATTACK) then 
		if (bot:GetTarget()) then
			if (!get_within_hitting_range()) then -- Checks if target is still within range
				bot.AIState = FMS_STATE.CHASE
			else
				if (!bot:GetTarget():Alive()) then
					bot.AIState = FMS_STATE.WANDER
				end
			end
		else
			bot.AIState = FMS_STATE.WANDER 
		end
	----------------------------------------------------
	-- Use Item State
	----------------------------------------------------
	elseif (bot.AIState == FMS_STATE.ACTIVATE) then
		--[[
		if (!bot:InVehicle()) then
			if (!bot:GetTarget()) then
				for ___, ent in pairs(ents.FindInSphere(bot:GetPos(), 192)) do 
					if (ent:GetClass() == "prop_vehicle_jeep") then 
						bot:SetTarget(ent)
					end
				end
			end
		else
			bot.RandomPosition = get_random_position(bot:GetPos())
			bot.AIState = FMS_STATE.WANDER
		end]]
	----------------------------------------------------
	-- Default State
	----------------------------------------------------
	else -- Default
	end
end
----------------------------------------------------
-- perfom_action()
-- Performs the action of the entity
----------------------------------------------------
local function perfom_action()
	if (bot.AIState == FMS_STATE.NOTHING) then -- Nothing
	elseif (bot.AIState == FMS_STATE.IDLE) then -- Idle
        cmd:SetForwardMove(0)
	elseif (bot.AIState == FMS_STATE.WANDER) then -- Wandering
		look_at_pos(bot.RandomPosition)
		set_key(IN_FORWARD)
		cmd:SetForwardMove(options.WanderingMovingSpeed)
	elseif (bot.AIState == FMS_STATE.CHASE) then -- Chase
		look_at_pos(bot:GetTarget():GetPos())
        set_key(IN_FORWARD)
		cmd:SetForwardMove(options.ChasingMovingSpeed)
	elseif (bot.AIState == FMS_STATE.ATTACK) then -- Attack
		look_at_pos(bot:GetTarget():GetPos())
		set_key(IN_ATTACK)
	elseif (bot.AIState == FMS_STATE.ACTIVATE) then -- Activate Item
	--[[if (bot:GetTarget()) then
			bot:EnterVehicle(bot:GetTarget())
		end]]
	else -- Default
	end
end

----------------------------------------------------
-- CreatePlayerBot()
-- Updates the action of the entity
----------------------------------------------------
local function create_player_bot()
	-- Randomly Generates a name given the botnames file
	if (!game.SinglePlayer() && #player.GetAll() < game.MaxPlayers()) then
		local bot = player.CreateNextBot( names[ math.random( #names ) ])
		bot.IsBRBot = true
		bot:SetAiState(FMS_STATE.WANDER) -- Default state
	else print( "Cannot create bot. Are you in Single Player?" ) end
end

----------------------------------------------------
-- StartCommand
-- StartCommand hook for controlling the bot
----------------------------------------------------
hook.Add( "StartCommand", "Control_Bots", function( player, playerCMD )
	if (!player.IsBRBot) then return false end
	-- Set as bot currently being used
	cmd = playerCMD
	bot = player

	-- Clear movements and button presses as default they do use keys for some reason
	cmd:ClearMovement()
	cmd:ClearButtons()

	-- Run the bot though the FSM
	update_action()
	perfom_action()
end )

----------------------------------------------------	
-- CMDs
-- Console Commands for bot
----------------------------------------------------

--  Spawn player bot
concommand.Add( "spawn_player", function(ply, cmd, args)
	if (ply:IsAdmin()) then create_player_bot() end
end )
