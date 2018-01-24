include("player_bot_extend.lua")
include("player_bot_names.lua")

local cmd = nil -- Cmd for bot
local bot = nil -- current Player bot

local findRandomPositionDelay = 0

local options = {
	HittingRange = 92,
	FindRandomPosition = 5
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
-- set_key()
-- Sets the key press for the bot
----------------------------------------------------
local function set_key(IN_ENUM)
	local KeysPressed = cmd:GetButtons()
	KeysPressed = bit.bor(KeysPressed, IN_ENUM)
	cmd:SetButtons(KeysPressed)
end

----------------------------------------------------
-- update_action()
-- Updates the action of the entity
----------------------------------------------------
local function update_action()
	if bot.AIState == 0 then -- Nothing
	elseif bot.AIState == 1 then -- Idle
	elseif bot.AIState == 2 then -- Wandering
		bot:SetTarget(table.Random(player.GetHumans()))
		if ((bot:GetTarget()) && (bot:GetTarget():Alive())) then
			if (get_distance_to_target() < 500) then
				bot.AIState = 3
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
		if (CurTime() > findRandomPositionDelay) then -- HACK this statement should not be here
			local randomPosition = Vector(bot:GetPos().x + math.random(-500, 500) , bot:GetPos().y + math.random(-500, 500), bot:GetPos().z)
			look_at_pos(randomPosition)
			findRandomPositionDelay = CurTime() + options.FindRandomPosition
		end
		set_key(IN_FORWARD)
		cmd:SetForwardMove(170)
	elseif bot.AIState == 3 then -- Chase
		look_at_pos(bot:GetTarget():GetPos())
        set_key(IN_FORWARD)
		cmd:SetForwardMove(170)
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
