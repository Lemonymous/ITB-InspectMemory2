
local mod = modApi:getCurrentMod()
local modApiExt = require(mod.scriptPath.."modApiExt/modApiExt")
local memoryFunctions = require(mod.scriptPath.."memoryFunctions")

local scanner = {
	current = 1,
	timeout = 100,
	running = false,
	output = "output",
	scans = {},
	clear = function(self)
		self.scans = {}
		self:stop()
	end,
	add = function(self, obj)
		if obj ~= nil then
			table.insert(self.scans, obj)
		end
	end,
	rem = function(self, obj)
		remove_element(obj, self.scans)
	end,
	start = function(self)
		self.running = true
	end,
	setTimeout = function(self, iterations)
		self.timeout = iterations
	end,
	stop = function(self)
		self.running = false
	end,
	print = function(self)
		local output = {
			pawn = {},
			board = {},
			tile = {}
		}
		for _, scan in pairs(self.scans) do
			local category = scan.category
			local type = scan.type
			local name = (scan.name or ""):gsub("%s","")
			local expected = scan.expected or 0x0
			local result = scan:result() or expected
			table.insert(output[category], {name = name, type = type, result = result, expected = expected} )
		end

		for category, list in pairs(output) do
			table.sort(list, function(a, b) return a.result < b.result end)

			local msg = category .." address list:\n"..
				"Address::[Category]<type>(\"[Name]\", [diff]) //[address]\n"
			for i, scan in ipairs(list) do
				local diff = scan.result
				if i > 1 then
					diff = list[i].result - list[i-1].result
				end
				msg = string.format("%sAddress::%s<%s>(%q, 0x%X), //0x%X\n", msg, category, scan.type, scan.name, diff, scan.result)
			end

			LOG(msg)
		end
	end,
	setOutputFile = function(self, fileName)
		self.output = fileName
	end,
	getCurrentScan = function(self)
		for i, scan in ipairs(self.scans) do
			if scan.toggled and not scan.disabled then
				if scan.results == false or #scan.results > scan.expectedResults then
					return i, scan
				end
			end
		end

		return -1, nil
	end
}

modApi.events.onFrameDrawn:subscribe(function()
	if not scanner.running then
		return
	end

	if #scanner.scans == 0 then
		return
	end

	local i, scan = scanner:getCurrentScan()
	if not scan then
		return
	end

	if scan.results == false or #scan.results > scan.expectedResults then
		scan.progressIndicator = scanner.timeout - scan.iterations
		scan:iterate()
		scan.iterations = scan.iterations + 1
	end

	scan.resultsPending = scan.resultsPending or scan.results ~= false and #scan.results > scan.expectedResults

	if scan.iterations >= scanner.timeout or not scan.resultsPending then
		table.remove(scanner.scans, i)
		table.insert(scanner.scans, scan)
		scan.iterations = 0
	end

	if scan.resultsPending and scan.skillHook then
		local instruction = scan.instruction or "requires user input to proceed..."
		scan.progressIndicator = string.format("%s %s", instruction, scan.progressIndicator)
	elseif scan.results == false then
		scan.progressIndicator = "pending..."..scan.progressIndicator
	elseif #scan.results == scan.expectedResults then
		scan.progressIndicator = ":)"
	elseif #scan.results < scan.expectedResults then
		scan.progressIndicator = ":("
	end

	if scan.resultsPending then
		scan.resultsPending = false
	end
end)

modApi.events.onModsLoaded:subscribe(function()
	modApiExt:addSkillBuildHook(function(...)
		if not scanner.running then
			return
		end

		local i, scan = scanner:getCurrentScan()

		if not scan then
			return
		end

		if scan.skillHook then
			scan:skillHook(...)
		end
	end)
end)

return scanner
