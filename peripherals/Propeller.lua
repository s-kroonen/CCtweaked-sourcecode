-- peripherals/Propeller.lua
-- IThruster wrapper for a propeller + upstream speed controller.
-- output range -1..1 (maps to -maxRPM..+maxRPM on the speed controller).

local FACING_VECTOR = {
    north = {x =  0, y = 0, z = -1},
    south = {x =  0, y = 0, z =  1},
    east  = {x =  1, y = 0, z =  0},
    west  = {x = -1, y = 0, z =  0},
    up    = {x =  0, y = 1, z =  0},
    down  = {x =  0, y =-1, z =  0},
}

local Propeller = {}
Propeller.__index = Propeller

-- cfg: one entry from config.propellers
-- maxRPM: config.maxPropRPM
function Propeller.new(cfg, maxRPM)
    local prop = peripheral.wrap(cfg.id)
    assert(prop, "Propeller: peripheral not found: " .. tostring(cfg.id))

    local ctrl = peripheral.wrap(cfg.controller)
    assert(ctrl, "Propeller: controller not found: " .. tostring(cfg.controller))

    local fv = FACING_VECTOR[cfg.facing]
    assert(fv, "Propeller: unknown facing: " .. tostring(cfg.facing))

    local pos = cfg.position or {x = 0, z = 0}

    -- Precompute contribution coefficients for MovementLoop.
    -- forward command = -Z direction → coeff = -fv.z
    -- right command   = +X direction → coeff =  fv.x
    -- up command      = +Y direction → coeff =  fv.y
    -- yaw torque about Y = pos × facing projected on Y: pos.x*fv.z - pos.z*fv.x
    local coeffs = {
        forward = -fv.z,
        right   =  fv.x,
        up      =  fv.y,
        yaw     =  pos.x * fv.z - pos.z * fv.x,
    }

    -- Normalise yaw coefficient so max yaw torque = 1 (done across all props in MovementLoop)
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
