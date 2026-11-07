--[[
================================================================================
 Drawing-based UI library (v3)
================================================================================

 LOADING
     local Library = loadstring(game:HttpGet("YOUR_RAW_URL"))()

 The script returns the Library table. It does NOT create a window by itself,
 so you build your own after loading (see the full example at the bottom).

 Requires an executor with the Drawing API. Config saving also needs
 writefile / readfile / isfile / isfolder / makefolder / listfiles / delfile
 (if they are missing, everything else still works, saving just reports an error).

 Menu is hidden/shown with RightShift (rebindable in the ui settings tab).
 The font is always Drawing.Fonts.UI (size 14).

--------------------------------------------------------------------------------
 WINDOW
--------------------------------------------------------------------------------
 Library.new(opts) -> Window
     opts.Title      string   window title            (default "menu")
     opts.Position   Vector2  top-left on screen      (default 200, 110)
     opts.Size       Vector2  window size             (default 560, 490)
     opts.ToggleKey  Enum     key that hides/shows    (default RightShift)

 Window:Tab(name)               -> Tab      adds a tab (first tab is auto-selected)
 Window:SetTab(tab)                         switch to a tab
 Window:SetVisible(bool)                    show/hide the whole menu
 Window:Notify(text, duration)              toast notification (duration default 3s)
 Window:SetWatermark(bool)                  toggle the top-right watermark
 Window:SetKeybindList(bool)                toggle the on-screen keybind list
 Window:Destroy()                           removes every drawing + disconnects all
 Window:BuildUIManager(tab)                 adds menu options + theme editor to a tab

 Window.Flags                               table of every flagged element
 Library.Theme                              live theme table (Accent, Text, etc.)

--------------------------------------------------------------------------------
 TABS AND SECTIONS
--------------------------------------------------------------------------------
 Tab:Section(name, side) -> Section
     side is "left" or "right" (default "left"). Sections stack downward.

 Every element is added to a Section and is placed under the previous one.

--------------------------------------------------------------------------------
 ELEMENTS   (flag = optional string; flagged elements are saved by SaveManager)
--------------------------------------------------------------------------------
 Section:Label(text) -> { SetText(_, str) }

 Section:Button(text, callback)

 Section:Toggle(name, default, callback, flag) -> toggle
     callback(state: boolean)
     toggle:Get() / toggle:Set(bool)
     toggle:IsActive()
         true when the toggle is on AND (no key bound, or the bound key is held)
     toggle:AddKeybind(default, keyFlag, onActive) -> toggle
         The key does NOT flip the toggle. The toggle is the on/off switch and
         the key marks when it is "active" (held).
         onActive(true) fires on key down, onActive(false) on key up
         (only fires while the toggle is on). default may be nil.
         Left-click the key text to rebind. Esc / Backspace clears it.
         Mouse2 / Mouse3 can be bound too.
     toggle:AddColorpicker(default: Color3, onChange, colorFlag) -> toggle
         onChange(color: Color3)
     AddKeybind / AddColorpicker return the toggle so they can be chained.

 Section:Slider(name, min, max, default, callback, opts) -> { Get, Set }
     opts.Step    number   increment             (default 1)
     opts.Suffix  string   text after the value  (default "")
     opts.Flag    string   save flag
     callback(value: number)

 Section:Dropdown(name, options, default, callback, flag) -> dropdown
     options = { "a", "b", ... }   (shows 8 rows, mouse wheel scrolls the rest)
     callback(selected: string)
     dropdown:Get() / dropdown:Set(option)
     dropdown:SetOptions(list)     replace the option list

 Section:Textbox(name, placeholder, callback) -> textbox
     callback(text) fires on Enter. Esc cancels typing.
     Allowed characters: letters, numbers, space, "_" and "-" (max 28).
     textbox:Get() / textbox:Set(str)

 Section:Keybind(name, default, callback, flag, onChange) -> keybind
     callback()        fires whenever the key is pressed
     onChange(key)     fires when the user rebinds it (key is nil if cleared)

 Section:ColorPicker(name, default, callback, flag) -> picker
     callback(color: Color3)
     picker:Get() / picker:Set(color)

--------------------------------------------------------------------------------
 SAVE MANAGER
--------------------------------------------------------------------------------
 local saves = Library.SaveManager.new(window, folderName)
     folderName default is "enigma". Configs live in <folder>/configs/*.json.

 saves:BuildSection(tab, side)   adds the config UI (create / load / overwrite /
                                 delete / refresh / set autoload). side default "right".
 saves:LoadAutoload()            loads the autoload config if one is set
 saves:Save(name)   -> ok, nameOrError
 saves:Load(name)   -> ok, nameOrError
 saves:Delete(name) -> ok, name
 saves:List()       -> { names }
 saves:SetAutoload(name) / saves:GetAutoload()

 Config names may only contain letters, numbers, spaces, "_" and "-".
 Saved values: toggles, sliders, dropdowns, keybinds, colors.

--------------------------------------------------------------------------------
 EXAMPLE
--------------------------------------------------------------------------------
 local Library = loadstring(game:HttpGet("YOUR_RAW_URL"))()
 local V2 = Vector2.new

 local win = Library.new({ Title = "enigma", Position = V2(300, 80), Size = V2(560, 490) })

 local main     = win:Tab("main")
 local visuals  = win:Tab("visuals")
 local settings = win:Tab("ui settings")

 local left = main:Section("section one", "left")

 left:Toggle("feature one", false, nil, "f1")
     :AddKeybind(nil, "f1_key", function(active) print("feature one active:", active) end)

 left:Toggle("draw circle", true, nil, "circle")
     :AddColorpicker(Color3.fromRGB(255, 255, 255), nil, "circle_color")

 left:Dropdown("mode", { "Closest to Cursor", "Nearest to Me", "Lowest Health" },
     "Closest to Cursor", nil, "mode")

 left:Slider("range", 0, 800, 400, nil, { Suffix = " studs", Flag = "range" })

 local right = main:Section("section two", "right")
 right:Slider("amount", 0, 1, 0.35, nil, { Step = 0.05, Flag = "amount" })

 -- reading values elsewhere in your script:
 local feature = left:Toggle("feature two", false, nil, "f2")
 feature:AddKeybind(nil, "f2_key")
 -- game:GetService("RunService").RenderStepped:Connect(function()
 --     if feature:IsActive() then ... end
 -- end)

 win:BuildUIManager(settings)

 local saves = Library.SaveManager.new(win, "enigma")
 saves:BuildSection(settings, "right")
 saves:LoadAutoload()

 win:Notify("loaded - press RightShift to toggle")

================================================================================
]]

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CAS = game:GetService("ContextActionService")
local Stats = game:GetService("Stats")

--------------------------------------------------------------------------
-- THEME  (paste your exact RGB values here, or edit them live in the menu)
--------------------------------------------------------------------------
local DEFAULT_THEME = {
    Background = Color3.fromRGB(0, 0, 0),
    Accent     = Color3.fromRGB(176, 156, 255), -- border, lines, fills
    Text       = Color3.fromRGB(255, 255, 255),
    SubText    = Color3.fromRGB(135, 135, 145),
    Track      = Color3.fromRGB(12, 12, 14),    -- slider / dropdown / button bg
    Hover      = Color3.fromRGB(26, 26, 30),
    Outline    = Color3.fromRGB(225, 220, 245), -- checkbox + swatch border
    Border     = Color3.fromRGB(40, 40, 46),    -- subtle borders / separators
}

-- the library always uses the UI font
local UI_FONT = (Drawing.Fonts and Drawing.Fonts.UI) or 0

local Theme = { TextSize = 14, Font = UI_FONT }
for k, v in pairs(DEFAULT_THEME) do Theme[k] = v end
Theme.AccentDark = Theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35)

local V2 = Vector2.new
local PAD, TOP, TITLE_H = 14, 62, 26

local Library, Section, Tab = {}, {}, {}
Library.__index, Section.__index, Tab.__index = Library, Section, Tab
Library.Theme = Theme

--------------------------------------------------------------------------
-- Drawing helpers (theme-bound)
--------------------------------------------------------------------------
local Bindings, AllTexts = {}, {}

local function mk(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function bind(d, key)
    if type(key) == "string" then table.insert(Bindings, { d = d, key = key }) end
end

local function rect(c, filled, z)
    local d = mk("Square", { Color = type(c) == "string" and Theme[c] or c, Filled = filled ~= false,
        Thickness = 1, Transparency = 1, ZIndex = z, Visible = false })
    bind(d, c)
    return d
end

local function txt(s, c, z, center)
    local d = mk("Text", { Text = s, Size = Theme.TextSize, Font = Theme.Font,
        Color = type(c) == "string" and Theme[c] or c or Theme.Text, Center = center or false,
        Outline = false, ZIndex = z, Visible = false })
    bind(d, c)
    table.insert(AllTexts, d)
    return d
end

local function add(group, d, rel, tri)
    local item = { d = d, rel = rel, tri = tri }
    table.insert(group.Items, item)
    return d, item
end

local function placeGroup(group, origin)
    for _, it in ipairs(group.Items) do
        if it.tri then
            it.d.PointA, it.d.PointB, it.d.PointC = origin + it.tri[1], origin + it.tri[2], origin + it.tri[3]
        else
            it.d.Position = origin + it.rel
        end
    end
end

local function showGroup(group, v)
    for _, it in ipairs(group.Items) do it.d.Visible = v end
end

local function removeGroup(group, anims)
    local gone = {}
    for _, it in ipairs(group.Items) do
        gone[it.d] = true
        if anims then anims[it.d] = nil end
        pcall(function() it.d:Remove() end)
    end
    table.clear(group.Items)
    for i = #Bindings, 1, -1 do if gone[Bindings[i].d] then table.remove(Bindings, i) end end
    for i = #AllTexts, 1, -1 do if gone[AllTexts[i]] then table.remove(AllTexts, i) end end
end

local function fmt(v) return tostring(math.floor(v * 100 + 0.5) / 100) end

local function keyShort(k)
    if not k then return "None" end
    if k.EnumType == Enum.UserInputType then return (k.Name:gsub("MouseButton", "M")) end
    return k.Name:sub(1, 4)
end

local function keyToStr(k)
    if not k then return false end
    return (k.EnumType == Enum.KeyCode and "KeyCode." or "UserInputType.") .. k.Name
end

local function strToKey(s)
    if not s then return nil end
    local t, n = tostring(s):match("^(%w+)%.(%w+)$")
    if not t then return nil end
    local ok, r = pcall(function() return Enum[t][n] end)
    return ok and r or nil
end

local function inAbs(m, pos, size)
    return m.X >= pos.X and m.X <= pos.X + size.X and m.Y >= pos.Y and m.Y <= pos.Y + size.Y
end

local function charFor(input)
    local kc = input.KeyCode
    if kc == Enum.KeyCode.Space then return " " end
    local ok, s = pcall(function() return UIS:GetStringForKeyCode(kc) end)
    if not ok or not s or #s ~= 1 then return nil end
    local shift = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
    if s:match("%a") then return shift and s:upper() or s:lower() end
    if s == "-" and shift then return "_" end
    return s
end

--------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------
function Library.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Library)
    self.Pos = opts.Position or V2(200, 110)
    self.Size = opts.Size or V2(560, 490)
    self.Title = opts.Title or "menu"
    self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
    self.Visible = true
    self.Chrome = { Items = {} }
    self.Tabs, self.Popups, self.Keybinds, self.Conns, self.Anims = {}, {}, {}, {}, {}
    self.Flags, self.Refreshers, self.Notes = {}, {}, {}
    self.AnimSpeed, self.Fps = 0.3, 60
    self.TabX = PAD

    local W, H = self.Size.X, self.Size.Y
    local shadow = add(self.Chrome, rect(Color3.new(0, 0, 0), true, 0), V2(-4, -4))
    shadow.Size, shadow.Transparency = V2(W + 8, H + 8), 0.35
    add(self.Chrome, rect("Background", true, 1), V2(0, 0)).Size = self.Size
    add(self.Chrome, rect("Border", true, 2), V2(0, TITLE_H)).Size = V2(W, 1)
    add(self.Chrome, rect("Accent", false, 3), V2(0, 0)).Size = self.Size
    add(self.Chrome, txt(self.Title, "Text", 4), V2(PAD - 2, 5))

    self:_buildOverlays()
    self:_connect()
    self:_place()
    self:_refresh()
    return self
end

function Library:_in(m, rx, ry, w, h)
    local p = self.Pos
    return m.X >= p.X + rx and m.X <= p.X + rx + w and m.Y >= p.Y + ry and m.Y <= p.Y + ry + h
end

function Library:_ease(d, prop, target)
    self.Anims[d] = { prop = prop, target = target }
end

function Library:_flag(flag, typ, get, set)
    if flag then self.Flags[flag] = { Type = typ, Get = get, Set = set } end
end

function Library:_place()
    placeGroup(self.Chrome, self.Pos)
    for _, t in ipairs(self.Tabs) do placeGroup(t, self.Pos) end
    for _, p in ipairs(self.Popups) do placeGroup(p, self.Pos + (p.Offset or V2(0, 0))) end
end

function Library:_refresh()
    showGroup(self.Chrome, self.Visible)
    for _, t in ipairs(self.Tabs) do showGroup(t, self.Visible and t == self.Active) end
    for _, p in ipairs(self.Popups) do
        showGroup(p, self.Visible and p.Open and p.Tab == self.Active)
    end
end

function Library:SetVisible(v)
    if not v then
        if self.Current then self:_close(self.Current) end
        self:_blur()
        self.Listening = nil
    end
    self.Visible = v
    self:_refresh()
end

function Library:_retheme()
    Theme.AccentDark = Theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35)
    for i = #Bindings, 1, -1 do
        local b = Bindings[i]
        if not pcall(function() b.d.Color = Theme[b.key] end) then table.remove(Bindings, i) end
    end
    for _, f in ipairs(self.Refreshers) do pcall(f) end
end

--------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------
function Library:_layoutTabs()
    local x = PAD
    for _, t in ipairs(self.Tabs) do
        local tw = (t.Label.TextBounds and t.Label.TextBounds.X > 0) and t.Label.TextBounds.X or #t.Name * 8
        t.LItem.rel, t.UItem.rel = V2(x, 33), V2(x, 51)
        t.Under.Size = V2(tw, 2)
        t.HX, t.HW = x, tw
        x += tw + 20
    end
    self.TabX = x
end

function Library:Tab(name)
    local tab = setmetatable({ Items = {}, Handlers = {}, Win = self, Name = name,
        Cursor = { left = TOP, right = TOP } }, Tab)

    local label, lItem = add(self.Chrome, txt(name, "SubText", 4), V2(0, 33))
    local under, uItem = add(self.Chrome, rect("Accent", true, 4), V2(0, 51))
    tab.Label, tab.LItem, tab.Under, tab.UItem = label, lItem, under, uItem

    table.insert(self.Tabs, tab)
    self:_layoutTabs()
    if not self.Active then self:SetTab(tab) else under.Transparency = 0 end
    self:_place()
    return tab
end

function Library:SetTab(tab)
    if self.Current then self:_close(self.Current) end
    self:_blur()
    self.Active = tab
    for _, t in ipairs(self.Tabs) do
        t.Under.Transparency = (t == tab) and 1 or 0
        if t == tab then t.Label.Color = Theme.Text end
    end
    self:_refresh()
end

function Tab:Section(name, side)
    local win = self.Win
    side = side or "left"
    local cw = (win.Size.X - PAD * 3) / 2
    local x = side == "right" and (PAD * 2 + cw) or PAD
    local y = self.Cursor[side]

    add(self, rect("Accent", true, 5), V2(x, y)).Size = V2(cw, 1)
    add(self, txt(name, "Text", 5), V2(x + 2, y + 6))

    local sec = setmetatable({ Win = win, Tab = self, X = x, W = cw, Y = y + 28, Side = side }, Section)
    self.Cursor[side] = sec.Y + 10
    win:_place()
    return sec
end

function Section:_adv(h)
    self.Y += h
    self.Tab.Cursor[self.Side] = self.Y + 10
end

--------------------------------------------------------------------------
-- Popups / focus helpers
--------------------------------------------------------------------------
function Library:_popup(tab)
    local p = { Items = {}, Open = false, Tab = tab }
    table.insert(self.Popups, p)
    return p
end

function Library:_open(p)
    if self.Current and self.Current ~= p then self:_close(self.Current) end
    p.Open = true
    self.Current = p
    if p.OnOpen then p.OnOpen() end
    self:_refresh()
end

function Library:_close(p)
    p.Open = false
    if self.Current == p then self.Current = nil end
    if p.OnClose then p.OnClose() end
    self:_refresh()
end

function Library:_sink(on)
    pcall(function()
        if on then
            CAS:BindActionAtPriority("EnigmaSink", function() return Enum.ContextActionResult.Sink end,
                false, Enum.ContextActionPriority.High.Value, unpack(Enum.KeyCode:GetEnumItems()))
        else
            CAS:UnbindAction("EnigmaSink")
        end
    end)
end

function Library:_blur()
    if self.Typing then
        local t = self.Typing
        self.Typing = nil
        t.Blur()
        self:_sink(false)
    end
end

--------------------------------------------------------------------------
-- Color picker (swatch + popup)
--------------------------------------------------------------------------
-- One shared popup for every color swatch. The field is a seamless gradient:
-- a hue-colored base, a white->clear overlay (left to right) and a clear->black
-- overlay (top to bottom), built from thin strips of varying transparency.
-- Changing hue only recolors the single base square.
function Library:_colorPopup()
    if self.CP then return self.CP end
    local win = self
    local pop = self:_popup(nil)
    pop.Offset = V2(0, 0)

    local G, STRIP, HW = 112, 2, 14
    local N = G / STRIP
    local gx, gy = 8, 8
    local hx = gx + G + 8
    local PW, PH = hx + HW + 8, G + 16

    add(pop, rect("Background", true, 60), V2(0, 0)).Size = V2(PW, PH)

    local base = add(pop, rect(Color3.new(1, 0, 0), true, 61), V2(gx, gy))
    base.Size = V2(G, G)
    for i = 0, N - 1 do
        local d = add(pop, rect(Color3.new(1, 1, 1), true, 62), V2(gx + i * STRIP, gy))
        d.Size = V2(STRIP, G)
        d.Transparency = 1 - (i + 0.5) / N
    end
    for j = 0, N - 1 do
        local d = add(pop, rect(Color3.new(0, 0, 0), true, 63), V2(gx, gy + j * STRIP))
        d.Size = V2(G, STRIP)
        d.Transparency = (j + 0.5) / N
    end
    for k = 0, N - 1 do
        local d = add(pop, rect(Color3.fromHSV(k / N, 1, 1), true, 62), V2(hx, gy + k * STRIP))
        d.Size = V2(HW, STRIP)
    end
    add(pop, rect("Border", false, 64), V2(gx, gy)).Size = V2(G, G)
    add(pop, rect("Border", false, 64), V2(hx, gy)).Size = V2(HW, G)
    add(pop, rect("Accent", false, 66), V2(0, 0)).Size = V2(PW, PH)

    local function circle(r, c, z)
        return mk("Circle", { Radius = r, Color = c, Filled = false, Thickness = 1, NumSides = 24,
            ZIndex = z, Transparency = 1, Visible = false })
    end
    local svOuter, svOuterItem = add(pop, circle(5, Color3.new(0, 0, 0), 67), V2(0, 0))
    local svInner, svInnerItem = add(pop, circle(4, Color3.new(1, 1, 1), 68), V2(0, 0))
    local hMark, hItem = add(pop, rect(Color3.new(1, 1, 1), false, 68), V2(0, 0))
    hMark.Size = V2(HW + 4, 3)

    local cp = { Pop = pop }
    self.CP = cp

    local function origin() return win.Pos + pop.Offset end

    local function sync()
        local A = cp.Active
        if not A then return end
        base.Color = Color3.fromHSV(A.h, 1, 1)
        local o = origin()
        local c = V2(gx + A.s * (G - 1), gy + (1 - A.v) * (G - 1))
        svOuterItem.rel, svInnerItem.rel = c, c
        svOuter.Position, svInner.Position = o + c, o + c
        hItem.rel = V2(hx - 2, gy + math.clamp(A.h * G - 1, 0, G - 3))
        hMark.Position = o + hItem.rel
    end

    local mode
    local function drag(m)
        local A = cp.Active
        if not A then return end
        local o = origin()
        if mode == "sv" then
            A.s = math.clamp((m.X - (o.X + gx)) / (G - 1), 0, 1)
            A.v = 1 - math.clamp((m.Y - (o.Y + gy)) / (G - 1), 0, 1)
        elseif mode == "hue" then
            A.h = math.clamp((m.Y - (o.Y + gy)) / G, 0, 0.999)
        end
        A.color = Color3.fromHSV(A.h, A.s, A.v)
        A.sw.Color = A.color
        sync()
        if A.cb then task.spawn(A.cb, A.color) end
    end

    pop.OnOpen = function()
        local A = cp.Active
        A.swBorder.Color = Theme.Accent
        placeGroup(pop, origin())
        sync()
    end
    pop.OnClose = function()
        mode = nil
        local A = cp.Active
        if A then win:_ease(A.swBorder, "Color", Theme.Outline) end
    end
    pop.Contains = function(m) return inAbs(m, origin(), V2(PW, PH)) end
    pop.Opener = function(m)
        local A = cp.Active
        return A and win:_in(m, A.swRel.X, A.swRel.Y, 28, 12)
    end
    pop.Click = function(m)
        local o = origin()
        if inAbs(m, o + V2(gx, gy), V2(G, G)) then mode = "sv"
        elseif inAbs(m, o + V2(hx, gy), V2(HW, G)) then mode = "hue" end
        if mode then drag(m) end
    end
    pop.Update = function(m, held)
        if mode then
            if held then drag(m) else mode = nil end
        end
    end

    function cp.Open(picker)
        cp.Active = picker
        local ox = picker.swRel.X + 28 - PW
        local oy = picker.swRel.Y + 18
        if oy + PH > win.Size.Y - 4 then oy = picker.swRel.Y - PH - 6 end
        pop.Offset = V2(math.max(ox, 4), oy)
        pop.Tab = picker.Tab
        win:_open(pop)
    end
    function cp.Resync(picker)
        if cp.Active == picker and pop.Open then sync() end
    end

    return cp
end

function Library:_colorpicker(tab, swRel, default, cb)
    local win = self
    local color = default or Color3.new(1, 1, 1)
    local h, s, v = color:ToHSV()

    local sw = add(tab, rect(color, true, 8), swRel); sw.Size = V2(28, 12)
    local swBorder = add(tab, rect("Outline", false, 9), swRel); swBorder.Size = V2(28, 12)

    local P = { Tab = tab, sw = sw, swBorder = swBorder, swRel = swRel, cb = cb,
        color = color, h = h, s = s, v = v }
    local cp = self:_colorPopup()

    table.insert(tab.Handlers, {
        update = function(m)
            if not (cp.Pop.Open and cp.Active == P) then
                win:_ease(swBorder, "Color", win:_in(m, swRel.X, swRel.Y, 28, 12) and Theme.Accent or Theme.Outline)
            end
        end,
        click = function(m)
            if win:_in(m, swRel.X, swRel.Y, 28, 12) then
                if cp.Pop.Open and cp.Active == P then win:_close(cp.Pop) else cp.Open(P) end
                return true
            end
        end,
    })

    return {
        Get = function() return P.color end,
        Set = function(_, c)
            P.color = c
            P.h, P.s, P.v = c:ToHSV()
            sw.Color = c
            cp.Resync(P)
            if cb then task.spawn(cb, c) end
        end,
    }
end

--------------------------------------------------------------------------
-- Keybind widget (click text to rebind; Esc / Backspace clears)
--------------------------------------------------------------------------
function Library:_keybind(tab, center, default, onPress, meta, onChange, onRelease)
    local win = self
    local obj = { Key = default, Meta = meta, Held = false }
    local t = add(tab, txt(keyShort(default), "SubText", 8, true), center)

    function obj.SetKey(k)
        obj.Key, obj.Held = k, false
        t.Text = keyShort(k)
        win:_ease(t, "Color", Theme.SubText)
        if onChange then task.spawn(onChange, k) end
    end
    function obj.Fire()
        obj.Held = true
        if onPress then onPress() end
    end
    function obj.Release()
        if obj.Held then
            obj.Held = false
            if onRelease then onRelease() end
        end
    end
    function obj.Cancel() t.Text = keyShort(obj.Key); win:_ease(t, "Color", Theme.SubText) end

    table.insert(tab.Handlers, {
        update = function(m)
            if win.Listening ~= obj then
                win:_ease(t, "Color", win:_in(m, center.X - 20, center.Y - 2, 40, 18) and Theme.Text or Theme.SubText)
            end
        end,
        click = function(m)
            if win:_in(m, center.X - 20, center.Y - 2, 40, 18) then
                win.Listening = obj
                t.Text, t.Color = "...", Theme.Accent
                win.Anims[t] = nil
                return true
            end
        end,
    })

    table.insert(self.Keybinds, obj)
    return obj
end

--------------------------------------------------------------------------
-- Elements
--------------------------------------------------------------------------
function Section:Label(str)
    local lbl = add(self.Tab, txt(str, "SubText", 5), V2(self.X + 2, self.Y))
    self:_adv(18)
    self.Win:_place()
    return { SetText = function(_, s) lbl.Text = s end }
end

function Section:Button(str, callback)
    local win, tab, rx, ry, W = self.Win, self.Tab, self.X, self.Y, self.W
    local bg = add(tab, rect("Track", true, 5), V2(rx, ry)); bg.Size = V2(W, 22)
    local border = add(tab, rect("Border", false, 6), V2(rx, ry)); border.Size = V2(W, 22)
    add(tab, txt(str, "Text", 7, true), V2(rx + W / 2, ry + 4))

    table.insert(tab.Handlers, {
        update = function(m)
            local over = win:_in(m, rx, ry, W, 22)
            win:_ease(bg, "Color", over and Theme.Hover or Theme.Track)
            win:_ease(border, "Color", over and Theme.Accent or Theme.Border)
        end,
        click = function(m)
            if win:_in(m, rx, ry, W, 22) then task.spawn(callback or function() end) return true end
        end,
    })
    self:_adv(30)
    win:_place()
end

function Section:Toggle(name, default, cb, flag)
    local win, tab, rx, ry, W = self.Win, self.Tab, self.X, self.Y, self.W
    local state = default and true or false

    local fill = add(tab, rect(state and "Accent" or "Track", true, 5), V2(rx + 2, ry + 4))
    fill.Size = V2(12, 12)
    local border = add(tab, rect("Outline", false, 6), V2(rx + 2, ry + 4)); border.Size = V2(12, 12)
    local label = add(tab, txt(name, state and "Text" or "SubText", 5), V2(rx + 24, ry + 3))

    local obj = { R = rx + W }
    local function set(v)
        state = v and true or false
        win:_ease(fill, "Color", state and Theme.Accent or Theme.Track)
        win:_ease(label, "Color", state and Theme.Text or Theme.SubText)
        if cb then task.spawn(cb, state) end
    end
    function obj:Set(v) set(v) end
    function obj:Get() return state end

    table.insert(win.Refreshers, function()
        fill.Color = state and Theme.Accent or Theme.Track
        label.Color = state and Theme.Text or Theme.SubText
    end)
    win:_flag(flag, "toggle", function() return state end, set)

    function obj:AddKeybind(default, kflag, onActive)
        local kb
        kb = win:_keybind(tab, V2(self.R - 18, ry + 3), default,
            function() if state and onActive then task.spawn(onActive, true) end end,
            { name = name, getActive = function() return state and kb.Held end }, nil,
            function() if onActive then task.spawn(onActive, false) end end)
        self.Bind = kb
        win:_flag(kflag, "keybind", function() return kb.Key end, function(k) kb.SetKey(k) end)
        self.R -= 40
        return self
    end
    -- enabled, and (if a key is bound) the key is currently held
    function obj:IsActive()
        if not state then return false end
        local kb = self.Bind
        return kb == nil or kb.Key == nil or kb.Held
    end
    function obj:AddColorpicker(default, onChange, cflag)
        local cp = win:_colorpicker(tab, V2(self.R - 28, ry + 4), default, onChange)
        win:_flag(cflag, "color", function() return cp.Get() end, function(c) cp:Set(c) end)
        self.R -= 36
        return self
    end

    table.insert(tab.Handlers, {
        update = function(m)
            local over = win:_in(m, rx, ry, obj.R - rx, 20)
            win:_ease(border, "Color", over and Theme.Accent or Theme.Outline)
            if not state then win:_ease(label, "Color", over and Theme.Text or Theme.SubText) end
        end,
        click = function(m)
            if win:_in(m, rx, ry, obj.R - rx, 20) then set(not state) return true end
        end,
    })

    self:_adv(22)
    win:_place()
    return obj
end

function Section:Keybind(name, default, cb, flag, onChange)
    local win, tab, rx, ry, W = self.Win, self.Tab, self.X, self.Y, self.W
    add(tab, txt(name, "Text", 5), V2(rx + 2, ry + 3))
    local kb = win:_keybind(tab, V2(rx + W - 22, ry + 3), default, cb, nil, onChange)
    win:_flag(flag, "keybind", function() return kb.Key end, function(k) kb.SetKey(k) end)
    self:_adv(22)
    win:_place()
    return kb
end

function Section:ColorPicker(name, default, cb, flag)
    local win, tab, rx, ry, W = self.Win, self.Tab, self.X, self.Y, self.W
    add(tab, txt(name, "Text", 5), V2(rx + 2, ry + 3))
    local cp = win:_colorpicker(tab, V2(rx + W - 28, ry + 4), default, cb)
    win:_flag(flag, "color", function() return cp.Get() end, function(c) cp:Set(c) end)
    self:_adv(22)
    win:_place()
    return cp
end

function Section:Slider(name, min, max, default, cb, opts)
    opts = opts or {}
    local step, suffix = opts.Step or 1, opts.Suffix or ""
    local win, tab, rx, ry, W = self.Win, self.Tab, self.X, self.Y, self.W
    local value = default or min
    local by = ry + 17

    add(tab, txt(name, "Text", 5), V2(rx + 2, ry))
    add(tab, rect("Track", true, 5), V2(rx, by)).Size = V2(W, 14)
    local fillTop = add(tab, rect("Accent", true, 6), V2(rx, by))
    local fillLow = add(tab, rect("AccentDark", true, 6), V2(rx, by + 7))
    local border = add(tab, rect("Border", false, 7), V2(rx, by)); border.Size = V2(W, 14)
    local label = add(tab, txt("", "Text", 8, true), V2(rx + W / 2, by - 1))

    local function render()
        local a = (value - min) / (max - min)
        local w = math.max(W * a, 0)
        fillTop.Size, fillLow.Size = V2(w, 7), V2(w, 7)
        local t = a > 0 and 1 or 0
        fillTop.Transparency, fillLow.Transparency = t, t
        label.Text = fmt(value) .. suffix .. "/" .. fmt(max) .. suffix
    end
    local function setValue(v)
        value = math.clamp(v, min, max)
        render()
        if cb then task.spawn(cb, value) end
    end
    local function fromMouse(m)
        local a = math.clamp((m.X - (win.Pos.X + rx)) / W, 0, 1)
        local nv = min + a * (max - min)
        nv = math.clamp(math.floor(nv / step + 0.5) * step, min, max)
        nv = math.floor(nv * 1000 + 0.5) / 1000
        if nv ~= value then setValue(nv) end
    end

    local dragging = false
    table.insert(tab.Handlers, {
        click = function(m)
            if win:_in(m, rx, by - 2, W, 18) then dragging = true; fromMouse(m) return true end
        end,
        update = function(m, held)
            if dragging then
                if held then fromMouse(m) else dragging = false end
            end
            local over = dragging or win:_in(m, rx, by - 2, W, 18)
            win:_ease(border, "Color", over and Theme.Accent or Theme.Border)
        end,
    })

    win:_flag(opts.Flag, "slider", function() return value end, function(v) setValue(tonumber(v) or value) end)
    render()
    self:_adv(36)
    win:_place()
    return {
        Get = function() return value end,
        Set = function(_, v) setValue(v) end,
    }
end

function Section:Dropdown(name, options, default, cb, flag)
    local win, tab, rx, ry, W = self.Win, self.Tab, self.X, self.Y, self.W
    local selected = default or options[1]
    local by = ry + 17
    local ROW, MAXROWS = 20, 8
    local offset = 0

    add(tab, txt(name, "Text", 5), V2(rx + 2, ry))
    add(tab, rect("Track", true, 5), V2(rx, by)).Size = V2(W, 20)
    local border = add(tab, rect("Border", false, 6), V2(rx, by)); border.Size = V2(W, 20)
    local selText = add(tab, txt(selected or "none", "Text", 7), V2(rx + 8, by + 3))

    local ax, ay = rx + W - 18, by + 8
    local _, arrowItem = add(tab, mk("Triangle", { Color = Theme.Text, Filled = true, ZIndex = 7, Visible = false }),
        nil, { V2(ax, ay), V2(ax + 8, ay), V2(ax + 4, ay + 5) })
    bind(tab.Items[#tab.Items].d, "Text")
    local function setArrow(open)
        arrowItem.tri = open and { V2(ax, ay + 5), V2(ax + 8, ay + 5), V2(ax + 4, ay) }
            or { V2(ax, ay), V2(ax + 8, ay), V2(ax + 4, ay + 5) }
        placeGroup(tab, win.Pos)
    end

    local pop = win:_popup(tab)
    local ly = by + 22
    local rowBg, rows, LH = {}, {}, 2

    local function visCount() return math.min(#options, MAXROWS) end

    local function build()
        removeGroup(pop, win.Anims)
        rowBg, rows = {}, {}
        local n = visCount()
        LH = n * ROW + 2
        add(pop, rect("Background", true, 60), V2(rx, ly)).Size = V2(W, LH)
        for i = 1, n do
            local bg = add(pop, rect("Background", true, 61), V2(rx + 1, ly + 1 + (i - 1) * ROW))
            bg.Size = V2(W - 2, ROW)
            rowBg[i] = bg
            rows[i] = add(pop, txt(options[offset + i], "Text", 62), V2(rx + 8, ly + 1 + (i - 1) * ROW + 3))
        end
        add(pop, rect("Accent", false, 63), V2(rx, ly)).Size = V2(W, LH)
        placeGroup(pop, win.Pos)
        showGroup(pop, win.Visible and pop.Open)
    end

    local function style(hover, instant)
        for i = 1, visCount() do
            local o = options[offset + i]
            local bgc = (i == hover) and Theme.Hover or Theme.Background
            local tc = (o == selected or i == hover) and Theme.Accent or Theme.Text
            if instant then
                rowBg[i].Color, rows[i].Color = bgc, tc
            else
                win:_ease(rowBg[i], "Color", bgc)
                win:_ease(rows[i], "Color", tc)
            end
        end
    end
    local function rowAt(m)
        local i = math.floor((m.Y - (win.Pos.Y + ly + 1)) / ROW) + 1
        return (i >= 1 and i <= visCount()) and i or nil
    end
    local function setSelected(o, silent)
        selected = o
        selText.Text = o or "none"
        if cb and not silent and o ~= nil then task.spawn(cb, o) end
    end

    pop.OnOpen = function() style(nil, true); setArrow(true); border.Color = Theme.Accent end
    pop.OnClose = function() setArrow(false); win:_ease(border, "Color", Theme.Border) end
    pop.Contains = function(m) return win:_in(m, rx, ly, W, LH) end
    pop.Opener = function(m) return win:_in(m, rx, by, W, 20) end
    pop.Update = function(m) style(rowAt(m)) end
    pop.Wheel = function(dir)
        if #options > MAXROWS then
            offset = math.clamp(offset + dir, 0, #options - MAXROWS)
            build()
            style(nil, true)
        end
    end
    pop.Click = function(m)
        local i = rowAt(m)
        if i then
            setSelected(options[offset + i])
            win:_close(pop)
        end
    end

    table.insert(tab.Handlers, {
        update = function(m)
            if not pop.Open then
                win:_ease(border, "Color", win:_in(m, rx, by, W, 20) and Theme.Accent or Theme.Border)
            end
        end,
        click = function(m)
            if win:_in(m, rx, by, W, 20) then
                if pop.Open then win:_close(pop)
                elseif #options > 0 then win:_open(pop) end
                return true
            end
        end,
    })

    build()
    win:_flag(flag, "dropdown", function() return selected end, function(o) setSelected(o) end)
    self:_adv(44)
    win:_place()
    return {
        Get = function() return selected end,
        Set = function(_, o) setSelected(o) end,
        SetOptions = function(_, list)
            if pop.Open then win:_close(pop) end
            options, offset = list, 0
            local found = false
            for _, o in ipairs(list) do if o == selected then found = true end end
            if not found then setSelected(list[1], true) end
            build()
        end,
    }
end

function Section:Textbox(name, placeholder, cb)
    local win, tab, rx, ry, W = self.Win, self.Tab, self.X, self.Y, self.W
    local by = ry + 17
    add(tab, txt(name, "Text", 5), V2(rx + 2, ry))
    add(tab, rect("Track", true, 5), V2(rx, by)).Size = V2(W, 20)
    local border = add(tab, rect("Border", false, 6), V2(rx, by)); border.Size = V2(W, 20)
    local disp = add(tab, txt("", "Text", 7), V2(rx + 8, by + 3))

    local obj = { Value = "" }
    local focused = false
    function obj.Focus()
        focused = true
        win.Typing = obj
        win:_sink(true)
        win.Anims[border] = nil
        border.Color = Theme.Accent
    end
    function obj.Blur()
        focused = false
        win:_ease(border, "Color", Theme.Border)
    end
    function obj.Commit() if cb then task.spawn(cb, obj.Value) end end
    function obj:Get() return self.Value end
    function obj:Set(v) self.Value = tostring(v or "") end

    table.insert(tab.Handlers, {
        update = function(m)
            if focused then
                disp.Text = obj.Value .. ((math.floor(os.clock() * 2) % 2 == 0) and "|" or " ")
                disp.Color = Theme.Text
            else
                if obj.Value == "" then
                    disp.Text, disp.Color = placeholder or "", Theme.SubText
                else
                    disp.Text, disp.Color = obj.Value, Theme.Text
                end
                win:_ease(border, "Color", win:_in(m, rx, by, W, 20) and Theme.Accent or Theme.Border)
            end
        end,
        click = function(m)
            if win:_in(m, rx, by, W, 20) then obj.Focus() return true end
        end,
    })

    self:_adv(44)
    win:_place()
    return obj
end

--------------------------------------------------------------------------
-- Overlays: watermark, keybind list, notifications
--------------------------------------------------------------------------
function Library:_buildOverlays()
    local vp = V2(1280, 720)
    pcall(function() vp = workspace.CurrentCamera.ViewportSize end)

    local wm = { Visible = false, Right = vp.X - 14, Y = 14, Pos = V2(0, 0), Size = V2(200, 22), Timer = 99 }
    wm.bg, wm.border = rect("Background", true, 90), rect("Border", false, 91)
    wm.line, wm.text = rect("Accent", true, 92), txt("", "Text", 93)
    wm.all = { wm.bg, wm.border, wm.line, wm.text }
    self.Watermark = wm

    local kl = { Visible = false, Pos = V2(14, math.floor(vp.Y / 2) - 80), Size = V2(140, 26), rows = {} }
    kl.bg, kl.border = rect("Background", true, 90), rect("Border", false, 91)
    kl.line, kl.head = rect("Accent", true, 92), txt("keybinds", "Text", 93)
    kl.all = { kl.bg, kl.border, kl.line, kl.head }
    for i = 1, 14 do
        kl.rows[i] = txt("", "SubText", 93)
        table.insert(kl.all, kl.rows[i])
    end
    self.KeyList = kl
end

function Library:SetWatermark(v)
    self.Watermark.Visible = v
    for _, d in ipairs(self.Watermark.all) do d.Visible = v end
end

function Library:SetKeybindList(v)
    self.KeyList.Visible = v
    for _, d in ipairs(self.KeyList.all) do d.Visible = v end
end

function Library:_updateOverlays(dt)
    self.Fps = self.Fps * 0.9 + (1 / math.max(dt, 0.001)) * 0.1

    local wm = self.Watermark
    if wm.Visible then
        wm.Timer += dt
        if wm.Timer > 0.5 then
            wm.Timer = 0
            local ping = 0
            pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            wm.text.Text = string.format("%s  |  %d fps  |  %d ms  |  %s", self.Title,
                math.floor(self.Fps + 0.5), math.floor(ping + 0.5), os.date("%I:%M %p"))
        end
        local w = (wm.text.TextBounds and wm.text.TextBounds.X or #wm.text.Text * 8) + 18
        wm.Size = V2(w, 22)
        wm.Pos = V2(wm.Right - w, wm.Y)
        wm.bg.Position, wm.bg.Size = wm.Pos, wm.Size
        wm.border.Position, wm.border.Size = wm.Pos, wm.Size
        wm.line.Position, wm.line.Size = wm.Pos, V2(w, 2)
        wm.text.Position = wm.Pos + V2(9, 5)
    end

    local kl = self.KeyList
    if kl.Visible then
        local entries = {}
        for _, kb in ipairs(self.Keybinds) do
            if kb.Meta and kb.Key then entries[#entries + 1] = kb end
        end
        local n = math.min(#entries, 14)
        local w = 130
        for i = 1, 14 do
            local row = kl.rows[i]
            if i <= n then
                local kb = entries[i]
                row.Text = kb.Meta.name .. "  [" .. keyShort(kb.Key) .. "]"
                local bw = (row.TextBounds and row.TextBounds.X or 0) + 20
                if bw > w then w = bw end
                row.Color = kb.Meta.getActive() and Theme.Accent or Theme.SubText
                row.Position = kl.Pos + V2(9, 26 + (i - 1) * 16)
            end
            row.Visible = i <= n
        end
        kl.Size = V2(w, 26 + n * 16 + 6)
        kl.bg.Position, kl.bg.Size = kl.Pos, kl.Size
        kl.border.Position, kl.border.Size = kl.Pos, kl.Size
        kl.line.Position, kl.line.Size = kl.Pos, V2(w, 2)
        kl.head.Position = kl.Pos + V2(9, 6)
    end
end

function Library:Notify(text, dur)
    local tx = txt(text, "Text", 102)
    tx.Visible = true
    local w = (tx.TextBounds and tx.TextBounds.X or #text * 8) + 24
    local bg, bar, bd = rect("Background", true, 100), rect("Accent", true, 101), rect("Border", false, 101)
    for _, d in ipairs({ bg, bar, bd }) do d.Visible = true end
    bg.Size, bd.Size, bar.Size = V2(w, 24), V2(w, 24), V2(2, 24)
    table.insert(self.Notes, { bg = bg, bar = bar, bd = bd, tx = tx, w = w, t = 0, dur = dur or 3 })
end

function Library:_updateNotes(dt)
    for i = #self.Notes, 1, -1 do
        local n = self.Notes[i]
        n.t += dt
        if n.t >= n.dur then
            local gone = { [n.bg] = true, [n.bar] = true, [n.bd] = true, [n.tx] = true }
            for d in pairs(gone) do pcall(function() d:Remove() end) end
            for j = #Bindings, 1, -1 do if gone[Bindings[j].d] then table.remove(Bindings, j) end end
            for j = #AllTexts, 1, -1 do if gone[AllTexts[j]] then table.remove(AllTexts, j) end end
            table.remove(self.Notes, i)
        else
            local a = math.min(n.t / 0.25, 1)
            local x = -n.w + (18 + n.w) * (1 - (1 - a) ^ 3)
            local target = 70 + (i - 1) * 30
            n.y = n.y and (n.y + (target - n.y) * 0.2) or target
            local rem = n.dur - n.t
            local alpha = rem < 0.4 and math.max(rem / 0.4, 0) or 1
            local pos = V2(x, n.y)
            n.bg.Position, n.bd.Position, n.bar.Position = pos, pos, pos
            n.tx.Position = pos + V2(12, 5)
            n.bg.Transparency, n.bd.Transparency, n.bar.Transparency, n.tx.Transparency = alpha, alpha, alpha, alpha
        end
    end
end

--------------------------------------------------------------------------
-- Input / render loop
--------------------------------------------------------------------------
function Library:_connect()
    local held = false

    local function onClick(m)
        if self.Typing then self:_blur() end

        local cur = self.Current
        if cur then
            if cur.Contains(m) then cur.Click(m) return end
            local opener = cur.Opener and cur.Opener(m)
            self:_close(cur)
            if opener then return end
        end

        for _, o in ipairs({ self.Watermark, self.KeyList }) do
            if o.Visible and inAbs(m, o.Pos, o.Size) then
                self.DragObj = { o = o, off = m - o.Pos }
                return
            end
        end

        if self:_in(m, 0, 0, self.Size.X, TITLE_H) then
            self.Dragging = m - self.Pos
            return
        end
        for _, t in ipairs(self.Tabs) do
            if self:_in(m, t.HX, 30, t.HW, 22) then self:SetTab(t) return end
        end
        if self.Active then
            for _, h in ipairs(self.Active.Handlers) do
                if h.click and h.click(m) then return end
            end
        end
    end

    table.insert(self.Conns, UIS.InputBegan:Connect(function(input)
        -- text entry
        if self.Typing and input.UserInputType == Enum.UserInputType.Keyboard then
            local t, kc = self.Typing, input.KeyCode
            if kc == Enum.KeyCode.Return or kc == Enum.KeyCode.KeypadEnter then
                self:_blur()
                t.Commit()
            elseif kc == Enum.KeyCode.Escape then
                self:_blur()
            elseif kc == Enum.KeyCode.Backspace then
                t.Value = t.Value:sub(1, -2)
            else
                local ch = charFor(input)
                if ch and ch:match("^[%w _%-]$") and #t.Value < 28 then t.Value ..= ch end
            end
            return
        end

        -- rebinding
        if self.Listening then
            local l, k = self.Listening, nil
            local ut = input.UserInputType
            if ut == Enum.UserInputType.MouseButton1 then
                l.Cancel()
                self.Listening = nil
            else
                if ut == Enum.UserInputType.Keyboard then
                    k = input.KeyCode
                    if k == Enum.KeyCode.Escape or k == Enum.KeyCode.Backspace then k = nil end
                elseif ut == Enum.UserInputType.MouseButton2 or ut == Enum.UserInputType.MouseButton3 then
                    k = ut
                else
                    return
                end
                l.SetKey(k)
                self.Listening = nil
                return
            end
        end

        if input.KeyCode == self.ToggleKey or input.UserInputType == self.ToggleKey then
            self:SetVisible(not self.Visible)
            return
        end

        if not UIS:GetFocusedTextBox() then
            for _, kb in ipairs(self.Keybinds) do
                if kb.Key and (input.KeyCode == kb.Key or input.UserInputType == kb.Key) then kb.Fire() end
            end
        end

        if self.Visible and input.UserInputType == Enum.UserInputType.MouseButton1 then
            held = true
            onClick(UIS:GetMouseLocation())
        end
    end))

    table.insert(self.Conns, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            held = false
            self.Dragging, self.DragObj = nil, nil
        end
        for _, kb in ipairs(self.Keybinds) do
            if kb.Key and (input.KeyCode == kb.Key or input.UserInputType == kb.Key) then kb.Release() end
        end
    end))

    table.insert(self.Conns, UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel and self.Visible
            and self.Current and self.Current.Wheel then
            self.Current.Wheel(input.Position.Z > 0 and -1 or 1)
        end
    end))

    table.insert(self.Conns, RunService.RenderStepped:Connect(function(dt)
        local m = UIS:GetMouseLocation()

        if self.DragObj and self.Visible then
            local o, np = self.DragObj.o, m - self.DragObj.off
            if o == self.Watermark then o.Right, o.Y = np.X + o.Size.X, np.Y else o.Pos = np end
        end
        self:_updateOverlays(dt)
        self:_updateNotes(dt)

        -- color animations
        for d, a in pairs(self.Anims) do
            local ok = pcall(function()
                local target = a.target
                local nxt = d[a.prop]:Lerp(target, self.AnimSpeed)
                if math.abs(nxt.R - target.R) + math.abs(nxt.G - target.G) + math.abs(nxt.B - target.B) < 0.01 then
                    nxt = target
                    self.Anims[d] = nil
                end
                d[a.prop] = nxt
            end)
            if not ok then self.Anims[d] = nil end
        end

        if not self.Visible then return end

        if self.Dragging then
            self.Pos = m - self.Dragging
            self:_place()
        end

        for _, t in ipairs(self.Tabs) do
            local on = t == self.Active
            local over = self:_in(m, t.HX, 30, t.HW, 22)
            self:_ease(t.Label, "Color", (on or over) and Theme.Text or Theme.SubText)
        end

        if self.Current and self.Current.Update then self.Current.Update(m, held) end
        if self.Active then
            for _, h in ipairs(self.Active.Handlers) do
                if h.update then h.update(m, held) end
            end
        end
    end))
end

function Library:Destroy()
    self:_blur()
    for _, c in ipairs(self.Conns) do c:Disconnect() end
    table.clear(self.Anims)
    removeGroup(self.Chrome)
    for _, t in ipairs(self.Tabs) do removeGroup(t) end
    for _, p in ipairs(self.Popups) do removeGroup(p) end
    for _, d in ipairs(self.Watermark.all) do pcall(function() d:Remove() end) end
    for _, d in ipairs(self.KeyList.all) do pcall(function() d:Remove() end) end
    for _, n in ipairs(self.Notes) do
        for _, d in ipairs({ n.bg, n.bar, n.bd, n.tx }) do pcall(function() d:Remove() end) end
    end
    table.clear(Bindings)
    table.clear(AllTexts)
end

--------------------------------------------------------------------------
-- UI manager: menu options, theme editor
--------------------------------------------------------------------------
function Library:BuildUIManager(tab)
    local win = self

    local menu = tab:Section("menu", "left")
    menu:Toggle("watermark", true, function(v) win:SetWatermark(v) end, "ui_watermark")
    menu:Toggle("keybind list", true, function(v) win:SetKeybindList(v) end, "ui_keylist")
    menu:Keybind("menu key", Enum.KeyCode.RightShift, nil, "ui_menukey", function(k)
        win.ToggleKey = k or Enum.KeyCode.RightShift
    end)
    menu:Button("unload", function() win:Destroy() end)
    win:SetWatermark(true)
    win:SetKeybindList(true)

    local theme = tab:Section("theme", "left")
    local pickers = {}
    for _, key in ipairs({ "Accent", "Text", "SubText", "Background", "Track", "Hover", "Outline", "Border" }) do
        pickers[key] = theme:ColorPicker(key:lower(), Theme[key], function(c)
            Theme[key] = c
            win:_retheme()
        end, "theme_" .. key)
    end
    theme:Button("reset theme", function()
        for key, c in pairs(DEFAULT_THEME) do pickers[key]:Set(c) end
        win:Notify("theme reset")
    end)
end

--------------------------------------------------------------------------
-- SaveManager: save / load / delete configs, autoload
--------------------------------------------------------------------------
local SaveManager = {}
SaveManager.__index = SaveManager
Library.SaveManager = SaveManager

local function hasFS()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
        and type(isfolder) == "function" and type(makefolder) == "function" and type(listfiles) == "function"
end

local function sanitize(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or name:find("[^%w _%-]") then return nil end
    return name
end

local function encodeValue(typ, v)
    if typ == "color" then
        return string.format("#%02X%02X%02X", math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5),
            math.floor(v.B * 255 + 0.5))
    elseif typ == "keybind" then
        return keyToStr(v)
    end
    return v
end

local function decodeValue(typ, v)
    if typ == "color" then
        local r, g, b = tostring(v):match("^#(%x%x)(%x%x)(%x%x)$")
        if r then return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)) end
        return nil
    elseif typ == "keybind" then
        return strToKey(v)
    end
    return v
end

function SaveManager.new(win, folder)
    local self = setmetatable({ Win = win, Folder = folder or "enigma" }, SaveManager)
    if hasFS() then
        pcall(function()
            if not isfolder(self.Folder) then makefolder(self.Folder) end
            if not isfolder(self.Folder .. "/configs") then makefolder(self.Folder .. "/configs") end
        end)
    end
    return self
end

function SaveManager:_path(name) return self.Folder .. "/configs/" .. name .. ".json" end

function SaveManager:List()
    local out = {}
    if not hasFS() then return out end
    pcall(function()
        for _, f in ipairs(listfiles(self.Folder .. "/configs")) do
            local n = f:match("([^/\\]+)%.json$")
            if n then out[#out + 1] = n end
        end
    end)
    table.sort(out)
    return out
end

function SaveManager:Save(name)
    name = sanitize(name)
    if not name then return false, "invalid config name" end
    if not hasFS() then return false, "filesystem unavailable" end
    local data = {}
    for flag, f in pairs(self.Win.Flags) do
        local ok, v = pcall(f.Get)
        if ok then data[flag] = encodeValue(f.Type, v) end
    end
    local ok, err = pcall(function() writefile(self:_path(name), HttpService:JSONEncode(data)) end)
    return ok, ok and name or tostring(err)
end

function SaveManager:Load(name)
    name = sanitize(name)
    if not name then return false, "invalid config name" end
    if not hasFS() or not isfile(self:_path(name)) then return false, "config not found" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(self:_path(name))) end)
    if not ok or type(data) ~= "table" then return false, "config is corrupted" end
    for flag, val in pairs(data) do
        local f = self.Win.Flags[flag]
        if f then
            local v = decodeValue(f.Type, val)
            if v ~= nil or f.Type == "keybind" then pcall(f.Set, v) end
        end
    end
    return true, name
end

function SaveManager:Delete(name)
    name = sanitize(name)
    if not name or not hasFS() or not isfile(self:_path(name)) then return false, "config not found" end
    local ok = pcall(function() delfile(self:_path(name)) end)
    return ok, name
end

function SaveManager:SetAutoload(name)
    if not hasFS() then return false end
    local ok = pcall(function() writefile(self.Folder .. "/autoload.txt", name or "") end)
    return ok
end

function SaveManager:GetAutoload()
    if not hasFS() then return nil end
    local ok, r = pcall(function()
        local p = self.Folder .. "/autoload.txt"
        return isfile(p) and readfile(p) or nil
    end)
    if ok and r and r ~= "" then return r end
    return nil
end

function SaveManager:LoadAutoload()
    local name = self:GetAutoload()
    if name then
        local ok, msg = self:Load(name)
        self.Win:Notify(ok and ("autoloaded " .. name) or ("autoload failed: " .. msg))
    end
end

function SaveManager:BuildSection(tab, side)
    local win = self.Win
    local sec = tab:Section("configs", side or "right")
    local nameBox = sec:Textbox("config name", "enter a name...")
    local list = sec:Dropdown("config list", self:List(), nil)
    local status = sec:Label("autoload: " .. (self:GetAutoload() or "none"))

    local function refresh() list:SetOptions(self:List()) end
    local function report(ok, msg, good)
        win:Notify(ok and good or msg)
    end
    local function selected()
        local s = list:Get()
        if not s then win:Notify("select a config first") end
        return s
    end

    sec:Button("create config", function()
        local ok, msg = self:Save(nameBox:Get())
        if ok then refresh(); list:Set(msg) end
        report(ok, msg, "created " .. tostring(msg))
    end)
    sec:Button("load config", function()
        local s = selected()
        if s then local ok, msg = self:Load(s); report(ok, msg, "loaded " .. s) end
    end)
    sec:Button("overwrite config", function()
        local s = selected()
        if s then local ok, msg = self:Save(s); report(ok, msg, "saved " .. s) end
    end)
    sec:Button("delete config", function()
        local s = selected()
        if s then
            local ok, msg = self:Delete(s)
            if ok then refresh() end
            report(ok, msg, "deleted " .. s)
        end
    end)
    sec:Button("refresh list", refresh)
    sec:Button("set as autoload", function()
        local s = selected()
        if s then
            self:SetAutoload(s)
            status:SetText("autoload: " .. s)
            win:Notify("autoload set to " .. s)
        end
    end)

    if not hasFS() then win:Notify("filesystem functions unavailable") end
    return sec
end

--------------------------------------------------------------------------
-- Example (runs when the script is loaded; delete this block to use the
-- file as a pure library)
--------------------------------------------------------------------------
