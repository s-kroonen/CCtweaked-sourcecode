-- core/PID.lua
-- Discrete PID controller with integral anti-windup.

local PID = {}
PID.__index = PID

-- gains: {kP, kI, kD, iLimit}
function PID.new(gains)
    return setmetatable({
        kP      = gains.kP,
        kI      = gains.kI,
        kD      = gains.kD,
        iLimit  = gains.iLimit or math.huge,
        _integral = 0,
        _lastError = nil,
    }, PID)
end

-- Returns output. dt in seconds.
function PID:update(error, dt)
    self._integral = math.max(-self.iLimit,
                     math.min( self.iLimit,
                     self._integral + error * dt))

    local derivative = 0
    if self._lastError ~= nil then
        derivative = (error - self._lastError) / dt
    end
    self._lastError = error

    return self.kP * error
         + self.kI * self._integral
         + self.kD * derivative
end

function PID:reset()
    self._integral = 0
    self._lastError = nil
end

return PID
