# gas_provider

Shared peripheral for gas-output blocks (burners, vents) that fill balloons. Reports gas output, signal, gas type, target amount, and balloon state. The additional type `gas_provider` lets scripts target every heater regardless of block kind.

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getGasOutput()` | `number` | Current gas output rate in m³/tick (×20 for m³/s). Output = target × signal/15 (burner), or target × efficiency × signal/15 (vent). |
| `isActive()` | `boolean` | Whether the provider can currently output gas. |
| `getSignalStrength()` | `number` | Redstone signal strength driving output (0–15). |
| `getGasType()` | `string` | ID of the gas produced (e.g. `"steam"`, `"default"`). |
| `getTargetAmount()` | `number` | Configured target gas amount. |
| `setTargetAmount(amount)` | *(yields)* | Set the target gas amount. Clamped to scroll-value min/max. |
| `getBoilerEfficiency()` | `number` | Boiler efficiency 0–1. Burners are always `1.0`; vents track boiler heat. |
| `hasBalloon()` | `boolean` | Whether a balloon is currently attached. |
| `getBalloonCapacity()` | `number` | Attached balloon's capacity, or `0` if none. |
| `getBalloonFilledVolume()` | `number` | Balloon's currently filled volume, or `0`. |
| `getBalloonTargetVolume()` | `number` | Balloon's target volume, or `0`. |
| `getBalloonVolumeChange()` | `number` | Per-tick volume change (signed), or `0`. |
| `getBalloonLift()` | `number` | Balloon's lift force, or `0`. |
| `getBalloonHeight()` | `number` | Balloon's height, or `0`. |
| `getBalloonGasMix()` | `{ {type, amount} }` | List of gas mix entries. |

## Usage notes

- `setTargetAmount` **yields** until the next server tick.
- To control lift: increase `setTargetAmount` to expand the balloon (more lift), decrease to shrink (less lift / descent).
- The `GasProvider` wrapper in `peripherals/GasProvider.lua` maps this to the `IThruster` interface with axis `"up"`.
