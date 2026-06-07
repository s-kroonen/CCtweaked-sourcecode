# gimbal_sensor

Inertial measurement on the body frame: pitch/roll angles, angular rates, gravity vector, and linear acceleration.

**Body frame** = the contraption's frame, not any individual block's local frame. At identity orientation, body axes equal world axes (body +X = east, +Y = up, +Z = south). The block's mounting orientation does not affect readings — two sensors in different orientations on the same contraption return identical values.

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getAngles()` | `{pitch, roll}` degrees | Pitch (rotation about body-X) and roll (rotation about body-Z). 0° = body-Y aligned with world-up. |
| `getAnglesRad()` | `{pitch, roll}` radians | Same as `getAngles()` in radians. |
| `getAngularRates()` | `{wx, wy, wz}` deg/s | Angular velocity in body frame: wx = pitch rate, wy = yaw rate, wz = roll rate. |
| `getAngularRatesRad()` | `{wx, wy, wz}` rad/s | Same as `getAngularRates()` in radians/sec. |
| `getGravity()` | `{gx, gy, gz}` m/s² | World gravity rotated into body frame. Default: `{0, -11.0, 0}` in world frame. |
| `getLinearAcceleration()` | `{ax, ay, az}` m/s² | Proper acceleration (what an onboard accelerometer reads). Computed as `(Δv × 20) - gravity_body`. One tick of lag. Stationary = `-getGravity()`; free-fall = zero. |

## Usage notes

- **Yaw is not reported here.** Use `gps.locate()` (CC built-in) or heading derived from two GPS samples for yaw. `getAngularRates().wy` gives the yaw *rate* for PID derivative terms.
- Attitude estimation from gravity: `atan2(g.x, -g.y) ≈ roll`, `atan2(g.z, -g.y) ≈ pitch` — same derivation `getAngles()` uses internally.
- `getAngularRates()` is the derivative term source for attitude PID loops (pitch/roll levelling, yaw rate damping).
- Mount anywhere on the contraption — mounting orientation does not change the readings.
