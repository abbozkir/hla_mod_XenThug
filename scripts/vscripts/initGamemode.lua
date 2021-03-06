--============ Copyright (c) Manuel "Manello" Bäuerle, All rights reserved. ==========
-- 
-- This file contains generic functions, globals and constants
--=============================================================================

require "mapdata"

print ("\n\n Initializing Manellos Invasion Mod...")

_G.ActivePlayer = Entities:GetLocalPlayer()

_G.NpcList = {}

_G.UPDATE_STEP_CHECK = 0
_G.UPDATE_STEP_SPAWN = 1
_G.UPDATE_STEP_REGISTER = 2
_G.UPDATE_DELAY_INIT = 3

_G.PolymerSpawnedTotal = 0
_G.PolymerTakenTotal = 0
_G.UpdateBoughtSomething = {}

_G.AlreadySetGoods = {}

_G.PolymersFreshSpawnPos = {}
_G.AlreadySetPolymers = {}
_G.AlreadySetCorpses = {}
_G.UpdatePolymers = false

--With this difference we can determine if the player picked up polymers
_G.TotalPolymersSpawned = 0
_G.TotalPolymersPickedUp = 0

_G.Stores = {
	AmmoVender = 0,
	ShellVender = 0,
	EnergyVender = 0,
	MedkitVender = 0,
	HealthVender = 0
}

_G.CurrentWave = 1

_G.UpdateStep = UPDATE_DELAY_INIT
_G.UpdateStepTimer = 0

_G.ToDelete = {}
_G.AlreadyDeletedCorpses = {}

_G.DelaySeconds = 0
_G.DelayLastTime = 0

_G.UpdateClasses = {} 
_G.UpdateClassesAmounts = {}

_G.SpawnLocation = {}

--PrecacheEntityFromTable("npc_headcrab", 1 , 2)
_G.CommandStack = {}
_G.CommandStack.queue = {}
_G.CommandStack.delayedComActive = false
_G.CommandStack.delayStart = 0
_G.CommandStack.delaySeconds = 0
--_G.CommandStack.queue[1].command = ""
--_G.CommandStack.queue[1].mode = 

_G.COMMAND_NONE = 0
_G.COMMAND_CONSOLE = 1
_G.COMMAND_INTERNAL = 2	--INTERNAL NOT SUPPORTED YET
_G.COMMAND_LUA = 3
_G.COMMAND_DELAYEDCONSOLE = 4	--The first 4 chars have to be digits containing the delay in ms!

_G.ModClock = 0

--=============================================================================

-- Commando Input
function _G.CommandStack.Add(theComm, theMode)
	if theMode == COMMAND_NONE then
		return
	else
		if theMode == nil then
			theMode = COMMAND_CONSOLE
		end
		CommandStack.queue[#CommandStack.queue + 1] = {command = theComm, mode = theMode}
	end
	
	if #CommandStack.queue > 100 then
		ModDebug("[WARNING]: More than 100 Commands in Stack! Expect bad gameplay!")
	end
end

-- Single Commando Execution, returns true if more commands are available
function _G.CommandStack.Exec()
	if CommandStack.delayedComActive == false then
		if #CommandStack.queue > 0 then
			if CommandStack.queue[1].mode == COMMAND_CONSOLE then
				SendToConsole(CommandStack.queue[1].command)
				table.remove(CommandStack.queue, 1)
				
			elseif CommandStack.queue[1].mode == COMMAND_LUA then
				local f = loadstring(CommandStack.queue[1].command)
				f()
				
			elseif CommandStack.queue[1].mode == COMMAND_DELAYEDCONSOLE then
				CommandStack.delayedComActive = true
				CommandStack.delayStart = ModClock
				CommandStack.delaySeconds = tonumber(string.sub(CommandStack.queue[1].command, 1, 4)) / 1000
			end
		end
	else
		local timeDiff = ModClock - CommandStack.delayStart 
		CommandStack.delaySeconds = CommandStack.delaySeconds - math.abs(timeDiff)
		CommandStack.delayStart = ModClock
		
		if CommandStack.delaySeconds <= 0 then
			SendToConsole(string.sub(CommandStack.queue[1].command, 5))
			table.remove(CommandStack.queue, 1)
			CommandStack.delayedComActive = false
		end
	end
	
	if #CommandStack.queue > 0 then
		return true
	else
		return false
	end
	return false
end

--Returns the index the mod uses for a npc class
function _G.ReturnIndexFromClass(strClass)
	for i = 1, #EntEnums, 1 do
		if EntEnums[i] == strClass then
			return i
		end
	end
	return nil
end

-- Outputs a Mod debug message
function _G.ModDebug(str)
	print("[MOD][XenThug]: " .. str)
end

-- Update Objects which where placed in Hammer (pre-runtime)
function _G.InitPreRuntimeObjects()
	AlreadySetCorpses = Entities:FindAllByClassname("prop_ragdoll")		--ignore existing corspes as mappers use them as deco
	AlreadyDeletedCorpses = Entities:FindAllByClassname("prop_ragdoll")
	
	local entsFound = Entities:FindAllByClassname("info_landmark")
	local entName = ""
	
	for i = 1, #entsFound, 1 do
		entName = entsFound[i]:GetName()
		
		if entName == "EnemySpawn" then
			SpawnLocation[#SpawnLocation + 1] = entsFound[i]
			if DebugEnabled == true then
				ModDebug("Found Location: SpawnLocation")
			end
			
		elseif string.sub(entName, 1, 7) == "Vender_" then		--Vender
			for j, vend in ipairs(Vender) do
				if vend.Name == entName then
					vend.Entity = entsFound[i]
				end
			end
			
			if DebugEnabled == true then
				ModDebug("Found Location: "..entName)
			end
		end
	end
	AlreadySetPolymers = Entities:FindAllByClassname("item_hlvr_crafting_currency_small")
	TotalPolymersSpawned = #AlreadySetPolymers + MyPolymer	--ACHTUNG: EVT WIEDER IN DEN FOR LOOP?
	TotalPolymersPickedUp = MyPolymer
	
	local firstEnt = Entities:First()
	local currEnt = firstEnt
	
	repeat
		if currEnt ~= nil then
			AlreadySetGoods[#AlreadySetGoods + 1] = currEnt
		end
	
		currEnt = Entities:Next(currEnt)
		if currEnt == nil then
			currEnt = Entities:Next(currEnt)
		end
	until (currEnt == firstEnt)
end

--Prints all Entities which are visible in the CURRENT TICK
function _G.DebugListEnts()
	local firstEnt = Entities:First()
	local currEnt = firstEnt
	
	repeat
		ModDebug("Entity: " .. currEnt:GetClassname())
	
		currEnt = Entities:Next(currEnt)
		if currEnt == nil then
			currEnt = Entities:Next(currEnt)
		end
	until (currEnt == firstEnt)
end

--Starts a delay for X seconds, stops the full script update process for this time
function _G.DelayStart(secs)
	DelaySeconds = secs
	DelayLastTime = ModClock
end

--Returns true if the Delay is still active
function _G.DelayActive()
	local timeDiff = ModClock - DelayLastTime
	DelaySeconds = DelaySeconds - math.abs(timeDiff/1000)
	
	if DelaySeconds <= 0 then
		DelaySeconds = 0
		return false
	end
	
	return true
end

--Updates the time in seconds passed since XenThug started up
function _G.UpdateModClock()
	if EnablePerformanceMode == true then
		ModClock = ModClock + FrameTime()*16
	else
		ModClock = ModClock + FrameTime()
	end
end

--Returns daytime in seconds
function _G.TimeInSeconds()
	return (LocalTime().Seconds + LocalTime().Minutes * 60 + LocalTime().Hours * 60 * 60)
end

--=============================================================================
InitPreRuntimeObjects()

_G.InitGamemodeDone = true

require "myGamemode"

ActivePlayer:SetThink(GamemodeThink, "xenthug_think", 0)

print ("Invasion Init done!")
