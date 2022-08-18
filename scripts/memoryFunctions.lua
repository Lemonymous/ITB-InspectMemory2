
local path = GetParentPath(...)
local cutils_init = require(path.."cutils")
local cutils

local this = {}

modApi.events.onModsInitialized:subscribe(function()
	cutils = cutils_init:get()
end)

function this.getObjAddr(obj)
	Assert.Equals('userdata', type(obj))
	return cutils.Debug.GetObjAddr(obj)
end

function this.isAddrNotPtr(addr, size)
	Assert.Equals('number', type(addr))
	Assert.Equals('number', type(size))
	return cutils.Debug.IsAddrNotPointer(addr, size)
end

function this.getAddrValue(addr)
	Assert.Equals('number', type(addr))
	return cutils.Debug.GetAddrValue(addr)
end

function this.getAddrInt(addr)
	Assert.Equals('number', type(addr))
	return cutils.Debug.GetAddrInt(addr)
end

function this.getAddrString(addr)
	Assert.Equals('number', type(addr))
	-- getAddrValue is safer than getAddrString,
	-- and will return a string if possible
	return cutils.Debug.GetAddrValue(addr)
end

function this.getAddrBool(addr)
	Assert.Equals('number', type(addr))
	return cutils.Debug.GetAddrBool(addr)
end

function this.getAddrByte(addr)
	Assert.Equals('number', type(addr))
	return cutils.Debug.GetAddrByte(addr)
end

return this
