local DecoCenteredText = Class.inherit(DecoAlignedText)
function DecoCenteredText:new(text, font, textset)
	DecoAlignedText.new(self, text, font, textset, "center", "center")
end

return DecoCenteredText
