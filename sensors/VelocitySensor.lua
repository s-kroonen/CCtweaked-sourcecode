-- sensors/VelocitySensor.lua
-- Wraps one or more velocity_sensor peripherals and reconstructs
-- the full body-frame velocity vector {vx, vy, vz}.

local VelocitySensor = {}
VelocitySensor.__index = VelocitySensor

function VelocitySensor.new(peripheralIds)
    local sensors = {}
    for _, id in ipairs(peripheralIds) do
        local p = peripheral.wrap(id)
        if p then
            sensors[#sensors + 1] = p
        else
            print("VelocitySensor: warning — peripheral not found: " .. tostring(id))
        end
    end
    return setmetatable({ _sensors = sensors }, VelocitySensor)
end

-- Updates state.sensors.vx/vy/vz.
function VelocitySensor:read(sensors)
    sensors.vx = 0
    sensors.vy = 0
    sensors.vz = 0
    for _, p in ipairs(self._sensors) do
        local axis = p.getAxis()
        local v    = p.getVelocity()
        if axis == "x" then sensors.vx = v
        elseif axis == "y" then sensors.vy = v
        elseif axis == "z" then sensors.vz = v
        end
    end
end

return VelocitySensor
