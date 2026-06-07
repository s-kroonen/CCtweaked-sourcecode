# steering_wheel

A pilot steering wheel. Reports whether it is held, the current and target angles, and the configured maximum deflection. Also a kinetic block — it drives a connected shaft when turned.

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `isHeld()` | `boolean` | Whether a player is currently holding the wheel. |
| `getAngle()` | `number` degrees | Current visible wheel angle. Bounded by ±`getMaxAngle()`. |
| `getAngleRad()` | `number` radians | Current visible angle in radians. |
| `getTargetAngle()` | `number` degrees | Angle the pilot is commanding (steering toward). |
| `getTargetAngleRad()` | `number` radians | Target angle in radians. |
| `getMaxAngle()` | `number` degrees | Maximum deflection in each direction. Set by scroll value (1–360). |
| `getNormalizedAngle()` | `number` [−1, +1] | Current angle as a fraction of max deflection. Use this for mixing into autopilot commands. |
| `getSelfId()` | `string` | This block's id. |
| `getSourceId()` | `string\|nil` | Id of the block immediately driving this one. |
| `getSubnetworkAnchorId()` | `string\|nil` *(yields)* | Speed-zone anchor id. |
| `getNetworkId()` | `string\|nil` | Kinetic network id. |
| `getKind()` | `string` | Role on the kinetic graph. |
| `getSpeed()` | `number` | Local rotational speed (signed). |
| `hasSource()` | `boolean` | Whether connected to a kinetic source. |
| `isOverstressed()` | `boolean` | Whether the network is overstressed. |
| `getStressImpact()` | `number` | Stress draw of this block. |
| `getStressContribution()` | `number` | Stress capacity contribution. |

## Usage notes

- `InputLoop` reads `isHeld()` to decide between manual and autopilot mode.
- Use `getNormalizedAngle()` (range −1..+1) directly as the yaw command — no scaling needed.
- `getTargetAngle()` leads `getAngle()` (the visible angle lags due to animation). Use `getTargetAngle()` for responsive control.
