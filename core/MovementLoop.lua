-- core/MovementLoop.lua
-- Routes forward/right/yaw commands from state.cmd to the correct propellers.
-- Each propeller's contribution is precomputed from its facing and position.
-- Runs as a coroutine via parallel.waitForAll in main.lua.

local PID = require("core.PID")

local MovementLoop = {}
MovementLoop.__index = MovementLoop

-- props  : list of Propeller IThruster objects (horizontal + mixed)
-- state  : shared state table
-- cfg    : config table (loopDt, pid.yaw, pid.pitch, pid.roll)
function MovementLoop.new(props, state, cfg)
    -- Normalise yaw coefficients so the largest absolute yaw coefficient = 1.
    -- This prevents one prop dominating the yaw authority budget.
    local maxYaw = 0
    for _, p in ipairs(props) do
        local a = math.abs(p.coeffs.yaw)
        if a > maxYaw then maxYaw = a end
    end
    if maxYaw > 0 then
        for _, p in ipairs(props) do
            p.coeffs.yaw = p.coeffs.yaw / maxYaw
        end
    end

    return setmetatable({
        _props    = props,
        _state    = state,
        _dt       = cfg.loopDt,
        _yawPID   = PID.new(cfg.pid.yaw),
        _pitchPID = PID.new(cfg.pid.pitch),
        _rollPID  = PID.new(cfg.pid.roll),
    }, MovementLoop)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

function MovementLoop:run()
    local state = self._state
    local dt    = self._dt

    while true do
        local cmd = state.cmd
        local s   = state.sensors

        -- Yaw rate PID: command is desired yaw rate; sensor gives actual yaw rate
        -- cmd.yaw is -1..1, scale to a desired deg/s (e.g. 30 deg/s max)
        local yawRateTarget = cmd.yaw * 30
        local yawOut = self._yawPID:update(yawRateTarget - s.yawRate, dt)

        -- Attitude levelling PIDs (zero-setpoint: keep craft flat)
        local pitchOut = self._pitchPID:update(-s.pitch, dt)
        local rollOut  = self._rollPID:update(-s.roll,  dt)

        for _, prop in ipairs(self._props) do
            if prop:isAvailable() then
                local c = prop.coeffs
                local output =
                    cmd.forward * c.forward +
                    cmd.right   * c.right   +
                    yawOut      * c.yaw

                -- Attitude correction: props with up-component help with pitch/roll trim
                -- (horizontal props can't help much, but mixed-axis props can)
                -- skip for pure horizontal props (c.up == 0)

                prop:setOutput(clamp(output, -1, 1))
            else
                prop:setOutput(0)
            end
        end

        sleep(dt)
    end
end

return MovementLoop
