--!strict

export type IDAllocator = {
	_next: number,
	_free: {number},
	_limit: number,
	_inUse: {[number]: true},

	new: (limit: number) -> IDAllocator,
	Allocate: (self: IDAllocator) -> number?,
	Release: (self: IDAllocator, id: number) -> (),
	__index: IDAllocator,
}

const IDAllocator = {} :: IDAllocator
IDAllocator.__index = IDAllocator

function IDAllocator.new(limit)
	const self = setmetatable({}, IDAllocator) :: IDAllocator
	self._next = 1
	self._free = {}
	self._limit = limit
	self._inUse = {}
	return self
end

function IDAllocator:Allocate()
	local id = table.remove(self._free)
	if not id then
		if self._next > self._limit then
			return nil
		end
		id = self._next
		self._next += 1
	end
	self._inUse[id] = true
	return id
end

function IDAllocator:Release(id)
	if not self._inUse[id] then return end
	self._inUse[id] = nil
	table.insert(self._free, id)
end

return IDAllocator
