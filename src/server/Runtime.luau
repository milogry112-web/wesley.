--!strict
-- Server-only integration registry. Never replicated and never callable by clients.
local ready = Instance.new("BindableEvent")
local services: any = nil
local Runtime = {}

function Runtime.Register(value: any)
	assert(services == nil, "Dungeon services already registered")
	services = value
	ready:Fire()
end

function Runtime.Get(): any
	assert(services ~= nil, "Dungeon is not ready; call Runtime.WaitReady() first")
	return services
end

function Runtime.WaitReady(): any
	if services == nil then ready.Event:Wait() end
	return services
end

return Runtime
