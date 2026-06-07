# physics_assembler

A physics assembler. Reports whether the host sub-level is assembled and exposes its mass, center of mass, and inertia tensor. Does **not** expose an assemble/disassemble command — assembly is triggered in-game (right-click or redstone).

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `isAssembled()` | `boolean` *(yields)* | Whether the host sub-level is currently assembled. |
| `getMass()` | `number` *(yields)* | Total mass of the assembled sub-level. Returns `0` if not assembled. |
| `getCenterOfMass()` | `{x, y, z}` *(yields)* | Center of mass in world coordinates. |
| `getInertiaTensor()` | `{9 numbers}` *(yields)* | Row-major 3×3 inertia tensor [Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz]. Symmetric. |
| `getSubLevelId()` | `string\|nil` *(yields)* | UUID of the sub-level, stable for the contraption's lifetime. `nil` if on stationary ground. |
| `getSubLevelName()` | `string\|nil` *(yields)* | Display name of the sub-level, or `nil` if none set. |

## Usage notes

- All methods **yield** one server tick.
- `isAssembled()` should be polled in `main.lua` startup before initialising any control loops — actuator peripherals only respond when the craft is assembled.
- `getMass()` and `getCenterOfMass()` are useful for tuning PID gains and for computing torque from off-centre thrust.
- `getInertiaTensor()` enables full rigid-body feedforward control if needed.
- Assembly/disassembly itself is not scriptable — it must be done by the player or via a redstone signal to the assembler.
