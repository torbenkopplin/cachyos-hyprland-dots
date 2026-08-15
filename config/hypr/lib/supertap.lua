-- lib/supertap.lua -- tap SUPER on its own to open the launcher.
--
-- Why this isn't just a release-bind
-- ----------------------------------
-- The obvious approach is:
--
--     hl.bind("SUPER + SUPER_L", <launcher>, { release = true })
--
-- That does not work when SUPER is also your main modifier. Hyprland registers
-- the release callback when SUPER_L goes down and fires it unconditionally when
-- SUPER_L comes back up -- there is no "was another key pressed in between?"
-- guard. So every SUPER+J, SUPER+Return, SUPER+1 ... would also pop the
-- launcher the moment you let go of SUPER.
--
-- Instead we watch raw key events. `input.keyboard.key` is emitted before the
-- keybind manager gets a look at the event, so we see *every* key, including
-- ones that binds consume. That gives us a real tap detector:
--
--   * SUPER down            -> arm, remember the timestamp
--   * any other key down    -> disarm (it was a chord, not a tap)
--   * SUPER up while armed  -> if it was quick enough, it was a tap
--
-- Args are (xkb keycode, time in ms, state) where state is 1 for press.

local M = {}

-- xkb keycodes: libinput KEY_LEFTMETA(125)/KEY_RIGHTMETA(126) + 8.
local SUPER_L, SUPER_R = 133, 134

local PRESSED = 1

--- @param command string shell command to run on a tap
--- @param tap_ms integer longest press still counted as a tap
function M.setup(command, tap_ms)
    local armed    = false
    local pressed_at = 0

    hl.on("input.keyboard.key", function(keycode, time_ms, state)
        if keycode == SUPER_L or keycode == SUPER_R then
            if state == PRESSED then
                armed      = true
                pressed_at = time_ms
            else
                -- time_ms is monotonic from the compositor, so no clock skew.
                if armed and (time_ms - pressed_at) <= tap_ms then
                    hl.exec_cmd(command)
                end
                armed = false
            end
        elseif state == PRESSED then
            -- Any other key means this was a chord. Held SUPER stays held; it
            -- just no longer counts as a tap when released.
            armed = false
        end
    end)
end

return M
