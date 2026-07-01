export type Maid = {
	Add: (self: Maid) -> (),
	Destroy: (self: Maid) -> ()
}

const Maid = {}
Maid.__index = Maid

function Maid.new(): Maid
	const self = setmetatable({}, Maid) :: Maid
	self.connections = {}
	
	return self
end

function Maid:Add(item: RBXScriptConnection)
	table.insert(self.connections, item)
end

function Maid:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	
	table.clear(self.connections)
end

return Maid
