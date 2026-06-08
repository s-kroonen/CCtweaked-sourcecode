-- terminal/install.lua
-- Run on the pocket computer once to download the config tool from GitHub.
-- Usage:  wget run https://raw.githubusercontent.com/s-kroonen/CCtweaked-sourcecode/master/terminal/install.lua

local REPO = "https://raw.githubusercontent.com/s-kroonen/CCtweaked-sourcecode/master"

local FILES = {
    "terminal/main.lua",
    "terminal/gui.lua",
    "terminal/comms.lua",
}

-- Entry point: run as  terminal/main
local STARTUP = [[shell.run("terminal/main")]]

local function mkdir(path)
    local parts = {}
    for p in path:gmatch("[^/]+") do parts[#parts+1] = p end
    table.remove(parts)
    local cur = ""
    for _, p in ipairs(parts) do
        cur = cur == "" and p or (cur .. "/" .. p)
        if not fs.exists(cur) then fs.makeDir(cur) end
    end
end

print("Installing blimp config terminal...")
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

-- Write startup file so the tool launches on boot
local sf = fs.open("startup.lua", "w")
sf.write(STARTUP)
sf.close()

print(string.format("\nDone: %d ok, %d failed.", ok, fail))
if fail == 0 then
    print("Reboot to launch, or run:  terminal/main")
end
