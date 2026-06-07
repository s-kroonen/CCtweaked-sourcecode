# velocity_sensor

A directional velocity sensor. Reports the host contraption's linear velocity component along the body-frame axis the block is mounted on.

**Axis convention.** Each sensor is mounted along one body-frame axis (fixed at place-time, unaffected by sub-level rotation). At identity orientation, body axes equal world axes (body +X = east, +Y = up, +Z = south). The sensor projects the contraption's global velocity onto its mounted axis direction (transformed into world frame). Three orthogonally-mounted sensors reconstruct the full body-frame velocity vector `{vx, vy, vz}`.

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getVelocity()` | `number` m/s | Signed velocity along the mounted axis. Positive = moving in axis-positive direction. Deadband: returns `0` below 0.05 m/s. Returns `0` when host is not on a sub-level. |
| `getAxis()` | `string` | Body-frame axis: `"x"`, `"y"`, or `"z"`. Fixed at place-time. |

## Usage notes

- Place three sensors along orthogonal axes to get full `{vx, vy, vz}` body-frame velocity.
- Use in `MovementLoop` to implement velocity-hold (brake to zero) and speed-limited translation.
- `getAxis()` lets a Lua script identify which sensor is which without hard-coding peripheral names per axis.
- 0.05 m/s deadband means very slow drift is reported as zero — account for this in PID integral windup.
