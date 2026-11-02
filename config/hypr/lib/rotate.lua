-- lib/rotate.lua -- the built-in panel turns as the device turns.
--
--     The panel follows the accelerometer, once a reading has held for a
--     second. MOD + CTRL + R freezes it where it is.
--
-- This was meant to happen in tablet mode only, and cannot: the HP ENVY x360
-- this was written on never tells the OS it is folded. Measured 2026-10-24,
-- folding and turning it with every input device watched as root: no switch
-- event, no switch state change (SW_TABLET_MODE is advertised by "HP WMI
-- hotkeys" and stays off), no input device removed, no kernel log line, and
-- /sys/devices/platform/hp-wmi/tablet reads 0 throughout. The firmware turns
-- the keyboard and touchpad off by itself, below Linux.
--
-- So the sensor is followed always, and the hold is what makes that tolerable
-- on a laptop: open on a desk or a lap the panel reads "normal", and a reading
-- has to stay put for HOLD_MS in bin/hypr-autorotate before it counts. The case
-- it gets wrong is carrying the laptop open on its side for longer than that.
--
-- The work is split the way lib/lid.lua and bin/hypr-sleepwatch split theirs.
-- This file owns the policy; bin/hypr-autorotate is only the trigger. It writes
-- each settled orientation to a file and asks for a reconcile, and the
-- reconcile reads that file back.
--
-- The state is read, never remembered -- the same rule as lib/lid.lua, for the
-- same reason: `hyprctl reload` starts this module over, and a reload with the
-- device on its side has to come back still turned. The orientation and the
-- lock come from files in $XDG_RUNTIME_DIR, and the panel's current transform
-- from Hyprland.

local M = {}

-- How long after a config reload to re-decide, in ms. Same reasoning as
-- SETTLE_MS in lib/lid.lua: a reload re-applies the monitor rules, and the touch
-- transform set at runtime goes back to its default with them.
local SETTLE_MS = 500

-- iio-sensor-proxy's orientations, as Hyprland transforms. Its names say which
-- edge of the panel points UP; Hyprland's numbers are quarter turns
-- anticlockwise. "undefined" -- lying flat, or no reading yet -- is absent on
-- purpose: it means "leave it as it is", not "upright".
local TRANSFORMS = {
    ["normal"]    = 0,
    ["left-up"]   = 1,
    ["bottom-up"] = 2,
    ["right-up"]  = 3,
}

local RUNTIME = os.getenv("XDG_RUNTIME_DIR") or "/tmp"

-- Written by bin/hypr-autorotate. Its directory is the unit's RuntimeDirectory,
-- which systemd removes whenever the reader stops -- crashes included -- so a
-- file that is there is a reading that is current, and no file means no reading.
local ORIENTATION_FILE = RUNTIME .. "/hypr-autorotate/orientation"

-- Present means locked. A file rather than a variable so a reload keeps it, and
-- in the runtime directory so a reboot does not. Not inside the reader's
-- directory, which goes away whenever the reader restarts.
local LOCK_FILE = RUNTIME .. "/hypr-rotation-locked"

local SERVICE = "hypr-autorotate.service"

--- The panel's monitor spec, as handed to M.setup().
---@type table|nil
local panel

--- The deferred reconcile's timer. Held at module level because an hl.timer()
--- handle that nothing holds is collected and never fires at all.
---@type userdata|nil
local settle_timer

---@param path string
---@return string|nil
local function slurp(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

---@return boolean
local function locked()
    return slurp(LOCK_FILE) ~= nil
end

--- The transform the sensor asks for, or nil if it has nothing to say.
---@return integer|nil
local function sensed()
    local text = slurp(ORIENTATION_FILE)
    return text and TRANSFORMS[text:match("^%s*(.-)%s*$")]
end

--- The panel's transform as Hyprland has it now, or nil if the panel is not
--- driving a screen.
---@return integer|nil
local function current()
    for _, mon in ipairs(hl.get_monitors()) do
        if mon.name == panel.output then return mon.transform end
    end

    return nil
end

--- Turn the panel, and the touch input on it, to `t`.
---
--- The monitor rule goes through lib/lid.lua when that module owns the panel:
--- its spec is the one it re-applies on every lid change, and a spec that left
--- the transform out would put the panel upright again under the user's hand.
---
--- The touch transform is set every time, not only when the panel turns. A value
--- set at runtime is gone after a reload, and Hyprland does not turn touch input
--- with the monitor on its own -- so after a reload with the panel turned the
--- option no longer agrees with it until something sets it again.
---@param t integer
local function turn(t)
    if current() ~= t then
        local lid = package.loaded["lib.lid"]
        if not (lid and lid.transform and lid.transform(panel.output, t)) then
            local spec = {}
            for k, v in pairs(panel) do spec[k] = v end
            spec.transform = t
            pcall(hl.monitor, spec)
        end
    end

    -- The stylus is a tablet device to Hyprland, not a touch device, and turns
    -- with the panel it is drawn on.
    pcall(hl.config, { input = {
        touchdevice = { transform = t },
        tablet      = { transform = t },
    } })
end

--- Re-decide which way up the panel should be, and turn it only if that is not
--- already how it is: wherever the sensor last settled, unless locked, and
--- where it is now if the sensor has nothing usable to say.
function M.reconcile()
    if not panel then return end

    local want = (not locked() and sensed()) or current()
    if want then turn(want) end
end

--- Freeze the panel where it is, or let it follow the sensor again.
function M.toggle_lock()
    if locked() then
        os.remove(LOCK_FILE)
        hl.exec_cmd("notify-send -a Hyprland -t 1500 'Rotation unlocked'")
    else
        local f = io.open(LOCK_FILE, "w")
        if f then f:close() end
        hl.exec_cmd("notify-send -a Hyprland -t 1500 'Rotation locked'")
    end

    M.reconcile()
end

--- `spec` is the panel's ordinary monitor spec -- the same table handed to
--- lid.setup(), when that is in use.
---@param spec table
function M.setup(spec)
    if type(spec) ~= "table" or type(spec.output) ~= "string" then return end

    panel = spec

    -- locked = true, so the lock can be set with the lock screen up.
    hl.bind(MOD .. " + CTRL + R", function() M.toggle_lock() end,
        { locked = true, description = "Rotation lock" })

    -- The reader is started here rather than enabled against a target because
    -- it is part of this mechanism: a machine that never calls setup() has no
    -- sensor worth powering. Once it is up it reports straight away, so this is
    -- also what turns a panel that was already on its side at login.
    hl.on("hyprland.start", function()
        hl.exec_cmd("systemctl --user start " .. SERVICE)
    end)

    -- A reload drops everything that happened during it, and puts the touch
    -- transform back to its default; see SETTLE_MS. The rule is also declared
    -- at parse time in the state it should be in, so a reload with the panel
    -- turned does not set it upright just to turn it back.
    settle_timer = hl.timer(function() M.reconcile() end,
        { timeout = SETTLE_MS, type = "oneshot" })

    M.reconcile()
end

return M
