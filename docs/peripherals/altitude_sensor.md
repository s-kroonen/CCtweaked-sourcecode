# altitude_sensor

Reports the sensor's world altitude, local air pressure, and vertical speed.

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getAltitude()` | `number` | World Y coordinate of the sensor block. |
| `getAirPressure()` | `number` | Local air pressure (decreases with altitude). |
| `getVerticalSpeed()` | `number` | Vertical speed in m/s (positive = rising). |

## Usage notes

- Used by `AltitudeLoop` as the primary feedback signal for the altitude PID controller.
- `getVerticalSpeed()` is the derivative term source — avoids needing to numerically differentiate altitude readings.
- Mount on the craft body so the reading moves with the physics assembler contraption.
