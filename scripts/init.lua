
local mod = {
	id = "lmn-cutils-memory-scanner",
	name = "Cutils Memory Scanner",
	version = "0.0.1",
	icon = "scripts/icon.png",
	enabled = false,
	requirements = {}
}

local scripts = {
	"cutils",
	"expectedAddresses",
	"scanner",
	"uiInspectObject",
	"uiFindAddress",
}

function mod:init()
	require(self.scriptPath.."modApiExt/modApiExt"):init()

	for i, script in ipairs(scripts) do
		require(self.scriptPath..script)
	end
end

function mod:load(options, version)
	require(self.scriptPath.."modApiExt/modApiExt"):load(options, version)
end

return mod
