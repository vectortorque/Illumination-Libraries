-- -----------------------------------------------------------------------------
--               Batched Yield-Safe Signal Implementation                     --
-- This is a Signal class which has effectively identical behavior to a       --
-- normal RBXScriptSignal, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the signal handlers comes at minimal extra cost over a naive signal        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--   sleitnick - August 3rd, 2021 - Modified for Knit.                        --
--   liquidpane - June 18th, 2026 - Debloated				      --
-- -----------------------------------------------------------------------------

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	FireDeferred: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	DisconnectAll: (self: Signal<T...>) -> (),
	GetConnections: (self: Signal<T...>) -> { Connection },
	Destroy: (self: Signal<T...>) -> (),
	Wait: (self: Signal<T...>) -> T...,
}

local freeRunnerThread = nil

local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)

	freeRunnerThread = acquiredRunnerThread
end

local function runEventHandlerInFreeThread(...)
	acquireRunnerThreadAndCallEventHandler(...)
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false

	if self._signal._handlerListHead == self then
		self._signal._handlerListHead = self._next
	else
		local prev = self._signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end

Connection.Destroy = Connection.Disconnect

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		_handlerListHead = false,
		_proxyHandler = nil,
		_yieldedThreads = nil,
	}, Signal)

	return self
end

function Signal:Connect(fn)
	local connection = setmetatable({
		Connected = true,
		_signal = self,
		_fn = fn,
		_next = false,
	}, Connection)

	if self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end

	return connection
end

function Signal:Once(fn)
	local connection
	local done = false

	connection = self:Connect(function(...)
		if done then
			return
		end

		done = true
		connection:Disconnect()
		fn(...)
	end)

	return connection
end

function Signal:GetConnections()
	local items = {}

	local item = self._handlerListHead
	while item do
		table.insert(items, item)
		item = item._next
	end

	return items
end

function Signal:DisconnectAll()
	local item = self._handlerListHead
	while item do
		item.Connected = false
		item = item._next
	end
	self._handlerListHead = false

	local yieldedThreads = self._yieldedThreads
	if yieldedThreads then
		for thread in yieldedThreads do
			if coroutine.status(thread) == "suspended" then
				warn(debug.traceback(thread, "signal disconnected; yielded thread cancelled", 2))
				task.cancel(thread)
			end
		end
		table.clear(self._yieldedThreads)
	end
end

function Signal:Fire(...)
	local item = self._handlerListHead
	while item do
		if item.Connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
			end
			task.spawn(freeRunnerThread, item._fn, ...)
		end
		item = item._next
	end
end

function Signal:FireDeferred(...)
	local item = self._handlerListHead
	while item do
		local conn = item
		task.defer(function(...)
			if conn.Connected then
				conn._fn(...)
			end
		end, ...)
		item = item._next
	end
end

function Signal:Wait()
	local yieldedThreads = self._yieldedThreads
	if not yieldedThreads then
		yieldedThreads = {}
		self._yieldedThreads = yieldedThreads
	end

	local thread = coroutine.running()
	yieldedThreads[thread] = true

	self:Once(function(...)
		yieldedThreads[thread] = nil

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, ...)
		end
	end)

	return coroutine.yield()
end

function Signal:Destroy()
	self:DisconnectAll()

	local proxyHandler = self._proxyHandler
	if proxyHandler then
		proxyHandler:Disconnect()
	end
end

return {
	new = Signal.new,
}
