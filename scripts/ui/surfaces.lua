local SURFACE = {ARROW = {LEFT={}, RIGHT={}}}
local BUTTON = {MAIN = {}}
SURFACE.ARROW.LEFT.ON   = sdlext.getSurface{ path = "img/ui/upgrade/arrow2_on.png" }
SURFACE.ARROW.LEFT.HL   = sdlext.getSurface{ path = "img/ui/upgrade/arrow2_select.png" }
SURFACE.ARROW.LEFT.OFF  = sdlext.getSurface{ path = "img/ui/upgrade/arrow2_off.png" }
SURFACE.ARROW.RIGHT.ON  = sdlext.getSurface{ path = "img/ui/upgrade/arrow_on.png" }
SURFACE.ARROW.RIGHT.HL  = sdlext.getSurface{ path = "img/ui/upgrade/arrow_select.png" }
SURFACE.ARROW.RIGHT.OFF = sdlext.getSurface{ path = "img/ui/upgrade/arrow_off.png" }

return SURFACE
