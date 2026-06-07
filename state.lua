-- state.lua
-- Shared mutable state passed between control loops each tick.
-- InputLoop writes; AltitudeLoop and MovementLoop read.

local state = {
    -- commands written by InputLoop
    cmd = {
        forward  = 0,   -- -1..1  (body -Z = forward)
        right    = 0,   -- -1..1  (body +X = right)
        yaw      = 0,   -- -1..1  (positive = clockwise from above)
        altRate  = 0,   -- m/s target climb rate (positive = up)
    },

    -- sensor readings updated each tick by the sensor wrappers
    sensors = {
        altitude      = 0,
        verticalSpeed = 0,
        pitch         = 0,   -- degrees, nose-up positive
        roll          = 0,   -- degrees, right-down positive
        pitchRate     = 0,   -- deg/s
        rollRate      = 0,   -- deg/s
        yawRate       = 0,   -- deg/s
        vx            = 0,   -- body-frame velocity m/s
        vy            = 0,
        vz            = 0,
    },

    -- target altitude set by InputLoop, held by AltitudeLoop
    targetAltitude = nil,   -- nil = use current altitude on first tick

    -- autopilot: set targetAltitude and cmd.forward/right/yaw from here
    autopilot = {
        enabled = false,
        targetX = nil,
        targetZ = nil,
        targetAltitude = nil,
    },
}

return state
