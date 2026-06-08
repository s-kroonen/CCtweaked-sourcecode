-- terminal/comms.lua
-- Rednet helpers. Auto-detects the first wireless (ender) modem.

local PROTOCOL = "blimp_cfg"
local TIMEOUT  = 3   -- seconds

local comms    = {}
local _shipId  = nil

-- Open rednet on the first wireless modem found.
-- Returns true, sideName  or  false, nil.
function comms.open()
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

-- Broadcast a ping and wait for the first ship to reply.
-- Returns the ship's computer ID, or nil on timeout.
function comms.findShip()
    rednet.broadcast({cmd = "ping"}, PROTOCOL)
    local sender, msg = rednet.receive(PROTOCOL, TIMEOUT)
    if sender and type(msg) == "table" and msg.cmd == "pong" then
        _shipId = sender
        return sender
    end
    return nil
end

function comms.shipId()
    return _shipId
end

-- Fetch config_data from the ship.
-- Returns table, nil  or  nil, errorString.
function comms.getConfig()
    if not _shipId then return nil, "not connected" end
    rednet.send(_shipId, {cmd = "get"}, PROTOCOL)
    local _, msg = rednet.receive(PROTOCOL, TIMEOUT)
    if not msg then return nil, "timeout" end
    if msg.cmd ~= "data" then
        return nil, "unexpected reply: " .. tostring(msg.cmd)
    end
    local data = textutils.unserialize(msg.payload or "")
    if type(data) ~= "table" then return nil, "bad payload" end
    return data, nil
end

-- Push config_data to the ship.
-- Returns true  or  nil, errorString.
function comms.setConfig(data)
    if not _shipId then return nil, "not connected" end
    rednet.send(_shipId, {
        cmd     = "set",
        payload = textutils.serialize(data),
    }, PROTOCOL)
    local _, msg = rednet.receive(PROTOCOL, TIMEOUT)
    if not msg then return nil, "timeout" end
    if msg.cmd == "ack" then return true end
    return nil, msg.msg or "ship error"
end

return comms
