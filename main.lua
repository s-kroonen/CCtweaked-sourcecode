-- main.lua
-- Entry point. Wraps peripherals, initialises loops, and runs them in parallel.

local config       = require("config")
local state        = require("state")
local ConfigServer = require("ship.config_server")
local GasProvider  = require("peripherals.GasProvider")
local Propeller    = require("peripherals.Propeller")
local AltitudeSensor = require("sensors.AltitudeSensor")
local GimbalSensor   = require("sensors.GimbalSensor")
local VelocitySensor = require("sensors.VelocitySensor")
local AltitudeLoop = require("core.AltitudeLoop")
local MovementLoop = require("core.MovementLoop")
local InputLoop    = require("core.InputLoop")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function tryWrap(name)
    local p = peripheral.wrap(name)
    if not p then
        print("[warn] peripheral not found: " .. tostring(name))
    end
    return p
end

-- ── Wait for assembly ─────────────────────────────────────────────────────────

local assembler = tryWrap("physics_assembler_0")
if assembler then
    print("Waiting for craft to be assembled...")
    while not assembler.isAssembled() do
        sleep(0.5)
    end
    print("Assembled. Starting control loops.")
else
    print("[warn] No physics_assembler found; assuming assembled.")
end

-- ── Build lift sources ────────────────────────────────────────────────────────

local liftSources = {}
for _, cfg in ipairs(config.liftSources) do
    local ok, obj = pcall(GasProvider.new, cfg.id)
    if ok then
        liftSources[#liftSources + 1] = obj
        print("  lift: " .. cfg.id)
    else
        print("[warn] lift source failed: " .. cfg.id .. " — " .. tostring(obj))
    end
end

-- ── Build propellers ──────────────────────────────────────────────────────────

local allProps  = {}
local upProps   = {}   -- up-facing props used by AltitudeLoop
local moveProps = {}   -- all other props used by MovementLoop

for _, cfg in ipairs(config.propellers) do
    local ok, obj = pcall(Propeller.new, cfg, config.maxPropRPM)
    if ok then
        allProps[#allProps + 1] = obj
        if cfg.facing == "up" or cfg.facing == "down" then
            upProps[#upProps + 1] = obj
        else
            moveProps[#moveProps + 1] = obj
        end
        print("  prop: " .. cfg.id .. " facing=" .. cfg.facing)
    else
        print("[warn] propeller failed: " .. cfg.id .. " — " .. tostring(obj))
    end
end

-- ── Build sensors ─────────────────────────────────────────────────────────────

local altSensor = AltitudeSensor.new(config.sensors.altitude)
local gimSensor = GimbalSensor.new(config.sensors.gimbal)
local velSensor = VelocitySensor.new(config.sensors.velocity)

-- ── Build input peripherals ───────────────────────────────────────────────────

local wheel = tryWrap(config.input.steeringWheel)
local lever = tryWrap(config.input.throttleLever)

-- ── Seed target altitude ──────────────────────────────────────────────────────

altSensor:read(state.sensors)
state.targetAltitude = state.sensors.altitude
print("Hover target: " .. state.targetAltitude .. " m")

-- ── Build loops ───────────────────────────────────────────────────────────────

local altLoop  = AltitudeLoop.new(liftSources, upProps, state, config)
local moveLoop = MovementLoop.new(moveProps, state, config)
local inpLoop  = InputLoop.new(wheel, lever, state, config)

-- ── Sensor update coroutine ───────────────────────────────────────────────────

local function sensorLoop()
    while true do
        altSensor:read(state.sensors)
        gimSensor:read(state.sensors)
        velSensor:read(state.sensors)
        sleep(config.loopDt)
    end
end

-- ── Key listener coroutine ────────────────────────────────────────────────────
-- Maintains state._heldKeys = {[keyCode] = true} for InputLoop.

state._heldKeys = {}

local function keyListener()
    while true do
        local event, key = os.pullEventRaw()
        if event == "key" then
            state._heldKeys[key] = true
        elseif event == "key_up" then
            state._heldKeys[key] = nil
        elseif event == "terminate" then
            -- Graceful shutdown: zero all outputs
            for _, src in ipairs(liftSources) do pcall(src.setOutput, src, 0) end
            for _, p   in ipairs(allProps)    do pcall(p.setOutput,   p,   0) end
            error("Terminated")
        end
    end
end

-- ── Status display coroutine ──────────────────────────────────────────────────

local function statusDisplay()
    while true do
        local s = state.sensors
        term.setCursorPos(1, 1)
        term.clearLine()
        print(string.format("Alt: %5.1f m (target %5.1f)  vSpeed: %+5.2f m/s",
            s.altitude, state.targetAltitude or 0, s.verticalSpeed))
        term.clearLine()
        print(string.format("Pitch: %+5.1f  Roll: %+5.1f  YawRate: %+5.1f deg/s",
            s.pitch, s.roll, s.yawRate))
        term.clearLine()
        local ap = state.autopilot.enabled and "[AUTOPILOT]" or "[MANUAL]"
        print(string.format("%s  Fwd:%+4.1f  Rt:%+4.1f  Yaw:%+4.1f  AltRate:%+4.1f",
            ap, state.cmd.forward, state.cmd.right, state.cmd.yaw, state.cmd.altRate))
        sleep(0.25)
    end
end

-- ── Run ───────────────────────────────────────────────────────────────────────

print("All systems ready. Running.")
sleep(0.1)
term.clear()
term.setCursorPos(1, 1)

parallel.waitForAll(
    function() sensorLoop() end,
    function() keyListener() end,
    function() altLoop:run() end,
    function() moveLoop:run() end,
    function() inpLoop:run() end,
    function() statusDisplay() end,
    function() ConfigServer.run() end
)
