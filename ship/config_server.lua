-- ship/config_server.lua
-- Rednet config server.  Runs as a coroutine inside main.lua.
-- Terminal tool connects wirelessly to read/write config_data.lua.
--
-- Protocol (all messages use protocol label "blimp_cfg"):
--   Terminal → Ship   {cmd="ping"}
--   Ship     → Term   {cmd="pong", id=<computer id>}
--
--   Terminal → Ship   {cmd="get"}
--   Ship     → Term   {cmd="data", payload=<textutils.serialize(data)>}
--
--   Terminal → Ship   {cmd="set", payload=<textutils.serialize(data)>}
--   Ship     → Term   {cmd="ack"} | {cmd="err", msg=<string>}

local PROTOCOL   = "blimp_cfg"
local DATA_FILE  = "config_data.lua"
local MODEM_SIDE = "back"   -- change to whichever side the wireless modem is on

local function openModem()
    if peripheral.isPresent(MODEM_SIDE) and
       peripheral.getType(MODEM_SIDE) == "modem" then
        rednet.open(MODEM_SIDE)
        return true
    end
    -- Try any available modem
    for _, side in ipairs({"top","bottom","left","right","front","back"}) do
        if peripheral.isPresent(side) and
           peripheral.getType(side) == "modem" then
            rednet.open(side)
            MODEM_SIDE = side
            return true
        end
    end
    return false
end

local function loadData()
    if not fs.exists(DATA_FILE) then return {} end
    local f = fs.open(DATA_FILE, "r")
    local src = f.readAll()
    f.close()
    -- File is written as: return <serialized table>
    local fn = load(src)
    if not fn then return {} end
    local ok, val = pcall(fn)
    return ok and type(val) == "table" and val or {}
end

local function saveData(data)
    local f = fs.open(DATA_FILE, "w")
    f.write("return " .. textutils.serialize(data))
    f.close()
end

local function run()
    if not openModem() then
        print("[cfg_server] No wireless modem found; config tool disabled.")
        return
    end
    print("[cfg_server] Listening on " .. MODEM_SIDE .. "  id=" .. os.getComputerID())

    while true do
        local sender, msg = rednet.receive(PROTOCOL, 5)
        if sender and type(msg) == "table" then
            if msg.cmd == "ping" then
                rednet.send(sender, {cmd="pong", id=os.getComputerID()}, PROTOCOL)

            elseif msg.cmd == "get" then
                local data = loadData()
                rednet.send(sender, {
                    cmd     = "data",
                    payload = textutils.serialize(data),
                }, PROTOCOL)

            elseif msg.cmd == "set" then
                local ok2, data = pcall(textutils.unserialize, msg.payload or "")
                if ok2 and type(data) == "table" then
                    saveData(data)
                    rednet.send(sender, {cmd="ack"}, PROTOCOL)
                    print("[cfg_server] config_data.lua updated by terminal " .. sender)
                else
                    rednet.send(sender, {cmd="err", msg="bad payload"}, PROTOCOL)
                end
            end
        end
    end
end

return { run = run }
