
local mod = mod_loader.mods[modApi.currentMod]
local memoryFunctions = require(mod.scriptPath .."memoryFunctions")

scanEvents = {
	skillExecuted = Event()
}

MemoryPawn = PunchMech:new{}
MemoryPawnEnemy = Hornet1:new{ SkillList = {"MemoryHornetAtk1"} }
MemoryHornetAtk1 = Skill:new{}

function MemoryHornetAtk1:GetTargetArea(p)
	local ret = PointList()
	for x = 0, 7 do
		for y = 0, 7 do
			ret:push_back(Point(x,y))
		end
	end
	return ret
end

function MemoryHornetAtk1:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	ret:AddQueuedDamage(SpaceDamage(p2))
	return ret
end

local BOARD_SIZE = 0x71A8
local BOARD_ROW_ADDR_EXPECTED = 0x50
local BOARD_ROW_STEP_EXPECTED = 0xC

-- sizes are scanned for
-- local PAWN_OBJ_SIZE_EXPECTED = 0x1128
-- local BOARD_OBJ_SIZE_EXPECTED = 0x71A8
-- local TILE_OBJ_SIZE_EXPECTED = 0x285C

local type2step = {
	boolean = "1",
	byte = "1",
	number = "4",
	string = "4",
}

local type2memFunc = {
	boolean = memoryFunctions.getAddrBool,
	byte = memoryFunctions.getAddrByte,
	number = memoryFunctions.getAddrInt,
	string = memoryFunctions.getAddrValue
}

function p2idx(p, w)
	if not w then w = Board:GetSize().x end
	return p.y * w + p.x
end

function idx2p(idx, w)
	if not w then w = Board:GetSize().x end
	return Point(idx % w, math.floor(idx / w))
end

local tiles = {}

local function prepareTiles()
	if tiles.prepared then
		return
	end

	for x = 0, 7 do
		for y = 0, 7 do
			local p = Point(x,y)
			local pawn = Board:GetPawn(p)
			local id = INT_MAX
			if pawn then
				id = pawn:GetId()
			end
			if id > 2 then
				Board:ClearSpace(p)
				Board:SetTerrain(p, TERRAIN_HOLE)
				Board:SetTerrain(p, TERRAIN_ROAD)
			end
		end
	end

	local pawns = {
		Board:GetPawn(0),
		Board:GetPawn(1),
		Board:GetPawn(2)
	}

	for x = 0, 7 do
		for y = 0, 7 do
			local p = Point(x,y)
			local i = p2idx(p)
			if not tiles[i] and not tiles.test then
				Board:SetTerrain(p, TERRAIN_ROAD)
				Board:SetTerrain(p, TERRAIN_BUILDING)
				if not Board:IsUniqueBuilding(p) then
					tiles.test = p
					tiles[i] = p
				end
				Board:SetTerrain(p, TERRAIN_ROAD)
			end
			if not tiles[i] and not tiles.testUnique then
				Board:SetTerrain(p, TERRAIN_ROAD)
				Board:SetTerrain(p, TERRAIN_BUILDING)
				if not Board:IsUniqueBuilding(p) then
					Board:AddUniqueBuilding("str_bar1")
					Assert.True(Board:IsUniqueBuilding(p))
					tiles.testUnique = p
					tiles[i] = p
				end
				Board:SetTerrain(p, TERRAIN_ROAD)
			end
			if not tiles[i] and not tiles.testOwner then
				tiles.testOwner = p
				tiles[i] = p
			end
			if not tiles[i] and not tiles.testOwned then
				tiles.testOwned = p
				tiles[i] = p
			end
			if pawns[1] and not tiles[i] and not tiles.mech0 then
				Board:SetTerrain(p, TERRAIN_ROAD)
				pawns[1]:SetSpace(p)
				tiles.mech0 = p
				tiles[i] = p
			end
			if pawns[2] and not tiles[i] and not tiles.mech1 then
				Board:SetTerrain(p, TERRAIN_ROAD)
				pawns[2]:SetSpace(p)
				tiles.mech1 = p
				tiles[i] = p
			end
			if pawns[3] and not tiles[i] and not tiles.mech2 then
				Board:SetTerrain(p, TERRAIN_ROAD)
				pawns[3]:SetSpace(p)
				tiles.mech2 = p
				tiles[i] = p
			end
			if not tiles[i] then
				while Board:IsPawnSpace(p) do
					Board:RemovePawn(p)
				end
			end
		end
	end

	tiles.prepared = true
end

local function getTestTile()
	prepareTiles()
	Assert.True(tiles.test ~= nil)
	return tiles.test
end
local function getTestTileOwner()
	prepareTiles()
	Assert.True(tiles.testOwner ~= nil)
	return tiles.testOwner
end
local function getTestTileOwned()
	prepareTiles()
	Assert.True(tiles.testOwned ~= nil)
	return tiles.testOwned
end
local function getTestTileUnique()
	prepareTiles()
	Assert.True(tiles.testUnique ~= nil)
	return tiles.testUnique
end

local function cleanupTile(p)
	Board:ClearSpace(p)
	Board:SetTerrain(p, TERRAIN_HOLE)
	Board:SetTerrain(p, TERRAIN_ROAD)
end

local function setTileTerrain(p, terrain)
	if not terrain then
		return
	end

	if not Board:IsTerrain(p, terrain) then
		Board:SetTerrain(p, terrain)
	end
end

scan = {
	type = "int",
	toggled = false,
	progressIndicator = 0,
	expectedResults = 1,
	expectedResultIndex = 1,
	iterations = 0,
	iterate = function(self) end,
	new = function(self, o)
		o = o or {}
		o.results = false
		setmetatable(o, self)
		self.__index = self
		return o
	end,
	result = function(self)
		if self.results == false or #self.results > self.expectedResults then
			return nil
		end

		table.sort(self.results, function(a,b) return a < b end)

		return self.results[self.expectedResultIndex]
	end,
}

local scans = {
	pawn = {},
	board = {},
	tile = {}
}

function scans:get(type, name)
	type = type:lower()
	name = name:gsub("%s", ""):lower()
	local scan = self[type][name] or scan:new{ disabled = true }
	return scan
end

scans.tile.size = scan:new{
	iterate = function(self)
		if self.results == false then
			local root = memoryFunctions.getObjAddr(Board)
			local row  = memoryFunctions.getAddrInt(root + BOARD_ROW_ADDR_EXPECTED)
			local tileRoots = {}
			local class = nil

			self.results = {}
			for x = 0, 7 * BOARD_ROW_STEP_EXPECTED, BOARD_ROW_STEP_EXPECTED do
				local tileRoot = memoryFunctions.getAddrInt(row + x)

				if class == nil then
					class = memoryFunctions.getAddrInt(tileRoot)
				elseif class ~= memoryFunctions.getAddrInt(tileRoot) then
					-- fail state. class mismatch.
					self.results = {}
					return
				end

				local value = nil
				tileRoots[#tileRoots+1] = tileRoot

				local addr = tileRoot
				repeat
					addr = addr + 4
					value = memoryFunctions.getAddrInt(addr)
				until value == class
				local size = addr - tileRoot
				if #self.results == 0 then
					self.results[1] = size
				else
					if self.results[1] ~= size then
						-- fail state. size mismatch.
						self.results = {}
						return
					end
				end
			end
		end
	end
}

scans.pawn.size = scan:new{
	iterate = function(self)
		if self.results == false then
			local pawns = {}
			local addr = {}
			local smallestDistance = INT_MAX

			for i = 1, 100 do
				local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
				pawns[#pawns+1] = pawn
			end

			pawns = {}
			for i = 1, 100 do
				local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
				pawns[#pawns+1] = pawn
				addr[#addr+1] = memoryFunctions.getObjAddr(pawn)
			end

			table.sort(addr, function(a,b) return a < b end)

			local smallestIterator = nil
			for i = 2, #addr do
				local distance = addr[i] - addr[i-1]
				if distance < smallestDistance then
					smallestIterator = i
					smallestDistance = distance
				end
			end

			self.results = {smallestDistance}
		end
	end
}

local function scanObject(root, obj_size, search, results)

	if type(search) ~= 'table' then
		search = { val = search }
	end

	search.type = search.type or type(search.val)
	search.step = search.step or type2step[search.type]
	search.func = search.func or type2memFunc[search.type]

	if results then
		local i = 0
		while i < #results do
			i = i + 1
			local addr = results[i]
			local value = search.func(root + addr)
			if value ~= search.val then
				-- swap and remove
				results[i] = results[#results]
				results[#results] = nil
			end
		end
	else
		results = {}
		for addr = 0, obj_size - search.step, search.step do
			local value = search.func(root + addr)
			if value == search.val then
				results[#results+1] = addr
			end
		end
	end

	return results
end

local function scanPawn(pawn, search, results)
	local size = scans.pawn.size:result()
	if size == nil then
		return false
	end
	local root = memoryFunctions.getObjAddr(pawn)
	return scanObject(root, size, search, results)
end

local function getBoardAddr()
	return memoryFunctions.getObjAddr(Board)
end

local function getTileAddr(p, y)
	if not Board then
		return 0x0
	end

	local x = p
	if type(p) == 'userdata' then
		x = p.x
		y = p.y
	end

	local board = memoryFunctions.getObjAddr(Board)
	local row = memoryFunctions.getAddrInt(board + BOARD_ROW_ADDR_EXPECTED)
	local column = memoryFunctions.getAddrInt(row + x * BOARD_ROW_STEP_EXPECTED)
	local size = scans.tile.size:result()
	return column + y * size
end

local function scanTile(p, search, results)
	local size = scans.tile.size:result()
	if size == nil then
		return false
	end
	local root = getTileAddr(p)
	return scanObject(root, size, search, results)
end

local function scanBoard(search, results)
	local root = getBoardAddr()
	return scanObject(root, BOARD_SIZE, search, results)
end

scans.tile.health = scan:new{
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		cleanupTile(p)
		Board:SetTerrain(p, TERRAIN_MOUNTAIN)
		local health = math.random(1,2)
		local d = SpaceDamage(p, 2 - health)
		Board:DamageSpace(d)
		self.results = scanTile(p, health, self.results)
	end
}

scans.tile.losthealth = scan:new{
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		cleanupTile(p)
		Board:SetTerrain(p, TERRAIN_MOUNTAIN)
		local dmg = math.random(0,1)
		local d = SpaceDamage(p, dmg)
		Board:DamageSpace(d)
		self.results = scanTile(p, dmg, self.results)
	end
}

scans.tile.maxhealth = scan:new{
	iterate = function(self)
		if not Board then
			return
		end
		local health = math.random(1,2)
		local p
		if health == 1 then
			p = getTestTileUnique()
			Board:SetTerrain(p, TERRAIN_BUILDING)
		else
			p = getTestTile()
			Board:SetTerrain(p, TERRAIN_MOUNTAIN)
			local d = SpaceDamage(p, 1)
			Board:DamageSpace(d)
		end
		self.results = scanTile(p, health, self.results)
	end
}

scans.tile.rubbletype = scan:new{
	type = "bool",
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		local rubbletype = math.random(0,1)
		if rubbletype == 0 then
			Board:SetTerrain(p, TERRAIN_BUILDING)
			Board:SetTerrain(p, TERRAIN_RUBBLE)
		else
			Board:SetTerrain(p, TERRAIN_MOUNTAIN)
			Board:SetTerrain(p, TERRAIN_RUBBLE)
		end
		self.results = scanTile(p, {type = 'byte', val = rubbletype}, self.results)
	end
}

scans.tile.uniquebuildingname = scan:new{
	type = "const char*",
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTileUnique()
		self.results = scanTile(p, "str_bar1", self.results)
	end
}

scans.tile.highlighted = scan:new{
	instruction = "hover tiles with skill 'Move'",
	skillHook = function(scan, mission, pawn, skillId, p1, p2, skillFx)
		if skillId ~= 'Move' then
			return
		end

		local value = true
		if math.random(2) == 1 then
			p2.y = (p2.y + 1) % 8
			value = false
		end
		scan.results = scanTile(p2, value, scan.results)
	end,
	iterate = function(self)
		if not Board then
			return
		end
		self.resultsPending = true
	end
}

local function isTipImage()
	return Board:GetSize() == Point(6,6)
end

scans.board.gameboard = scan:new{
	type = "bool",
	instruction = "hover tip images",
	skillHook = function(scan, mission, pawn, skillId, p1, p2, skillFx)
		local value = not isTipImage()
		LOG("scan gameboard")
		scan.results = scanBoard(value, scan.results)
	end,
	iterate = function(self)
		if not Board then
			return
		end
		LOG("iterate gameboard")
		self.resultsPending = true
	end
}

scans.tile.state = scan:new{
	clean = true,
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		if self.clean then
			cleanupTile(p)
		end
		setTileTerrain(p, self.terrain)
		local value = self.values[math.random(#self.values)]
		local arg = value
		if type(value) == 'table' then
			arg = value.arg
		end
		if type(arg) ~= 'table' then
			arg = {arg}
		end
		Board[self.boardFunc](Board, p, unpack(arg))
		self.results = scanTile(p, value, self.results)
		if self.clean then
			cleanupTile(p)
		end
	end
}

scans.tile.stateBool		= scans.tile.state:new{ type = "bool", values = {false, true} }
scans.tile.stateInt			= scans.tile.state:new{ type = "int", values = {1, 2, 3} }
scans.tile.stateString		= scans.tile.state:new{ type = "const char*", values = {"/control1/", "/control2/"} }
scans.tile.stateByte1		= scans.tile.state:new{ type = "bool", values = {{type = 'byte', arg = false, val = 0}, {type = 'byte', arg = true, val = 1}} }
scans.tile.stateByte2		= scans.tile.state:new{ type = "BYTE", values = {{type = 'byte', arg = false, val = 0}, {type = 'byte', arg = true, val = 2}} }

scans.tile.terrainicon		= scans.tile.stateString:new{ boardFunc = "SetTerrainIcon" }
scans.tile.acid				= scans.tile.stateBool:new{ boardFunc = "SetAcid", terrain = TERRAIN_ROAD }
scans.tile.smoke			= scans.tile.stateBool:new{ boardFunc = "SetSmoke", terrain = TERRAIN_ROAD,
								values = {{arg = {false, true}, val = false}, {arg = {true, true}, val = true}} }
scans.tile.firetype			= scans.tile.stateBool:new{ boardFunc = "SetFire", terrain = TERRAIN_ROAD }
scans.tile.frozen			= scans.tile.stateByte1:new{ boardFunc = "SetFrozen", terrain = TERRAIN_MOUNTAIN, clean = false }
scans.tile.shield			= scans.tile.stateByte2:new{ boardFunc = "SetShield", terrain = TERRAIN_MOUNTAIN }
scans.tile.itemname			= scans.tile.stateString:new{ boardFunc = "SetItem", terrain = TERRAIN_MOUNTAIN, values = {"Item_Mine", "Freeze_Mine"} }
scans.tile.terrain			= scans.tile.stateInt:new{ boardFunc = "SetTerrain", values = {TERRAIN_MOUNTAIN, TERRAIN_ICE}}

scans.pawn.defaultteam = scan:new{
	expectedResults = 2,
	expectedResultIndex = 1,
	iterate = function(self)
		local value = math.random(1,10)
		MemoryPawn.DefaultTeam = value
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		self.results = scanPawn(pawn, value, self.results)
	end
}

scans.pawn.id = scan:new{
	expectedResults = 2,
	expectedResultIndex = 2,
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		Board:AddPawn(pawn, p)
		self.results = scanPawn(pawn, pawn:GetId(), self.results)
		cleanupTile(p)
	end
}

scans.pawn.mech = scan:new{
	type = "bool",
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		local isMech = math.random(0,1)
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		Board:AddPawn(pawn, p)
		if isMech == 1 then
			pawn:SetMech()
		end
		self.results = scanPawn(pawn, {type = 'byte', val = isMech}, self.results)
		cleanupTile(p)
	end
}

scans.pawn.queuedtargetx = scan:new{
	expectedResults = 3,
	expectedResultIndex = 2,
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		local target = Point(math.random(0,7), math.random(0,7))
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawnEnemy")
		Board:AddPawn(pawn, p)
		pawn:FireWeapon(target, 1)
		self.results = scanPawn(pawn, target.x, self.results)
		cleanupTile(p)
	end
}
scans.pawn.queuedtargety = scan:new{
	expectedResults = 3,
	expectedResultIndex = 2,
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		local target = Point(math.random(0,7), math.random(0,7))
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawnEnemy")
		Board:AddPawn(pawn, p)
		pawn:FireWeapon(target, 1)
		self.results = scanPawn(pawn, target.y, self.results)
		cleanupTile(p)
	end
}

scans.pawn.owner = scan:new{
	iterate = function(self)
		if not Board then
			return
		end
		local p1 = getTestTileOwner()
		local p2 = getTestTileOwned()
		local owner = Board:GetPawn(p1)
		local owned = Board:GetPawn(p2)
		if owner and owned then
			self.results = scanPawn(owned, owner:GetId(), self.results)
		end

		cleanupTile(p1)
		cleanupTile(p2)

		if not self.results or #self.results > 1 then
			local owner = PAWN_FACTORY:CreatePawn("MemoryPawn")
			Board:AddPawn(owner, p1)
			local fx = SkillEffect()
			local d = SpaceDamage(p2)
			d.sPawn = "MemoryPawn"
			fx.iOwner = owner:GetId()
			fx:AddDamage(d)
			Board:AddEffect(fx)
			self.resultsPending = true
		end
	end
}

scans.pawn.health = scan:new{
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		cleanupTile(p)
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		Board:AddPawn(pawn, p)
		local health = pawn:GetHealth()
		local dmg = math.random(1,health)
		local d = SpaceDamage(p, dmg)
		Board:DamageSpace(d)
		self.results = scanPawn(pawn, health - dmg, self.results)
		Board:RemovePawn(pawn)
	end
}

scans.pawn.maxhealth = scan:new{
	expectedResults = 2,
	expectedResultIndex = 1,
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		cleanupTile(p)
		local maxhealth = math.random(2,10)
		MemoryPawn.Health = maxhealth
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		Board:AddPawn(pawn, p)
		local d = SpaceDamage(p, 1)
		Board:DamageSpace(d)
		self.results = scanPawn(pawn, maxhealth, self.results)
		Board:RemovePawn(pawn)
	end
}

scans.pawn.basemaxhealth = scan:new{
	expectedResults = 2,
	expectedResultIndex = 2,
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		cleanupTile(p)
		local maxhealth = math.random(2,10)
		MemoryPawn.Health = maxhealth
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		Board:AddPawn(pawn, p)
		local d = SpaceDamage(p, 1)
		Board:DamageSpace(d)
		self.results = scanPawn(pawn, maxhealth, self.results)
		Board:RemovePawn(pawn)
	end
}

local function search_weaponlist(addr)
	addr = memoryFunctions.getAddrInt(addr)
	if memoryFunctions.isAddrNotPtr(addr, 0x4) then
		return nil
	end
	addr = memoryFunctions.getAddrInt(addr)
	if memoryFunctions.isAddrNotPtr(addr, 0x4) then
		return nil
	end
	return memoryFunctions.getAddrValue(addr)
end

scans.pawn.weaponlist = scan:new{
	iterate = function(self)
		if not Board then
			return
		end
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		local search = { val = "Move", func = search_weaponlist }
		self.results = scanPawn(pawn, search, self.results)
	end
}

local function search_repairskill(addr)
	local obj_addr = memoryFunctions.getAddrInt(addr)
	if memoryFunctions.isAddrNotPtr(obj_addr, 0x4) then
		return nil
	end
	return memoryFunctions.getAddrValue(obj_addr)
end

scans.pawn.repairskill = scan:new{
	iterate = function(self)
		if not Board then
			return
		end
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		local search = { val = "Skill_Repair", func = search_repairskill }
		self.results = scanPawn(pawn, search, self.results)
	end
}

scans.pawn.undox = scan:new{
	expectedResults = 2,
	expectedResultIndex = 2,
	instruction = "repeatedly move and undo move",
	skillHook = function(scan, mission, pawn, skillId, p1, p2, skillFx)
		if skillId ~= 'Move' then
			return
		end

		if not pawn then
			return
		end

		skillFx:AddScript(string.format([[
			scanEvents.undox:dispatch(%s, %s)
		]], pawn:GetId(), p1.x))
	end,
	iterate = function(self)
		if not Board then
			return
		end

		self.resultsPending = true
	end
}

scanEvents.undox = Event()
scanEvents.undox:subscribe(function(pawnId, value)
	local scan = scans.pawn.undox
	local pawn = Board:GetPawn(pawnId)
	scan.results = scanPawn(pawn, value, scan.results)
end)

scans.pawn.undoy = scan:new{
	expectedResults = 2,
	expectedResultIndex = 2,
	instruction = "repeatedly move and undo move",
	skillHook = function(scan, mission, pawn, skillId, p1, p2, skillFx)
		if skillId ~= 'Move' then
			return
		end

		if not pawn then
			return
		end

		skillFx:AddScript(string.format([[
			scanEvents.undoy:dispatch(%s, %s)
		]], pawn:GetId(), p1.y))
	end,
	iterate = function(self)
		if not Board then
			return
		end

		self.resultsPending = true
	end
}

scanEvents.undoy = Event()
scanEvents.undoy:subscribe(function(pawnId, value)
	local scan = scans.pawn.undoy
	local pawn = Board:GetPawn(pawnId)
	scan.results = scanPawn(pawn, value, scan.results)
end)

scans.pawn.movespent = scan:new{
	expectedResults = 2,
	expectedResultIndex = 1,
	instruction = "repeatedly move and undo move",
	skillHook = function(scan, mission, pawn, skillId, p1, p2, skillFx)
		if skillId ~= 'Move' then
			return
		end

		if not pawn then
			return
		end

		skillFx:AddScript(string.format([[
			scanEvents.movespent:dispatch(%s, {type = 'byte', val = 1})
		]], pawn:GetId()))
	end,
	iterate = function(self)
		if not Board then
			return
		end

		local pawn = Board:GetSelectedPawn()
		if pawn and not pawn:IsUndoPossible() then
			self.results = scanPawn(pawn, {type = 'byte', val = 0}, self.results)
		end

		self.resultsPending = true
	end
}

scanEvents.movespent = Event()
scanEvents.movespent:subscribe(function(pawnId, value)
	local scan = scans.pawn.movespent
	local pawn = Board:GetPawn(pawnId)
	scan.results = scanPawn(pawn, value, scan.results)
end)

scans.pawn.trait = scan:new{
	iterate = function(self)
		local value = self.values[math.random(#self.values)]
		MemoryPawn[self.pawnTrait] = value
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		self.results = scanPawn(pawn, value, self.results)
	end
}

scans.pawn.state = scan:new{
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		cleanupTile(p)
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		Board:AddPawn(pawn, p)
		local value = self.values[math.random(#self.values)]
		pawn[self.pawnFunc](pawn, value)
		self.results = scanPawn(pawn, value, self.results)
		Board:RemovePawn(pawn)
	end
}

scans.pawn.effect = scan:new{
	type = "bool",
	create = EFFECT_CREATE,
	remove = EFFECT_REMOVE,
	iterate = function(self)
		if not Board then
			return
		end
		local p = getTestTile()
		cleanupTile(p)
		local effect = math.random(0,1)
		local pawn = PAWN_FACTORY:CreatePawn("MemoryPawn")
		Board:AddPawn(pawn, p)
		local d = SpaceDamage(p)
		d[self.effect] = self.create
		Board:DamageSpace(d)
		local d = SpaceDamage(p)
		d[self.effect] = self.remove
		Board:DamageSpace(d)
		if effect == 1 then
			local d = SpaceDamage(p)
			d[self.effect] = effect
			Board:DamageSpace(d)
		end
		self.results = scanPawn(pawn, {type = 'byte', val = effect}, self.results)
		Board:RemovePawn(pawn)
		cleanupTile(p)
	end
}

scans.pawn.traitBool		= scans.pawn.trait:new{ type = "bool", values = {false, true} }
scans.pawn.traitInt			= scans.pawn.trait:new{ type = "int", values = {1,2,3} }
scans.pawn.traitString		= scans.pawn.trait:new{ type = "const char*", values = {"/control1/", "/control2/"} }

scans.pawn.soundbase		= scans.pawn.traitString:new{ pawnTrait = "SoundLocation" }
scans.pawn.class			= scans.pawn.traitString:new{ pawnTrait = "Class" }
scans.pawn.imageoffset		= scans.pawn.traitInt:new{ pawnTrait = "ImageOffset" }
scans.pawn.movespeed		= scans.pawn.traitInt:new{ pawnTrait = "MoveSpeed" }
scans.pawn.impactmaterial	= scans.pawn.traitInt:new{ pawnTrait = "ImpactMaterial" }
scans.pawn.leader			= scans.pawn.traitInt:new{ pawnTrait = "Leader" }
scans.pawn.defaultfaction	= scans.pawn.traitInt:new{ pawnTrait = "DefaultFaction" }
scans.pawn.spacecolor		= scans.pawn.traitBool:new{ pawnTrait = "SpaceColor" }
scans.pawn.minor			= scans.pawn.traitBool:new{ pawnTrait = "Minor" }
scans.pawn.neutral			= scans.pawn.traitBool:new{ pawnTrait = "Neutral" }
scans.pawn.pushable			= scans.pawn.traitBool:new{ pawnTrait = "Pushable" }
scans.pawn.corpse			= scans.pawn.traitBool:new{ pawnTrait = "Corpse" }
scans.pawn.massive			= scans.pawn.traitBool:new{ pawnTrait = "Massive" }
scans.pawn.flying			= scans.pawn.traitBool:new{ pawnTrait = "Flying" }
scans.pawn.jumper			= scans.pawn.traitBool:new{ pawnTrait = "Jumper" }
scans.pawn.teleporter		= scans.pawn.traitBool:new{ pawnTrait = "Teleporter" }

scans.pawn.stateBool		= scans.pawn.state:new{ type = "bool", values = {false, true} }
scans.pawn.stateInt			= scans.pawn.state:new{ type = "int", values = {1,2,3} }
scans.pawn.stateString		= scans.pawn.state:new{ type = "const char*", values = {"/control1/", "/control2/"} }

scans.pawn.team				= scans.pawn.stateInt:new{ pawnFunc = "SetTeam" }
scans.pawn.mutation			= scans.pawn.stateInt:new{ pawnFunc = "SetMutation" }
scans.pawn.customanim		= scans.pawn.stateString:new{ pawnFunc = "SetCustomAnim" }
scans.pawn.active			= scans.pawn.stateBool:new{ pawnFunc = "SetActive" }
scans.pawn.invisible		= scans.pawn.stateBool:new{ pawnFunc = "SetInvisible" }
scans.pawn.missioncritical	= scans.pawn.stateBool:new{ pawnFunc = "SetMissionCritical" }
scans.pawn.powered			= scans.pawn.stateBool:new{ pawnFunc = "SetPowered" }

scans.pawn.acid				= scans.pawn.effect:new{ effect = "iAcid" }
scans.pawn.smoke			= scans.pawn.effect:new{ effect = "iSmoke" }
scans.pawn.frozen			= scans.pawn.effect:new{ effect = "iFrozen" }
scans.pawn.fire				= scans.pawn.effect:new{ effect = "iFire" }
scans.pawn.shield			= scans.pawn.effect:new{ effect = "iShield", remove = -1 }

return scans
