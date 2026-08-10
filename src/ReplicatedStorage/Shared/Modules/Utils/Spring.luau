local RunService = game:GetService("RunService")

-- Vector3 spring, ported from the reference gunsystem's SpringModule. Set Target and
-- read Position; it advances itself on Heartbeat until destroyed.
local Spring = {}
Spring.__index = Spring

function Spring.new(initialPosition)
	local self = setmetatable({
		Position = initialPosition or Vector3.zero,
		Velocity = Vector3.zero,
		Target = initialPosition or Vector3.zero,

		Speed = 250,
		Damper = 20,

		_connection = nil,
	}, Spring)

	self._connection = RunService.Heartbeat:Connect(function(dt)
		local force = (self.Target - self.Position) * self.Speed
		local dampingForce = -self.Velocity * self.Damper

		self.Velocity = self.Velocity + (force + dampingForce) * dt
		self.Position = self.Position + self.Velocity * dt
	end)

	return self
end

function Spring:Impulse(velocity)
	self.Velocity = self.Velocity + velocity
end

function Spring:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return Spring
