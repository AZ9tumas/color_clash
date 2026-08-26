local RunService = game:GetService("RunService")

local Spring = {}
Spring.__index = Spring

function Spring.new(initialPosition)
	local self = setmetatable({
		Position = initialPosition or Vector3.new();
		Velocity = Vector3.new();
		Target = initialPosition or Vector3.new();

		Speed = 250;
		Damper = 20;

		_connection = nil;
	}, Spring)

	self:_start()
	return self
end

function Spring:_update(dt)
	local stiffness = self.Speed
	local damping = self.Damper

	local force = (self.Target - self.Position) * stiffness
	local dampingForce = -self.Velocity * damping

	self.Velocity = self.Velocity + (force + dampingForce) * dt
	self.Position = self.Position + self.Velocity * dt
end

function Spring:_start()
	if self._connection then return end
	self._connection = RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end)
end

function Spring:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return Spring
