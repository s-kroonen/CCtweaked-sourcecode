# Create_RotationSpeedController

Drop-in replacement for Create's speed controller peripheral. Acts as a speed-zone boundary. Its downstream blocks report this block's id as their `getSubnetworkAnchorId()`.

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `setTargetSpeed(speed)` | *(yields)* | Set output speed in RPM. Must be an integer in −256..+256. Values outside are clamped. Sign sets direction. |
| `getTargetSpeed()` | `number` | Configured target speed in RPM. Reflects last `setTargetSpeed` or in-game scroll — not the live shaft speed. |

## Usage notes

- `setTargetSpeed` **yields** until the next server tick.
- Range is −256..+256 RPM. Map a normalised command (−1..+1) with `math.floor(cmd * 256)`.
- Positive speed = one thrust direction; negative = opposite. Use sign to reverse a propeller's thrust without rewiring.
- Each propeller that needs independent speed control needs its own speed controller upstream.
- Pass integer values — the parameter must be an integer per the API contract.
