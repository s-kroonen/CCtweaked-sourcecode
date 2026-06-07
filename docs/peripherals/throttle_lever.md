# throttle_lever

A 16-position physical lever. Its state is the analog redstone signal it emits. Writing it updates the lever and plays the click sound. Use this to drive any block that lacks a direct peripheral API (via redstone signal 0–15).

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getState()` | `number` | Current lever state (0–15). |
| `setSignal(signal)` | *(yields)* | Drive the lever to a new state. Clamped to 0–15. A player can still override it. |

## Usage notes

- `setSignal` **yields** until the next server tick.
- Unlike `analog_transmission`, there is no externally-controlled lock — a player can move the lever after the script sets it.
- Useful as a fallback actuator for devices without a CC peripheral (e.g. a vanilla redstone-controlled motor).
- Map a normalised thrust command (0..1) to signal (0..15) with `math.floor(value * 15 + 0.5)`.
