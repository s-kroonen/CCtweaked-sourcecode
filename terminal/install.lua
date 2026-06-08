-- terminal/install.lua
-- Run on the pocket computer to install Basalt and the config tool.
-- Usage:  wget run https://raw.githubusercontent.com/s-kroonen/CCtweaked-sourcecode/master/terminal/install.lua

local REPO = "https://raw.githubusercontent.com/s-kroonen/CCtweaked-sourcecode/master"

-- Step 1: install Basalt if not already present
if not fs.exists("basalt.lua") and not fs.exists("basalt") then
    print("Installing Basalt...")
    local ok = shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua packed")
    if not ok then
        printError("Basalt install failed. Check HTTP is enabled in server config.")
        return
    end
    print("Basalt installed.")
else
    print("Basalt already installed, skipping.")
end

-- Step 2: download the config tool files
local FILES = {
    "terminal/main.lua",
    "terminal/comms.lua",
}

local function mkdir(path)
    local parts = {}
    for p in path:gmatch("[^/]+") do parts[#parts+1] = p end
    table.remove(parts)   -- drop filename
    local cur = ""
    for _, p in ipairs(parts) do
        cur = cur == "" and p or (cur .. "/" .. p)
        if not fs.exists(cur) then fs.makeDir(cur) end
    end
end

print("Downloading config tool...")
local ok, fail = 0, 0
for _, path in ipairs(FILES) do
    local resp = http.get(REPO .. "/" .. path)
    if resp then
        mkdir(path)
        local f = fs.open(path, "w")
        f.write(resp.readAll())
        f.close()
        resp.close()
        print("  OK  " .. path)
        ok = ok + 1
    else
        printError("  ERR " .. path)
        fail = fail + 1
    end
end

-- Step 3: write startup so the tool launches on boot
local sf = fs.open("startup.lua", "w")
sf.write('shell.run("terminal/main")\n')
sf.close()

print(string.format("\nDone: %d ok, %d failed.", ok, fail))
if fail == 0 then
    print("Rebooting in 2 seconds...")
    sleep(2)
    os.reboot()
end
