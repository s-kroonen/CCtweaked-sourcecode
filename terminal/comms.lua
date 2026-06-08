-- terminal/comms.lua
-- Rednet helpers for the pocket-computer config tool.

local PROTOCOL = "blimp_cfg"
local TIMEOUT  = 3   -- seconds to wait for a reply

local comms = {}
local _shipId = nil   -- cached ship computer ID

-- Open rednet on the first available modem.
function comms.open()
    for _, side in ipairs({"top","bottom","left","right","front","back"}) do
        if peripheral.isPresent(side) then
            local t = peripheral.getType(side)
            if t == "modem" then
                rednet.open(side)
                return true, side
            end
        end
    end
    return false, nil
end

-- Broadcast a ping and collect the first "pong" reply.
-- Returns shipId (number) or nil on timeout.
function comms.findShip()
    rednet.broadcast({cmd="ping"}, PROTOCOL)
    local sender, msg = rednet.receive(PROTOCOL, TIMEOUT)
    if sender and type(msg) == "table" and msg.cmd == "pong" then
        _shipId = sender
        return sender
    end
    return nil
end

function comms.shipId() return _shipId end

-- Fetch config data from ship. Returns table or nil, errMsg.
function comms.getConfig()
    if not _shipId then return nil, "not connected" end
    rednet.send(_shipId, {cmd="get"}, PROTOCOL)
    local _, msg = rednet.receive(PROTOCOL, TIMEOUT)
    if not msg then return nil, "timeout" end
    if msg.cmd ~= "data" then return nil, "unexpected reply: " .. tostring(msg.cmd) end
    local ok, data = pcall(textutils.unserialize, msg.payload or "")
    if not ok or type(data) ~= "table" then return nil, "bad payload" end
    return data, nil
end

-- Push config data to ship. Returns true or nil, errMsg.
function comms.setConfig(data)
    if not _shipId then return nil, "not connected" end
    rednet.send(_shipId, {
        cmd     = "set",
        payload = textutils.serialize(data),
    }, PROTOCOL)
    local _, msg = rednet.receive(PROTOCOL, TIMEOUT)
    if not msg then return nil, "timeout" end
    if msg.cmd == "ack" then return true end
    return nil, msg.msg or "error"
end

return comms
