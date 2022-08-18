
UiTextBox = UiTextBox or Ui
DecoTextBox = DecoTextBox or UiDeco

local mod = mod_loader.mods[modApi.currentMod]
local scanner = require(mod.scriptPath .."scanner")
local scans = require(mod.scriptPath .."scans")
local DecoInvertedLabel = require(mod.scriptPath .."ui/decoInvertedLabel")
local DecoCenteredText = require(mod.scriptPath .."ui/decoCenteredText")
local DecoDrawCheckbox = require(mod.scriptPath .."ui/decoDrawCheckbox")
local DecoButton = require(mod.scriptPath .."ui/decoButton")
local DecoFrame = require(mod.scriptPath .."ui/decoFrame")
local SURFACE = require(mod.scriptPath .."ui/surfaces")

local COLOR_SCANNER_OK = sdl.rgb(64, 196, 64)
local COLOR_SCANNER_RUNNING = sdl.rgb(192, 192, 64)
local COLOR_SCANNER_HALTED = sdl.rgb(192, 32, 32)
local MAIN_BUTTON_WIDTH = 210
local MAIN_BUTTON_HEIGHT = 60
local MAIN_BUTTON_OFFSET = 329
local MAIN_BUTTON_GAP = 7

local BUTTON = {
	RUN = { WIDTH = 80 },
	ITER = { WIDTH = 110 },
	BREAK = { WIDTH = 80 },
	PRINT = { WIDTH = 80 },
	FILE = { WIDTH = 110 },
}

local BUTTON_HEIGHT = 41
local BUTTON_GAP = 7

local ADDR_ENTRY_WIDTH = 400
local ADDR_WIDTH = 80
local ADDR_HEIGHT = 41

local LeftArea
local RightArea
local BottomArea
local backgroundpane
local mainFrame
local frameReleaseSnap
local frameSnapLeft
local frameSnapRight

local data = {
	pawn = {
		{ name = "Size" },
		{ name = "Weapon List" },
		{ name = "Queued Target X" },
		{ name = "Queued Target Y" },
		{ name = "Team" },
		{ name = "Default Team" },
		{ name = "Repair Skill" },
		{ name = "Health" },
		{ name = "Max Health" },
		{ name = "Mark Health Loss" },
		{ name = "Fire" },
		{ name = "Frozen" },
		{ name = "Acid" },
		{ name = "Shield" },
		{ name = "Pushable" },
		{ name = "Neutral" },
		{ name = "Base Max Health" },
		{ name = "Move Speed" },
		{ name = "Player Controlled" },
		{ name = "Massive" },
		{ name = "Move Spent" },
		{ name = "Id" },
		{ name = "Image Offset" },
		{ name = "Class" },
		{ name = "Mech" },
		{ name = "Undo X" },
		{ name = "Undo Y" },
		{ name = "Corpse" },
		{ name = "Sound Base" },
		{ name = "Impact Material" },
		{ name = "Space Color" },
		{ name = "Default Faction" },
		{ name = "Minor" },
		{ name = "Flying" },
		{ name = "Teleporter" },
		{ name = "Leader" },
		{ name = "Jumper" },
		{ name = "Owner" },
		{ name = "Active" },
		{ name = "Custom Anim" },
		{ name = "Invisible" },
		{ name = "Mission Critical" },
		{ name = "Mutation" },
		{ name = "Powered" },
	},
	board = {
		{ name = "Size" },
		{ name = "Gameboard" },
		{ name = "Highlighted X" },
		{ name = "Highlighted Y" },
	},
	tile = {
		{ name = "Size" },
		{ name = "Terrain" },
		{ name = "Rubble Type" },
		{ name = "Health" },
		{ name = "Max Health" },
		{ name = "Lost Health" },
		{ name = "Terrain Icon" },
		{ name = "Highlighted" },
		{ name = "Unique Building" },
		{ name = "Unique Building Object" },
		{ name = "Unique Building Name" },
		{ name = "Frozen" },
		{ name = "Shield" },
		{ name = "Fire Type" },
		{ name = "Acid" },
		{ name = "Item Name" },
		--{ name = "Item Active" },
		{ name = "Smoke" },
		{ name = "Grid Loss" },
	}
}

for category, list in pairs(data) do
	for _, data in ipairs(list) do
		data.addr_expected = EXPECTED_ADDRESSES[category:upper()][data.name:upper()] or 0x0
		data.addr = "?"
	end
end

local function UiSeparator(orientation, size)
	size = size or 2

	local separator = Ui()
		:decorate{ DecoSolid(deco.colors.buttonborder) }

	if orientation == "vertical" then
		separator:widthpx(2):height(1)
	elseif orientation == "horizontal" then
		separator:width(1):heightpx(2)
	else
		error('orientation expected: "horizontal" or "vertical"')
	end

	return separator
end

local function UiAddressHeader()
	local header = UiWeightLayout()
	header.padr = UiScrollArea().scrollwidth

	Ui():width(1):height(1)
		:decorate{ DecoCenteredText("Name") }
		:addTo(header)

	UiSeparator("vertical")
		:addTo(header)

	Ui():widthpx(ADDR_WIDTH):height(1)
		:decorate{ DecoCenteredText("Expected") }
		:addTo(header)

	UiSeparator("vertical")
		:addTo(header)

	Ui():widthpx(ADDR_WIDTH):height(1)
		:decorate{ DecoCenteredText("Addr") }
		:addTo(header)

	return header
end

local function onEnterNewLine(self)
	self:addText("\n")
end

local function onEnterUnfocus(self)
	if self.focused then
		self.root:setfocus(nil)
	end
end

local function unqueueAddress(self)
	scanner:rem(self.Data.scan)
	self:detach()
	return true
end

local function queueAddress(self)
	local text = "N/A"
	local data = self.Data

	if data.name then
		text = data.name .." >"
	end

	local deco_text = DecoText(text)
	local ui = Ui()
		:widthpx(deco_text.surface:w()):heightpx(40)
		:decorate{
			DecoSolidHoverable(deco.colors.transparent, deco.colors.button),
			deco_text
		}

	ui.deco_text = deco_text
	ui.onclicked = unqueueAddress
	ui.Data = data
	ui:addTo(LeftArea.Header)

	scanner:add(data.scan, unqueueAddress)

	return true
end

local function checkAddress(self)
	self.CheckBox.checked = not self.CheckBox.checked
	return true
end

local function onToggledScan(checked)
	if self.Data.scan then
		self.Data.scan.toggled = checked
	else
		self.checked = false
	end
end

local function onToggleScanGroup(self, checked)
	local checkboxes = self.parent.CheckBoxes
	for _, checkbox in ipairs(checkboxes) do
		checkbox.checked = checked
		checkbox.onToggled:fire(checkbox, checked)
	end
end

local function saveResult(scan)
	local msg = ""
	for i, addr in ipairs(scan.results) do
		local suffix = ""
		if i == scan.expectedResultIndex then
			suffix = " <---"
		end
		msg = string.format("%s<0x%X>%s\n", msg, addr, suffix)
	end
	return msg
end

local function updateAddr(self)
	local data = self.Data

	if data.scan then
		local results = data.scan.results
		local expectedResults = data.scan.expectedResults
		local expectedResultIndex = data.scan.expectedResultIndex

		if results == false then
			self.DecoFrame.bordercolor = deco.colors.buttonborder
			self.DecoText:setsurface("?")
			self.tooltip = "Not yet scanned"
		elseif #results == expectedResults then
			table.sort(results, function(a,b) return a < b end)
			self.DecoText:setsurface(string.format("0x%X", results[expectedResultIndex]))
			if results[expectedResultIndex] == data.addr_expected then
				self.DecoFrame.bordercolor = TestConsole.colors.border_ok
				self.tooltip = "Scan result matches expected address\n"..saveResult(data.scan)
			else
				self.DecoFrame.bordercolor = TestConsole.colors.border_fail
				self.tooltip = "Scan result does not match expected address\n"..saveResult(data.scan)
			end
		elseif #results < expectedResults then
			self.DecoFrame.bordercolor = TestConsole.colors.border_fail
			self.DecoText:setsurface(":(")
			self.tooltip = "Scan failed\n"..saveResult(data.scan)
		elseif #results > expectedResults then
			self.DecoText:setsurface("[#"..#results.."]")
			if list_contains(results, data.addr_expected) then
				self.DecoFrame.bordercolor = TestConsole.colors.border_running
				self.tooltip = "Scan in progress - possible candidates:"
			else
				self.DecoFrame.bordercolor = TestConsole.colors.border_fail
				self.tooltip = "Scan expected to fail - no candidates match the expected address:"
			end

			for i = 1, math.min(10, #results) do
				self.tooltip = self.tooltip ..
				string.format("\n<0x%X>", results[i])
			end
			if #results > 10 then
				self.tooltip = self.tooltip.."\n..."
			end
		end
	end

	Ui.relayout(self)
end

local function resetScan(self)
	if self.Data.scan then
		self.Data.scan.results = false
	end
	return true
end

local function buildAddressButtons(category, content)
	local data = data[category]

	local buttons = UiBoxLayout()
		:width(1)
		:vgap(2)
		:addTo(content)

	local label = UiCheckbox()
		:width(1):heightpx(ADDR_HEIGHT)
		:decorate{
			DecoButton(),
			DecoDrawCheckbox(),
			DecoAlignedText(category, nil, nil, "center", "center")
		}
		:addTo(buttons)
	label.CheckBoxes = {}
	label.checked = true

	local function onToggledScan(self, button)
		if button ~= 1 then
			return true
		end

		if self.disabled then
			self.checked = false
			return true
		end

		self.Data.scan.toggled = self.checked

		if self.checked then
			if not label.checked then
				label.checked = true
			end
		else
			if label.checked then
				for _, checkbox in ipairs(label.CheckBoxes) do
					if checkbox.checked then
						return true
					end
				end
				label.checked = false
			end
		end

		return true
	end

	label.onclicked = function(self, button)
		if button ~= 1 then
			return true
		end

		for _, checkbox in ipairs(self.CheckBoxes) do
			checkbox.checked = self.checked
			checkbox:onclicked(button)
		end

		return true
	end

	for i, data in ipairs(data) do
		data.scan = scans:get(category, data.name)

		if data.scan then
			data.scan.category = category
			data.scan.name = data.name
			data.scan.expected = data.addr_expected
			data.scan.toggled = true
			scanner:add(data.scan)
		end

		local container = UiWeightLayout()
			:width(1):heightpx(ADDR_HEIGHT)
			:hgap(2)
			:addTo(buttons)
		container.Data = data

		local disabled = not data.scan or data.scan.disabled
		local checkbox = UiCheckbox()
			:width(1):height(1)
			:clip()
			:decorate{
				DecoButton(),
				DecoDrawCheckbox(),
				DecoAlign(4, 2),
				DecoText(data.name)
			}
			:addTo(container)
		checkbox.disabled = disabled
		checkbox.Data = data
		checkbox.checked = not disabled
		checkbox.onclicked = onToggledScan
		table.insert(label.CheckBoxes, checkbox)

		local expectedAddr = Ui()
			:widthpx(ADDR_WIDTH):height(1)
			:clip()
			:decorate{
				DecoFrame(),
				DecoAlignedText(string.format("0x%X", data.addr_expected or 0), nil, nil, "center", "center")
			}
			:addTo(container)
		expectedAddr.disabled = disabled

		local decoFrame = DecoFrame()
		local decoText = DecoAlignedText(data.addr, nil, nil, "center", "center")
		local foundAddr = Ui()
			:widthpx(ADDR_WIDTH):height(1)
			:clip()
			:decorate{ decoFrame, decoText }
			:addTo(container)
		foundAddr.disabled = disabled
		foundAddr.DecoFrame = decoFrame
		foundAddr.DecoText = decoText
		foundAddr.Data = data
		foundAddr.relayout = updateAddr
		foundAddr.onclicked = resetScan
	end

	return buttons
end

local function cleanup()
	scanner:clear()
end

local function buildContent(scroll)
	-- ALL AREA --
	local owner = scroll.parent
	local container = Ui()
		:width(1):height(1)

	local content = UiWeightLayout()
		:width(1):height(1)
		:vgap(0):hgap(0)
		:addTo(container)

	-- LEFT AREA --
	LeftArea = Ui()
		:width(1):height(1)
		:addTo(content)

	local scrollContent = UiScrollArea()
		:width(1):height(1)
		:padding(10)
		:addTo(LeftArea)

	LeftArea.Content = UiTextBox()
		:width(1):height(1)
		:decorate{
			DecoTextBox{
				font = deco.fonts.justin12,
				textset = deco.textset(deco.colors.buttonborder, nil, nil),
				alignH = "left",
				alignV = "top"
			}
		}
		:addTo(scrollContent)

	function LeftArea.Content:relayout()
		-- TODO: temporary returning from this method to avoid crash when textbox is not implemented
		if true then return end
		
		if scanner.running then
			self:setCaret(0)
			self:delete(self.textfield:size())
			local _, scan = scanner:getCurrentScan()
			if scan then
				local results = scan.results or {}
				self:addText(
					string.format("%s [#%s] %s\n", scan.name,
					tostring(#results), scan.progressIndicator)
				)
				for i = 1, math.min(10, #results) do
					local addr = results[i]
					self:addText(string.format("<0x%X>\n", addr))
				end
				if #results > 10 then
					self:addText("...\n")
				end
			end
		end
		UiTextBox.relayout(self)
	end

	local line = UiSeparator("vertical")
		:addTo(content)

	-- RIGHT AREA --
	RightArea = UiWeightLayout()
		:widthpx(ADDR_ENTRY_WIDTH):height(1)
		:orientation(false)
		:vgap(0)
		:padding(10)
		:addTo(content)

	RightArea.Header = UiAddressHeader()
		:width(1):heightpx(ADDR_HEIGHT)
		:hgap(0)
		:addTo(RightArea)

	local line = UiSeparator("horizontal")
		:addTo(RightArea)

	RightArea.Scroll = UiScrollArea()
		:width(1):height(1)
		:addTo(RightArea)
	RightArea.Scroll.padt = RightArea.Scroll.padt + 2

	RightArea.Content = UiBoxLayout()
		:width(1)
		:vgap(2)
		:addTo(RightArea.Scroll)

	scanner:clear()
	local pawnButtons = buildAddressButtons("pawn", RightArea.Content)
	local boardButtons = buildAddressButtons("board", RightArea.Content)
	local tileButtons = buildAddressButtons("tile", RightArea.Content)

	return container
end

local function buildButtons(buttonLayout)
	buttonLayout
		:width(1):hgap(0)

	local btnContainer = UiWeightLayout()
		:width(1):height(1)
		:addTo(buttonLayout)

	local arrowLeft = Ui()
		:widthpx(22):heightpx(42)
		:decorate{
			DecoSurfaceButton(
				SURFACE.ARROW.LEFT.ON,
				SURFACE.ARROW.LEFT.HL,
				SURFACE.ARROW.LEFT.OFF
			)
		}
		:addTo(btnContainer)

	local centerContainer = UiWeightLayout()
		:width(1):height(1)
		:addTo(btnContainer)

	local arrowRight = Ui()
		:widthpx(22):heightpx(42)
		:decorate{
			DecoSurfaceButton(
				SURFACE.ARROW.RIGHT.ON,
				SURFACE.ARROW.RIGHT.HL,
				SURFACE.ARROW.RIGHT.OFF
			)
		}
		:addTo(btnContainer)

	local decoButton = DecoButton()

	function decoButton:draw(screen, widget)
		if scanner.running then
			self.bordercolor = COLOR_SCANNER_RUNNING
		else
			self.bordercolor = COLOR_SCANNER_HALTED
		end

		DecoButton.draw(self, screen, widget)
	end

	local btnRun = Ui()
		:width(1):heightpx(BUTTON_HEIGHT)
		:settooltip("Run scan")
		:decorate{
			decoButton,
			DecoAnchor(),
			DecoCenteredText("Run"),
		}
		:addTo(centerContainer)
	btnRun.onclicked = function(self)
		scanner:start()
		return true
	end

	local btnIter = UiTextBox(scanner.timeout)
		:width(1):heightpx(BUTTON_HEIGHT)
		--:setAlphabet("1234567890")
		:settooltip("Progress to next scan after # iterations")
		:clip()
		:decorate{
			DecoTextBox{
				prefix = "#",
				alignH = "center",
				alignV = "center"
			},
			DecoBorder(),
			DecoInvertedLabel("#"),
		}
		:addTo(centerContainer)
	btnIter.onEnter = function(self)
		self.root:setfocus(nil)
		scanner:setTimeout(tonumber(self.textfield:get(1,self.textfield:size())))
	end

	local btnBreak = Ui()
		:width(1):heightpx(BUTTON_HEIGHT)
		:settooltip("Stop scanning")
		:setxpx(BUTTON.RUN.WIDTH + BUTTON_GAP)
		:decorate{
			DecoButton(),
			DecoAnchor(),
			DecoCenteredText("Break"),
		}
		:addTo(centerContainer)
	btnBreak.onclicked = function(self)
		scanner:stop()
		return true
	end

	local btnPrint = Ui()
		:width(1):heightpx(BUTTON_HEIGHT)
		:settooltip("Print out results to console")
		:decorate{
			DecoButton(),
			DecoAnchor(),
			DecoCenteredText("Print"),
		}
		:addTo(centerContainer)
	btnPrint.onclicked = function(self)
		scanner:print()
		return true
	end

	function arrowLeft:onclicked(button)
		if button ~= 1 then
			return
		end

		if mainFrame.snap == "left" then
		elseif mainFrame.snap == "right" then
			frameReleaseSnap()
		else
			frameSnapLeft()
		end

		return true
	end

	function arrowRight:onclicked(button)
		if button ~= 1 then
			return
		end

		if mainFrame.snap == "left" then
			frameReleaseSnap()
		elseif mainFrame.snap == "right" then
		else
			frameSnapRight()
		end

		return true
	end
end

local function showWindow()
	Assert.False(Board == nil)

	if backgroundpane then
		frameReleaseSnap()
		return
	end

	sdlext.showDialog(function(ui, quit)
		ui.onDialogExit = function()
			cleanup()
			backgroundpane = nil
		end

		local snapSideWidth = 400
		local morphspeed = 0.7
		backgroundpane = ui
		backgroundpane.wheel = Ui.wheel
		backgroundpane.mousedown = Ui.mousedown
		backgroundpane.mouseup = Ui.mouseup
		backgroundpane.mousemove = Ui.mousemove
		backgroundpane.keydown = Ui.keydown
		backgroundpane.keyup = Ui.keyup

		local frame = sdlext.buildButtonDialog(
			"Address Scan",
			buildContent,
			buildButtons,
			{
				maxW = 0.6 * ScreenSizeX(),
				maxH = 0.95 * ScreenSizeY(),
				compactH = false
			}
		)

		mainFrame = frame
		frame:addTo(ui)

		function frame:relayout()
			UiWeightLayout.relayout(self)
			self.h = math.floor(0.95 * ScreenSizeY())
			self.y = math.floor((ScreenSizeY() - self.h) / 2)
			if self.snap == "left" then
				self.targetw = self.targetw or math.floor(0.6 * ScreenSizeX())
				self.targetx = 0
			elseif self.snap == "right" then
				self.targetw = self.targetw or math.floor(0.6 * ScreenSizeX())
				self.targetx = ScreenSizeX() - self.targetw
			else
				self.targetw = math.floor(0.6 * ScreenSizeX())
				self.targetx = math.floor((ScreenSizeX() - self.targetw) / 2)
			end
			if math.abs(self.targetx - self.x) > 1 then
				self.x = self.targetx * (1 - morphspeed)  + self.x * morphspeed
			else
				self.x = self.targetx
			end
			if math.abs(self.targetw - self.w) > 1 then
				self.w = self.targetw * (1 - morphspeed)  + self.w * morphspeed
			else
				self.w = self.targetw
			end
		end

		function frameReleaseSnap()
			frame.snap = nil
			backgroundpane.decorations[1].color = deco.colors.dialogbg
			backgroundpane.dismissible = true
			backgroundpane.translucent = false
		end

		function frameSnapLeft()
			frame.snap = "left"
			frame.targetw = snapSideWidth
			backgroundpane.decorations[1].color = deco.colors.transparent
			backgroundpane.dismissible = false
			backgroundpane.translucent = true
		end

		function frameSnapRight()
			frameSnapLeft()
			frame.snap = "right"
		end
	end)
end

local function calculateOpenButtonPosition()
	-- Use the Buttons element maintained by the game itself.
	-- This way we don't have to worry about calculating locations
	-- for our UI, we can just offset based on the game's own UI
	-- whenever the screen is resized.
	local btnEndTurn = Buttons["action_end"]
	return btnEndTurn.pos.x + MAIN_BUTTON_OFFSET + MAIN_BUTTON_WIDTH + MAIN_BUTTON_GAP, btnEndTurn.pos.y
end

local function createOpenButton(root)

	local button = sdlext.buildButton(
		"Find Addresses",
		"Scan for memory addresses in Pawn, Board and Tile", 
		function()
			showWindow()
		end
	)
	:widthpx(MAIN_BUTTON_WIDTH):heightpx(MAIN_BUTTON_HEIGHT)
	:pospx(calculateOpenButtonPosition())
	:addTo(root)

	button.deco_text = button.decorations[3]

	function button:draw(screen)
		self.visible = not sdlext.isConsoleOpen() and modApi.developmentMode and Board ~= nil

		Ui.draw(self, screen)
	end

	modApi.events.onSettingsChanged:subscribe(function()
		button:pospx(calculateOpenButtonPosition())
	end)

	modApi.events.onGameWindowResized:subscribe(function()
		button:pospx(calculateOpenButtonPosition())
	end)
end

modApi.events.onUiRootCreated:subscribe(function(screen, root)
	createOpenButton(root)
end)
