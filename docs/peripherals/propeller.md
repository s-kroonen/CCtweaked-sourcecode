# propeller

Shared peripheral for all small propeller variants (wooden, andesite, smart). Reports axis, kinetic and rotation speed, thrust output, and active state. Primary type follows the block id; the additional type `"propeller"` lets scripts target every variant uniformly.

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getAxis()` | `string` | Mounted direction (serialised direction name, e.g. `"north"`, `"up"`). |
| `getRotationSpeed()` | `number` | Smoothed rotation speed (visual; lags `getSpeed` by ~0.15 lerp). |
| `getThrust()` | `number` | Raw thrust in pixel-Newtons (pN). Sign tracks kinetic input. |
| `getAirflow()` | `number` | Airflow in m/s. |
| `isActive()` | `boolean` | Whether the propeller is currently active. |
| `getSelfId()` | `string` | This block's id (used as anchor id by downstream blocks). |
| `getSourceId()` | `string\|nil` | Id of the block immediately driving this one, or `nil`. |
| `getSubnetworkAnchorId()` | `string\|nil` *(yields)* | Id of this block's speed-zone anchor. |
| `getNetworkId()` | `string\|nil` | Kinetic network id (same for all blocks on the same network). |
| `getKind()` | `string` | Role: `"generator"`, `"split_shaft"`, `"consumer"`, or `"passthrough"`. |
| `getSpeed()` | `number` | Local rotational speed (signed). |
| `hasSource()` | `boolean` | Whether connected to a kinetic source. |
| `isOverstressed()` | `boolean` | Whether the network is overstressed. |
| `getStressImpact()` | `number` | Stress draw of this block. |
| `getStressContribution()` | `number` | Stress capacity contributed by this block. |

## Usage notes

- Propellers do not have a `setSpeed` method. Speed is set on the upstream `Create_RotationSpeedController` in the same speed zone.
- `getAxis()` determines which movement axis this propeller contributes to in `MovementLoop`.
- Thrust is direction-independent; the sign of `getThrust()` tracks kinetic input sign.
- `getSubnetworkAnchorId()` **yields** one tick.
- The `Propeller` wrapper in `peripherals/Propeller.lua` pairs this peripheral with an upstream speed controller and exposes the `IThruster` interface.
