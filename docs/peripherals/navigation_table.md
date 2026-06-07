# navigation_table

A navigation table. Returns directions to beds, graves, or banners — **not** raw XYZ coordinates. Not suitable for autopilot waypoint navigation in this project.

## Methods

*(Standard Create navigation_table methods — bearing/distance to named markers.)*

## Usage in this project

**Do not use `navigation_table` for autopilot XYZ coordinates.**

Use CC: Tweaked's built-in `gps` API instead:

```lua
local x, y, z = gps.locate(timeout)
```

- `gps.locate(timeout)` returns world XYZ, or `nil` if no GPS satellites are reachable.
- Requires 4 GPS host computers placed and configured in the world.
- Call once per autopilot tick in `InputLoop` to get current craft position.
- Derive heading from two successive GPS samples or from `gimbal_sensor.getAngularRates().wy` integrated over time.

For yaw heading, take two `gps.locate()` samples a tick apart and compute `math.atan2(x2-x1, z2-z1)`.
