local DecoButtonEx = Class.inherit(DecoButton)
function DecoButtonEx:new(...)
	DecoButton.new(self, ...)
	self.disabledbordercolor = deco.colors.buttonborderdisabled
end

function DecoButtonEx:draw(screen, widget)
	local bordercolor = self.bordercolor
	local borderhlcolor = self.borderhlcolor
	if widget.disabled then
		self.bordercolor = self.disabledbordercolor
		self.borderhlcolor = self.disabledbordercolor
	end
	DecoButton.draw(self, screen, widget)
	self.bordercolor = bordercolor
	self.borderhlcolor = borderhlcolor
end

return DecoButtonEx
