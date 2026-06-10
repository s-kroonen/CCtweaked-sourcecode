-- config.lua
-- Human-edited tuning constants (PID gains, timing, limits).
-- Peripheral IDs, positions, and facings are stored in config_data.lua
-- and written by the terminal config tool.

local config = {}

-- ── Load machine-written peripheral data ─────────────────────────────────────
local ok, data = pcall(require, "config_data")
if not ok or type(data) ~= "table" then
    data = {}
    print("[config] No config_data.lua found; using empty peripheral lists.")
end

config.liftSources  = data.liftSources  or {}
config.propellers   = data.propellers   or {}
-- Direction the FRONT of the craft faces in the world at build orientation.
-- Rotates forward/right command frame so player input always matches craft.
-- Valid values: "north" | "south" | "east" | "west"
config.craftFacing  = data.craftFacing  or "north"
config.sensors      = data.sensors      or {
    altitude = "altitude_sensor_0",
    gimbal   = "gimbal_sensor_0",
    velocity = {},
}
config.input = data.input or {
    steeringWheel       = "steering_wheel_0",
    throttleLever       = "throttle_lever_0",
    altitudeRatePerUnit = 0.5,
    maxTranslation      = 0.8,
    maxYaw              = 0.6,
}

-- ── PID gains (edit here, not via the terminal tool) ─────────────────────────
config.pid = {
    altitude = { kP = 0.5,  kI = 0.04, kD = 0.25, iLimit = 2.0 },
    pitch    = { kP = 0.4,  kI = 0.0,  kD = 0.15, iLimit = 1.0 },
    roll     = { kP = 0.4,  kI = 0.0,  kD = 0.15, iLimit = 1.0 },
    yaw      = { kP = 0.35, kI = 0.0,  kD = 0.1,  iLimit = 1.0 },
}

-- ── Propeller limits ──────────────────────────────────────────────────────────
config.maxPropRPM = 200   -- -256..256 RPM, must be integer

-- ── Loop timing ───────────────────────────────────────────────────────────────
config.loopDt = 0.05      -- seconds per control tick (~20 Hz)

return config
