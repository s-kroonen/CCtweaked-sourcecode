-- terminal/main.lua
-- Pocket-computer blimp config tool.
-- Navigate with arrow keys.  Enter = select/edit.  Backspace = back.

local gui   = require("terminal.gui")
local comms = require("terminal.comms")

local W, H = gui.size()

-- ── State ─────────────────────────────────────────────────────────────────────

local data = {
    liftSources = {},
    propellers  = {},
    sensors     = {
        altitude = "altitude_sensor_0",
        gimbal   = "gimbal_sensor_0",
        velocity = {},
    },
    input = {
        steeringWheel       = "steering_wheel_0",
        throttleLever       = "throttle_lever_0",
        altitudeRatePerUnit = 0.5,
        maxTranslation      = 0.8,
        maxYaw              = 0.6,
    },
}
local connected = false
local statusMsg = "Not connected"

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function setStatus(msg) statusMsg = msg end

local function clampStr(s, n)
    return tostring(s or ""):sub(1, n)
end

-- Draw a two-button footer: left=A label, right=B label
local function footer(left, right)
    term.setCursorPos(1, H)
    term.setBackgroundColor(gui.COL.ok)
    term.setTextColor(gui.COL.okTx)
    local l = (" " .. left  .. " "):sub(1, math.floor(W / 2))
    term.write(l .. string.rep(" ", math.floor(W / 2) - #l))
    term.setBackgroundColor(gui.COL.cancel)
    term.setTextColor(gui.COL.cancelTx)
    local r = (" " .. right .. " "):sub(1, W - math.floor(W / 2))
    term.write(r .. string.rep(" ", W - math.floor(W / 2) - #r))
    term.setBackgroundColor(gui.COL.bg)
    term.setTextColor(gui.COL.itemTx)
end

-- ── Position calculator screen ────────────────────────────────────────────────
-- Enter world coords for center and for the block; returns {x, z} relative.
local function posCalc(currentPos)
    local cx, cz = 0, 0
    local bx, bz = currentPos and currentPos.x or 0,
                   currentPos and currentPos.z or 0

    while true do
        gui.clear()
        gui.header("Pos Calculator")
        term.setCursorPos(1, 3)
        term.setTextColor(gui.COL.labelTx)
        term.write("Craft center (world XZ):")
        gui.fieldRow("Center X", cx, 4, false)
        gui.fieldRow("Center Z", cz, 5, false)
        term.setCursorPos(1, 7)
        term.write("Block (world XZ):")
        gui.fieldRow("Block X",  bx, 8, false)
        gui.fieldRow("Block Z",  bz, 9, false)
        term.setCursorPos(1, 11)
        term.setTextColor(gui.COL.ok)
        term.write(string.format("Relative: x=%-6s z=%s",
            tostring(bx - cx), tostring(bz - cz)))
        gui.status("E=edit  Enter=confirm  Bksp=back")

        local _, key = os.pullEvent("key")
        if key == keys.e then
            cx = tonumber(gui.prompt("Ctr X", cx, 4)) or cx
            cz = tonumber(gui.prompt("Ctr Z", cz, 5)) or cz
            bx = tonumber(gui.prompt("Blk X", bx, 8)) or bx
            bz = tonumber(gui.prompt("Blk Z", bz, 9)) or bz
        elseif key == keys.enter then
            return {x = bx - cx, z = bz - cz}
        elseif key == keys.backspace then
            return currentPos
        end
    end
end

-- ── Propeller editor ──────────────────────────────────────────────────────────
local PROP_FIELDS = {"id","controller","facing","pos_x","pos_z"}
local PROP_LABELS = {id="ID", controller="Ctrl", facing="Facing",
                     pos_x="Pos X", pos_z="Pos Z"}

local function editPropeller(prop)
    prop = prop or {id="",controller="",facing="north",position={x=0,z=0}}
    -- working copy
    local p = {
        id         = prop.id or "",
        controller = prop.controller or "",
        facing     = prop.facing or "north",
        pos_x      = tostring(prop.position and prop.position.x or 0),
        pos_z      = tostring(prop.position and prop.position.z or 0),
    }
    local sel = 1

    while true do
        gui.clear()
        gui.header("Edit Propeller")
        for i, key in ipairs(PROP_FIELDS) do
            gui.fieldRow(PROP_LABELS[key], p[key], i + 2, i == sel)
        end
        -- Pos calculator shortcut row
        term.setCursorPos(1, #PROP_FIELDS + 4)
        term.setBackgroundColor(gui.COL.field)
        term.setTextColor(gui.COL.fieldTx)
        term.write(" C = open position calculator ")
        term.setBackgroundColor(gui.COL.bg)
        footer("Save (Enter)", "Cancel (Bksp)")

        local _, key = os.pullEvent("key")

        if key == keys.up   then sel = math.max(1, sel - 1)
        elseif key == keys.down  then sel = math.min(#PROP_FIELDS, sel + 1)
        elseif key == keys.backspace then return nil  -- cancel

        elseif key == keys.c then
            local r = posCalc({x = tonumber(p.pos_x) or 0,
                               z = tonumber(p.pos_z) or 0})
            if r then p.pos_x = tostring(r.x); p.pos_z = tostring(r.z) end

        elseif key == keys.enter then
            local field = PROP_FIELDS[sel]
            if field == "facing" then
                local f = gui.pickFacing(p.facing)
                if f then p.facing = f end
            else
                p[field] = gui.prompt(PROP_LABELS[field], p[field],
                                      sel + 2) or p[field]
            end

        elseif key == keys.s then
            -- s = save from anywhere in the form
            local ok2 = p.id ~= "" and p.controller ~= ""
            if not ok2 then
                setStatus("ID and Ctrl required")
            else
                return {
                    id         = p.id,
                    controller = p.controller,
                    facing     = p.facing,
                    position   = {
                        x = tonumber(p.pos_x) or 0,
                        z = tonumber(p.pos_z) or 0,
                    },
                }
            end
        end
    end
end

-- ── Lift source editor ────────────────────────────────────────────────────────
local function editLiftSource(src)
    src = src or {id="",position={x=0,z=0}}
    local p = {
        id    = src.id or "",
        pos_x = tostring(src.position and src.position.x or 0),
        pos_z = tostring(src.position and src.position.z or 0),
    }
    local fields  = {"id","pos_x","pos_z"}
    local labels  = {id="ID", pos_x="Pos X", pos_z="Pos Z"}
    local sel = 1

    while true do
        gui.clear()
        gui.header("Edit Lift Source")
        for i, key in ipairs(fields) do
            gui.fieldRow(labels[key], p[key], i + 2, i == sel)
        end
        term.setCursorPos(1, #fields + 4)
        term.setBackgroundColor(gui.COL.field)
        term.setTextColor(gui.COL.fieldTx)
        term.write(" C = open position calculator ")
        term.setBackgroundColor(gui.COL.bg)
        footer("Save (S key)", "Cancel (Bksp)")

        local _, key = os.pullEvent("key")
        if key == keys.up   then sel = math.max(1, sel - 1)
        elseif key == keys.down  then sel = math.min(#fields, sel + 1)
        elseif key == keys.backspace then return nil
        elseif key == keys.c then
            local r = posCalc({x = tonumber(p.pos_x) or 0,
                               z = tonumber(p.pos_z) or 0})
            if r then p.pos_x = tostring(r.x); p.pos_z = tostring(r.z) end
        elseif key == keys.enter then
            p[fields[sel]] = gui.prompt(labels[fields[sel]], p[fields[sel]],
                                        sel + 2) or p[fields[sel]]
        elseif key == keys.s then
            if p.id == "" then setStatus("ID required") else
                return {
                    id       = p.id,
                    position = {x = tonumber(p.pos_x) or 0,
                                z = tonumber(p.pos_z) or 0},
                }
            end
        end
    end
end

-- ── Generic list manager ──────────────────────────────────────────────────────
-- items: list, title: string, editFn: function(item)->item|nil
local function listScreen(title, items, editFn)
    local sel = math.max(1, math.min(#items, 1))

    local function makeLabels()
        local out = {}
        for i, item in ipairs(items) do
            local label = clampStr(item.id, 18)
            if item.facing then
                label = label .. "  " .. item.facing
            end
            out[i] = label
        end
        return out
    end

    while true do
        local labels = makeLabels()
        gui.clear()
        gui.header(title .. " (" .. #items .. ")")
        local listEnd = H - 2
        if #items > 0 then
            gui.drawList(labels, sel, 2, listEnd)
        else
            term.setCursorPos(1, 3)
            term.setTextColor(gui.COL.labelTx)
            term.write("  (empty — press A to add)")
        end
        gui.status("A=add  E=edit  D=del  Bksp=back")

        local _, key = os.pullEvent("key")
        if key == keys.backspace then
            return items

        elseif key == keys.up then
            sel = math.max(1, sel - 1)
        elseif key == keys.down then
            sel = math.min(math.max(#items, 1), sel + 1)

        elseif key == keys.a then
            local newItem = editFn(nil)
            if newItem then
                items[#items + 1] = newItem
                sel = #items
                setStatus("Added " .. tostring(newItem.id))
            end

        elseif key == keys.e then
            if items[sel] then
                local edited = editFn(items[sel])
                if edited then
                    items[sel] = edited
                    setStatus("Saved " .. tostring(edited.id))
                end
            end

        elseif key == keys.d then
            if items[sel] and gui.confirm("Delete " .. clampStr(items[sel].id, 14) .. "?") then
                table.remove(items, sel)
                sel = math.max(1, math.min(#items, sel))
                setStatus("Deleted")
            end
        end
    end
end

-- ── Sensors screen ────────────────────────────────────────────────────────────
local SENS_FIELDS = {"altitude","gimbal","vel0","vel1","vel2"}
local SENS_LABELS = {altitude="Alt sens", gimbal="Gimbal",
                     vel0="Vel X", vel1="Vel Y", vel2="Vel Z"}

local function sensorsScreen()
    local s = data.sensors
    local p = {
        altitude = s.altitude or "",
        gimbal   = s.gimbal   or "",
        vel0     = s.velocity and s.velocity[1] or "",
        vel1     = s.velocity and s.velocity[2] or "",
        vel2     = s.velocity and s.velocity[3] or "",
    }
    local sel = 1

    while true do
        gui.clear()
        gui.header("Sensors")
        for i, key in ipairs(SENS_FIELDS) do
            gui.fieldRow(SENS_LABELS[key], p[key], i + 2, i == sel)
        end
        footer("Save (S key)", "Cancel (Bksp)")

        local _, key = os.pullEvent("key")
        if key == keys.up   then sel = math.max(1, sel - 1)
        elseif key == keys.down  then sel = math.min(#SENS_FIELDS, sel + 1)
        elseif key == keys.backspace then return
        elseif key == keys.enter then
            local f = SENS_FIELDS[sel]
            p[f] = gui.prompt(SENS_LABELS[f], p[f], sel + 2) or p[f]
        elseif key == keys.s then
            data.sensors = {
                altitude = p.altitude,
                gimbal   = p.gimbal,
                velocity = {p.vel0, p.vel1, p.vel2},
            }
            setStatus("Sensors saved")
            return
        end
    end
end

-- ── Input devices screen ──────────────────────────────────────────────────────
local INP_FIELDS = {"steeringWheel","throttleLever","altitudeRatePerUnit",
                    "maxTranslation","maxYaw"}
local INP_LABELS = {steeringWheel="Wheel", throttleLever="Lever",
                    altitudeRatePerUnit="AltRate", maxTranslation="MaxTrans",
                    maxYaw="MaxYaw"}

local function inputScreen()
    local inp = data.input
    local p = {}
    for _, f in ipairs(INP_FIELDS) do
        p[f] = tostring(inp[f] or "")
    end
    local sel = 1

    while true do
        gui.clear()
        gui.header("Input Devices")
        for i, key in ipairs(INP_FIELDS) do
            gui.fieldRow(INP_LABELS[key], p[key], i + 2, i == sel)
        end
        footer("Save (S key)", "Cancel (Bksp)")

        local _, key = os.pullEvent("key")
        if key == keys.up   then sel = math.max(1, sel - 1)
        elseif key == keys.down  then sel = math.min(#INP_FIELDS, sel + 1)
        elseif key == keys.backspace then return
        elseif key == keys.enter then
            local f = INP_FIELDS[sel]
            p[f] = gui.prompt(INP_LABELS[f], p[f], sel + 2) or p[f]
        elseif key == keys.s then
            data.input = {
                steeringWheel       = p.steeringWheel,
                throttleLever       = p.throttleLever,
                altitudeRatePerUnit = tonumber(p.altitudeRatePerUnit) or 0.5,
                maxTranslation      = tonumber(p.maxTranslation) or 0.8,
                maxYaw              = tonumber(p.maxYaw) or 0.6,
            }
            setStatus("Input saved")
            return
        end
    end
end

-- ── Main menu ─────────────────────────────────────────────────────────────────
local MENU = {
    "Connect to ship",
    "Lift sources",
    "Propellers",
    "Sensors",
    "Input devices",
    "─────────────",
    "Push to ship",
    "Pull from ship",
    "Save locally",
}

local function mainMenu()
    local sel = 1
    while true do
        gui.clear()
        gui.header("Blimp Config")
        -- Connection line
        term.setCursorPos(1, 2)
        term.setTextColor(connected and gui.COL.ok or gui.COL.cancel)
        term.setBackgroundColor(gui.COL.bg)
        local shipTxt = connected
            and "Ship #" .. tostring(comms.shipId())
            or  "Not connected"
        term.write((" Ship: " .. shipTxt):sub(1, W))
        term.setTextColor(gui.COL.itemTx)

        local labels = {}
        for _, v in ipairs(MENU) do labels[#labels+1] = "  " .. v end
        gui.drawList(labels, sel, 3, H - 1)
        gui.status(statusMsg:sub(1, W))

        local _, key = os.pullEvent("key")
        if key == keys.up   then
            sel = math.max(1, sel - 1)
            if MENU[sel]:sub(1,1) == "─" then sel = math.max(1, sel - 1) end
        elseif key == keys.down then
            sel = math.min(#MENU, sel + 1)
            if MENU[sel] and MENU[sel]:sub(1,1) == "─" then
                sel = math.min(#MENU, sel + 1)
            end
        elseif key == keys.enter then
            local choice = MENU[sel]

            if choice == "Connect to ship" then
                setStatus("Scanning...")
                gui.clear(); gui.header("Connecting...")
                term.setCursorPos(1,3); term.write("Broadcasting ping...")
                local id = comms.findShip()
                if id then
                    connected = true
                    setStatus("Connected to #" .. id)
                else
                    connected = false
                    setStatus("No ship found")
                end

            elseif choice == "Lift sources" then
                data.liftSources = listScreen("Lift Sources",
                    data.liftSources, editLiftSource)

            elseif choice == "Propellers" then
                data.propellers = listScreen("Propellers",
                    data.propellers, editPropeller)

            elseif choice == "Sensors" then
                sensorsScreen()

            elseif choice == "Input devices" then
                inputScreen()

            elseif choice == "Push to ship" then
                if not connected then
                    setStatus("Connect first")
                else
                    local ok, err = comms.setConfig(data)
                    setStatus(ok and "Pushed OK" or ("Push failed: " .. tostring(err)))
                end

            elseif choice == "Pull from ship" then
                if not connected then
                    setStatus("Connect first")
                else
                    local d, err = comms.getConfig()
                    if d then
                        data = d
                        setStatus("Pulled OK")
                    else
                        setStatus("Pull failed: " .. tostring(err))
                    end
                end

            elseif choice == "Save locally" then
                local f = fs.open("config_data.lua", "w")
                f.write("return " .. textutils.serialize(data))
                f.close()
                setStatus("Saved to config_data.lua")
            end
        end
    end
end

-- ── Boot ──────────────────────────────────────────────────────────────────────

gui.clear()
gui.header("Blimp Config")
term.setCursorPos(1, 3)
term.write("Opening modem...")
local ok, side = comms.open()
if ok then
    term.setCursorPos(1, 4)
    term.write("Modem on " .. tostring(side))
else
    term.setCursorPos(1, 4)
    term.setTextColor(colours.red)
    term.write("No modem — wireless disabled")
    term.setTextColor(colours.white)
end
sleep(0.6)

mainMenu()
