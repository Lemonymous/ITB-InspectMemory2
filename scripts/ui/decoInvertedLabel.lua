local DecoInvertedLabel = Class.inherit(DecoLabel)
function DecoInvertedLabel:new(text, opt)
	DecoLabel.new(self, text, {
		textset = deco.uifont.default.set,
		fillcolor = deco.colors.framebg,
		bordercolor = deco.colors.buttonborder,
		right = true,
		bottom = true
	})

	if type(opt) == 'table' then
		for key, option in pairs(opt) do
			ui[key] = option
		end
	end
end

return DecoInvertedLabel
