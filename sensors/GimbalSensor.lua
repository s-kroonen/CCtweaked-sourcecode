-- sensors/GimbalSensor.lua

local GimbalSensor = {}
GimbalSensor.__index = GimbalSensor

function GimbalSensor.new(peripheralId)
    local p = peripheral.wrap(peripheralId)
    assert(p, "GimbalSensor: peripheral not found: " .. tostring(peripheralId))
    return setmetatable({ _p = p }, GimbalSensor)
end

-- Updates state.sensors with pitch, roll, and angular rates.
function GimbalSensor:read(sensors)
    local angles = self._p.getAngles()
    sensors.pitch = angles[1]
    sensors.roll  = angles[2]

    local rates = self._p.getAngularRates()
    sensors.pitchRate = rates[1]   -- wx: rotation about body-X
    sensors.yawRate   = rates[2]   -- wy: rotation about body-Y
    sensors.rollRate  = rates[3]   -- wz: rotation about body-Z
end

return GimbalSensor
