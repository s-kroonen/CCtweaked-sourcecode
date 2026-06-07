-- install.lua
-- Run once in-game to download the full blimp controller from GitHub.
-- Usage:  wget run https://raw.githubusercontent.com/s-kroonen/CCtweaked-sourcecode/master/install.lua

local REPO  = "https://raw.githubusercontent.com/s-kroonen/CCtweaked-sourcecode/master"

local FILES = {
    "main.lua",
    "config.lua",
    "state.lua",
    "core/PID.lua",
    "core/AltitudeLoop.lua",
    "core/MovementLoop.lua",
    "core/InputLoop.lua",
    "peripherals/GasProvider.lua",
    "peripherals/Propeller.lua",
    "sensors/AltitudeSensor.lua",
    "sensors/GimbalSensor.lua",
    "sensors/VelocitySensor.lua",
}

local function mkdir(path)
    local parts = {}
    for p in path:gmatch("[^/]+") do parts[#parts+1] = p end
    table.remove(parts)  -- drop filename
    local cur = ""
    for _, p in ipairs(parts) do
        cur = cur == "" and p or (cur .. "/" .. p)
        if not fs.exists(cur) then fs.makeDir(cur) end
    end
end

local ok, fail = 0, 0
for _, path in ipairs(FILES) do
    local url  = REPO .. "/" .. path
    local resp = http.get(url)
    if resp then
        mkdir(path)
        local f = fs.open(path, "w")
        f.write(resp.readAll())
        f.close()
        resp.close()
        print("  OK  " .. path)
        ok = ok + 1
    else
        print("  ERR " .. path)
        fail = fail + 1
    end
end

print(string.format("\nDone: %d ok, %d failed.", ok, fail))
if fail == 0 then
    print("Run:  main")
end
