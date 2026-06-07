-- core/InputLoop.lua
-- Writes state.cmd each tick from either manual input (steering_wheel +
-- throttle_lever + keyboard) or autopilot (GPS waypoint).
-- Runs as a coroutine via parallel.waitForAll in main.lua.

local InputLoop = {}
InputLoop.__index = InputLoop

-- wheel  : steering_wheel peripheral (may be nil)
-- lever  : throttle_lever peripheral (may be nil)
-- state  : shared state table
-- cfg    : config.input and config.loopDt
function InputLoop.new(wheel, lever, state, cfg)
    return setmetatable({
        _wheel     = wheel,
        _lever     = lever,
        _state     = state,
        _dt        = cfg.loopDt,
        _altRate   = cfg.input.altitudeRatePerUnit,
        _maxTrans  = cfg.input.maxTranslation,
        _maxYaw    = cfg.input.maxYaw,
        _leverMid  = 7,   -- lever centre position (0..15); below = descend, above = climb
    }, InputLoop)
end

-- ── Keyboard movement ─────────────────────────────────────────────────────────
-- Reads held keys via os.pullEventRaw is not practical in a sleep loop.
-- Instead we use a simple event queue: main.lua queues key events into
-- state._keys = {[key]=true} via a parallel key-listener coroutine.
-- InputLoop reads that table each tick.

local KEY_FORWARD  = keys.w
local KEY_BACK     = keys.s
local KEY_RIGHT    = keys.d
local KEY_LEFT     = keys.a
local KEY_AUTOPILOT = keys.p

local function keyAxis(heldKeys, pos, neg)
    local p = heldKeys[pos] and 1 or 0
    local n = heldKeys[neg] and 1 or 0
    return p - n
end

function InputLoop:run()
    local state   = self._state
    local dt      = self._dt
    local wheel   = self._wheel
    local lever   = self._lever

    while true do
        local cmd     = state.cmd
        local held    = state._heldKeys or {}
        local ap      = state.autopilot

        -- Toggle autopilot on P key edge
        if held[KEY_AUTOPILOT] and not self._wasAutopilot then
            ap.enabled = not ap.enabled
            self._wasAutopilot = true
        elseif not held[KEY_AUTOPILOT] then
            self._wasAutopilot = false
        end

        if ap.enabled then
            self:_runAutopilot(cmd, ap, state.sensors)
        else
            self:_runManual(cmd, held, wheel, lever)
        end

        sleep(dt)
    end
end

function InputLoop:_runManual(cmd, held, wheel, lever)
    -- Yaw: steering wheel takes priority over keyboard
    if wheel and wheel.isHeld() then
        cmd.yaw = wheel.getNormalizedAngle() * self._maxYaw
    else
        cmd.yaw = keyAxis(held, keys.e, keys.q) * self._maxYaw
    end

    -- Translation: keyboard WASD
    cmd.forward = keyAxis(held, KEY_FORWARD, KEY_BACK)  * self._maxTrans
    cmd.right   = keyAxis(held, KEY_RIGHT,   KEY_LEFT)  * self._maxTrans

    -- Altitude rate: throttle lever (centre = hover, above = climb, below = descend)
    if lever then
        local pos = lever.getState()   -- 0..15
        cmd.altRate = (pos - self._leverMid) * self._altRate
    else
        cmd.altRate = keyAxis(held, keys.space, keys.leftShift) * (self._altRate * self._leverMid)
    end
end

function InputLoop:_runAutopilot(cmd, ap, sensors)
    if not ap.targetX or not ap.targetZ then
        -- No waypoint: hover in place
        cmd.forward  = 0
        cmd.right    = 0
        cmd.yaw      = 0
        cmd.altRate  = 0
        return
    end

    -- Get current position from GPS
    local x, y, z = gps.locate(1)
    if not x then return end  -- no GPS fix; keep last command

    -- Altitude
    local altError = (ap.targetAltitude or sensors.altitude) - sensors.altitude
    cmd.altRate = math.max(-2, math.min(2, altError * 0.5))

    -- Horizontal: compute bearing and distance
    local dx = ap.targetX - x
    local dz = ap.targetZ - z
    local dist = math.sqrt(dx*dx + dz*dz)

    if dist < 1.0 then
        -- Close enough; stop
        cmd.forward = 0
        cmd.right   = 0
        cmd.yaw     = 0
        return
    end

    -- Desired world-frame heading (atan2 gives angle from +Z axis)
    -- We use craft's yaw (from GPS heading, derived externally if available)
    -- For simplicity, command full forward and let the yaw PID orient the craft.
    -- TODO: integrate heading from GPS delta or gimbal yaw accumulation.
    local speed = math.min(1.0, dist * 0.1) * self._maxTrans
    cmd.forward = speed
    cmd.right   = 0
    -- Yaw toward waypoint: bearing = atan2(dx, -dz) converts to Minecraft heading
    -- cmd.yaw would need current heading subtracted — requires heading tracking
    cmd.yaw = 0
end

return InputLoop
