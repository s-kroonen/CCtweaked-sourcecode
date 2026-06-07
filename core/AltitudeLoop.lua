-- core/AltitudeLoop.lua
-- Holds the craft at a target altitude using all configured lift sources
-- (gas_provider balloons and any up-facing propellers).
-- Runs as a coroutine via parallel.waitForAll in main.lua.

local PID = require("core.PID")

local AltitudeLoop = {}
AltitudeLoop.__index = AltitudeLoop

-- liftSources : list of GasProvider (and any up-axis Propeller) IThruster objects
-- upProps     : list of Propeller objects with facing == "up"
-- cfg         : config.pid.altitude and config.loopDt
function AltitudeLoop.new(liftSources, upProps, state, cfg)
    return setmetatable({
        _lift    = liftSources,
        _upProps = upProps or {},
        _state   = state,
        _dt      = cfg.loopDt,
        _pid     = PID.new(cfg.pid.altitude),
    }, AltitudeLoop)
end

function AltitudeLoop:run()
    local state = self._state
    local dt    = self._dt

    -- seed target altitude on first tick
    while state.targetAltitude == nil do
        sleep(dt)
    end

    while true do
        local s = state.sensors

        -- Integrate altitude rate command into target altitude
        state.targetAltitude = state.targetAltitude + state.cmd.altRate * dt

        local error  = state.targetAltitude - s.altitude
        local output = self._pid:update(error, dt)

        -- Bias: 0.5 = hover (half capacity keeps balloon neutral).
        -- PID output shifts it up or down.
        local liftCmd = math.max(0, math.min(1, 0.5 + output))

        for _, src in ipairs(self._lift) do
            if src:isAvailable() then
                src:setOutput(liftCmd)
            end
        end

        -- Up-facing props add extra lift authority on top of balloons
        for _, prop in ipairs(self._upProps) do
            if prop:isAvailable() then
                -- remap liftCmd 0..1 → prop output -1..1
                prop:setOutput((liftCmd - 0.5) * 2)
            end
        end

        sleep(dt)
    end
end

return AltitudeLoop
