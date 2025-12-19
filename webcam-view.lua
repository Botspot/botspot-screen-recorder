local mp = require 'mp'
local assdraw = require 'mp.assdraw'
local osd = mp.create_osd_overlay("ass-events")

local visible = false
local hide_timer = nil

-- Function to render OSD
function render_osd()
    local ass = assdraw.ass_new()

    if not visible then
        osd.data = ""
        osd:update()
        return
    end

    -- Get video dimensions
    local screen_w, screen_h = mp.get_osd_size()
    if not screen_w then return end -- Avoid errors if video is not loaded

    -- Draw semi-transparent black overlay (dimming effect)
    if false then --commented out for better performance
    ass:new_event()
    ass:pos(0, 0)
    ass:append("{\\an7}")
    ass:append("{\\bord0}")
    ass:append("{\\shad0}")
    ass:append("{\\c&H000000&}")
    ass:append("{\\1a&HCC}") -- Transparency for the dimming
    ass:draw_start()
    ass:rect_cw(0, 0, screen_w * 20, screen_h * 20) -- Dimming the entire screen
    ass:draw_stop()
    end

    -- Check if video is paused or playing
    local is_paused = mp.get_property("pause") == "yes"

    -- Draw Play or Pause button in the center
    ass:new_event()
    ass:append("{\\an5\\shad0\\bord4\\c&HFFFFFF&\\3c&H000000&}")
    
    if is_paused then
        -- Draw a play button (triangle)
        ass:append("{\\p1}m 0 80 l 0 0 l 70 40 l 0 80 f")  -- Play button (triangle)
    else
        -- Draw a pause button (two vertical bars)
        ass:append("{\\p1}m -5 0 l 25 0 l 25 80 l -5 80 f")  -- Left bar of pause
        ass:append("{\\p1}m 20 0 l 50 0 l 50 80 l 20 80 f")  -- Right bar of pause
    end

    osd.data = ass.text
    osd:update()
end

-- Function to show OSD when the mouse moves
function show_osd()
    visible = true
    render_osd()

    -- Reset the hide timer
    if hide_timer then hide_timer:kill() end
    hide_timer = mp.add_timeout(1, function()
        visible = false
        render_osd()
    end)
end

-- Function to handle clicks (toggle pause)
function handle_click()
    local screen_w, screen_h = mp.get_osd_size()
    local cursor_x, cursor_y = mp.get_mouse_pos()

    if not screen_w or not screen_h then return end

    local center_x, center_y = screen_w / 2, screen_h / 2

    if math.abs(cursor_x - center_x) < 100 and math.abs(cursor_y - center_y) < 100 then
        mp.command("cycle pause")
        show_osd() -- Keep OSD visible briefly
    end
end

-- Observe mouse movement to show OSD
mp.observe_property("mouse-pos", "native", function()
    show_osd()
end)

-- Bind left mouse button clicks
mp.add_key_binding("MBTN_LEFT", "click", handle_click)

-- Bind F11 key to toggle fullscreen
mp.add_key_binding("F11", "toggle-fullscreen", function()
    mp.command("cycle fullscreen")
end)

-- Bind F key to toggle fullscreen
mp.add_key_binding("F", "toggle-fullscreen", function()
    mp.command("cycle fullscreen")
end)

-- Disable MPV's default OSC
mp.commandv("script-message", "osc-visibility", "never")
