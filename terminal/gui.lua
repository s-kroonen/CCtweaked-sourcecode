-- terminal/gui.lua
-- Primitive UI helpers for the pocket-computer config tool.
-- Pocket screen: 26 wide × 20 tall (standard CC:Tweaked pocket computer).

local gui = {}

local W, H = term.getSize()

-- ── Colours ───────────────────────────────────────────────────────────────────
gui.COL = {
    bg       = colours.black,
    header   = colours.blue,
    headerTx = colours.white,
    item     = colours.black,
    itemTx   = colours.white,
    sel      = colours.lightBlue,
    selTx    = colours.black,
    field    = colours.grey,
    fieldTx  = colours.white,
    label    = colours.black,
    labelTx  = colours.lightGrey,
    ok       = colours.green,
    okTx     = colours.black,
    cancel   = colours.red,
    cancelTx = colours.white,
    status   = colours.black,
    statusTx = colours.yellow,
}

function gui.size() return W, H end

function gui.clear()
    term.setBackgroundColor(gui.COL.bg)
    term.setTextColor(gui.COL.itemTx)
    term.clear()
    term.setCursorPos(1, 1)
end

-- Draw a single-line header bar at y=1.
function gui.header(title)
    term.setCursorPos(1, 1)
    term.setBackgroundColor(gui.COL.header)
    term.setTextColor(gui.COL.headerTx)
    term.clearLine()
    local pad = math.floor((W - #title) / 2)
    term.setCursorPos(pad + 1, 1)
    term.write(title)
    term.setBackgroundColor(gui.COL.bg)
    term.setTextColor(gui.COL.itemTx)
end

-- Draw a status bar at the bottom (y=H).
function gui.status(msg)
    term.setCursorPos(1, H)
    term.setBackgroundColor(gui.COL.status)
    term.setTextColor(gui.COL.statusTx)
    term.clearLine()
    term.write(msg:sub(1, W))
    term.setBackgroundColor(gui.COL.bg)
    term.setTextColor(gui.COL.itemTx)
end

-- Draw a scrollable list. Returns new selected index.
-- items: list of strings.  sel: 1-based selected index.
-- yStart/yEnd: rows to draw in.
function gui.drawList(items, sel, yStart, yEnd)
    local visible = yEnd - yStart + 1
    local offset  = math.max(0, sel - math.ceil(visible / 2))
    offset = math.min(offset, math.max(0, #items - visible))

    for row = 0, visible - 1 do
        local idx = offset + row + 1
        local y   = yStart + row
        term.setCursorPos(1, y)
        if idx <= #items then
            if idx == sel then
                term.setBackgroundColor(gui.COL.sel)
                term.setTextColor(gui.COL.selTx)
            else
                term.setBackgroundColor(gui.COL.item)
                term.setTextColor(gui.COL.itemTx)
            end
            local line = items[idx]
            term.write(line:sub(1, W))
            term.write(string.rep(" ", W - math.min(#line, W)))
        else
            term.setBackgroundColor(gui.COL.bg)
            term.clearLine()
        end
    end
    term.setBackgroundColor(gui.COL.bg)
    term.setTextColor(gui.COL.itemTx)
    return sel
end

-- Draw a labelled read-only field row.
function gui.fieldRow(label, value, y, highlight)
    term.setCursorPos(1, y)
    term.setBackgroundColor(highlight and gui.COL.sel or gui.COL.label)
    term.setTextColor(highlight and gui.COL.selTx or gui.COL.labelTx)
    local lbl = label:sub(1, 8)
    term.write(lbl .. string.rep(" ", 8 - #lbl) .. " ")
    term.setBackgroundColor(highlight and gui.COL.sel or gui.COL.field)
    term.setTextColor(highlight and gui.COL.selTx or gui.COL.fieldTx)
    local val = tostring(value or ""):sub(1, W - 10)
    term.write(val .. string.rep(" ", W - 9 - math.min(#tostring(value or ""), W - 10)))
end

-- Inline text prompt: clears the field row and calls read() there.
-- Returns the entered string (or oldVal if empty and keepOld=true).
function gui.prompt(label, oldVal, y)
    term.setCursorPos(1, y)
    term.setBackgroundColor(gui.COL.field)
    term.setTextColor(gui.COL.fieldTx)
    term.clearLine()
    local lbl = label:sub(1, 8)
    term.write(lbl .. string.rep(" ", 8 - #lbl) .. ": ")
    term.setCursorBlink(true)
    local input = read(nil, nil, nil, tostring(oldVal or ""))
    term.setCursorBlink(false)
    if input == nil or input == "" then return oldVal end
    return input
end

-- Yes/No dialog centred on screen. Returns true for yes.
function gui.confirm(msg)
    local y = math.floor(H / 2) - 1
    term.setCursorPos(1, y)
    term.setBackgroundColor(gui.COL.field)
    term.setTextColor(gui.COL.fieldTx)
    -- Draw message centred
    for i = y, y + 2 do
        term.setCursorPos(1, i)
        term.clearLine()
    end
    term.setCursorPos(math.floor((W - #msg) / 2) + 1, y)
    term.write(msg)
    term.setCursorPos(math.floor(W / 2) - 5, y + 2)
    term.setBackgroundColor(gui.COL.ok)
    term.setTextColor(gui.COL.okTx)
    term.write(" Yes ")
    term.setBackgroundColor(gui.COL.cancel)
    term.setTextColor(gui.COL.cancelTx)
    term.write("  No  ")
    term.setBackgroundColor(gui.COL.bg)
    term.setTextColor(gui.COL.itemTx)

    while true do
        local _, key = os.pullEvent("key")
        if key == keys.y or key == keys.enter then return true end
        if key == keys.n or key == keys.backspace then return false end
    end
end

-- Direction picker popup. Returns new facing string or nil if cancelled.
local FACINGS = {"north","south","east","west","up","down"}
function gui.pickFacing(current)
    local sel = 1
    for i, f in ipairs(FACINGS) do
        if f == current then sel = i end
    end

    while true do
        gui.clear()
        gui.header("Pick Facing")
        for i, f in ipairs(FACINGS) do
            gui.fieldRow("", f, i + 2, i == sel)
        end
        gui.status("↑↓ move  Enter confirm  Esc cancel")

        local _, key = os.pullEvent("key")
        if key == keys.up   then sel = math.max(1, sel - 1)
        elseif key == keys.down  then sel = math.min(#FACINGS, sel + 1)
        elseif key == keys.enter then return FACINGS[sel]
        elseif key == keys.backspace then return nil
        end
    end
end

return gui
