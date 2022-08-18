
local filePath = ...
local folderPath = GetParentPath(filePath)
local cutilsPath = folderPath.."cutils.dll"
local successMsg = "cutils.dll successfully loaded"
local failMsg = "Something went wrong when loading"
local NAME = "cutils_inspect"

local options = {
	name = "cutils_inspect",
	debug = true,
	verbose = true,
	hex = true,
	set = true,
	get = true,
}


local function init(options)
	options = options or {}
	options.name = options.name or NAME

	local func = package.loadlib(cutilsPath, "luaopen_inspect")
	local ok, err = pcall(func, options)

	if not ok then
		error(string.format("%s %s - %s", failMsg, cutilsPath, err))
	else
		LOGDF("%s into global table _G[\"%s\"]", successMsg, options.name)
	end
end

modApi.events.onModsInitialized:subscribe(function()
	init(options)
end)

return {
	get = function()
		return _G["cutils_inspect"]
	end
}
