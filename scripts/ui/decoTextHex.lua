
local function toHex(text)
	if type(text) == 'number' then
		text = string.format("0x%X", text)
	end

	return text
end

local DecoTextHex = Class.inherit(DecoAlignedText)
function DecoTextHex:new(text, font, textset, alignH, alignV)
	DecoAlignedText.new(self, toHex(text), font, textset, alignH, alignV)
end

function DecoTextHex:setsurface(text)
	DecoText:setsurface(toHex(text))
end
