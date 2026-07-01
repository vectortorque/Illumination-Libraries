const UIUtils = {}

function UIUtils.syncTextLabelWithAttribute(textLabel: TextLabel,
	container: Instance, attributeName: string, formattingFunction: (s: string) -> string)
	
	container:GetAttributeChangedSignal(attributeName):Connect(function()
		textLabel.Text = formattingFunction(tostring(container:GetAttribute(attributeName)))
	end)
	
	const val = container:GetAttribute(attributeName)
	if val then
		textLabel.Text = formattingFunction(tostring(val))
	end
end

return UIUtils
