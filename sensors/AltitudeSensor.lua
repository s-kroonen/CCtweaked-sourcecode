-- sensors/AltitudeSensor.lua

local AltitudeSensor = {}
AltitudeSensor.__index = AltitudeSensor

function AltitudeSensor.new(peripheralId)
    local p = peripheral.wrap(peripheralId)
    assert(p, "AltitudeSensor: peripheral not found: " .. tostring(peripheralId))
    return setmetatable({ _p = p }, AltitudeSensor)
end

-- Updates state.sensors with altitude and verticalSpeed.
function AltitudeSensor:read(sensors)
    sensors.altitude      = self._p.getAltitude()
    sensors.verticalSpeed = self._p.getVerticalSpeed()
end

return AltitudeSensor
