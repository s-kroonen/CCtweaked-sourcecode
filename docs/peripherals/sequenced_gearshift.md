# Create_SequencedGearshift

Drop-in replacement for Create's sequenced gearshift peripheral. Used to drive flaps or control surfaces to a specific angular position by rotating a shaft by a set angle.

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `rotate(angle, [modifier])` | *(async)* | Rotate the connected shaft by `angle` degrees. `angle` must be a positive integer. Use `modifier` to set direction. |
| `move(distance, [modifier])` | *(async)* | Rotate to move a connected piston/pulley/gantry by `distance` blocks. `distance` must be a positive integer. |
| `isRunning()` | `boolean` | Whether the gearshift is currently spinning. |

### `rotate(angle, modifier)`
- `angle`: positive integer, degrees to rotate.
- `modifier`: integer in −2..+2. Use negative to reverse direction. Values outside range default to `1`.

### `move(distance, modifier)`
- `distance`: positive integer, blocks to move connected piston/pulley/gantry.
- `modifier`: integer in −2..+2. Negative = reverse direction.

## Usage for flaps

A flap control surface is a shaft-driven wing section. To set a flap angle:

1. Track the current flap position in software.
2. Compute `delta = target_angle - current_angle`.
3. Call `rotate(math.abs(delta), delta < 0 and -1 or 1)`.
4. Wait until `isRunning()` returns `false` before issuing the next command.

```lua
-- Example: set flap to targetDeg from currentDeg
local delta = targetDeg - currentDeg
if delta ~= 0 then
    gearshift.rotate(math.abs(delta), delta < 0 and -1 or 1)
    repeat sleep(0.05) until not gearshift.isRunning()
    currentDeg = targetDeg
end
```

## Usage notes

- The gearshift does not report absolute position — you must track it in software from a known home position.
- Home the flap on startup by rotating to a hard stop or a known reference angle.
- Flaps implement `IThruster` with axis `"pitch"` or `"roll"` depending on orientation. `setOutput(n)` maps a normalised deflection (−1..+1) to a target angle and drives the gearshift.
