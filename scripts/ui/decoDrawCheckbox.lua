local DecoDrawCheckbox = Class.inherit(UiDeco)
function DecoDrawCheckbox:new(color, hlcolor, disabledcolor)
	self.color = color or deco.colors.white
	self.hlcolor = hlcolor or deco.colors.buttonborderhl
	self.disabledcolor = disabledcolor or deco.colors.buttonborderdisabled
	self.rect = sdl.rect(0,0,0,0)
end

function DecoDrawCheckbox:draw(screen, widget)
	local r = self.rect
	local color = self.color
	local borderwidth = self.borderwidth or 2

	r.x = widget.rect.x
	r.y = widget.rect.y
	r.w = 25
	r.h = 25

	r.x = r.x + widget.decorationx
	r.y = r.y + math.floor(widget.decorationy + widget.rect.h / 2 - r.h / 2)

	if widget.disabled then
		color = self.disabledcolor
	elseif widget.hovered then
		color = self.hlcolor
	end

	drawborder(screen, color, r, borderwidth)
	widget.decorationx = widget.decorationx + r.w

	if widget.checked then
		r.x = r.x + 4
		r.y = r.y + 4
		r.w = r.w - 8
		r.h = r.h - 8

		screen:drawrect(color, r)
	end
end

return DecoDrawCheckbox
