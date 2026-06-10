-- terminal/main.lua
-- Pocket-computer blimp config tool built with Basalt 2.
-- Install Basalt first:  wget run https://basalt.madefor.cc/install.lua packed

-- ── Basalt check ──────────────────────────────────────────────────────────────
if not fs.exists("basalt.lua") and not fs.exists("basalt") then
    printError("Basalt is not installed.")
    printError("Run: wget run https://basalt.madefor.cc/install.lua packed")
    printError("Then reboot and try again.")
    return
end

local basalt = require("./basalt")
local comms  = require("comms")

local W, H = term.getSize()

-- ── Config data (working copy in memory) ──────────────────────────────────────
local data = {
    liftSources  = {},
    propellers   = {},
    craftFacing  = "north",
    sensors = {
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

-- Ensure all required fields exist after loading from any source.
local HORIZ_FACINGS = {"north", "south", "east", "west"}
local function sanitizeData(d)
    d.liftSources = d.liftSources or {}
    d.propellers  = d.propellers  or {}
    d.sensors     = d.sensors     or {}
    d.sensors.altitude = d.sensors.altitude or ""
    d.sensors.gimbal   = d.sensors.gimbal   or ""
    d.sensors.velocity = d.sensors.velocity or {}
    d.input = d.input or {}
    d.input.steeringWheel       = d.input.steeringWheel       or ""
    d.input.throttleLever       = d.input.throttleLever       or ""
    d.input.altitudeRatePerUnit = d.input.altitudeRatePerUnit or 0.5
    d.input.maxTranslation      = d.input.maxTranslation      or 0.8
    d.input.maxYaw              = d.input.maxYaw              or 0.6
    -- Validate craftFacing — fall back to "north" if unknown
    local validFacing = false
    for _, f in ipairs(HORIZ_FACINGS) do
        if d.craftFacing == f then validFacing = true; break end
    end
    if not validFacing then d.craftFacing = "north" end
    return d
end

-- ── Colours ───────────────────────────────────────────────────────────────────
local COL = {
    bg      = colours.black,
    tx      = colours.white,
    hdr     = colours.blue,
    hdrTx   = colours.white,
    btn     = colours.grey,
    btnTx   = colours.white,
    ok      = colours.green,
    okTx    = colours.black,
    danger  = colours.red,
    dangerTx= colours.white,
    field   = colours.grey,
    sub     = colours.lightGrey,
    statusTx= colours.yellow,
    conn    = colours.lime,
    noconn  = colours.red,
}

-- ── Facing cycle ──────────────────────────────────────────────────────────────
local FACINGS = {"north","south","east","west","up","down"}
local function nextFacing(f)
    for i, v in ipairs(FACINGS) do
        if v == f then return FACINGS[i % #FACINGS + 1] end
    end
    return "north"
end

-- ── Frame registry & screen switcher ─────────────────────────────────────────
local allFrames = {}
local function switchTo(frame)
    for _, f in ipairs(allFrames) do f:setVisible(false) end
    frame:setVisible(true)
end

-- ── Root BaseFrame ────────────────────────────────────────────────────────────
local root = basalt.getMainFrame():setBackground(COL.bg)

-- ── Shared element builders ───────────────────────────────────────────────────
local function addHeader(frame, title)
    frame:addLabel()
        :setPosition(1, 1):setSize(W, 1)
        :setBackground(COL.hdr):setForeground(COL.hdrTx)
        :setText(title)
end

local function addBtn(frame, text, x, y, w, bg, fg, cb)
    return frame:addButton()
        :setPosition(x, y):setSize(w, 1)
        :setBackground(bg):setForeground(fg)
        :setText(text)
        :onClick(cb)
end

local function addLbl(frame, text, x, y, w, fg, bg)
    return frame:addLabel()
        :setPosition(x, y):setSize(w or W - x + 1, 1)
        :setBackground(bg or COL.bg):setForeground(fg or COL.tx)
        :setText(text)
end

local function addInp(frame, x, y, w, placeholder)
    return frame:addInput()
        :setPosition(x, y):setSize(w, 1)
        :setBackground(COL.field):setForeground(COL.tx)
        :setPlaceholder(placeholder or "")
end

-- ── Status label (shared, lives on root, always visible) ─────────────────────
local statusLbl = root:addLabel()
    :setPosition(1, H):setSize(W, 1)
    :setBackground(COL.bg):setForeground(COL.statusTx)
    :setText("Starting...")

local function setStatus(msg)
    statusLbl:setText(tostring(msg):sub(1, W))
    sleep(0)   -- yield so Basalt's event loop can flush the render before we continue
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSITION CALCULATOR SCREEN
-- ═══════════════════════════════════════════════════════════════════════════════
local posCalcFrame = root:addFrame()
    :setPosition(1, 1):setSize(W, H - 1)
    :setBackground(COL.bg):setVisible(false)
allFrames[#allFrames+1] = posCalcFrame

local _posCalcCB = nil   -- callback(relX, relZ) or (nil) on cancel

local posCalcInputs = {}
local posCalcResult

do
    addHeader(posCalcFrame, "Position Calc")
    addLbl(posCalcFrame, "Craft center (world XZ):", 1, 2, W, COL.sub)
    addLbl(posCalcFrame, "X:", 1, 3, 3, COL.sub)
    posCalcInputs.cx = addInp(posCalcFrame, 3, 3, 10, "0")
    addLbl(posCalcFrame, "Z:", 14, 3, 3, COL.sub)
    posCalcInputs.cz = addInp(posCalcFrame, 16, 3, 10, "0")

    addLbl(posCalcFrame, "Block position (world XZ):", 1, 5, W, COL.sub)
    addLbl(posCalcFrame, "X:", 1, 6, 3, COL.sub)
    posCalcInputs.bx = addInp(posCalcFrame, 3, 6, 10, "0")
    addLbl(posCalcFrame, "Z:", 14, 6, 3, COL.sub)
    posCalcInputs.bz = addInp(posCalcFrame, 16, 6, 10, "0")

    posCalcResult = addLbl(posCalcFrame, "Relative: x=0  z=0", 1, 8, W, COL.ok)

    local function recalc()
        local cx = tonumber(posCalcInputs.cx:getText()) or 0
        local cz = tonumber(posCalcInputs.cz:getText()) or 0
        local bx = tonumber(posCalcInputs.bx:getText()) or 0
        local bz = tonumber(posCalcInputs.bz:getText()) or 0
        posCalcResult:setText(string.format("Relative: x=%d  z=%d", bx-cx, bz-cz))
    end

    posCalcInputs.cx:onChange("text", recalc)
    posCalcInputs.cz:onChange("text", recalc)
    posCalcInputs.bx:onChange("text", recalc)
    posCalcInputs.bz:onChange("text", recalc)

    addBtn(posCalcFrame, "Apply", 1, 10, 7, COL.ok, COL.okTx, function()
        local cx = tonumber(posCalcInputs.cx:getText()) or 0
        local cz = tonumber(posCalcInputs.cz:getText()) or 0
        local bx = tonumber(posCalcInputs.bx:getText()) or 0
        local bz = tonumber(posCalcInputs.bz:getText()) or 0
        if _posCalcCB then _posCalcCB(bx - cx, bz - cz) end
    end)
    addBtn(posCalcFrame, "Cancel", 10, 10, 8, COL.btn, COL.btnTx, function()
        if _posCalcCB then _posCalcCB(nil) end
    end)
end

local function openPosCalc(curX, curZ, returnFrame, callback)
    _posCalcCB = function(rx, rz)
        _posCalcCB = nil
        switchTo(returnFrame)
        if rx ~= nil and callback then callback(rx, rz) end
    end
    -- pre-fill block position with current values
    posCalcInputs.bx:setText(tostring(curX or 0))
    posCalcInputs.bz:setText(tostring(curZ or 0))
    switchTo(posCalcFrame)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PROPELLER EDIT SCREEN
-- ═══════════════════════════════════════════════════════════════════════════════
local propEditFrame = root:addFrame()
    :setPosition(1, 1):setSize(W, H - 1)
    :setBackground(COL.bg):setVisible(false)
allFrames[#allFrames+1] = propEditFrame

local propEditInputs = {}
local propFacingBtn
local propFacingVal = "north"
local propEditIndex = nil

local function refreshPropFacingBtn()
    propFacingBtn:setText("Facing: " .. propFacingVal .. " (click to cycle)")
end

do
    addHeader(propEditFrame, "Edit Propeller")
    addLbl(propEditFrame, "Peripheral ID:", 1, 2, W, COL.sub)
    propEditInputs.id = addInp(propEditFrame, 1, 3, W, "propeller_0")

    addLbl(propEditFrame, "Speed controller ID:", 1, 4, W, COL.sub)
    propEditInputs.controller = addInp(propEditFrame, 1, 5, W, "Create_RotationSpeedController_0")

    addLbl(propEditFrame, "Facing direction:", 1, 6, W, COL.sub)
    propFacingBtn = addBtn(propEditFrame,
        "Facing: north (click to cycle)", 1, 7, W, COL.field, COL.tx,
        function()
            propFacingVal = nextFacing(propFacingVal)
            refreshPropFacingBtn()
        end)

    addLbl(propEditFrame, "Relative position from craft center:", 1, 8, W, COL.sub)
    addLbl(propEditFrame, "X:", 1, 9, 2, COL.sub)
    propEditInputs.pos_x = addInp(propEditFrame, 3, 9, 10, "0")
    addLbl(propEditFrame, "Z:", 14, 9, 2, COL.sub)
    propEditInputs.pos_z = addInp(propEditFrame, 16, 9, 10, "0")

    addBtn(propEditFrame, "[Pos Calc]", 1, 10, 11, COL.btn, COL.btnTx, function()
        openPosCalc(
            tonumber(propEditInputs.pos_x:getText()) or 0,
            tonumber(propEditInputs.pos_z:getText()) or 0,
            propEditFrame,
            function(rx, rz)
                propEditInputs.pos_x:setText(tostring(rx))
                propEditInputs.pos_z:setText(tostring(rz))
            end
        )
    end)

    addBtn(propEditFrame, "Save", 1, 12, 6, COL.ok, COL.okTx, function()
        local id   = propEditInputs.id:getText()
        local ctrl = propEditInputs.controller:getText()
        if id == "" or ctrl == "" then
            setStatus("ID and controller are required")
            return
        end
        local entry = {
            id         = id,
            controller = ctrl,
            facing     = propFacingVal,
            position   = {
                x = tonumber(propEditInputs.pos_x:getText()) or 0,
                z = tonumber(propEditInputs.pos_z:getText()) or 0,
            },
        }
        if propEditIndex then
            data.propellers[propEditIndex] = entry
        else
            data.propellers[#data.propellers + 1] = entry
        end
        setStatus("Saved: " .. id)
        switchTo(propListFrame)   -- defined below, forward ref resolved at runtime
    end)

    addBtn(propEditFrame, "Cancel", 9, 12, 8, COL.btn, COL.btnTx, function()
        switchTo(propListFrame)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PROPELLER LIST SCREEN
-- ═══════════════════════════════════════════════════════════════════════════════
propListFrame = root:addFrame()   -- used by propEditFrame callbacks above
    :setPosition(1, 1):setSize(W, H - 1)
    :setBackground(COL.bg):setVisible(false)
allFrames[#allFrames+1] = propListFrame

local propList

local function refreshPropList()
    propList:clear()
    for _, p in ipairs(data.propellers) do
        local lbl = string.format("%-14s %s", (p.id or ""):sub(1,14), p.facing or "?")
        propList:addItem({text = lbl})
    end
end

local function openPropEdit(idx)
    propEditIndex = idx
    local p = idx and data.propellers[idx] or {}
    propEditInputs.id:setText(p.id or "")
    propEditInputs.controller:setText(p.controller or "")
    propEditInputs.pos_x:setText(tostring(p.position and p.position.x or 0))
    propEditInputs.pos_z:setText(tostring(p.position and p.position.z or 0))
    propFacingVal = p.facing or "north"
    refreshPropFacingBtn()
    switchTo(propEditFrame)
end

do
    addHeader(propListFrame, "Propellers")
    propList = propListFrame:addList()
        :setPosition(1, 2):setSize(W, H - 4)
        :setBackground(COL.bg):setForeground(COL.tx)

    local bRow = H - 2
    addBtn(propListFrame, "[+Add]", 1,    bRow, 7,  COL.ok,     COL.okTx,     function()
        openPropEdit(nil)
    end)
    addBtn(propListFrame, "[Edit]", 9,    bRow, 7,  COL.btn,    COL.btnTx,    function()
        local idx = propList:getSelectedIndex()
        if idx and idx > 0 then openPropEdit(idx) end
    end)
    addBtn(propListFrame, "[Del]",  17,   bRow, 7,  COL.danger, COL.dangerTx, function()
        local idx = propList:getSelectedIndex()
        if idx and idx > 0 then
            local removed = data.propellers[idx].id
            table.remove(data.propellers, idx)
            refreshPropList()
            setStatus("Deleted: " .. tostring(removed))
        end
    end)
    addBtn(propListFrame, "[<]", 1, H-1, 4, COL.btn, COL.btnTx, function()
        switchTo(menuFrame)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LIFT SOURCE EDIT SCREEN
-- ═══════════════════════════════════════════════════════════════════════════════
local liftEditFrame = root:addFrame()
    :setPosition(1, 1):setSize(W, H - 1)
    :setBackground(COL.bg):setVisible(false)
allFrames[#allFrames+1] = liftEditFrame

local liftEditInputs = {}
local liftEditIndex  = nil

do
    addHeader(liftEditFrame, "Edit Lift Source")
    addLbl(liftEditFrame, "Peripheral ID:", 1, 2, W, COL.sub)
    liftEditInputs.id = addInp(liftEditFrame, 1, 3, W, "gas_provider_0")

    addLbl(liftEditFrame, "Relative position from craft center:", 1, 4, W, COL.sub)
    addLbl(liftEditFrame, "X:", 1, 5, 2, COL.sub)
    liftEditInputs.pos_x = addInp(liftEditFrame, 3, 5, 10, "0")
    addLbl(liftEditFrame, "Z:", 14, 5, 2, COL.sub)
    liftEditInputs.pos_z = addInp(liftEditFrame, 16, 5, 10, "0")

    addBtn(liftEditFrame, "[Pos Calc]", 1, 6, 11, COL.btn, COL.btnTx, function()
        openPosCalc(
            tonumber(liftEditInputs.pos_x:getText()) or 0,
            tonumber(liftEditInputs.pos_z:getText()) or 0,
            liftEditFrame,
            function(rx, rz)
                liftEditInputs.pos_x:setText(tostring(rx))
                liftEditInputs.pos_z:setText(tostring(rz))
            end
        )
    end)

    addBtn(liftEditFrame, "Save", 1, 8, 6, COL.ok, COL.okTx, function()
        local id = liftEditInputs.id:getText()
        if id == "" then setStatus("ID is required"); return end
        local entry = {
            id       = id,
            position = {
                x = tonumber(liftEditInputs.pos_x:getText()) or 0,
                z = tonumber(liftEditInputs.pos_z:getText()) or 0,
            },
        }
        if liftEditIndex then
            data.liftSources[liftEditIndex] = entry
        else
            data.liftSources[#data.liftSources + 1] = entry
        end
        setStatus("Saved: " .. id)
        switchTo(liftListFrame)
    end)
    addBtn(liftEditFrame, "Cancel", 9, 8, 8, COL.btn, COL.btnTx, function()
        switchTo(liftListFrame)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LIFT SOURCE LIST SCREEN
-- ═══════════════════════════════════════════════════════════════════════════════
liftListFrame = root:addFrame()
    :setPosition(1, 1):setSize(W, H - 1)
    :setBackground(COL.bg):setVisible(false)
allFrames[#allFrames+1] = liftListFrame

local liftList

local function refreshLiftList()
    liftList:clear()
    for _, s in ipairs(data.liftSources) do
        local pos = s.position or {x=0, z=0}
        local lbl = string.format("%-14s x=%-3d z=%d",
            (s.id or ""):sub(1,14), pos.x, pos.z)
        liftList:addItem({text = lbl})
    end
end

local function openLiftEdit(idx)
    liftEditIndex = idx
    local s = idx and data.liftSources[idx] or {}
    liftEditInputs.id:setText(s.id or "")
    liftEditInputs.pos_x:setText(tostring(s.position and s.position.x or 0))
    liftEditInputs.pos_z:setText(tostring(s.position and s.position.z or 0))
    switchTo(liftEditFrame)
end

do
    addHeader(liftListFrame, "Lift Sources")
    liftList = liftListFrame:addList()
        :setPosition(1, 2):setSize(W, H - 4)
        :setBackground(COL.bg):setForeground(COL.tx)

    local bRow = H - 2
    addBtn(liftListFrame, "[+Add]", 1,  bRow, 7, COL.ok,     COL.okTx,     function()
        openLiftEdit(nil)
    end)
    addBtn(liftListFrame, "[Edit]", 9,  bRow, 7, COL.btn,    COL.btnTx,    function()
        local idx = liftList:getSelectedIndex()
        if idx and idx > 0 then openLiftEdit(idx) end
    end)
    addBtn(liftListFrame, "[Del]",  17, bRow, 7, COL.danger, COL.dangerTx, function()
        local idx = liftList:getSelectedIndex()
        if idx and idx > 0 then
            local removed = data.liftSources[idx].id
            table.remove(data.liftSources, idx)
            refreshLiftList()
            setStatus("Deleted: " .. tostring(removed))
        end
    end)
    addBtn(liftListFrame, "[<]", 1, H-1, 4, COL.btn, COL.btnTx, function()
        switchTo(menuFrame)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SENSORS SCREEN
-- ═══════════════════════════════════════════════════════════════════════════════
local sensorsFrame = root:addFrame()
    :setPosition(1, 1):setSize(W, H - 1)
    :setBackground(COL.bg):setVisible(false)
allFrames[#allFrames+1] = sensorsFrame

local sensInp = {}

do
    addHeader(sensorsFrame, "Sensors")

    local rows = {
        {lbl = "Altitude sensor:", key = "altitude", y = 2},
        {lbl = "Gimbal sensor:",   key = "gimbal",   y = 4},
        {lbl = "Velocity X:",      key = "vel0",     y = 6},
        {lbl = "Velocity Y:",      key = "vel1",     y = 8},
        {lbl = "Velocity Z:",      key = "vel2",     y = 10},
    }
    for _, r in ipairs(rows) do
        addLbl(sensorsFrame, r.lbl, 1, r.y, W, COL.sub)
        sensInp[r.key] = addInp(sensorsFrame, 1, r.y + 1, W, r.key)
    end

    addBtn(sensorsFrame, "Save", 1, 13, 6, COL.ok, COL.okTx, function()
        data.sensors = {
            altitude = sensInp.altitude:getText(),
            gimbal   = sensInp.gimbal:getText(),
            velocity = {
                sensInp.vel0:getText(),
                sensInp.vel1:getText(),
                sensInp.vel2:getText(),
            },
        }
        setStatus("Sensors saved")
        switchTo(menuFrame)
    end)
    addBtn(sensorsFrame, "Cancel", 9, 13, 8, COL.btn, COL.btnTx, function()
        switchTo(menuFrame)
    end)
end

local function openSensors()
    local s = data.sensors
    sensInp.altitude:setText(s.altitude or "")
    sensInp.gimbal:setText(s.gimbal or "")
    sensInp.vel0:setText((s.velocity and s.velocity[1]) or "")
    sensInp.vel1:setText((s.velocity and s.velocity[2]) or "")
    sensInp.vel2:setText((s.velocity and s.velocity[3]) or "")
    switchTo(sensorsFrame)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INPUT DEVICES SCREEN
-- ═══════════════════════════════════════════════════════════════════════════════
local inputDevFrame = root:addFrame()
    :setPosition(1, 1):setSize(W, H - 1)
    :setBackground(COL.bg):setVisible(false)
allFrames[#allFrames+1] = inputDevFrame

local inpDevInp = {}

do
    addHeader(inputDevFrame, "Input Devices")

    local rows = {
        {lbl="Steering wheel:",   key="steeringWheel",       y=2},
        {lbl="Throttle lever:",   key="throttleLever",       y=4},
        {lbl="Alt rate/unit:",    key="altitudeRatePerUnit", y=6},
        {lbl="Max translation:",  key="maxTranslation",      y=8},
        {lbl="Max yaw:",          key="maxYaw",              y=10},
    }
    for _, r in ipairs(rows) do
        addLbl(inputDevFrame, r.lbl, 1, r.y, W, COL.sub)
        inpDevInp[r.key] = addInp(inputDevFrame, 1, r.y + 1, W, r.key)
    end

    addBtn(inputDevFrame, "Save", 1, 13, 6, COL.ok, COL.okTx, function()
        data.input = {
            steeringWheel       = inpDevInp.steeringWheel:getText(),
            throttleLever       = inpDevInp.throttleLever:getText(),
            altitudeRatePerUnit = tonumber(inpDevInp.altitudeRatePerUnit:getText()) or 0.5,
            maxTranslation      = tonumber(inpDevInp.maxTranslation:getText()) or 0.8,
            maxYaw              = tonumber(inpDevInp.maxYaw:getText()) or 0.6,
        }
        setStatus("Input devices saved")
        switchTo(menuFrame)
    end)
    addBtn(inputDevFrame, "Cancel", 9, 13, 8, COL.btn, COL.btnTx, function()
        switchTo(menuFrame)
    end)
end

local function openInputDev()
    local i = data.input
    inpDevInp.steeringWheel:setText(i.steeringWheel or "")
    inpDevInp.throttleLever:setText(i.throttleLever or "")
    inpDevInp.altitudeRatePerUnit:setText(tostring(i.altitudeRatePerUnit or 0.5))
    inpDevInp.maxTranslation:setText(tostring(i.maxTranslation or 0.8))
    inpDevInp.maxYaw:setText(tostring(i.maxYaw or 0.6))
    switchTo(inputDevFrame)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN MENU SCREEN
-- ═══════════════════════════════════════════════════════════════════════════════
menuFrame = root:addFrame()
    :setPosition(1, 1):setSize(W, H - 1)
    :setBackground(COL.bg)
allFrames[#allFrames+1] = menuFrame

local connLabel

do
    addHeader(menuFrame, "Blimp Config Tool")

    connLabel = addLbl(menuFrame, "Ship: Not connected", 1, 2, W, COL.noconn)

    local function navBtn(label, y, cb)
        return addBtn(menuFrame, label, 1, y, W, COL.btn, COL.btnTx, cb)
    end

    navBtn("Connect to ship",  3,  function()
        setStatus("Scanning for ship...")   -- renders immediately via sleep(0) in setStatus
        local id = comms.findShip()
        if id then
            connLabel:setText("Ship: #" .. id .. " connected")
            connLabel:setForeground(COL.conn)
        else
            connLabel:setText("Ship: Not found")
            connLabel:setForeground(COL.noconn)
        end
        setStatus(id and "Connected to ship #" .. id or "No ship responded (timeout)")
        -- setStatus includes sleep(0) so the connLabel colour change also renders now
    end)

    navBtn("Lift sources",     4,  function()
        refreshLiftList(); switchTo(liftListFrame)
    end)
    navBtn("Propellers",       5,  function()
        refreshPropList(); switchTo(propListFrame)
    end)
    navBtn("Sensors",          6,  function() openSensors() end)
    navBtn("Input devices",    7,  function() openInputDev() end)

    -- divider
    addLbl(menuFrame, string.rep("\140", W), 1, 8, W, COL.btn)

    -- Craft facing cycle button — updates in-place
    local facingBtn = menuFrame:addButton()
        :setPosition(1, 9):setSize(W, 1)
        :setBackground(COL.field):setForeground(COL.tx)
        :setText("Craft facing: " .. data.craftFacing .. " (click to change)")

    local function nextHorizFacing(f)
        for i, v in ipairs(HORIZ_FACINGS) do
            if v == f then return HORIZ_FACINGS[i % #HORIZ_FACINGS + 1] end
        end
        return "north"
    end

    facingBtn:onClick(function()
        data.craftFacing = nextHorizFacing(data.craftFacing)
        facingBtn:setText("Craft facing: " .. data.craftFacing .. " (click to change)")
    end)

    navBtn("Push to ship",     10, function()
        if not comms.shipId() then setStatus("Connect first"); return end
        setStatus("Pushing config to ship...")
        local ok, err = comms.setConfig(data)
        setStatus(ok and "Pushed OK" or "Push failed: " .. tostring(err))
    end)
    navBtn("Pull from ship",   11, function()
        if not comms.shipId() then setStatus("Connect first"); return end
        setStatus("Pulling config from ship...")
        local d, err = comms.getConfig()
        if d then
            data = sanitizeData(d)
            facingBtn:setText("Craft facing: " .. data.craftFacing .. " (click to change)")
            setStatus("Pulled OK — " .. #data.propellers .. " props, "
                      .. #data.liftSources .. " lift")
        else
            setStatus("Pull failed: " .. tostring(err))
        end
    end)
    navBtn("Save locally",     12, function()
        local f = fs.open("config_data.lua", "w")
        f.write("return " .. textutils.serialize(data))
        f.close()
        setStatus("Saved config_data.lua")
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- BOOT
-- ═══════════════════════════════════════════════════════════════════════════════

-- Load local config if it exists
if fs.exists("config_data.lua") then
    local f      = fs.open("config_data.lua", "r")
    local src    = f.readAll()
    f.close()
    local loaded = textutils.unserialize(src)
    if type(loaded) == "table" then
        data = sanitizeData(loaded)
        setStatus("Loaded local config_data.lua")
    end
end

-- Open wireless modem
local modemOk, modemSide = comms.open()
if modemOk then
    setStatus("Modem open on " .. tostring(modemSide))
else
    setStatus("No wireless modem found")
end

-- Show the main menu
switchTo(menuFrame)

basalt.run()
