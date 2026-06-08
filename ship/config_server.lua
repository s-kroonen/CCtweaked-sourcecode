-- ship/config_server.lua
-- Rednet config server coroutine. Started inside main.lua's parallel.waitForAll.
-- Auto-detects the first wireless (ender) modem.
--
-- Protocol (label "blimp_cfg"):
--   {cmd="ping"}                           → {cmd="pong", id=<number>}
--   {cmd="get"}                            → {cmd="data", payload=<string>}
--   {cmd="set", payload=<string>}          → {cmd="ack"} | {cmd="err", msg=<string>}

local PROTOCOL  = "blimp_cfg"
local DATA_FILE = "config_data.lua"

local function openModem()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "modem" then
            local m = peripheral.wrap(name)
            if m and m.isWireless() then
                rednet.open(name)
                return true, name
            end
        end
    end
    return false, nil
end

local function loadData()
    if not fs.exists(DATA_FILE) then return {} end
    local f   = fs.open(DATA_FILE, "r")
    local src = f.readAll()
    f.close()
    local data = textutils.unserialize(src)
    return type(data) == "table" and data or {}
end

local function saveData(data)
    local f = fs.open(DATA_FILE, "w")
    f.write("return " .. textutils.serialize(data))
    f.close()
end

local function run()
    local ok, side = openModem()
    if not ok then
        print("[cfg_server] No wireless modem — config tool disabled.")
        return
    end
    print("[cfg_server] Ready on modem '" .. side .. "'  id=" .. os.getComputerID())

    while true do
        local sender, msg = rednet.receive(PROTOCOL, 5)
        if sender and type(msg) == "table" then

            if msg.cmd == "ping" then
                rednet.send(sender, {cmd = "pong", id = os.getComputerID()}, PROTOCOL)

            elseif msg.cmd == "get" then
                local data = loadData()
                rednet.send(sender, {
                    cmd     = "data",
                    payload = textutils.serialize(data),
                }, PROTOCOL)

            elseif msg.cmd == "set" then
                local data = textutils.unserialize(msg.payload or "")
                if type(data) == "table" then
                    saveData(data)
                    rednet.send(sender, {cmd = "ack"}, PROTOCOL)
                    print("[cfg_server] config_data.lua updated by #" .. sender)
                else
                    rednet.send(sender, {cmd = "err", msg = "bad payload"}, PROTOCOL)
                end
            end
        end
    end
end

return { run = run }
