-- config.lua
-- All peripheral names and tuning constants live here.
-- Add/remove entries to reconfigure the craft without touching control code.

local config = {}

-- ── Lift sources ─────────────────────────────────────────────────────────────
-- Any peripheral that implements the gas_provider API.
-- All driven equally by AltitudeLoop; position reserved for future per-corner
-- pitch/roll trim.
config.liftSources = {
    { id = "gas_front_left",  position = {x = -2, z =  2} },
    { id = "gas_front_right", position = {x =  2, z =  2} },
    { id = "gas_back_left",   position = {x = -2, z = -2} },
    { id = "gas_back_right",  position = {x =  2, z = -2} },
}

-- ── Propellers ───────────────────────────────────────────────────────────────
-- facing: body-frame direction the prop PUSHES the craft toward.
--   Body frame at identity: +X = east, +Y = up, +Z = south.
--   "north" means the prop pushes toward -Z (forward if craft faces north).
-- position: {x, z} offset from craft center in blocks.
--   Used to compute yaw torque: torque_y = pos.x * facing.z - pos.z * facing.x
-- controller: peripheral name of the upstream Create_RotationSpeedController.
config.propellers = {
    {
        id         = "propeller_front_right_left",
        controller = "Create_RotationSpeedController_10",
        facing     = "north",
        position   = {x =  15, z =  14},
    },
    {
        id         = "propeller_front_right_backward",
        controller = "Create_RotationSpeedController_5",
        facing     = "west",
        position   = {x =  19, z =  11},
    },
    {
        id         = "propeller_front_left_backward",
        controller = "Create_RotationSpeedController_7",
        facing     = "west",
        position   = {x =  19, z = -11},
    },
    {
        id         = "propeller_front_left_right",
        controller = "Create_RotationSpeedController_9",
        facing     = "south",
        position   = {x =  15, z =  -14},
    },
    {
        id         = "propeller_back_right_forward",
        controller = "Create_RotationSpeedController_3",
        facing     = "east", 
        position   = {x =  -19, z = 14},
    },
    {
        id         = "propeller_back_left_forward",
        controller = "Create_RotationSpeedController_1",
        facing     = "east", 
        position   = {x = -19, z = -11},
    },
    {
        id         = "propeller_back_left_right",
        controller = "Create_RotationSpeedController_11",
        facing     = "south",
        position   = {x =  -15, z = -14},
    },
    {
        id         = "propeller_back_right_left",
        controller = "Create_RotationSpeedController_8",
        facing     = "north",
        position   = {x = -15, z = 14},
    },
    -- Example: add an up-facing prop for extra lift assist
    -- {
    --     id         = "propeller_lift",
    --     controller = "rsc_lift",
    --     facing     = "up",
    --     position   = {x = 0, z = 0},
    -- },
}

-- ── Sensors ──────────────────────────────────────────────────────────────────
config.sensors = {
    altitude  = "altitude_sensor_0",
    gimbal    = "gimbal_sensor_0",
    -- velocity_sensor peripherals; wrapper reads getAxis() to sort them by axis
    velocity  = { "velocity_sensor_0", "velocity_sensor_1", "velocity_sensor_2" },
}

-- ── Input ────────────────────────────────────────────────────────────────────
config.input = {
    steeringWheel    = "steering_wheel_0",
    throttleLever    = "throttle_lever_0",
    -- how many metres to shift target altitude per lever unit per second
    altitudeRatePerUnit = 0.5,
    -- clamp on manual translation and yaw commands (normalised 0..1)
    maxTranslation   = 0.8,
    maxYaw           = 0.6,
}

-- ── PID gains ────────────────────────────────────────────────────────────────
config.pid = {
    altitude = { kP = 0.5,  kI = 0.04, kD = 0.25, iLimit = 2.0 },
    pitch    = { kP = 0.4,  kI = 0.0,  kD = 0.15, iLimit = 1.0 },
    roll     = { kP = 0.4,  kI = 0.0,  kD = 0.15, iLimit = 1.0 },
    yaw      = { kP = 0.35, kI = 0.0,  kD = 0.1,  iLimit = 1.0 },
}

-- ── Propeller limits ─────────────────────────────────────────────────────────
-- setTargetSpeed range is -256..256 RPM (must be integer)
config.maxPropRPM = 200

-- ── Loop timing ──────────────────────────────────────────────────────────────
config.loopDt = 0.05   -- seconds between control ticks (~20 Hz)

return config
