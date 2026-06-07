# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **CC: Tweaked** (ComputerCraft) Lua program for a **Create Aeronautics** blimp controller. The craft is a physics-assembled blimp with 4 gas-provider balloons at the corners and directional propellers for movement. The program runs on an in-game computer attached to the craft via the `physics_assembler` peripheral.

The language is **Lua 5.2** (CC: Tweaked flavour). There is no build step — `.lua` files are run directly on the in-game computer. Editing happens either in-game or by syncing files into a world save.

## Architecture

```
main.lua                  -- Entry point: wraps peripherals, seeds altitude, runs parallel coroutines
config.lua                -- All peripheral IDs, positions, facings, PID gains, and timing
state.lua                 -- Shared mutable table (cmd, sensors, targetAltitude, autopilot)
peripherals/
  GasProvider.lua         -- IThruster for gas_provider; output 0..1 → setTargetAmount
  Propeller.lua           -- IThruster for propeller + speed controller; output -1..1 → setTargetSpeed
  [future].lua            -- New actuators: implement getAxis/setOutput/getOutput/isAvailable
core/
  PID.lua                 -- Discrete PID with integral anti-windup
  AltitudeLoop.lua        -- PID altitude hold; drives all lift sources equally
  MovementLoop.lua        -- Routes forward/right/yaw commands to props via precomputed coefficients
  InputLoop.lua           -- Manual (wheel+lever+keyboard) or autopilot (GPS) input writer
sensors/
  AltitudeSensor.lua      -- Reads altitude_sensor → state.sensors.altitude/verticalSpeed
  GimbalSensor.lua        -- Reads gimbal_sensor → state.sensors.pitch/roll/rates
  VelocitySensor.lua      -- Reads 1-3 velocity_sensor peripherals → state.sensors.vx/vy/vz
```

### Key design rules

- **IThruster interface**: every actuator (balloon, prop, future thruster) implements `getAxis() -> string`, `setOutput(value)`, `getOutput() -> number`, and `isAvailable() -> bool`. The control loops never call peripheral APIs directly — only through this interface.
- **Peripheral wrappers** hold a reference to the raw peripheral object (acquired via `peripheral.wrap(name)`). Wrapper constructors accept the peripheral name string from `config.lua`.
- **Config-driven**: `config.lua` lists all peripheral names and sides, PID gains, axis assignments for each thruster, and max/min RPM or gas volume. No peripheral name should appear outside `config.lua` and the constructor call.
- **Coroutine-per-loop**: `main.lua` runs `FlightController`, `AltitudeLoop`, `MovementLoop`, and `InputLoop` as parallel coroutines via `parallel.waitForAll`.
- **Axis convention**: X = right, Y = up, Z = forward (craft-local). Propellers report their axis via `getAxis()`; the controller uses this to route commands.

### Control flow

```
InputLoop  →  shared command table  →  AltitudeLoop + MovementLoop
                                              ↓
                                       FlightController
                                              ↓
                              IThruster.setOutput() on all actuators
```

The shared command table is a plain Lua table updated each tick: `{ yaw, pitch, roll, throttle, lateral_x, lateral_z }`. Loops read it; `InputLoop` writes it.

## Peripheral documentation

See [`docs/peripherals/`](docs/peripherals/) for full API references for every peripheral used:

- [`gas_provider.md`](docs/peripherals/gas_provider.md) — balloon lift control
- [`propeller.md`](docs/peripherals/propeller.md) — directional thrust
- [`speed_controller.md`](docs/peripherals/speed_controller.md) — RPM control for propeller chains
- [`throttle_lever.md`](docs/peripherals/throttle_lever.md) — 16-position physical input lever
- [`altitude_sensor.md`](docs/peripherals/altitude_sensor.md) — altitude + vertical speed
- [`gimbal_sensor.md`](docs/peripherals/gimbal_sensor.md) — pitch/roll/yaw rates
- [`velocity_sensor.md`](docs/peripherals/velocity_sensor.md) — directional velocity
- [`steering_wheel.md`](docs/peripherals/steering_wheel.md) — pilot input device
- [`physics_assembler.md`](docs/peripherals/physics_assembler.md) — craft assembly/disassembly
- [`navigation_table.md`](docs/peripherals/navigation_table.md) — **not used for autopilot XYZ** (returns directions to beds/graves/banners); use CC `gps.locate()` instead
- [`sequenced_gearshift.md`](docs/peripherals/sequenced_gearshift.md) — drives flaps/control surfaces to a target angle

## Autopilot position

Use CC: Tweaked's built-in `gps` API — **not** `navigation_table`:
```lua
local x, y, z = gps.locate(timeout)
```
Requires 4 GPS host computers in the world. Derive heading from two successive GPS samples or integrate `gimbal_sensor.getAngularRates()` wy.

## Peripheral gaps (still needed for a complete control loop)

All core peripherals are now documented. The control loop is complete with:

| Peripheral | Role |
|-----------|------|
| `gimbal_sensor` | Pitch/roll error + angular rates for attitude PID |
| `velocity_sensor` × 3 | Body-frame velocity feedback for movement loop |
| `steering_wheel` | Pilot yaw input; `isHeld()` switches manual/autopilot |
| `physics_assembler` | Poll `isAssembled()` on boot before starting loops |
| `Create_RotationSpeedController` | Sets RPM (−256..+256, integer) per propeller speed zone |
| `Create_SequencedGearshift` | Drives flap angle; track position in software from a homed reference |
| `gps` (CC built-in) | World XYZ for autopilot waypoint navigation |

The `throttle_lever` covers any block without a direct peripheral API via redstone signal 0–15.
