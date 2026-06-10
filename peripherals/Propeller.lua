-- peripherals/Propeller.lua
-- IThruster wrapper for a propeller + upstream speed controller.
-- output range -1..1 (maps to -maxRPM..+maxRPM on the speed controller).
--
-- craftFacing: the direction the FRONT of the ship faces in the world at
-- identity (build) orientation.  Rotates the forward/right command frame so
-- player "forward" always maps to the correct props regardless of build facing.

local FACING_VECTOR = {
    north = {x =  0, y = 0, z = -1},
    south = {x =  0, y = 0, z =  1},
    east  = {x =  1, y = 0, z =  0},
    west  = {x = -1, y = 0, z =  0},
    up    = {x =  0, y = 1, z =  0},
    down  = {x =  0, y =-1, z =  0},
}

-- craft-forward and craft-right unit vectors for each build facing.
-- forward_coeff = dot(craftForward, propFacing)
-- right_coeff   = dot(craftRight,   propFacing)
local CRAFT_AXES = {
    north = {fx =  0, fz = -1,  rx = 1, rz =  0},
    south = {fx =  0, fz =  1,  rx =-1, rz =  0},
    east  = {fx =  1, fz =  0,  rx = 0, rz =  1},
    west  = {fx = -1, fz =  0,  rx = 0, rz = -1},
}

local Propeller = {}
Propeller.__index = Propeller

-- cfg        : one entry from config.propellers
-- maxRPM     : config.maxPropRPM
-- craftFacing: config.craftFacing ("north" default)
function Propeller.new(cfg, maxRPM, craftFacing)
    local prop = peripheral.wrap(cfg.id)
    assert(prop, "Propeller: peripheral not found: " .. tostring(cfg.id))

    local ctrl = peripheral.wrap(cfg.controller)
    assert(ctrl, "Propeller: controller not found: " .. tostring(cfg.controller))

    local fv = FACING_VECTOR[cfg.facing]
    assert(fv, "Propeller: unknown facing: " .. tostring(cfg.facing))

    local axes = CRAFT_AXES[craftFacing or "north"] or CRAFT_AXES.north
    local pos  = cfg.position or {x = 0, z = 0}

    -- forward_coeff = how much this prop contributes to the player's forward command
    -- right_coeff   = how much it contributes to the player's right command
    -- yaw torque about Y (body frame, sign-independent of craft facing):
    --   cross(pos, propFacing).y = pos.x * fv.z - pos.z * fv.x
    local coeffs = {
        forward = axes.fx * fv.x + axes.fz * fv.z,
        right   = axes.rx * fv.x + axes.rz * fv.z,
        up      = fv.y,
        yaw     = pos.x * fv.z - pos.z * fv.x,
    }

    return setmetatable({
        _prop   = prop,
        _ctrl   = ctrl,
        _id     = cfg.id,
        _facing = cfg.facing,
        _fv     = fv,
        _pos    = pos,
        _maxRPM = maxRPM,
        _output = 0,
        coeffs  = coeffs,   -- public: read by MovementLoop
    }, Propeller)
end

-- IThruster interface ─────────────────────────────────────────────────────────

function Propeller:getAxis()
    return self._facing
end

-- value: -1..1
function Propeller:setOutput(value)
    value = math.max(-1, math.min(1, value))
    self._output = value
    local rpm = math.floor(value * self._maxRPM)
    self._ctrl.setTargetSpeed(rpm)
end

function Propeller:getOutput()
    return self._output
end

function Propeller:isAvailable()
    return self._prop.hasSource() and not self._prop.isOverstressed()
end

-- Diagnostics ─────────────────────────────────────────────────────────────────

function Propeller:getThrust()
    return self._prop.getThrust()
end

function Propeller:isOverstressed()
    return self._prop.isOverstressed()
end

return Propeller
