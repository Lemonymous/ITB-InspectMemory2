local DecoFrameEx = Class.inherit(DecoFrame)
function DecoFrameEx:new(...)
	DecoFrame.new(self, ...)
	self.disabledbordercolor = deco.colors.buttonborderdisabled
end

function DecoFrameEx:draw(screen, widget)
	local bordercolor = self.bordercolor
	if widget.disabled then
		self.bordercolor = self.disabledbordercolor
	end
	DecoFrame.draw(self, screen, widget)
	self.bordercolor = bordercolor
end

return DecoFrameEx
