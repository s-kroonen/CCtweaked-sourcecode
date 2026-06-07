-- peripherals/GasProvider.lua
-- IThruster wrapper for a gas_provider balloon burner.
-- axis = "y", output range 0..1 (maps to 0..balloon capacity).

local GasProvider = {}
GasProvider.__index = GasProvider

function GasProvider.new(peripheralId)
    local p = peripheral.wrap(peripheralId)
    assert(p, "GasProvider: peripheral not found: " .. tostring(peripheralId))

    local self = setmetatable({
        _p        = p,
        _id       = peripheralId,
        _capacity = 0,
        _output   = 0,
    }, GasProvider)

    self:_refreshCapacity()
    return self
end

function GasProvider:_refreshCapacity()
    if self._p.hasBalloon() then
        self._capacity = self._p.getBalloonCapacity()
    else
        self._capacity = 0
    end
end

-- IThruster interface ─────────────────────────────────────────────────────────

function GasProvider:getAxis()
    return "y"
end

-- value: 0..1 (0 = no gas, 1 = full balloon capacity)
function GasProvider:setOutput(value)
    value = math.max(0, math.min(1, value))
    self._output = value

    if self._capacity == 0 then
        self:_refreshCapacity()
    end

    local target = math.floor(value * self._capacity)
    self._p.setTargetAmount(target)
end

function GasProvider:getOutput()
    return self._output
end

function GasProvider:isAvailable()
    return self._p.hasBalloon() and self._p.isActive()
end

-- Diagnostics ─────────────────────────────────────────────────────────────────

function GasProvider:getLift()
    return self._p.getBalloonLift()
end

function GasProvider:getFilledVolume()
    return self._p.getBalloonFilledVolume()
end

return GasProvider
