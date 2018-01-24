include("player_bot_extend.lua")
include("player_bot_names.lua")

local cmd = nil -- Cmd for bot
local bot = nil -- current Player bot

local options = {
	HittingRange 		= 92,
	FindRandomPosition 	= 5,
	MinIdleDelay		= 1,
	MaxIdleDelay		= 3,
	WanderingMovingSpeed= 90,
	ChasingMovingSpeed	= 170
}

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
	if (bot:GetTarget()) then
		return false
	end
	return true
end

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
-- set_key()
-- Sets the key press for the bot
----------------------------------------------------
local function set_key(IN_ENUM)
	local KeysPressed = cmd:GetButtons()
	KeysPressed = bit.bor(KeysPressed, IN_ENUM)
	cmd:SetButtons(KeysPressed)
end

----------------------------------------------------
-- get_random_position()
-- Get a random position near given position
----------------------------------------------------
local function get_random_position(pos)
	local newXPos = pos.x + math.random(-500, 500)
	local newYPos = pos.y + math.random(-500, 500)
	local position = Vector(newXPos, newYPos, pos.z)
	return position
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
-- update_action()
-- Updates the action of the entity
----------------------------------------------------
local function update_action()
	if bot.AIState == 0 then -- Nothing
	elseif bot.AIState == 1 then -- Idle
		if ((!bot.idleDelay) || (CurTime() > bot.idleDelay)) then
			bot.AIState = 2
			bot.idleDelay = CurTime() + get_random_idle_delay()
		end
	elseif bot.AIState == 2 then -- Wandering
		bot:SetTarget(table.Random(get_players_within_radius(bot:GetPos(), 500)))
		if (bot:GetTarget()) then
			if (bot:GetTarget():Alive()) then 
				if (get_distance_to_target() < 500) then
					bot.AIState = 3
				end
			end
		end
		if ((!bot.findRandomPositionDelay) || (CurTime() > bot.findRandomPositionDelay)) then 
			bot.RandomPosition = get_random_position(bot:GetPos())
			bot.findRandomPositionDelay = CurTime() + options.FindRandomPosition
		else
			if (bot:GetPos():Distance(bot.RandomPosition) < 128) then
				bot.AIState = 1
			end
		end
	elseif bot.AIState == 3 then -- Chase
		if (bot:GetTarget()) then
			if (!bot:GetTarget():Alive()) then
				bot.AIState = 2
			else
				if (get_distance_to_target() > 500) then
					bot.AIState = 2
				else
					if (get_within_hitting_range()) then
						bot.AIState = 4
					end
				end
			end
		end
	elseif bot.AIState == 4 then -- Attack
		if (bot:GetTarget()) then
			if (!get_within_hitting_range()) then
				bot.AIState = 3
			else
				if (!bot:GetTarget():Alive()) then
					bot.AIState = 2 
				end
			end
		else
			bot.AIState = 2 
		end
	elseif bot.AIState == 5 then -- Use Item
	else -- Default
	end
end
----------------------------------------------------
-- perfom_action()
-- Performs the action of the entity
----------------------------------------------------
local function perfom_action()
	if bot.AIState == 0 then -- Nothing
	elseif bot.AIState == 1 then -- Idle
        cmd:SetForwardMove(0)
	elseif bot.AIState == 2 then -- Wandering
		look_at_pos(bot.RandomPosition)
		set_key(IN_FORWARD)
		cmd:SetForwardMove(options.WanderingMovingSpeed)
	elseif bot.AIState == 3 then -- Chase
		look_at_pos(bot:GetTarget():GetPos())
        set_key(IN_FORWARD)
		cmd:SetForwardMove(options.ChasingMovingSpeed)
	elseif bot.AIState == 4 then -- Attack
		look_at_pos(bot:GetTarget():GetPos())
		set_key(IN_ATTACK)
	elseif bot.AIState == 5 then -- Use Item
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
		bot.IsNBBot = true
		bot:SetAiState(2)
	else print( "Cannot create bot. Are you in Single Player?" ) end
end

----------------------------------------------------
-- StartCommand
-- StartCommand hook for controlling the bot
----------------------------------------------------
hook.Add( "StartCommand", "Control_Bots", function( player, playerCMD )
	if (!player.IsNBBot) then return false end
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
