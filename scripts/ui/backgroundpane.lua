local backgroundpane = {
	wheel = function(self, mx, my, y)
		Ui.wheel(self, mx, my, y)
		return not self.translucent
	end,
	mousedown = function(self, mx, my, button)
		Ui.mousedown(self, mx, my, button)
		return not self.translucent
	end,
	mouseup = function(self, mx, my, button)
		Ui.mouseup(self, mx, my, button)
		return not self.translucent
	end,
	mousemove = function(self, mx, my)
		Ui.mousemove(self, mx, my)
		return not self.translucent
	end,
	keydown = function(self, keycode)
		if not self.translucent and self.dismissible and keycode == SDLKeycodes.ESCAPE then
			popDialog()
		end
		return not self.translucent
	end,
	keyup = function(self, keycode)
		return not self.translucent
	end
}

return backgroundpane
