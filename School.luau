const SchoolRegistry = require("./SchoolRegistry")

const School = {}

School.LOAD_MODES = {
	Default = "Lazy",
	Lazy = "Lazy",
	Immediate = "Immediate",
}

function School.new(schoolContainer: Instance, loadMode: keyof<typeof(School.LOAD_MODES)>?)
	loadMode = loadMode or School.LOAD_MODES.Default

	const classes = {}
	
	const isLazy = loadMode == School.LOAD_MODES.Lazy
	if isLazy then
		classes._lazy = true
	end

	for _, classScript in schoolContainer:QueryDescendants("ModuleScript") do
		if isLazy then
			classes[classScript.Name] = classScript
		else
			classes[classScript.Name] = require(classScript)
		end
	end

	SchoolRegistry._schools[schoolContainer.Name] = classes
end

return School
