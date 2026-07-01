const SchoolRegistry = {}

local lastSchoolName: string

const schools = {}
SchoolRegistry._schools = schools

const function startClass(className, class)
	const start = class.start
	assert(start, "Class: " .. `"{className}"` .. " does not have a :start")

	start(class)
end

const function stopClass(className, class)
	const stop = class.Stop
	if not stop then return end

	stop(class)
end

function SchoolRegistry.switchTo(schoolName: string)
	local classes = schools[schoolName]
	while not classes do
		print("Waiting for school: " .. schoolName)
		task.wait(0.1)
		classes = schools[schoolName]
	end

	if lastSchoolName then
		for className, class in schools[lastSchoolName] do
			stopClass(className, class)
		end
	end

	if classes._lazy then
		classes._lazy = nil

		const newClasses = {}
		for className, classScript in classes do
			const class = require(classScript)
			newClasses[className] = class
		end

		for className, class in newClasses do
			classes[className] = class
		end
	end

	for className, class in classes do
		startClass(className, class)
	end

	lastSchoolName = schoolName
end

return SchoolRegistry
