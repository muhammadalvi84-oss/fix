--[[
    MhmmdalviStudio v4.0  |  BY MHMMDALVI   (dasar: Copy Map UI v3.4)
    Tab: Copy Map, Import Map, Replacer, Scripts, Info, Settings.
    Import RBXL / RBXM / RBXLX / RBXMX: isi script dibaca LANGSUNG dari file lalu dipasang ke script hasil import.
    Hanya GUI (tampilan + interaksi). Logika copy/import dipasang lewat:
        UI.OnCopy   = function(services, fileName) ... end
        UI.OnImport = function(path, opts) ... end   -- sudah terpasang (RBXL biner)
        UI.OnScan   = function() ... end   -- opsional
    Update progress dari logika kamu:
        UI.Begin()
        UI.SetProgress(persen, "judul status", "keterangan")
        UI.SetProgress(100, "Selesai", "File tersimpan")
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------------
-- OWNER  (akun yang dikenali sebagai pemilik script ini)
---------------------------------------------------------------------
-- Cocokkan lewat username (tanpa peka huruf besar/kecil). Awalan "5KxVii" juga dikenali,
-- jadi 5KxVii_02 otomatis owner. Lebih aman: isi UserId akunmu di OWNER_USER_IDS
-- (angka UserId tampil di tab Info), karena username bisa ditiru akun lain.
local OWNER_NAMES    = {"5KxVii"}
local OWNER_USER_IDS = {}

local function isOwnerPlayer(p)
    if table.find(OWNER_USER_IDS, p.UserId) then return true end
    local n = string.lower(p.Name)
    for _, o in ipairs(OWNER_NAMES) do
        if string.sub(n, 1, #o) == string.lower(o) then return true end
    end
    return false
end
local IS_OWNER = isOwnerPlayer(Players.LocalPlayer)

---------------------------------------------------------------------
-- THEME
---------------------------------------------------------------------
local T = {
    Window   = Color3.fromRGB(14, 14, 20),
    Panel    = Color3.fromRGB(19, 19, 27),
    Card     = Color3.fromRGB(28, 28, 38),
    Field    = Color3.fromRGB(10, 10, 14),
    Line     = Color3.fromRGB(48, 48, 64),
    Accent   = Color3.fromRGB(136, 96, 250),    -- ungu (tombol utama)
    AccentLn = Color3.fromRGB(178, 148, 255),
    OnAccent = Color3.fromRGB(255, 255, 255),
    Text     = Color3.fromRGB(240, 240, 248),
    Muted    = Color3.fromRGB(150, 150, 172),
    Title    = Color3.fromRGB(172, 150, 255),
    Ok       = Color3.fromRGB(52, 200, 120),
    Bad      = Color3.fromRGB(240, 84, 96),
    NavOn    = Color3.fromRGB(70, 50, 126),       -- menu aktif (abu gelap)
}

-- latar gelap dengan semburat ungu tipis
local GLASS_BG = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 16, 24)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(24, 19, 40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 22)),
})

local SERVICES = {
    "Workspace", "Players", "Lighting", "MaterialService",
    "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage",
    "StarterGui", "StarterPack", "StarterPlayer", "Teams",
    "SoundService", "Chat", "TextChatService", "LocalizationService",
}

---------------------------------------------------------------------
-- HELPER
---------------------------------------------------------------------
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
        if o.TextSize <= 9 then o.TextSize = o.TextSize + 1 end
    end
    o.Parent = parent
    return o
end

local function corner(p, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r)}, p)
end

local function stroke(p, color, thick, trans)
    local st = new("UIStroke", {
        Color = color, Thickness = thick or 1, Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
    if color == T.Line then
        -- terang di tengah, memudar ke ujung: efek "glow" seperti desain referensi
        new("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.75),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(1, 0.75),
            }),
        }, st)
    end
    return st
end

local function label(parent, props)
    local d = {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }
    for k, v in pairs(props) do d[k] = v end
    return new("TextLabel", d, parent)
end

local function button(parent, props)
    local d = {
        AutoButtonColor = false, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.Text,
        BackgroundColor3 = T.Card, Text = "",
    }
    for k, v in pairs(props) do d[k] = v end
    local b = new("TextButton", d, parent)
    local base = b.BackgroundColor3
    b.MouseEnter:Connect(function()
        if b:GetAttribute("NoHover") then return end
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.35)}):Play()
    end)
    b.MouseLeave:Connect(function()
        if b:GetAttribute("NoHover") then return end
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = base}):Play()
    end)
    return b
end

local function fmt(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (out:gsub("^%.", ""))
end

local function mmss(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%02d:%02d", sec // 60, sec % 60)
end

---------------------------------------------------------------------
-- PARENT GUI
---------------------------------------------------------------------
local ok, host = pcall(function()
    return (gethui and gethui()) or game:GetService("CoreGui")
end)
if not ok or not host then
    host = Players.LocalPlayer:WaitForChild("PlayerGui")
end
for _, nm in ipairs({"CopyMapUI", "MhmmdalviStudio"}) do
    local old = host:FindFirstChild(nm)
    if old then old:Destroy() end
end

local UI = {}
UI.Cleanups = {}
UI.Settings = {stream = true, decompile = true, threads = 24, timeout = 5, radius = 1024}
UI.CancelFlag = false
UI.ScriptCache = setmetatable({}, {__mode = "k"})
local gui = new("ScreenGui", {
    Name = "MhmmdalviStudio", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, host)

local WIN_W, WIN_H = 910, 440
-- Frame biasa (bukan CanvasGroup): CanvasGroup merender isinya sebagai tekstur lalu
-- diskalakan, itu yang membuat teks blur. Dengan Frame, teks digambar langsung = tajam.
local main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(WIN_W, WIN_H),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
corner(main, 26)
do
    local ms = stroke(main, T.Accent, 1.8, 0.15)
    local mg = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 92, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 96, 200)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 200, 255)),
        }),
    }, ms)
    TweenService:Create(mg, TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = 360}):Play()
end
new("UIGradient", {Color = GLASS_BG, Rotation = 35}, main)

local scale = new("UIScale", {}, main)
local isOpen, animating, fitK = true, false, 1
local function fitScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    -- maks 0.88 (lebih kecil dari sebelumnya), dibulatkan ke kelipatan 0.05 agar piksel teks rapi
    fitK = math.min(0.88, (vp.X * 0.9) / WIN_W, (vp.Y * 0.9) / WIN_H)
    fitK = math.max(math.floor(fitK * 20) / 20, 0.5)
    if isOpen and not animating then scale.Scale = fitK end
end
fitScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
end

---------------------------------------------------------------------
-- DRAG
---------------------------------------------------------------------
local function makeDraggable(handle)
    local dragging, startInput, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = (i.Position - startInput) / scale.Scale
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

---------------------------------------------------------------------
-- HEADER
---------------------------------------------------------------------
local header = new("Frame", {
    Name = "Header", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 46),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, main)
corner(header, 16)
stroke(header, T.Line, 1)
makeDraggable(header)
new("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 34, 104)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(26, 21, 44)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(19, 19, 27)),
    }),
}, header)

local headLogo = new("Frame", {
    Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, header)
corner(headLogo, 11)
stroke(headLogo, T.Line, 1)
label(headLogo, {
    Text = "M", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = T.Title,
    TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
})
label(header, {
    Text = "BUILD  ·  COPY  ·  IMPORT", Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = T.Muted,
    Position = UDim2.fromOffset(52, 3), Size = UDim2.fromOffset(200, 11),
})
label(header, {
    Text = 'Mhmmdalvi<font color="#C79BFF">Studio</font>', RichText = true,
    Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.Text,
    Position = UDim2.fromOffset(52, 13), Size = UDim2.fromOffset(260, 18),
})
local statDot = new("Frame", {
    Position = UDim2.fromOffset(53, 35), Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = T.Ok, BorderSizePixel = 0,
}, header)
corner(statDot, 3)
label(header, {
    Text = Players.LocalPlayer.Name .. "  ·  v4.0", TextSize = 9, TextColor3 = T.Muted,
    Position = UDim2.fromOffset(65, 31), Size = UDim2.fromOffset(200, 14),
})
if IS_OWNER then
    local badge = new("Frame", {
        Position = UDim2.fromOffset(250, 14), Size = UDim2.fromOffset(62, 16),
        BackgroundColor3 = Color3.fromRGB(255, 196, 60), BorderSizePixel = 0,
    }, header)
    corner(badge, 8)
    label(badge, {
        Text = "👑 OWNER", Font = Enum.Font.GothamBlack, TextSize = 9,
        TextColor3 = Color3.fromRGB(40, 26, 0), TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1),
    })
end

local function headIcon(text, x)
    local b = new("TextButton", {
        Text = text, Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, x, 0.5, -17),
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        TextColor3 = T.Text, Font = Enum.Font.GothamBold, TextSize = 16,
    }, header)
    corner(b, 17)
    stroke(b, T.Line, 1.5)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {TextColor3 = T.AccentLn}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {TextColor3 = T.Text}):Play()
    end)
    return b
end
local btnClose    = headIcon("X", -42)
local btnMinimize = headIcon("-", -80)   -- kecilkan (animasi)

-- sidebar menu
local sidebar = new("Frame", {
    Position = UDim2.fromOffset(10, 62), Size = UDim2.new(0, 130, 1, -72),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, main)
corner(sidebar, 18)
stroke(sidebar, T.Line, 1)
new("UIListLayout", {
    Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, sidebar)
new("UIPadding", {PaddingTop = UDim.new(0, 10)}, sidebar)

local function navItem(text, order)
    local b = new("TextButton", {
        LayoutOrder = order, Size = UDim2.new(1, -16, 0, 31), BackgroundColor3 = T.NavOn,
        BackgroundTransparency = 1, Text = text, TextColor3 = T.Muted, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0,
    }, sidebar)
    corner(b, 12)
    new("UIPadding", {PaddingLeft = UDim.new(0, 14)}, b)
    return b
end
local tabCopy     = navItem("🗺  Copy Map", 1)
local tabImport   = navItem("📂  Import Map", 2)
local tabReplacer = navItem("🔁  Replacer", 3)
local tabScripts  = navItem("📜  Scripts", 4)
local tabInfo     = navItem("ℹ  Info", 5)
local tabSettings = navItem("⚙  Settings", 6)

-- AKSI CEPAT (bawah sidebar)
local quick = new("Frame", {
    Position = UDim2.fromOffset(16, 358), Size = UDim2.fromOffset(118, 66), BackgroundTransparency = 1,
}, main)
label(quick, {
    Text = "Aksi Cepat", TextSize = 9, TextColor3 = T.Muted,
    Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, 0, 0, 12),
})
local btnPing = button(quick, {
    Text = "Cek Koneksi", Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 24),
    BackgroundColor3 = Color3.fromRGB(37, 88, 200), TextColor3 = T.OnAccent, TextSize = 10,
})
corner(btnPing, 10)
local btnHide = button(quick, {
    Text = "Sembunyi", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 24),
    BackgroundColor3 = T.Card, TextSize = 10,
})
corner(btnHide, 10)
local pinging = false
btnPing.MouseButton1Click:Connect(function()
    if pinging then return end
    pinging = true
    btnPing.Text = "Mengecek..."
    task.spawn(function()
        local t0 = os.clock()
        local ok = pcall(function() return game:HttpGet("https://www.roblox.com/robots.txt") end)
        local ms = math.floor((os.clock() - t0) * 1000)
        btnPing.Text = ok and ("OK  " .. ms .. " ms") or "Gagal"
        task.wait(2)
        btnPing.Text = "Cek Koneksi"
        pinging = false
    end)
end)
btnHide.MouseButton1Click:Connect(function()
    if UI.Minimize then UI.Minimize() end
end)

---------------------------------------------------------------------
-- BUKA / TUTUP GUI (BERANIMASI) + TOMBOL MELAYANG
--   *  = kecilkan (animasi) -> tombol melayang CM muncul, tap untuk buka
--   X  = tutup & keluar (animasi)
--   RightCtrl = buka/tutup cepat (PC)
---------------------------------------------------------------------
local OPEN_FROM = 0.84
local animToken = 0
local uiConns = {}

local fab = new("TextButton", {
    Name = "Fab", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 44, 0.5, 0),
    Size = UDim2.fromOffset(0, 0), BackgroundColor3 = T.Accent, Text = "M", TextColor3 = T.OnAccent,
    Font = Enum.Font.GothamBlack, TextSize = 15, AutoButtonColor = false, BorderSizePixel = 0,
    Visible = false, ZIndex = 50,
}, gui)
corner(fab, 30)
stroke(fab, T.AccentLn, 2)
local fabDot = new("Frame", {
    Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -14, 0, 2),
    BackgroundColor3 = T.Ok, BorderSizePixel = 0, ZIndex = 51,
}, fab)
corner(fabDot, 6)

local fabTip = label(fab, {
    Position = UDim2.new(1, 10, 0.5, -15), AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 0, 30), BackgroundTransparency = 0, BackgroundColor3 = T.Window,
    Text = "", TextSize = 10, Font = Enum.Font.GothamBold, ZIndex = 51, Visible = false,
    TextTruncate = Enum.TextTruncate.AtEnd,
})
corner(fabTip, 15)
stroke(fabTip, T.AccentLn, 1)
new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, fabTip)
new("UISizeConstraint", {MaxSize = Vector2.new(420, 30)}, fabTip)

local fabNoteId = 0
function UI.FabNote(text, secs)
    if not fab.Visible then return end
    fabNoteId += 1
    local id = fabNoteId
    fabTip.Text = text
    fabTip.Visible = true
    task.delay(secs or 3, function()
        if id == fabNoteId then fabTip.Visible = false end
    end)
end

local fabMoved = false
do
    local dragging, startIn, startPos = false, nil, nil
    fab.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, fabMoved = true, false
            startIn, startPos = i.Position, fab.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    table.insert(uiConns, UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startIn
            if d.Magnitude > 8 then fabMoved = true end
            if fabMoved then
                fab.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end))
end

local function showFab()
    fab.Visible = true
    fab.Size = UDim2.fromOffset(0, 0)
    TweenService:Create(fab, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.fromOffset(56, 56)}):Play()
end
local function hideFab()
    if not fab.Visible then return end
    fabTip.Visible = false
    local t = TweenService:Create(fab, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = UDim2.fromOffset(0, 0)})
    t:Play()
    task.delay(0.2, function()
        if isOpen then fab.Visible = false end
    end)
end

local function openWindow()
    animToken += 1
    local my = animToken
    isOpen = true
    animating = true
    hideFab()
    main.Visible = true
    scale.Scale = fitK * OPEN_FROM
    TweenService:Create(scale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = fitK}):Play()
    task.delay(0.42, function()
        if animToken == my then
            animating = false
            scale.Scale = fitK
        end
    end)
end

local function closeWindow(destroyAfter)
    animToken += 1
    local my = animToken
    isOpen = false
    animating = true
    TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = fitK * OPEN_FROM}):Play()
    task.delay(0.26, function()
        if animToken ~= my then return end
        main.Visible = false
        if destroyAfter then gui:Destroy() else showFab() end
    end)
end

function UI.Minimize() if isOpen then closeWindow(false) end end
function UI.Restore()
    if UI.OnRestore then pcall(UI.OnRestore) end
    if not isOpen then openWindow() end
end
function UI.IsOpen() return isOpen end
function UI.OverGui(p)
    if fab.Visible then
        local a, s = fab.AbsolutePosition, fab.AbsoluteSize
        if p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y then return true end
    end
    if isOpen and main.Visible then
        local a, s = main.AbsolutePosition, main.AbsoluteSize
        if p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y then return true end
    end
    return false
end

fab.MouseButton1Click:Connect(function()
    if fabMoved then return end
    UI.Restore()
end)
btnClose.MouseButton1Click:Connect(function() closeWindow(true) end)
btnMinimize.MouseButton1Click:Connect(function() closeWindow(false) end)

table.insert(uiConns, UserInputService.InputBegan:Connect(function(i, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if i.KeyCode == Enum.KeyCode.RightControl then
        if isOpen then closeWindow(false) else UI.Restore() end
    end
end))

gui.Destroying:Connect(function()
    for _, c in ipairs(uiConns) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(UI.Cleanups) do pcall(fn) end
end)

---------------------------------------------------------------------
-- PAGE: COPY MAP
---------------------------------------------------------------------
local copyPage = new("Frame", {
    Name = "CopyPage", Position = UDim2.fromOffset(150, 58), Size = UDim2.new(1, -150, 1, -58),
    BackgroundTransparency = 1,
}, main)

-- judul kolom
label(copyPage, {
    Text = "SERVICE STUDIO", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(180, 20),
})
local lblSelected = label(copyPage, {
    Text = "0 dipilih", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(204, 4), Size = UDim2.fromOffset(98, 20),
})
label(copyPage, {
    Text = "COPY MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(316, 4), Size = UDim2.fromOffset(120, 20),
})
label(copyPage, {
    Text = "FILE.RBXL  ·  SAMA DENGAN STUDIO", TextSize = 8, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(436, 4), Size = UDim2.fromOffset(310, 20),
})

-- ===== panel kiri =====
local left = new("Frame", {
    Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(290, 340),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, copyPage)
corner(left, 14)
stroke(left, T.Line, 1)

local btnRow = new("Frame", {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1,
}, left)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, btnRow)

local function smallBtn(text, order)
    local b = button(btnRow, {
        Text = text, Size = UDim2.new(1 / 3, -6, 1, 0), BackgroundColor3 = T.Field,
        TextSize = 8, LayoutOrder = order,
    })
    corner(b, 10)
    stroke(b, T.Line, 1)
    return b
end
local btnAll   = smallBtn("PILIH SEMUA", 1)
local btnNone  = smallBtn("KOSONGKAN", 2)
local btnScan  = smallBtn("SCAN ULANG", 3)

local list = new("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 1, -60),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, left)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, list)
new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, list)

-- ===== panel kanan =====
local stats = new("Frame", {
    Position = UDim2.fromOffset(316, 30), Size = UDim2.fromOffset(430, 92),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, copyPage)
corner(stats, 14)
stroke(stats, T.Line, 1)

local function statCard(title, x, y)
    local c = new("Frame", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(203, 36),
        BackgroundColor3 = T.Field, BorderSizePixel = 0,
    }, stats)
    corner(c, 10)
    stroke(c, T.Line, 1, 0.3)
    label(c, {Text = title, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 11)})
    return label(c, {Text = "0", Font = Enum.Font.GothamBold, TextSize = 12,
        Position = UDim2.fromOffset(12, 16), Size = UDim2.new(1, -24, 0, 16)})
end
local valService = statCard("SERVICE", 8, 8)
local valItem    = statCard("ITEM", 219, 8)
local valScript  = statCard("SCRIPT", 8, 48)
local valFormat  = statCard("FORMAT", 219, 48)
valFormat.Text = "RBXL  -  Binary"

-- nama file
local nameBox = new("Frame", {
    Position = UDim2.fromOffset(316, 130), Size = UDim2.fromOffset(430, 56),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, copyPage)
corner(nameBox, 14)
stroke(nameBox, T.Line, 1)
local lblNameMode = label(nameBox, {Text = "NAMA FILE  -  OTOMATIS", Font = Enum.Font.GothamBold, TextSize = 8,
    TextColor3 = T.Muted, Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(250, 12)})
local lblFileOut = label(nameBox, {Text = "Studio Lite.rbxl", TextSize = 8, TextColor3 = T.AccentLn,
    TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.new(1, -232, 0, 6), Size = UDim2.fromOffset(220, 12)})

local nameField = new("Frame", {
    Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 28),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, nameBox)
corner(nameField, 8)
stroke(nameField, T.Line, 1)
local nameInput = new("TextBox", {
    Size = UDim2.new(1, -112, 1, 0), Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = T.Text, PlaceholderText = "Studio Lite", PlaceholderColor3 = T.Muted,
    Text = "", TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
}, nameField)
local btnAutoName = button(nameField, {
    Text = "NAMA MAP", Size = UDim2.fromOffset(92, 20), AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -4, 0.5, 0), BackgroundColor3 = T.Card, TextSize = 8,
})
corner(btnAutoName, 7)

local function currentFileName()
    local n = nameInput.Text:gsub("[\\/:*?\"<>|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then n = "Studio Lite" end
    return n
end
local function refreshFileLabel()
    lblFileOut.Text = currentFileName() .. ".rbxl"
    lblNameMode.Text = (nameInput.Text:gsub("%s", "") == "") and "NAMA FILE  -  OTOMATIS" or "NAMA FILE  -  CUSTOM"
end
nameInput:GetPropertyChangedSignal("Text"):Connect(refreshFileLabel)
btnAutoName.MouseButton1Click:Connect(function()
    local nm = "Studio Lite"
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        if info and info.Name then nm = info.Name end
    end)
    nameInput.Text = nm
end)
refreshFileLabel()

-- progress
local progBox = new("Frame", {
    Position = UDim2.fromOffset(316, 194), Size = UDim2.fromOffset(430, 126),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, copyPage)
corner(progBox, 14)
stroke(progBox, T.Line, 1)
local progTitle = label(progBox, {Text = "Siap copy map", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16)})
local progSub = label(progBox, {Text = "Pilih service lalu tekan COPY MAP", TextSize = 9, TextColor3 = T.Muted,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -28, 0, 13)})
local barBg = new("Frame", {
    Position = UDim2.fromOffset(14, 43), Size = UDim2.new(1, -28, 0, 12),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, progBox)
corner(barBg, 6)
local barFill = new("Frame", {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.AccentLn, BorderSizePixel = 0,
}, barBg)
corner(barFill, 6)
local lblPct = label(progBox, {Text = "0%", Font = Enum.Font.GothamBold, TextSize = 9,
    Position = UDim2.fromOffset(14, 59), Size = UDim2.fromOffset(100, 13)})
local lblTime = label(progBox, {Text = "00:00", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -114, 0, 59), Size = UDim2.fromOffset(100, 13)})
local lblStats = label(progBox, {Text = "", TextSize = 8, TextColor3 = T.Muted,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.fromOffset(14, 76), Size = UDim2.new(1, -28, 0, 12)})
local lblDetail = label(progBox, {Text = "", TextSize = 8, TextColor3 = T.Muted, TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Position = UDim2.fromOffset(14, 90), Size = UDim2.new(1, -28, 0, 32)})

local btnCopy = button(copyPage, {
    Text = "COPY MAP", Position = UDim2.fromOffset(316, 326), Size = UDim2.fromOffset(430, 44),
    BackgroundColor3 = T.Accent, TextColor3 = T.OnAccent, TextSize = 12,
})
btnCopy:SetAttribute("NoHover", true)
corner(btnCopy, 14)
stroke(btnCopy, T.AccentLn, 1, 0.3)

---------------------------------------------------------------------
-- PAGE: IMPORT MAP
---------------------------------------------------------------------
local importPage = new("Frame", {
    Name = "ImportPage", Position = UDim2.fromOffset(150, 58), Size = UDim2.new(1, -150, 1, -58),
    BackgroundTransparency = 1, Visible = false,
}, main)

local replacerPage = new("Frame", {
    Name = "ReplacerPage", Position = UDim2.fromOffset(150, 58), Size = UDim2.new(1, -150, 1, -58),
    BackgroundTransparency = 1, Visible = false,
}, main)

local infoPage = new("Frame", {
    Name = "InfoPage", Position = UDim2.fromOffset(150, 58), Size = UDim2.new(1, -150, 1, -58),
    BackgroundTransparency = 1, Visible = false,
}, main)

local scriptsPage = new("Frame", {
    Name = "ScriptsPage", Position = UDim2.fromOffset(150, 58), Size = UDim2.new(1, -150, 1, -58),
    BackgroundTransparency = 1, Visible = false,
}, main)

label(importPage, {
    Text = "LIBRARY", Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = T.Muted,
    Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(180, 20),
})
local lblFileCount = label(importPage, {
    Text = "0 FILES", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(204, 4), Size = UDim2.fromOffset(98, 20),
})
label(importPage, {
    Text = "IMPORT MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(316, 4), Size = UDim2.fromOffset(120, 20),
})
label(importPage, {
    Text = "RBXL  RBXM  RBXLX  RBXMX  XML", TextSize = 8, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(436, 4), Size = UDim2.fromOffset(310, 20),
})

-- ===== panel kiri: daftar file =====
local impLeft = new("Frame", {
    Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(290, 340),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, importPage)
corner(impLeft, 14)
stroke(impLeft, T.Line, 1)

local impSearch = new("TextBox", {
    Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -62, 0, 32), BackgroundColor3 = T.Field,
    BorderSizePixel = 0, Text = "", PlaceholderText = "Search files...", PlaceholderColor3 = T.Muted,
    TextColor3 = T.Text, TextSize = 11, Font = Enum.Font.GothamMedium, ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, impLeft)
corner(impSearch, 16)
stroke(impSearch, T.Line, 1)
new("UIPadding", {PaddingLeft = UDim.new(0, 14)}, impSearch)

local btnRefresh = button(impLeft, {
    Text = "↻", Position = UDim2.new(1, -44, 0, 10), Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = T.Field, TextSize = 14,
})
corner(btnRefresh, 16)
stroke(btnRefresh, T.Line, 1)

local impList = new("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 50), Size = UDim2.new(1, -16, 1, -58),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, impLeft)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, impList)
new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, impList)

-- ===== panel kanan =====
local impInfo = new("Frame", {
    Position = UDim2.fromOffset(316, 30), Size = UDim2.fromOffset(430, 92),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, importPage)
corner(impInfo, 14)
stroke(impInfo, T.Line, 1)

local function infoCard(title, x, y)
    local c = new("Frame", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(203, 36),
        BackgroundColor3 = T.Field, BorderSizePixel = 0,
    }, impInfo)
    corner(c, 10)
    stroke(c, T.Line, 1, 0.3)
    label(c, {Text = title, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 11)})
    return label(c, {Text = "-", Font = Enum.Font.GothamBold, TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(12, 16), Size = UDim2.new(1, -24, 0, 16)})
end
local valFile = infoCard("FILE", 8, 8)
local valSize = infoCard("UKURAN", 219, 8)
local valInst = infoCard("INSTANCE DIBUAT", 8, 48)
local valStat = infoCard("STATUS", 219, 48)
valStat.Text = "Belum dipilih"

local optBox = new("Frame", {
    Position = UDim2.fromOffset(316, 130), Size = UDim2.fromOffset(430, 58),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, importPage)
corner(optBox, 14)
stroke(optBox, T.Line, 1)

local function toggleRow(text, y, default)
    local state = default
    label(optBox, {Text = text, TextSize = 9, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -80, 0, 20)})
    local sw = button(optBox, {
        Text = "", Size = UDim2.fromOffset(38, 18), AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, y + 1), BackgroundColor3 = default and T.AccentLn or T.Field,
    })
    sw:SetAttribute("NoHover", true)
    corner(sw, 9)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
        Position = default and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
    }, sw)
    corner(knob, 6)
    sw.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(sw, TweenInfo.new(0.12), {BackgroundColor3 = state and T.AccentLn or T.Field}):Play()
        TweenService:Create(knob, TweenInfo.new(0.12), {
            Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
        }):Play()
    end)
    return function() return state end
end
local getStudioMode = toggleRow("Mode Studio Lite (part di-anchor + atribut SL_)", 6, true)
local getSvcProps   = toggleRow("Terapkan properti service (Lighting dll)", 30, false)

local impProg = new("Frame", {
    Position = UDim2.fromOffset(316, 196), Size = UDim2.fromOffset(430, 122),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, importPage)
corner(impProg, 14)
stroke(impProg, T.Line, 1)
local impTitle = label(impProg, {Text = "Siap import map", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16)})
local impSub = label(impProg, {Text = "Pilih file di daftar lalu tekan IMPORT MAP", TextSize = 9, TextColor3 = T.Muted,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -28, 0, 13)})
local impBarBg = new("Frame", {
    Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 12),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, impProg)
corner(impBarBg, 7)
stroke(impBarBg, T.Line, 1)
local impBar = new("Frame", {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.AccentLn, BorderSizePixel = 0,
}, impBarBg)
corner(impBar, 7)
local impPct = label(impProg, {Text = "0%", Font = Enum.Font.GothamBold, TextSize = 9,
    Position = UDim2.fromOffset(14, 58), Size = UDim2.fromOffset(100, 14)})
local impTime = label(impProg, {Text = "00:00", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -114, 0, 58), Size = UDim2.fromOffset(100, 14)})
local impDetail = label(impProg, {Text = "", TextSize = 8, TextColor3 = T.Muted, TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Position = UDim2.fromOffset(14, 74), Size = UDim2.new(1, -28, 0, 44)})

local btnImport = button(importPage, {
    Text = "IMPORT MAP", Position = UDim2.fromOffset(316, 326), Size = UDim2.fromOffset(430, 44),
    BackgroundColor3 = T.Accent, TextColor3 = T.OnAccent, TextSize = 12,
})
corner(btnImport, 14)
stroke(btnImport, T.AccentLn, 1, 0.3)

local navItems = {copy = tabCopy, import = tabImport, replacer = tabReplacer, scripts = tabScripts, info = tabInfo, settings = tabSettings}
local currentTab = "copy"
local function paintNav(active)
    for k, b in pairs(navItems) do
        local on = (k == active)
        b.BackgroundTransparency = on and 0 or 1
        b.TextColor3 = on and T.Text or T.Muted
        b.Font = on and Enum.Font.GothamBold or Enum.Font.GothamMedium
    end
end
local function showTab(name)
    currentTab = name
    local pagesByName = {copy = copyPage, import = importPage, replacer = replacerPage, scripts = scriptsPage, info = infoPage}
    for k, pg in pairs(pagesByName) do
        local show = (k == name)
        if show and not pg.Visible then
            pg.Position = UDim2.fromOffset(170, 58)
            pg.Visible = true
            TweenService:Create(pg, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Position = UDim2.fromOffset(150, 58)}):Play()
        else
            pg.Visible = show
        end
    end
    paintNav(name)
end
tabCopy.MouseButton1Click:Connect(function() showTab("copy") end)
tabImport.MouseButton1Click:Connect(function() showTab("import") end)
tabReplacer.MouseButton1Click:Connect(function() showTab("replacer") end)
tabScripts.MouseButton1Click:Connect(function() showTab("scripts") end)
tabInfo.MouseButton1Click:Connect(function() showTab("info") end)
showTab("copy")

---------------------------------------------------------------------
-- PENGATURAN (ikon ⚙)
---------------------------------------------------------------------
local settingsPanel = new("Frame", {
    Name = "Settings", Position = UDim2.new(0, 150, 0, 82), Size = UDim2.new(1, -150, 1, -58),
    BackgroundColor3 = T.Window, BorderSizePixel = 0, Visible = false, ZIndex = 30,
}, main)
label(settingsPanel, {
    Text = "PENGATURAN COPY MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(300, 20),
})
local sList = new("Frame", {
    Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 1, -92), BackgroundTransparency = 1,
}, settingsPanel)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, sList)

local function settingRow(order, title, sub)
    local row = new("Frame", {
        LayoutOrder = order, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = T.Card, BorderSizePixel = 0,
    }, sList)
    corner(row, 12)
    stroke(row, T.Line, 1)
    label(row, {Text = title, Font = Enum.Font.GothamBold, TextSize = 11,
        Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -160, 0, 16)})
    label(row, {Text = sub, TextSize = 9, TextColor3 = T.Muted, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(16, 26), Size = UDim2.new(1, -160, 0, 14)})
    return row
end

local function settingSwitch(order, title, sub, key)
    local row = settingRow(order, title, sub)
    local on = UI.Settings[key]
    local sw = button(row, {
        Text = "", Size = UDim2.fromOffset(44, 22), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0), BackgroundColor3 = on and T.AccentLn or T.Field,
    })
    sw:SetAttribute("NoHover", true)
    corner(sw, 11)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
        Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
    }, sw)
    corner(knob, 8)
    sw.MouseButton1Click:Connect(function()
        UI.Settings[key] = not UI.Settings[key]
        local v = UI.Settings[key]
        TweenService:Create(sw, TweenInfo.new(0.15), {BackgroundColor3 = v and T.AccentLn or T.Field}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = v and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
        }):Play()
    end)
end

local function settingCycle(order, title, sub, key, options, suffix)
    local row = settingRow(order, title, sub)
    local b = button(row, {
        Text = "", Size = UDim2.fromOffset(112, 26), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0), BackgroundColor3 = T.Field, TextSize = 10,
    })
    corner(b, 10)
    stroke(b, T.Line, 1)
    local function paint() b.Text = tostring(UI.Settings[key]) .. (suffix or "") end
    b.MouseButton1Click:Connect(function()
        local idx = table.find(options, UI.Settings[key]) or 0
        UI.Settings[key] = options[idx % #options + 1]
        paint()
    end)
    paint()
end

settingSwitch(1, "Muat area map (StreamingEnabled)", "Memuat bagian map yang jauh sebelum disalin. Matikan untuk map kecil.", "stream")
settingSwitch(2, "Decompile script", "Baca isi LocalScript/ModuleScript lewat decompile executor.", "decompile")
settingCycle(3, "Thread decompile paralel", "Makin banyak makin cepat, tapi bisa membuat game lag.", "threads", {8, 16, 24, 32, 48}, " thread")
settingCycle(4, "Batas waktu per script", "Script yang melewati batas ini dilewati.", "timeout", {2, 3, 5, 8, 15}, " detik")
settingCycle(5, "Radius muat area", "Jarak jelajah saat memuat streaming.", "radius", {512, 1024, 2048, 4096}, " stud")

local btnSetClose = button(settingsPanel, {
    Text = "TUTUP", Position = UDim2.new(0, 14, 1, -52), Size = UDim2.new(1, -28, 0, 40),
    BackgroundColor3 = T.Accent, TextColor3 = T.OnAccent, TextSize = 12,
})
corner(btnSetClose, 12)

local settingsOpen = false
local function toggleSettings(v)
    if v == settingsOpen then return end
    settingsOpen = v
    paintNav(v and "settings" or currentTab)
    if v then
        settingsPanel.Position = UDim2.new(0, 150, 0, 82)
        settingsPanel.Visible = true
        TweenService:Create(settingsPanel, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 150, 0, 58)}):Play()
    else
        TweenService:Create(settingsPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0, 150, 0, 82)}):Play()
        task.delay(0.22, function()
            if not settingsOpen then settingsPanel.Visible = false end
        end)
    end
end
tabSettings.MouseButton1Click:Connect(function() toggleSettings(not settingsOpen) end)
btnSetClose.MouseButton1Click:Connect(function() toggleSettings(false) end)
tabCopy.MouseButton1Click:Connect(function() toggleSettings(false) end)
tabImport.MouseButton1Click:Connect(function() toggleSettings(false) end)
tabReplacer.MouseButton1Click:Connect(function() toggleSettings(false) end)
tabScripts.MouseButton1Click:Connect(function() toggleSettings(false) end)
tabInfo.MouseButton1Click:Connect(function() toggleSettings(false) end)

---------------------------------------------------------------------
-- DAFTAR SERVICE
---------------------------------------------------------------------
local cards, selected, info = {}, {}, {}
local busyCopyUI = false

local function updateSummary()
    local n, items, scripts = 0, 0, 0
    for _, name in ipairs(SERVICES) do
        if selected[name] then
            n += 1
            local i = info[name]
            if i then items += i.items; scripts += i.scripts end
        end
    end
    lblSelected.Text = n .. " dipilih"
    valService.Text = n .. " / " .. #SERVICES
    valItem.Text = fmt(items)
    valScript.Text = fmt(scripts)
end

local PILL = {
    queue  = {"ANTRI",  T.Field,  T.Muted},
    stream = {"MUAT",   T.Accent, T.OnAccent},
    script = {"SCRIPT", T.Accent, T.OnAccent},
    save   = {"SIMPAN", T.Accent, T.OnAccent},
}

local function paintCard(name)
    local c = cards[name]
    if not c then return end
    local on = selected[name]
    local ps = c.state and PILL[c.state]
    TweenService:Create(c.stroke, TweenInfo.new(0.12), {
        Color = on and T.AccentLn or T.Line, Thickness = on and 1.5 or 1,
    }):Play()
    if ps then
        c.pill.Text, c.pill.BackgroundColor3, c.pill.TextColor3 = ps[1], ps[2], ps[3]
    elseif on then
        c.pill.Text, c.pill.BackgroundColor3, c.pill.TextColor3 = "OK", T.Ok, T.OnAccent
    else
        c.pill.Text, c.pill.BackgroundColor3, c.pill.TextColor3 = "OFF", T.Field, T.Muted
    end
    c.barBg.Visible = (c.state == "script")
end

function UI.SetCardState(name, state, frac)
    local c = cards[name]
    if not c then return end
    if c.state ~= state then
        c.state = state
        paintCard(name)
    end
    if frac then c.bar.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1) end
end

function UI.ResetCards()
    for name, c in pairs(cards) do
        c.state = nil
        paintCard(name)
    end
end

local function setSelected(name, v)
    selected[name] = v and true or false
    paintCard(name)
    updateSummary()
end

for idx, name in ipairs(SERVICES) do
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = idx,
    }, list)
    corner(card, 12)
    local st = stroke(card, T.Line, 1)
    label(card, {Text = name, Font = Enum.Font.GothamBold, TextSize = 12,
        Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -112, 0, 18)})
    local sub = label(card, {Text = "memindai...", TextSize = 9, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(18, 33), Size = UDim2.new(1, -112, 0, 14)})
    local pill = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -4),
        Size = UDim2.fromOffset(76, 26), BackgroundColor3 = T.Ok, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = T.OnAccent, Text = "OK",
    }, card)
    corner(pill, 13)
    local barBg2 = new("Frame", {
        Position = UDim2.new(0, 18, 1, -10), Size = UDim2.new(1, -36, 0, 3),
        BackgroundColor3 = T.Field, BorderSizePixel = 0, Visible = false,
    }, card)
    corner(barBg2, 2)
    local bar2 = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.AccentLn, BorderSizePixel = 0}, barBg2)
    corner(bar2, 2)
    local hit = new("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3,
    }, card)
    hit.MouseButton1Click:Connect(function()
        if busyCopyUI then return end
        setSelected(name, not selected[name])
    end)

    cards[name] = {frame = card, stroke = st, sub = sub, pill = pill, barBg = barBg2, bar = bar2, state = nil}
    selected[name] = true
    paintCard(name)
end

local scanning = false
local function scan()
    if scanning then return end
    scanning = true
    for _, name in ipairs(SERVICES) do
        local items, scripts = 0, 0
        local okS, svc = pcall(game.GetService, game, name)
        if okS and svc then
            local okD, desc = pcall(svc.GetDescendants, svc)
            if okD then
                items = #desc
                for _, d in ipairs(desc) do
                    if d:IsA("LuaSourceContainer") then scripts += 1 end
                end
            end
        end
        info[name] = {items = items, scripts = scripts}
        local c = cards[name]
        if c and c.frame.Parent then
            if items > 0 then
                c.sub.Text = fmt(items) .. " item" .. (scripts > 0 and ("  -  " .. fmt(scripts) .. " script") or "")
                if name == "Workspace" and workspace.StreamingEnabled then
                    c.sub.Text = c.sub.Text .. "  -  streaming"
                end
            else
                c.sub.Text = "kosong"
            end
        end
        updateSummary()
        task.wait()
    end
    scanning = false
end

btnAll.MouseButton1Click:Connect(function()
    for _, n in ipairs(SERVICES) do selected[n] = true; paintCard(n) end
    updateSummary()
end)
btnNone.MouseButton1Click:Connect(function()
    for _, n in ipairs(SERVICES) do selected[n] = false; paintCard(n) end
    updateSummary()
end)
btnScan.MouseButton1Click:Connect(function()
    if UI.OnScan then task.spawn(UI.OnScan) end
    task.spawn(scan)
end)

---------------------------------------------------------------------
-- PROGRESS API
---------------------------------------------------------------------
local running, t0 = false, 0

function UI.Begin()
    running, t0 = true, os.clock()
    task.spawn(function()
        while running and gui.Parent do
            lblTime.Text = mmss(os.clock() - t0)
            task.wait(0.25)
        end
    end)
end

function UI.SetProgress(pct, title, sub)
    if pct ~= nil then
        pct = math.clamp(pct, 0, 100)
        TweenService:Create(barFill, TweenInfo.new(0.2), {Size = UDim2.fromScale(pct / 100, 1)}):Play()
        lblPct.Text = math.floor(pct) .. "%"
    end
    if title then progTitle.Text = title end
    if sub then progSub.Text = sub end
    if pct ~= nil and pct >= 100 then
        running = false
        lblTime.Text = mmss(os.clock() - t0)
    end
end

function UI.SetStats(text) lblStats.Text = text or "" end
function UI.SetDetail(text) lblDetail.Text = text or "" end

local copyState = "idle"
function UI.SetCopyState(state)
    copyState = state
    busyCopyUI = (state == "running")
    if state == "running" then
        btnCopy.Text, btnCopy.BackgroundColor3, btnCopy.TextColor3 = "BATAL", T.Bad, T.OnAccent
    elseif state == "done" then
        btnCopy.Text, btnCopy.BackgroundColor3, btnCopy.TextColor3 = "SELESAI", T.Ok, T.OnAccent
    else
        btnCopy.Text, btnCopy.BackgroundColor3, btnCopy.TextColor3 = "COPY MAP", T.Accent, T.OnAccent
        UI.CancelFlag = false
    end
end

function UI.GetSelected()
    local out = {}
    for _, n in ipairs(SERVICES) do
        if selected[n] then table.insert(out, n) end
    end
    return out
end

function UI.GetFileName()
    return currentFileName()
end

---------------------------------------------------------------------
-- TOMBOL AKSI
---------------------------------------------------------------------
btnCopy.MouseButton1Click:Connect(function()
    if copyState == "running" then
        UI.CancelFlag = true
        UI.SetProgress(nil, "Membatalkan...", "menunggu proses berhenti")
        return
    end
    if copyState == "done" then
        UI.SetCopyState("idle")
        UI.ResetCards()
        barFill.BackgroundColor3 = T.AccentLn
        UI.SetProgress(0, "Siap copy map", "Pilih service lalu tekan COPY MAP")
        UI.SetStats("")
        UI.SetDetail("")
        lblTime.Text = "00:00"
        return
    end
    local picked = UI.GetSelected()
    if #picked == 0 then
        progTitle.Text = "Belum ada service dipilih"
        progSub.Text = "Pilih minimal satu service dulu"
        return
    end
    if not UI.OnCopy then
        progTitle.Text = "Fungsi copy belum dipasang"
        progSub.Text = "Isi UI.OnCopy dengan logika copy kamu"
        return
    end
    UI.CancelFlag = false
    UI.SetCopyState("running")
    UI.SetStats("")
    UI.SetDetail("")
    UI.SetProgress(0, "Memulai copy...", #picked .. " service dipilih")
    UI.Begin()
    task.spawn(UI.OnCopy, picked, UI.GetFileName())
end)


local SC = {}
do
---------------------------------------------------------------------
-- SCRIPT: baca isi script saat COPY (file NAMA.scripts.json) dan pulihkan saat IMPORT
-- saveinstance sering menyimpan script sebagai placeholder ("Decompiling is disabled"),
-- jadi isi script dibaca sendiri lewat decompile() dan disimpan terpisah.
-- Script SERVER tidak pernah ada di client, jadi memang tidak bisa disalin.
---------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local SCRIPTS_EXT = ".scripts.json"
local PLACEHOLDERS = {"Decompiling is disabled", "IMPOSSIBLE to save", "Failed to decompile"}

local function isPlaceholderSource(src)
    if type(src) ~= "string" then return false end
    local hit = false
    for _, p in ipairs(PLACEHOLDERS) do
        if src:find(p, 1, true) then hit = true break end
    end
    if not hit then return false end
    for line in src:gmatch("[^\r\n]+") do
        local t = line:match("^%s*(.-)%s*$")
        if t ~= "" and t:sub(1, 2) ~= "--" then return false end   -- ada kode asli
    end
    return true
end

local function cleanUtf8(s)
    if utf8.len(s) then return s end
    return (s:gsub("[\128-\255]", "?"))
end

local function usableSource(r)
    if type(r) ~= "string" then return false end
    if not r:find("%S") then return false end
    if isPlaceholderSource(r) then return false end
    if r:match("^%s*%-%-%s*[Ff]ail") or r:match("^%s*%-%-%s*[Dd]ecompil[a-z]* [Ff]ail") then return false end
    return true
end

local function scriptKey(scr, occ)
    local okN, full = pcall(scr.GetFullName, scr)
    local k = (okN and full or scr.Name) .. "|" .. scr.ClassName
    occ[k] = (occ[k] or 0) + 1
    return k .. "|" .. occ[k], (okN and full or scr.Name), occ[k]
end

-- hook decompile: hasil decompile paralel dipakai ulang oleh saveinstance (uSSI / bawaan executor)
local function installDecompileHook(cache)
    local okE, env = pcall(getgenv)
    if not okE or type(env) ~= "table" then return function() end end
    local orig = env.decompile
    if type(orig) ~= "function" then return function() end end
    local wrapper = function(scr, ...)
        local c = cache[scr]
        if c then return c end
        return orig(scr, ...)
    end
    env.decompile = wrapper
    return function()
        if env.decompile == wrapper then env.decompile = orig end
    end
end

-- decompile paralel: banyak thread sekaligus, tiap script punya batas waktu sendiri
local function decompileBatch(list, cache, threads, timeout, onStep, cancelled)
    local n = #list
    local nextI, active, finished, okCount = 1, 0, 0, 0
    local function step(scr, ok)
        finished += 1
        if ok then okCount += 1 end
        if onStep then onStep(finished, n, scr, ok) end
    end
    local function launch(i)
        local scr = list[i]
        active += 1
        local settled = false
        local function settle(src)
            if settled then return end
            settled = true
            active -= 1
            if src then cache[scr] = src end
            step(scr, src ~= nil)
        end
        task.spawn(function()
            local ok, r = pcall(decompile, scr)
            settle((ok and usableSource(r)) and r or nil)
        end)
        task.delay(timeout, function() settle(nil) end)
    end
    while finished < n do
        if cancelled and cancelled() then break end
        while active < threads and nextI <= n do
            local i = nextI
            nextI += 1
            if cache[list[i]] then step(list[i], true) else launch(i) end
        end
        task.wait()
    end
    return okCount
end

local function writeSidecar(entries, baseName)
    if #entries == 0 or type(writefile) ~= "function" then return nil end
    local okE, json = pcall(HttpService.JSONEncode, HttpService, {v = 1, scripts = entries})
    if not okE then return nil, tostring(json) end
    local file = baseName .. SCRIPTS_EXT
    if pcall(writefile, file, json) then return file end
    return nil, "writefile gagal"
end

-- IMPORT: pasang isi script ke instance script
local function applyScriptSource(scr, src)
    return SC.writeSource(scr, src)   -- lihat "MESIN SCRIPT v4" di bawah
end

local SCRIPT_SERVICES = {"Workspace", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "StarterGui",
    "StarterPack", "StarterPlayer", "SoundService", "TextChatService", "Teams", "Chat",
    "ServerStorage", "ServerScriptService", "MaterialService"}

local function loadScriptSidecar(rbxlPath)
    local base = rbxlPath:gsub("%.[^./\\]+$", "")
    local cands = {base .. SCRIPTS_EXT}
    local short = (base:gsub("\\", "/")):match("[^/]+$")
    if short then cands[#cands + 1] = short .. SCRIPTS_EXT end
    for _, c in ipairs(cands) do
        local okR, txt = pcall(readfile, c)
        if okR and type(txt) == "string" and #txt > 2 then
            local okJ, data = pcall(HttpService.JSONDecode, HttpService, txt)
            if okJ and type(data) == "table" and type(data.scripts) == "table" then
                local map = {}
                for _, e in ipairs(data.scripts) do
                    map[e.p .. "|" .. e.c .. "|" .. e.o] = e.s
                end
                return map, c
            end
        end
    end
    return nil
end

local function restoreImportedScripts(path, stat)
    local set = stat and stat.scriptSet
    local done = (stat and stat.srcDone) or {}
    local info = {total = 0, restored = 0, direct = 0, sidecar = false}
    if not set then return info end
    local ordered = {}
    for _, name in ipairs(SCRIPT_SERVICES) do
        local okS, svc = pcall(game.GetService, game, name)
        if okS and svc then
            local okD, d = pcall(svc.GetDescendants, svc)
            for i, inst in ipairs(okD and d or {}) do
                if set[inst] then ordered[#ordered + 1] = inst end
                if i % 4000 == 0 then task.wait() end
            end
        end
    end
    info.total = #ordered
    if #ordered == 0 then return info end
    local map = loadScriptSidecar(path)
    if not map then return info end
    info.sidecar = true
    local occ = {}
    for i, scr in ipairs(ordered) do
        local key = scriptKey(scr, occ)
        local src = map[key]
        if src and not done[scr] then
            info.restored += 1
            if applyScriptSource(scr, src) then info.direct += 1 end
        end
        if i % 25 == 0 then task.wait() end
    end
    return info
end

SC.isPlaceholderSource = isPlaceholderSource
SC.cleanUtf8 = cleanUtf8
SC.usableSource = usableSource
SC.scriptKey = scriptKey
SC.applyScriptSource = applyScriptSource
SC.installDecompileHook = installDecompileHook
SC.decompileBatch = decompileBatch
SC.writeSidecar = writeSidecar
SC.restoreImportedScripts = restoreImportedScripts
SC.SCRIPTS_EXT = SCRIPTS_EXT
end

---------------------------------------------------------------------
-- MESIN SCRIPT v4 (MhmmdalviStudio)
--  * tulis Source dengan banyak cara (langsung / hidden / setscriptable / identity thread)
--  * simpan di registri _G.ACS_RAW_SOURCES (dibaca hook editor Studio Lite)
--  * sisipkan ke editor Studio Lite (SL_CodeTextBox) bila game punya StudioLiteFolder
--  * pustaka script untuk tab "Scripts" (isi script selalu bisa dilihat / disalin)
--  * cadangan dekompresi ZSTD lewat HttpService:JSONDecode (executor tanpa zstddecompress)
---------------------------------------------------------------------
do
    SC.SCRIPT_CLASSES = {Script = true, LocalScript = true, ModuleScript = true}
    SC.SERVICES_ORDER = {"Workspace", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "StarterGui",
        "StarterPack", "StarterPlayer", "SoundService", "TextChatService", "Teams", "Chat",
        "ServerStorage", "ServerScriptService", "MaterialService"}
    SC.EMPTY_NOTE = "-- [MhmmdalviStudio] Isi script ini KOSONG di dalam file.\n-- Script server tidak ikut tersimpan, atau map disimpan tanpa decompile.\n-- Tidak ada kode yang bisa dipulihkan dari file ini."
    SC.NOSRC_NOTE = "-- [MhmmdalviStudio] Tidak ada data isi untuk script ini di dalam file."
    SC.lib = setmetatable({}, {__mode = "k"})

    -- ===== base64 + ZSTD via JSON =====
    local B64A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local B64P
    SC.b64 = function(s)
        local env = (getgenv and getgenv()) or {}
        local cands = {}
        local function add(f) if type(f) == "function" then cands[#cands + 1] = f end end
        add(env.base64encode); add(env.base64_encode)
        if type(env.crypt) == "table" then
            add(env.crypt.base64encode)
            if type(env.crypt.base64) == "table" then add(env.crypt.base64.encode) end
        end
        if type(env.base64) == "table" then add(env.base64.encode) end
        for _, fn in ipairs(cands) do
            local ok, r = pcall(fn, s)
            if ok and type(r) == "string" and #r >= math.floor(#s * 4 / 3) - 4 then return r end
        end
        if not B64P then
            B64P = {}
            for i = 0, 4095 do
                local a, b = i // 64, i % 64
                B64P[i] = string.sub(B64A, a + 1, a + 1) .. string.sub(B64A, b + 1, b + 1)
            end
        end
        local out, n, len, i = {}, 0, #s, 1
        while i + 2 <= len do
            local a, b, c = string.byte(s, i, i + 2)
            n += 1
            out[n] = B64P[a * 16 + b // 16] .. B64P[(b % 16) * 256 + c]
            i += 3
            if n % 30000 == 0 then task.wait() end
        end
        local rem = len - i + 1
        if rem == 1 then
            local a = string.byte(s, i)
            n += 1
            out[n] = string.sub(B64A, a // 4 + 1, a // 4 + 1) .. string.sub(B64A, (a % 4) * 16 + 1, (a % 4) * 16 + 1) .. "=="
        elseif rem == 2 then
            local a, b = string.byte(s, i, i + 1)
            local c2 = (a % 4) * 16 + b // 16
            local c3 = (b % 16) * 4
            n += 1
            out[n] = string.sub(B64A, a // 4 + 1, a // 4 + 1) .. string.sub(B64A, c2 + 1, c2 + 1) .. string.sub(B64A, c3 + 1, c3 + 1) .. "="
        end
        return table.concat(out)
    end

    SC.zstdViaJson = function(stream)
        local HS = game:GetService("HttpService")
        local z64 = SC.b64(stream)
        local v = HS:JSONDecode('{"m":null,"t":"buffer","zbase64":"' .. z64 .. '"}')
        return buffer.tostring(v)
    end

    -- ===== menulis Source =====
    local function trySet(inst, src)
        if pcall(function() inst.Source = src end) then return "langsung" end
        if type(sethiddenproperty) == "function" and pcall(sethiddenproperty, inst, "Source", src) then
            return "hidden"
        end
        if type(setscriptable) == "function" then
            local okS, was = pcall(setscriptable, inst, "Source", true)
            if okS then
                local okA = pcall(function() inst.Source = src end)
                if was == false then pcall(setscriptable, inst, "Source", false) end
                if okA then return "scriptable" end
            end
        end
        return nil
    end

    local function verify(inst, src)
        local ok, got = pcall(function() return inst.Source end)
        if ok and type(got) == "string" then return got == src end
        return nil
    end

    SC.forceSource = function(inst, src)
        local how = trySet(inst, src)
        if how then
            local v = verify(inst, src)
            if v ~= false then return how, v end
        end
        local si = (type(setthreadidentity) == "function" and setthreadidentity)
            or (type(set_thread_identity) == "function" and set_thread_identity)
            or (type(setidentity) == "function" and setidentity) or nil
        local gi = (type(getthreadidentity) == "function" and getthreadidentity)
            or (type(get_thread_identity) == "function" and get_thread_identity)
            or (type(getidentity) == "function" and getidentity) or nil
        if si then
            local old
            if gi then
                local okG, o = pcall(gi)
                if okG and type(o) == "number" then old = o end
            end
            for _, id in ipairs({8, 7, 6, 5, 4}) do
                if pcall(si, id) then
                    local h = trySet(inst, src)
                    if h then
                        local v = verify(inst, src)
                        if v ~= false then
                            if old then pcall(si, old) end
                            return h .. "+id" .. id, v
                        end
                    end
                end
            end
            if old then pcall(si, old) end
        end
        return how, (how ~= nil) and false or nil
    end

    -- ===== Studio Lite =====
    local SL_ASSET = {Script = "InsertScriptScript", LocalScript = "InsertLocalScriptLocalScript",
        ModuleScript = "InsertModuleScriptModuleScript"}
    local tplCache = {}

    SC.installHooks = function()
        local genv
        pcall(function() genv = getgenv() end)
        if type(genv) ~= "table" then genv = _G end
        if genv.__MHSTUDIO_HOOKED or genv.__ACS_HOOK_INSTALLED or _G.__ACS_HOOK_INSTALLED
            or genv.__RBXM_GEN_SL_HOOKED or genv.__RIZA_IMPORTER_HOOKED then return end
        if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
        genv.__MHSTUDIO_HOOKED = true
        local old
        local function ownerOf(reg, caller)
            local cur = caller
            for _ = 1, 8 do
                if typeof(cur) ~= "Instance" then return nil end
                local s = reg[cur]
                if type(s) == "string" then return cur, s end
                local okp, par = pcall(function() return cur.Parent end)
                if not okp then return nil end
                cur = par
            end
            return nil
        end
        local function handler(self, ...)
            local method = getnamecallmethod()
            if method == "InvokeServer" and not (checkcaller and checkcaller()) then
                local okn, nm = pcall(function() return self.Name end)
                if okn and (nm == "GetScriptSourceServerFunction" or nm == "SaveScriptSourceServerFunction") then
                    local reg = _G.ACS_RAW_SOURCES
                    if type(reg) == "table" then
                        local args = {...}
                        local caller
                        if getcallingscript then
                            local okc, cs = pcall(getcallingscript)
                            if okc then caller = cs end
                        end
                        local obj, cur = ownerOf(reg, caller)
                        if not obj then
                            local target = tostring(args[1])
                            for o, s in pairs(reg) do
                                if typeof(o) == "Instance" and type(s) == "string" then
                                    local okk, key = pcall(function() return o.ClassName .. o.Name end)
                                    if okk and key == target then obj, cur = o, s break end
                                end
                            end
                        end
                        if obj then
                            if nm == "GetScriptSourceServerFunction" then
                                if cur ~= "" then return cur end
                            else
                                reg[obj] = tostring(args[2])
                            end
                        end
                    end
                end
            end
            return old(self, ...)
        end
        local wrapped = handler
        if type(newcclosure) == "function" then
            local okw, w = pcall(newcclosure, handler)
            if okw and w then wrapped = w end
        end
        local okh, res = pcall(hookmetamethod, game, "__namecall", wrapped)
        if okh then old = res else genv.__MHSTUDIO_HOOKED = nil end
    end

    SC.slActive = function()
        if SC._sl == nil then
            local ok, sf = pcall(function()
                local f = game:GetService("ReplicatedStorage"):FindFirstChild("StudioLiteFolder")
                return f and f:FindFirstChild("ServerFunctions")
            end)
            SC._sl = (ok and sf) or false
            if SC._sl then pcall(SC.installHooks) end
        end
        return SC._sl
    end

    SC.injectSL = function(scr, text)
        local sf = SC.slActive()
        if not sf then return false end
        local ui = text
        if #ui > 190000 then ui = string.sub(ui, 1, 190000) .. "\n-- ... [TERPOTONG di editor, isi utuh ada di tab Scripts]" end
        local tb = scr:FindFirstChild("SL_CodeTextBox")
        if not tb then
            local assetName = SL_ASSET[scr.ClassName]
            if assetName then
                if tplCache[assetName] == nil then
                    tplCache[assetName] = false
                    pcall(function()
                        local pg = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
                        sf:InvokeServer("LoadAssetToPlayerGui", assetName)
                        local g = pg:WaitForChild(assetName, 3)
                        if g then
                            local list = {}
                            for _, c in ipairs(g:GetChildren()) do list[#list + 1] = c:Clone() end
                            if #list > 0 then tplCache[assetName] = list end
                        end
                        sf:InvokeServer("ClearAssetFromPlayerGui", assetName)
                    end)
                end
                local tpl = tplCache[assetName]
                if tpl then
                    for _, c in ipairs(tpl) do pcall(function() c:Clone().Parent = scr end) end
                    tb = scr:FindFirstChild("SL_CodeTextBox")
                end
            end
        end
        if tb then
            pcall(function() tb.Text = ui end)
            if scr.ClassName == "ModuleScript" then
                local ro = scr:FindFirstChild("SL_1ReadOnly")
                if ro then
                    pcall(function() ro.Text = ui end)
                    pcall(function() ro.ContentText = ui end)
                end
            end
            return true
        end
        return false
    end

    -- ===== titik masuk tunggal: pasang isi script ke sebuah instance =====
    SC.writeSource = function(scr, src)
        if type(src) ~= "string" then return false end
        src = (src:gsub("\0+$", ""))
        pcall(function()
            local reg = _G.ACS_RAW_SOURCES
            if type(reg) ~= "table" then reg = {}; _G.ACS_RAW_SOURCES = reg end
            reg[scr] = src
        end)
        local how, verified = SC.forceSource(scr, src)
        pcall(function()
            for _, ch in ipairs(scr:GetChildren()) do
                if ch:IsA("StringValue") and string.sub(ch.Name, 1, 9) == "MH_Source" then ch:Destroy() end
            end
        end)
        if verified ~= true then   -- cadangan teks supaya kode tetap tersimpan & bisa dibaca
            local n, i = 1, 1
            repeat
                local sv = Instance.new("StringValue")
                sv.Name = (n == 1) and "MH_Source" or ("MH_Source_" .. n)
                pcall(function() sv.Value = string.sub(src, i, i + 149999) end)
                sv.Parent = scr
                n += 1
                i += 150000
            until i > #src
        end
        SC.lib[scr] = {src = src, how = how or "registri"}
        if SC.slActive() then pcall(SC.injectSL, scr, src) end
        return how ~= nil
    end

    SC.collectLib = function(res)
        local arr = {}
        for inst in pairs(res.scriptSet or {}) do
            if inst.Parent then
                local rec = SC.lib[inst]
                local okP, full = pcall(inst.GetFullName, inst)
                arr[#arr + 1] = {
                    inst = inst, cls = inst.ClassName, name = inst.Name, path = okP and full or inst.Name,
                    src = rec and rec.src or SC.NOSRC_NOTE, how = rec and rec.how or "-", real = rec ~= nil,
                }
            end
        end
        table.sort(arr, function(a, b) return a.path < b.path end)
        return arr
    end

    -- ===== cocokkan isi script dari FILE ke instance hasil import =====
    SC.restoreFromFile = function(entries, res, report)
        local out = {entries = #entries, matched = 0, real = 0, empty = 0, unmatched = 0, skipped = 0}
        local set = res.scriptSet or {}
        res.srcDone = res.srcDone or {}
        local ordered, seenI = {}, {}
        local function addDesc(root)
            local okD, d = pcall(root.GetDescendants, root)
            if not okD then return end
            for i, inst in ipairs(d) do
                if set[inst] and not seenI[inst] then seenI[inst] = true; ordered[#ordered + 1] = inst end
                if i % 4000 == 0 then task.wait() end
            end
        end
        for _, name in ipairs(SC.SERVICES_ORDER) do
            local okS, svc = pcall(game.GetService, game, name)
            if okS and svc then addDesc(svc) end
        end
        for inst in pairs(set) do   -- script di luar service di atas (PlayerGui, Backpack, dll.)
            if not seenI[inst] and inst.Parent then seenI[inst] = true; ordered[#ordered + 1] = inst end
        end

        local qFull, qRel = {}, {}
        local function push(q, k, e)
            local l = q[k]
            if not l then l = {n = 0, i = 1}; q[k] = l end
            l.n += 1
            l[l.n] = e
        end
        local function take(q, k)
            local l = q[k]
            if not l then return nil end
            while l.i <= l.n do
                local e = l[l.i]
                l.i += 1
                if not e.used then return e end
            end
            return nil
        end
        for _, e in ipairs(entries) do
            push(qRel, e.rel .. "\1" .. e.cls, e)
            if e.svc then push(qFull, e.svc .. "\1" .. e.rel .. "\1" .. e.cls, e) end
        end
        local function instKey(inst)
            local names, cur, guard = {}, inst, 0
            while cur and cur ~= game and guard < 300 do
                table.insert(names, 1, cur.Name)
                cur = cur.Parent
                guard += 1
            end
            local svc = table.remove(names, 1)
            return svc or "", table.concat(names, "\0")
        end

        local pairsList, unmatchedI = {}, {}
        for _, inst in ipairs(ordered) do
            if res.srcDone[inst] then
                out.skipped += 1
            else
                local okK, svc, rel = pcall(instKey, inst)
                local e
                if okK then
                    e = take(qFull, svc .. "\1" .. rel .. "\1" .. inst.ClassName) or take(qRel, rel .. "\1" .. inst.ClassName)
                end
                if e then
                    e.used = true
                    pairsList[#pairsList + 1] = {inst, e}
                else
                    unmatchedI[#unmatchedI + 1] = inst
                end
            end
        end
        -- cadangan: samakan urutan per class kalau jumlahnya sama persis
        local unI, unE = {}, {}
        for _, inst in ipairs(unmatchedI) do
            local c = inst.ClassName
            unI[c] = unI[c] or {}
            table.insert(unI[c], inst)
        end
        for _, e in ipairs(entries) do
            if not e.used then
                unE[e.cls] = unE[e.cls] or {}
                table.insert(unE[e.cls], e)
            end
        end
        for c, li in pairs(unI) do
            local le = unE[c]
            if le and #le == #li then
                for k = 1, #li do
                    le[k].used = true
                    pairsList[#pairsList + 1] = {li[k], le[k]}
                end
            else
                out.unmatched += #li
            end
        end

        for i, pr in ipairs(pairsList) do
            local inst, e = pr[1], pr[2]
            out.matched += 1
            local src = e.src or ""
            if SC.usableSource(src) then
                SC.writeSource(inst, src)
                res.srcDone[inst] = true
                out.real += 1
            else
                SC.writeSource(inst, SC.EMPTY_NOTE)
                out.empty += 1
            end
            if i % 15 == 0 then
                if report then report(i / #pairsList) end
                task.wait()
            end
        end
        res.fileInfo = out
        return out
    end
end


do
---------------------------------------------------------------------
-- FITUR: COPY MAP (memakai saveinstance dari executor)
---------------------------------------------------------------------
local SAVER_NAMES = {"saveinstance", "save_instance", "SaveInstance", "savegame", "save_game", "saveplace", "save_place", "SavePlace"}

local function findNativeSaver()
    local envs = {}
    pcall(function() if getgenv then envs[#envs + 1] = getgenv() end end)
    pcall(function() if getfenv then envs[#envs + 1] = getfenv(0) end end)
    pcall(function() envs[#envs + 1] = _G end)
    pcall(function() if shared then envs[#envs + 1] = shared end end)
    pcall(function() if syn then envs[#envs + 1] = syn end end)
    pcall(function() if fluxus then envs[#envs + 1] = fluxus end end)
    for _, env in ipairs(envs) do
        for _, n in ipairs(SAVER_NAMES) do
            local okG, f = pcall(function() return env[n] end)
            if okG and type(f) == "function" then return f end
        end
    end
    return nil
end

-- Cadangan: Universal Syn SaveInstance (script open-source, dimuat dari GitHub).
-- Butuh HttpGet + loadstring + writefile di executor.
local cachedUniversal
local saverDiag = ""   -- alasan gagal (ditampilkan di status)

local SAVER_URLS = {}
do
    -- repo resmi USSI + mirror/repo lama; ekstensi .luau dan .lua dicoba keduanya
    local bases = {
        "https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/",
        "https://raw.githubusercontent.com/rbxlx/UniversalSynSaveInstance/main/",
        "https://raw.githubusercontent.com/luau/SynSaveInstance/main/",
        "https://raw.githubusercontent.com/rbxlx/SynSaveInstance/main/",
        "https://cdn.jsdelivr.net/gh/luau/UniversalSynSaveInstance@main/",
        "https://cdn.jsdelivr.net/gh/rbxlx/SynSaveInstance@main/",
    }
    for _, base in ipairs(bases) do
        for _, ext in ipairs({".luau", ".lua"}) do
            SAVER_URLS[#SAVER_URLS + 1] = base .. "saveinstance" .. ext
        end
    end
end

local function envFn(name)
    local f
    pcall(function() if getgenv then f = getgenv()[name] end end)
    if type(f) ~= "function" then pcall(function() f = getfenv(0)[name] end) end
    if type(f) ~= "function" then
        local okG, v = pcall(function() return _G[name] end)
        if okG then f = v end
    end
    return type(f) == "function" and f or nil
end

-- ambil teks dari URL: coba HttpGet bawaan, lalu request/http_request milik executor
local function fetchText(url)
    local errs = {}
    local okH, r = pcall(function() return game:HttpGet(url, true) end)
    if okH and type(r) == "string" and #r > 100 then return r end
    errs[#errs + 1] = "HttpGet: " .. tostring(r)
    local reqf = envFn("request") or envFn("http_request")
        or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if reqf then
        local okR, res = pcall(reqf, {Url = url, Method = "GET"})
        local body = okR and type(res) == "table" and (res.Body or res.body)
        if type(body) == "string" and #body > 100 then return body end
        errs[#errs + 1] = "request: " .. tostring(okR and (res and (res.StatusCode or res.status)) or res)
    else
        errs[#errs + 1] = "request: tidak ada"
    end
    return nil, table.concat(errs, " | ")
end

local function loadUniversalSaver()
    if cachedUniversal then return cachedUniversal end
    local lf = envFn("loadstring") or envFn("load")
    if not lf then
        saverDiag = "executor tidak punya loadstring"
        return nil
    end
    local errList = {}
    for i, url in ipairs(SAVER_URLS) do
        local src, e = fetchText(url)
        if src then
            local okC, chunk = pcall(lf, src, "saveinstance")
            if okC and type(chunk) == "function" then
                local okE, f = pcall(chunk)
                if okE and type(f) == "function" then
                    cachedUniversal = f
                    return f
                end
                errList[#errList + 1] = "#" .. i .. " saver error: " .. tostring(f)
            else
                errList[#errList + 1] = "#" .. i .. " loadstring: " .. tostring(chunk)
            end
        else
            errList[#errList + 1] = "#" .. i .. " unduh: " .. tostring(e)
        end
    end
    saverDiag = #errList .. " URL dicoba, semua gagal. Terakhir: " .. tostring(errList[#errList])
    return nil
end

local function getSaver()
    return findNativeSaver() or loadUniversalSaver()
end

local function fileExists(p)
    local okF, r = pcall(function() return isfile and isfile(p) end)
    return okF and r == true
end

local busy = false

local function isValidInstance(inst)
    local okV, v = pcall(function()
        return typeof(inst) == "Instance" and inst.Parent == game
    end)
    return okV and v == true
end

local function shortErr(e, n)
    local s = tostring(e):gsub("%s+", " ")
    return s:sub(1, n or 110)
end

-- Map dengan StreamingEnabled hanya memuat area di sekitar pemain.
-- Fungsi ini "mengunjungi" grid titik di sekitar pemain supaya server mengirim bagian map lain.
-- Berhenti otomatis kalau jumlah item sudah tidak bertambah (jadi map kecil tidak buang waktu).
UI.StreamStep       = 512    -- jarak antar titik (stud)
UI.StreamMaxSeconds = 30     -- batas waktu total

local function countWorkspace()
    local okD, d = pcall(workspace.GetDescendants, workspace)
    return okD and #d or 0
end

local function preloadStreaming(onStep, cancelled)
    local okE, enabled = pcall(function() return workspace.StreamingEnabled end)
    if not (okE and enabled) then return false, 0 end
    local lp = Players.LocalPlayer
    if not lp then return false, 0 end

    local center = Vector3.zero
    local ch = lp.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if hrp then
        center = hrp.Position
    elseif workspace.CurrentCamera then
        center = workspace.CurrentCamera.CFrame.Position
    end

    local R, step = UI.Settings.radius, UI.StreamStep
    local pts = {}
    for x = -R, R, step do
        for z = -R, R, step do
            pts[#pts + 1] = center + Vector3.new(x, 0, z)
        end
    end
    table.sort(pts, function(a, b) return (a - center).Magnitude < (b - center).Magnitude end)

    local t0 = os.clock()
    local lastCount, flat = countWorkspace(), 0
    for i, pos in ipairs(pts) do
        if (cancelled and cancelled()) or not gui.Parent or os.clock() - t0 > UI.StreamMaxSeconds then break end
        pcall(function() lp:RequestStreamAroundAsync(pos, 1.0) end)
        if onStep then onStep(i, #pts) end
        if i % 12 == 0 then
            local c = countWorkspace()
            if c <= lastCount * 1.005 then flat += 1 else flat = 0 end
            lastCount = c
            if flat >= 3 then break end
        end
    end
    task.wait(0.3)
    return true, #pts
end

local function sizeText(bytes)
    if bytes >= 1048576 then return ("%.2f MB"):format(bytes / 1048576) end
    return ("%d KB"):format(math.max(1, math.floor(bytes / 1024 + 0.5)))
end

UI.OnCopy = function(services, fileName)
    if busy then return end
    busy = true
    UI.CancelFlag = false
    local S = UI.Settings
    local startClock = os.clock()
    barFill.BackgroundColor3 = T.AccentLn
    local restoreHook = function() end
    local lastUi = 0
    local function cancelled() return UI.CancelFlag end

    local function cleanup()
        pcall(restoreHook)
        UI.ResetCards()
    end
    local function fail(title, sub)
        cleanup()
        running = false
        barFill.BackgroundColor3 = T.Bad
        UI.SetProgress(100, title, sub)
        lblPct.Text = "GAGAL"
        UI.SetCopyState("idle")
        busy = false
    end

    for _, n in ipairs(services) do UI.SetCardState(n, "queue") end

    -- hook decompile harus terpasang sebelum saveinstance universal dimuat,
    -- supaya hasil decompile paralel dipakai ulang (bukan placeholder)
    restoreHook = SC.installDecompileHook(UI.ScriptCache)

    local saver = getSaver()
    if type(saver) ~= "function" then
        local exe = "?"
        pcall(function() exe = tostring((identifyexecutor())) end)
        local full = "Executor: " .. exe .. " | " .. saverDiag
        pcall(warn, "[MhmmdalviStudio] saver gagal: " .. full)
        pcall(function() if setclipboard then setclipboard(full) end end)
        return fail("Saver gagal dimuat",
            string.sub(saverDiag, 1, 70) .. "  (detail disalin ke clipboard)")
    end
    UI.SetProgress(2, "Menyiapkan...", "Fungsi saveinstance siap")

    -- 1) map streaming: muat area dulu supaya Workspace tidak kosong
    local streamNote
    local tStream0 = os.clock()
    local abortDecomp = false
    if S.stream and table.find(services, "Workspace") then
        local okW, streaming = pcall(function() return workspace.StreamingEnabled end)
        if okW and streaming then
            UI.SetCardState("Workspace", "stream")
            local before = countWorkspace()
            local okP, did = pcall(preloadStreaming, function(i, total)
                UI.SetProgress(2 + 8 * (i / total), "Memuat area map (streaming)...", i .. " / " .. total .. " titik")
            end, cancelled)
            if okP and did then
                local after = countWorkspace()
                info.Workspace = info.Workspace or {items = 0, scripts = 0}
                info.Workspace.items = after
                local sc = 0
                local okD, d = pcall(workspace.GetDescendants, workspace)
                for _, inst in ipairs(okD and d or {}) do
                    if inst:IsA("LuaSourceContainer") then sc += 1 end
                end
                info.Workspace.scripts = sc
                streamNote = "streaming: " .. fmt(before) .. " -> " .. fmt(after) .. " item"
                pcall(warn, "[CopyMap] " .. streamNote)
            end
            UI.SetCardState("Workspace", "queue")
        end
    end
    if cancelled() then return fail("Dibatalkan", "Proses dihentikan") end

    local tStream = os.clock() - tStream0
    -- 2) kumpulkan service yang dipilih (buang yang kosong / tidak bisa diakses)
    UI.SetProgress(10, "Menyiapkan...", "Mengumpulkan service")
    local picks, instances, totalItems, empty = {}, {}, 0, {}
    for _, name in ipairs(services) do
        local okS, svc = pcall(game.GetService, game, name)
        local count = 0
        if okS and isValidInstance(svc) then
            count = info[name] and info[name].items
            if count == nil then
                local okD, d = pcall(svc.GetDescendants, svc)
                count = okD and #d or 0
            end
        end
        if count > 0 then
            table.insert(picks, {name = name, svc = svc})
            table.insert(instances, svc)
            totalItems += count
        else
            table.insert(empty, name)
            UI.SetCardState(name, nil)
        end
    end
    if #instances == 0 then
        return fail("Instance tidak ditemukan",
            "Service yang dipilih kosong / tidak bisa diakses. Pilih Workspace lalu SCAN ULANG")
    end

    -- 3) decompile script secara paralel (hasilnya di-cache untuk saveinstance + file .scripts.json)
    local sst = {total = 0, ok = 0, server = 0, failed = 0, unavailable = false}
    local entries = {}
    local tDecomp0 = os.clock()
    if S.decompile then
        if type(decompile) ~= "function" then
            sst.unavailable = true
        else
            local groups, grand = {}, 0
            for _, pk in ipairs(picks) do
                local okD, d = pcall(pk.svc.GetDescendants, pk.svc)
                local all, client = {}, {}
                for _, inst in ipairs(okD and d or {}) do
                    if inst:IsA("LuaSourceContainer") then
                        all[#all + 1] = inst
                        local serverOnly = false
                        if inst.ClassName == "Script" then
                            local okR, rc = pcall(function() return inst.RunContext end)
                            serverOnly = not (okR and rc == Enum.RunContext.Client)
                        end
                        if serverOnly then sst.server += 1 else client[#client + 1] = inst end
                    end
                end
                sst.total += #all
                grand += #client
                groups[#groups + 1] = {name = pk.name, all = all, client = client}
                task.wait()
            end

            local doneAll = 0
            local function statsLine()
                return ("Item %s  -  Script %d  -  Decompile %d  -  Kosong %d"):format(
                    fmt(totalItems), sst.total, sst.ok, sst.failed + sst.server)
            end
            UI.SetStats(statsLine())
            for _, g in ipairs(groups) do
                if cancelled() or abortDecomp then break end
                if #g.client > 0 then
                    UI.SetCardState(g.name, "script", 0)
                    SC.decompileBatch(g.client, UI.ScriptCache, S.threads, S.timeout, function(i, n, scr, ok)
                        doneAll += 1
                        if ok then sst.ok += 1 else sst.failed += 1 end
                        -- decompile tidak berfungsi (belasan script pertama semua gagal): hentikan, jangan buang waktu
                        if sst.ok == 0 and sst.failed >= 15 and not abortDecomp then
                            abortDecomp = true
                            pcall(warn, "[CopyMap] decompile executor tidak berfungsi, dilewati")
                        end
                        local now = os.clock()
                        if now - lastUi > 0.06 or i == n then
                            lastUi = now
                            UI.SetCardState(g.name, "script", i / n)
                            UI.SetProgress(10 + 60 * (doneAll / math.max(1, grand)),
                                "Membaca script " .. g.name,
                                ("Decompile %d / %d  -  %s"):format(i, n, scr.Name))
                            UI.SetStats(statsLine())
                        end
                    end, function() return cancelled() or abortDecomp end)
                    UI.SetCardState(g.name, nil)
                end
            end
            if cancelled() then return fail("Dibatalkan", "Proses dihentikan saat membaca script") end

            for _, g in ipairs(groups) do
                local occ = {}
                for _, scr in ipairs(g.all) do
                    local _, full, o = SC.scriptKey(scr, occ)
                    local src = UI.ScriptCache[scr]
                    if src then
                        entries[#entries + 1] = {p = full, c = scr.ClassName, o = o, s = SC.cleanUtf8(src)}
                    end
                end
            end
        end
    end

    local tDecomp = os.clock() - tDecomp0
    local useDecomp = S.decompile and not abortDecomp
    local tSave0 = os.clock()
    -- 4) saveinstance (urutan percobaan dari yang paling lengkap)
    local path = fileName .. ".rbxl"
    for _, pk in ipairs(picks) do UI.SetCardState(pk.name, "save") end
    UI.SetProgress(72, "Menyimpan map...", "saveinstance berjalan")

    local finished, saved, wholeGame = false, false, false
    local errs = {}
    task.spawn(function()
        local attempts = {
            {whole = false, run = function()
                return saver({
                    FileName = path, Mode = "invalid", ExtraInstances = instances,
                    Decompile = useDecomp, DecompileTimeout = S.timeout, ReadMe = false,
                    ShutdownWhenDone = false, ShowStatus = false,
                })
            end},
            -- sebagian executor menambah ekstensi sendiri
            {whole = false, run = function()
                return saver({
                    FileName = fileName, Mode = "invalid", ExtraInstances = instances,
                    Decompile = useDecomp, ReadMe = false,
                })
            end},
            -- opsi minimal untuk executor yang menolak opsi tak dikenal
            {whole = false, run = function()
                return saver({FileName = path, ExtraInstances = instances})
            end},
            {whole = true, run = function() return saver(path) end},
            {whole = true, run = function() return saver() end},
        }
        for i, a in ipairs(attempts) do
            local okRun, e = pcall(a.run)
            if okRun then
                saved, wholeGame = true, a.whole
                break
            end
            errs[#errs + 1] = shortErr(e, 200)
            pcall(warn, ("[CopyMap] percobaan %d gagal: %s"):format(i, tostring(e)))
        end
        finished = true
    end)

    -- saveinstance tidak memberi progress asli, jadi bar ini hanya estimasi
    local est = math.max(4, totalItems / 1500)
    local started = os.clock()
    while not finished and gui.Parent do
        local p = 72 + 23 * (1 - math.exp(-(os.clock() - started) / est))
        UI.SetProgress(p, "Menyimpan map...", "Estimasi, tergantung ukuran map dan executor")
        task.wait(0.3)
    end
    if not gui.Parent then busy = false return end
    if not saved then
        -- tampilkan error percobaan PERTAMA (paling relevan), bukan yang terakhir
        return fail("Gagal menyimpan", shortErr(errs[1] or "unknown", 110))
    end

    -- 5) data script (.scripts.json) + ringkasan
    UI.SetProgress(96, "Menulis data script...", #entries .. " script")
    local sidecar = (#entries > 0) and SC.writeSidecar(entries, fileName) or nil
    local size
    pcall(function() if fileExists(path) then size = #readfile(path) end end)

    cleanup()
    local elapsed = os.clock() - startClock
    local tSave = os.clock() - tSave0
    UI.SetProgress(100, "Selesai", "File siap di folder workspace executor")
    UI.SetStats(("Item %s  -  Script %d  -  Decompile %d  -  Kosong %d"):format(
        fmt(totalItems), sst.total, sst.ok, sst.failed + sst.server))
    local l1 = "Tersimpan: " .. path .. (size and (" (" .. sizeText(size) .. ")") or "")
        .. "  -  Waktu " .. ("%.0f"):format(elapsed) .. " dtk"
        .. (" (muat area %.0f / script %.0f / simpan %.0f)"):format(tStream, tDecomp, tSave)
    local l2 = ("%d service  -  %s item  -  %d script"):format(#picks, fmt(totalItems), sst.total)
    local l3
    if sst.unavailable then
        l3 = "⚠ executor tidak punya decompile: script tidak terbaca"
    elseif not S.decompile then
        l3 = "decompile dimatikan di pengaturan"
    else
        l3 = ("%d script dipulihkan lewat decompile executor"):format(sst.ok)
        if sst.server > 0 then l3 ..= ("  -  %d server (mustahil disalin)"):format(sst.server) end
        if sst.failed > 0 then l3 ..= ("  -  %d gagal"):format(sst.failed) end
        if abortDecomp then l3 = "⚠ decompile executor tidak berfungsi, script dilewati  -  " .. l3 end
        if sidecar then l3 ..= "  -  " .. sidecar end
    end
    if wholeGame then l3 = "⚠ executor menyimpan seluruh game  -  " .. l3 end
    if streamNote then l3 ..= "  -  " .. streamNote end
    UI.SetDetail(l1 .. "\n" .. l2 .. "\n" .. l3)
    UI.SetCopyState("done")
    busy = false
end
end

---------------------------------------------------------------------
-- FITUR: IMPORT MAP (parser RBXL / RBXM biner)
---------------------------------------------------------------------
local InsertService = game:GetService("InsertService")

-- id rotasi CFrame biner -> R00,R01,R02,R10,R11,R12,R20,R21,R22
local ROT = {
    [0x02] = {1,0,0, 0,1,0, 0,0,1},    [0x03] = {1,0,0, 0,0,-1, 0,1,0},
    [0x05] = {1,0,0, 0,-1,0, 0,0,-1},  [0x06] = {1,0,0, 0,0,1, 0,-1,0},
    [0x07] = {0,1,0, 1,0,0, 0,0,-1},   [0x09] = {0,0,1, 1,0,0, 0,1,0},
    [0x0A] = {0,-1,0, 1,0,0, 0,0,1},   [0x0C] = {0,0,-1, 1,0,0, 0,-1,0},
    [0x0D] = {0,1,0, 0,0,1, 1,0,0},    [0x0E] = {0,0,-1, 0,1,0, 1,0,0},
    [0x10] = {0,-1,0, 0,0,-1, 1,0,0},  [0x11] = {0,0,1, 0,-1,0, 1,0,0},
    [0x14] = {-1,0,0, 0,1,0, 0,0,-1},  [0x15] = {-1,0,0, 0,0,1, 0,1,0},
    [0x17] = {-1,0,0, 0,-1,0, 0,0,1},  [0x18] = {-1,0,0, 0,0,-1, 0,-1,0},
    [0x19] = {0,1,0, -1,0,0, 0,0,1},   [0x1B] = {0,0,-1, -1,0,0, 0,1,0},
    [0x1C] = {0,-1,0, -1,0,0, 0,0,-1}, [0x1E] = {0,0,1, -1,0,0, 0,-1,0},
    [0x1F] = {0,1,0, 0,0,-1, -1,0,0},  [0x20] = {0,0,1, 0,1,0, -1,0,0},
    [0x22] = {0,-1,0, 0,0,1, -1,0,0},  [0x23] = {0,0,-1, 0,-1,0, -1,0,0},
}

-- nama properti di file -> nama properti API
local ALIAS = {size = "Size", shape = "Shape", Color3uint8 = "Color"}
local SKIP_PROP = {
    formFactorRaw = true, Attributes = true, AttributesSerialize = true, Tags = true,
    MaterialVariantSerialized = true, UniqueId = true, HistoryId = true, SourceAssetId = true,
    ScriptGuid = true, LinkedSource = true, SecurityCapabilities = true, Capabilities = true,
    DefinesCapabilities = true, NeedsPivotMigration = true, Parent = true,
}
local SKIP_CLASS = {Camera = true, Terrain = true}

-- bisa kamu ubah dari luar
UI.ImportSkipServices = {Players = true}          -- isi service ini tidak diimport
UI.ImportSkipNames = {StudioLiteFolder = true}    -- folder bawaan Studio Lite jangan digandakan
UI.ResolveMesh = nil                              -- opsional: function(meshId) return MeshPart end

---------------------------------------------------------------------
-- LZ4 (pakai bawaan executor kalau ada, kalau tidak pakai Luau murni)
---------------------------------------------------------------------
local function lz4pure(src, outSize)
    local out, ip, op, n = table.create(outSize), 1, 0, #src
    local byte, work = string.byte, 0
    while ip <= n do
        local token = byte(src, ip); ip += 1
        local lit = token // 16
        if lit == 15 then
            local b
            repeat b = byte(src, ip); ip += 1; lit += b until b ~= 255
        end
        for i = 0, lit - 1 do out[op + 1 + i] = byte(src, ip + i) end
        ip += lit; op += lit
        if ip > n then break end
        local offset = byte(src, ip) + byte(src, ip + 1) * 256; ip += 2
        local ml = token % 16
        if ml == 15 then
            local b
            repeat b = byte(src, ip); ip += 1; ml += b until b ~= 255
        end
        ml += 4
        local from = op - offset
        for i = 1, ml do out[op + i] = out[from + i] end
        op += ml
        work += lit + ml
        if work > 400000 then work = 0; task.wait() end
    end
    local parts = {}
    for i = 1, op, 4000 do
        local okC, piece = pcall(function()
            return string.char(table.unpack(out, i, math.min(i + 3999, op)))
        end)
        if not okC then
            local h = {}
            for k = 1, math.min(4, #src) do h[k] = string.format("%02X", byte(src, k)) end
            error("Chunk bukan LZ4 valid (awal data: " .. table.concat(h, " ") .. ")", 0)
        end
        parts[#parts + 1] = piece
    end
    return table.concat(parts)
end

local function lz4(src, outSize)
    local env = (getgenv and getgenv()) or {}
    local fn = env.lz4decompress or lz4decompress
    if type(fn) == "function" then
        local okL, res = pcall(fn, src, outSize)
        if okL and type(res) == "string" and #res == outSize then return res end
    end
    return lz4pure(src, outSize)
end

-- chunk bisa dikompres LZ4 (lama) atau ZSTD (magic 28 B5 2F FD)
local ZSTD_MAGIC = "\40\181\47\253"
local function decompress(src, outSize)
    if src:sub(1, 4) == ZSTD_MAGIC then
        local env = (getgenv and getgenv()) or {}
        local fn = env.zstddecompress or zstddecompress
        if type(fn) == "function" then
            local okZ, res = pcall(fn, src, outSize)
            if not (okZ and type(res) == "string" and #res == outSize) then
                okZ, res = pcall(fn, src)
            end
            if okZ and type(res) == "string" and #res == outSize then return res end
        end
        local okJ, res2 = pcall(SC.zstdViaJson, src)   -- cadangan: dekompresi bawaan engine via JSONDecode
        if okJ and type(res2) == "string" and #res2 == outSize then return res2 end
        error("Kompresi ZSTD tidak bisa dibaca (executor tanpa zstddecompress & cadangan JSON gagal)", 0)
    end
    return lz4(src, outSize)
end

---------------------------------------------------------------------
-- PEMBACA BINER
---------------------------------------------------------------------
local function zz(u)
    if u % 2 == 0 then return u / 2 end
    return -(u + 1) / 2
end

-- float yang disimpan dengan bit tanda dipindah ke posisi terendah
local function unrot(u)
    local bits = (u // 2) + (u % 2) * 2147483648
    local sign = bits >= 2147483648 and -1 or 1
    local e = (bits // 8388608) % 256
    local m = bits % 8388608
    if e == 0 then return sign * m * 2 ^ -149 end
    if e == 255 then return m == 0 and sign * math.huge or 0 end
    return sign * (1 + m / 8388608) * 2 ^ (e - 127)
end

local function newReader(s)
    local r = {p = 1}
    local byte = string.byte
    function r.u8() local v = byte(s, r.p); r.p += 1; return v end
    function r.u32() local v = string.unpack("<I4", s, r.p); r.p += 4; return v end
    function r.i16() local v = string.unpack("<i2", s, r.p); r.p += 2; return v end
    function r.f32() local v = string.unpack("<f", s, r.p); r.p += 4; return v end
    function r.f64() local v = string.unpack("<d", s, r.p); r.p += 8; return v end
    function r.str()
        local n = r.u32()
        local v = s:sub(r.p, r.p + n - 1)
        r.p += n
        return v
    end
    function r.inter(n, size)
        local out, base = table.create(n), r.p
        if size == 4 then
            for i = 1, n do
                local o = base + i - 1
                out[i] = byte(s, o) * 16777216 + byte(s, o + n) * 65536 + byte(s, o + 2 * n) * 256 + byte(s, o + 3 * n)
            end
        else
            for i = 1, n do
                local o, v = base + i - 1, 0
                for j = 0, 7 do v = v * 256 + byte(s, o + j * n) end
                out[i] = v
            end
        end
        r.p = base + n * size
        return out
    end
    function r.uints(n) return r.inter(n, 4) end
    function r.ints(n)
        local a = r.inter(n, 4)
        for i = 1, n do a[i] = zz(a[i]) end
        return a
    end
    function r.ints64(n)
        local a = r.inter(n, 8)
        for i = 1, n do a[i] = zz(a[i]) end
        return a
    end
    function r.floats(n)
        local a = r.inter(n, 4)
        for i = 1, n do a[i] = unrot(a[i]) end
        return a
    end
    function r.refs(n)
        local a, acc = r.ints(n), 0
        for i = 1, n do acc += a[i]; a[i] = acc end
        return a
    end
    function r.bytesArr(n)
        local a = table.create(n)
        for i = 1, n do a[i] = byte(s, r.p + i - 1) end
        r.p += n
        return a
    end
    return r
end

---------------------------------------------------------------------
-- DECODER TIPE PROPERTI (id tipe -> function(reader, jumlah) -> array nilai)
---------------------------------------------------------------------
local function try(f, ...)
    local okT, v = pcall(f, ...)
    if okT then return v end
    return nil
end

local D = {}
D[0x01] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.str() end
    return t
end
D[0x02] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.u8() ~= 0 end
    return t
end
D[0x03] = function(r, n) return r.ints(n) end
D[0x04] = function(r, n) return r.floats(n) end
D[0x05] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.f64() end
    return t
end
D[0x06] = function(r, n)
    local sc = r.floats(n)
    local of = r.ints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = UDim.new(sc[i], of[i]) end
    return t
end
D[0x07] = function(r, n)
    local sx = r.floats(n)
    local sy = r.floats(n)
    local ox = r.ints(n)
    local oy = r.ints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = UDim2.new(sx[i], ox[i], sy[i], oy[i]) end
    return t
end
D[0x0B] = function(r, n)
    local a = r.uints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = try(BrickColor.new, a[i]) end
    return t
end
D[0x0C] = function(r, n)
    local cr = r.floats(n)
    local cg = r.floats(n)
    local cb = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Color3.new(cr[i], cg[i], cb[i]) end
    return t
end
D[0x0D] = function(r, n)
    local x = r.floats(n)
    local y = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Vector2.new(x[i], y[i]) end
    return t
end
D[0x0E] = function(r, n)
    local x = r.floats(n)
    local y = r.floats(n)
    local z = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Vector3.new(x[i], y[i], z[i]) end
    return t
end
D[0x10] = function(r, n)
    local rots = table.create(n)
    for i = 1, n do
        local id = r.u8()
        if id == 0 then
            local m = table.create(9)
            for j = 1, 9 do m[j] = r.f32() end
            rots[i] = m
        else
            rots[i] = ROT[id] or ROT[0x02]
        end
    end
    local x = r.floats(n)
    local y = r.floats(n)
    local z = r.floats(n)
    local t = table.create(n)
    for i = 1, n do
        local m = rots[i]
        t[i] = try(CFrame.new, x[i], y[i], z[i], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
    end
    return t
end
D[0x12] = function(r, n)
    local a = r.uints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = {enum = a[i]} end
    return t
end
D[0x14] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local x = r.i16()
        local y = r.i16()
        local z = r.i16()
        t[i] = Vector3int16.new(x, y, z)
    end
    return t
end
D[0x15] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local k = r.u32()
        local kp = {}
        for j = 1, k do
            local tm = r.f32()
            local v = r.f32()
            local env = r.f32()
            kp[j] = NumberSequenceKeypoint.new(tm, v, env)
        end
        t[i] = try(NumberSequence.new, kp)
    end
    return t
end
D[0x16] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local k = r.u32()
        local kp = {}
        for j = 1, k do
            local tm = r.f32()
            local cr, cg, cb = r.f32(), r.f32(), r.f32()
            r.f32()
            kp[j] = ColorSequenceKeypoint.new(tm, Color3.new(cr, cg, cb))
        end
        t[i] = try(ColorSequence.new, kp)
    end
    return t
end
D[0x17] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local mn = r.f32()
        local mx = r.f32()
        t[i] = NumberRange.new(mn, mx)
    end
    return t
end
D[0x18] = function(r, n)
    local x0 = r.floats(n)
    local y0 = r.floats(n)
    local x1 = r.floats(n)
    local y1 = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Rect.new(x0[i], y0[i], x1[i], y1[i]) end
    return t
end
D[0x1A] = function(r, n)
    local cr = r.bytesArr(n)
    local cg = r.bytesArr(n)
    local cb = r.bytesArr(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Color3.fromRGB(cr[i], cg[i], cb[i]) end
    return t
end
D[0x1B] = function(r, n) return r.ints64(n) end

---------------------------------------------------------------------
-- BANTUAN SET PROPERTI
---------------------------------------------------------------------
local enumCache = {}
local function enumItem(enumType, value)
    local map = enumCache[enumType]
    if not map then
        map = {}
        for _, it in ipairs(enumType:GetEnumItems()) do map[it.Value] = it end
        enumCache[enumType] = map
    end
    return map[value]
end

local function setValue(inst, name, val)
    name = ALIAS[name] or name
    if SKIP_PROP[name] or val == nil then return end
    if type(val) == "table" and val.enum then
        local okR, cur = pcall(function() return inst[name] end)
        if okR and typeof(cur) == "EnumItem" then
            local it = enumItem(cur.EnumType, val.enum)
            if it then pcall(function() inst[name] = it end) end
        end
        return
    end
    local okS = pcall(function() inst[name] = val end)
    if not okS and name == "Source" and type(sethiddenproperty) == "function" then
        pcall(sethiddenproperty, inst, "Source", val)
    end
end

local meshCache = {}
local function makeMeshPart(id)
    if meshCache[id] ~= nil then
        return meshCache[id] and meshCache[id]:Clone() or nil
    end
    local okM, mp = pcall(function()
        return InsertService:CreateMeshPartAsync(id, Enum.CollisionFidelity.Default, Enum.RenderFidelity.Automatic)
    end)
    if not (okM and mp) and UI.ResolveMesh then
        local ok2, res = pcall(UI.ResolveMesh, id)
        if ok2 and typeof(res) == "Instance" then mp, okM = res, true end
    end
    meshCache[id] = (okM and mp) and mp or false
    return meshCache[id] and meshCache[id]:Clone() or nil
end

---------------------------------------------------------------------
-- IMPORTER UTAMA
---------------------------------------------------------------------
local function importRbx(data, opts, report)
    local head = data:sub(1, 8)
    if head == "<roblox " then
        error("Format XML (.rbxlx/.rbxmx) belum didukung, simpan sebagai .rbxl biner", 0)
    end
    if data:sub(1, 14) ~= "<roblox!\137\255\r\n\26\n" then
        error("Bukan file RBXL/RBXM biner", 0)
    end

    local total = #data
    local rd = newReader(data)
    rd.p = 21
    local totalInst = rd.u32()
    rd.p = 33

    local classes, objs, isSvc, deferred, pending = {}, {}, {}, {}, {}
    local parentData
    local stat = {created = 0, skipped = 0, meshFallback = 0, skippedClasses = {}, placeholder = 0, realSource = 0, srcPending = {}, srcDone = {}}
    local lastYield = os.clock()
    local function tick()
        if os.clock() - lastYield > 0.03 then task.wait(); lastYield = os.clock() end
    end

    local function apply(ref, name, val)
        local d = deferred[ref]
        if d then d.props[name] = val return end
        local inst = objs[ref]
        if not inst then return end
        if isSvc[ref] and not opts.serviceProps then return end
        if name == "Source" and type(val) == "string" then
            if SC.isPlaceholderSource(val) then stat.placeholder += 1 else stat.realSource += 1 end
            stat.srcPending[inst] = val   -- ditulis belakangan lewat SC.writeSource
            return
        end
        setValue(inst, name, val)
    end

    -- 1) baca chunk satu per satu
    while rd.p <= total - 15 do
        local cname = data:sub(rd.p, rd.p + 3)
        rd.p += 4
        local clen = rd.u32()
        local ulen = rd.u32()
        rd.p += 4
        local payload
        if clen == 0 then
            payload = data:sub(rd.p, rd.p + ulen - 1)
            rd.p += ulen
        else
            payload = decompress(data:sub(rd.p, rd.p + clen - 1), ulen)
            rd.p += clen
        end
        if cname == "END\0" then break end

        local cr = newReader(payload)
        if cname == "INST" then
            local id = cr.u32()
            local className = cr.str()
            local hasService = cr.u8()
            local n = cr.u32()
            local refs = cr.refs(n)
            classes[id] = {name = className, refs = refs}
            for _, ref in ipairs(refs) do
                if hasService == 1 then
                    local okS, svc = pcall(game.GetService, game, className)
                    isSvc[ref] = true
                    objs[ref] = (okS and svc and not UI.ImportSkipServices[className]) and svc or false
                elseif SKIP_CLASS[className] then
                    objs[ref] = false
                    stat.skipped += 1
                elseif className == "MeshPart" then
                    objs[ref] = false
                    deferred[ref] = {props = {}}
                else
                    local okI, inst = pcall(Instance.new, className)
                    if okI and inst then
                        objs[ref] = inst
                        stat.created += 1
                    else
                        objs[ref] = false
                        stat.skipped += 1
                        stat.skippedClasses[className] = (stat.skippedClasses[className] or 0) + 1
                    end
                end
            end
        elseif cname == "PROP" then
            local cls = classes[cr.u32()]
            local pname = cr.str()
            local tid = cr.u8()
            if cls then
                local n = #cls.refs
                if tid == 0x13 then
                    local okR, targets = pcall(cr.refs, n)
                    if okR then
                        for i = 1, n do pending[#pending + 1] = {cls.refs[i], pname, targets[i]} end
                    end
                elseif D[tid] then
                    local okD, vals = pcall(D[tid], cr, n)
                    if okD and vals then
                        for i = 1, n do apply(cls.refs[i], pname, vals[i]) end
                    end
                end
            end
        elseif cname == "PRNT" then
            cr.u8()
            local n = cr.u32()
            local childs = cr.refs(n)
            local parents = cr.refs(n)
            parentData = {childs, parents, n}
        end
        report(5 + 60 * (rd.p / total), "Membaca map...", "Memproses data (" .. fmt(totalInst) .. " instance di file)")
        tick()
    end
    if not parentData then error("Struktur file tidak lengkap (PRNT tidak ditemukan)", 0) end

    -- 2) bangun MeshPart yang tertunda
    local meshRefs = {}
    for ref in pairs(deferred) do meshRefs[#meshRefs + 1] = ref end
    for i, ref in ipairs(meshRefs) do
        local d = deferred[ref]
        local id = d.props.MeshId
        local inst
        if type(id) == "string" and id ~= "" then inst = makeMeshPart(id) end
        if inst then
            stat.created += 1
        else
            inst = Instance.new("Part")
            stat.meshFallback += 1
        end
        objs[ref] = inst
        for k, v in pairs(d.props) do
            if k ~= "MeshId" then setValue(inst, k, v) end
        end
        report(65 + 15 * (i / #meshRefs), "Memuat mesh...", i .. " / " .. #meshRefs)
        tick()
    end

    -- 3) properti referensi (Part0, Part1, PrimaryPart, dll)
    for _, pr in ipairs(pending) do
        local inst, target = objs[pr[1]], objs[pr[3]]
        if inst and target and not isSvc[pr[1]] then
            pcall(function() inst[pr[2]] = target end)
        end
    end

    -- 4) mode Studio Lite: anchor + simpan nilai asli di atribut SL_
    if opts.studioMode then
        for ref, inst in pairs(objs) do
            if inst and not isSvc[ref] and inst:IsA("BasePart") then
                pcall(function()
                    if inst:GetAttribute("SL_Anchored") == nil then
                        inst:SetAttribute("SL_Anchored", inst.Anchored)
                        inst:SetAttribute("SL_CanCollide", inst.CanCollide)
                    end
                    inst.Anchored = true
                end)
            end
        end
    end

    -- 5) susun hierarki: bagian dalam dulu, baru ditempel ke service
    local childs, parents, n = parentData[1], parentData[2], parentData[3]
    for i = 1, n do
        local cRef, pRef = childs[i], parents[i]
        local c = objs[cRef]
        if c and not isSvc[cRef] and pRef ~= -1 and not isSvc[pRef] then
            local p = objs[pRef]
            if p then pcall(function() c.Parent = p end) end
        end
        if i % 500 == 0 then
            report(80 + 10 * (i / n), "Menyusun hierarki...", fmt(i) .. " / " .. fmt(n))
            tick()
        end
    end
    local attached = 0
    for i = 1, n do
        local cRef, pRef = childs[i], parents[i]
        local c = objs[cRef]
        if c and not isSvc[cRef] and (pRef == -1 or isSvc[pRef]) then
            local p = (pRef == -1) and workspace or objs[pRef]
            if p and not UI.ImportSkipNames[c.Name] then
                if pcall(function() c.Parent = p end) then attached += 1 end
            end
        end
        if i % 500 == 0 then
            report(90 + 10 * (i / n), "Menempel ke game...", fmt(i) .. " / " .. fmt(n))
            tick()
        end
    end
    stat.attached = attached
    stat.scriptSet = {}
    stat.parts, stat.scripts = 0, 0

    -- ringkasan per service (diagnosa: apakah isi Workspace ikut terbawa?)
    local parentOf = {}
    for i = 1, n do parentOf[childs[i]] = parents[i] end
    local rootCache = {}
    local function rootName(ref)
        if rootCache[ref] then return rootCache[ref] end
        local chain, cur, name = {}, ref, nil
        for _ = 1, 400 do
            if rootCache[cur] then name = rootCache[cur] break end
            chain[#chain + 1] = cur
            if isSvc[cur] then
                local si = objs[cur]
                name = si and si.ClassName or "?"
                break
            end
            local pr = parentOf[cur]
            if pr == nil or pr == -1 then name = "Workspace" break end
            cur = pr
        end
        name = name or "?"
        for _, r in ipairs(chain) do rootCache[r] = name end
        return name
    end
    stat.bySvc = {}
    for ref, inst in pairs(objs) do
        if inst and not isSvc[ref] and typeof(inst) == "Instance" then
            local nm = rootName(ref)
            stat.bySvc[nm] = (stat.bySvc[nm] or 0) + 1
            if inst:IsA("BasePart") then
                stat.parts += 1
            elseif inst:IsA("LuaSourceContainer") then
                stat.scripts += 1
                stat.scriptSet[inst] = true
            end
        end
    end
    -- isi script: tulis lewat mesin script (langsung / hidden / identity / registri / Studio Lite)
    local nSrc = 0
    for inst, val in pairs(stat.srcPending) do
        if stat.scriptSet[inst] and SC.usableSource(val) then
            SC.writeSource(inst, val)
            stat.srcDone[inst] = true
            nSrc += 1
            if nSrc % 20 == 0 then report(99, "Memasang isi script...", nSrc .. " script"); tick() end
        end
    end
    stat.srcPending = nil
    return stat
end

---------------------------------------------------------------------
-- IMPORT VIA GetObjects (cara utama; parser biner di atas jadi cadangan)
---------------------------------------------------------------------
local function assetCandidates(path)
    local c, seen = {}, {}
    local function add(x)
        if x and x ~= "" and not seen[x] then seen[x] = true; c[#c + 1] = x end
    end
    local p = path:gsub("\\", "/")
    add(p)
    for _, pre in ipairs({"workspace/", "Delta/workspace/", "delta/workspace/",
        "Android/Delta/workspace/", "/sdcard/Delta/workspace/", "/sdcard/Android/Delta/workspace/"}) do
        if p:sub(1, #pre):lower() == pre:lower() then add(p:sub(#pre + 1)) end
    end
    add(p:match("[^/]+$"))
    return c
end

-- tempat default sebuah objek hasil import (Sky -> Lighting, Sound -> SoundService, dst.)
local function defaultParent(inst)
    local function svc(n)
        local ok, v = pcall(game.GetService, game, n)
        return (ok and v) or workspace
    end
    if inst:IsA("Sky") or inst:IsA("Atmosphere") or inst:IsA("PostEffect") then return svc("Lighting") end
    if inst:IsA("Clouds") then return workspace.Terrain end
    if inst:IsA("Sound") or inst:IsA("SoundGroup") then return svc("SoundService") end
    local lp = Players.LocalPlayer
    if lp then
        if inst:IsA("ScreenGui") then return lp:FindFirstChildOfClass("PlayerGui") or workspace end
        if inst:IsA("Tool") then return lp:FindFirstChildOfClass("Backpack") or workspace end
    end
    return workspace
end

local function placeInstance(inst, parent, stat)
    if UI.ImportSkipNames[inst.Name] then stat.skipped += 1 return end
    if inst:IsA("Sky") then   -- hanya satu Sky yang berlaku: ganti yang lama
        for _, ch in ipairs(parent:GetChildren()) do
            if ch:IsA("Sky") then pcall(function() ch:Destroy() end) end
        end
    end
    if pcall(function() inst.Parent = parent end) then stat.attached += 1 else stat.skipped += 1 end
end

local function importViaAsset(path, opts, report, loose, expected)
    local getAsset = getcustomasset or getsynasset
    if type(getAsset) ~= "function" then
        return nil, "getcustomasset tidak tersedia"
    end
    local lastErr = "GetObjects tidak mengembalikan apa-apa"
    local objects
    for _, cand in ipairs(assetCandidates(path)) do
        local okA, asset = pcall(getAsset, cand)
        if okA and asset then
            local okO, res = pcall(function() return game:GetObjects(asset) end)
            if okO and type(res) == "table" and #res > 0 then
                objects = res
                break
            end
            lastErr = okO and lastErr or tostring(res)
        else
            lastErr = tostring(asset)
        end
    end
    if not objects then return nil, lastErr end

    -- periksa isi sebelum menempel: harus ada part / script
    local nParts, nScripts, summary, nTotal = 0, 0, {}, 0
    local scriptSet = {}
    local bySvc = {}
    for _, obj in ipairs(objects) do
        local okD, d = pcall(obj.GetDescendants, obj)
        d = okD and d or {}
        for _, inst in ipairs(d) do
            if inst:IsA("BasePart") then nParts += 1
            elseif inst:IsA("LuaSourceContainer") then nScripts += 1; scriptSet[inst] = true end
        end
        nTotal += #d + 1
        bySvc[obj.ClassName] = (bySvc[obj.ClassName] or 0) + #d + 1
        summary[#summary + 1] = obj.ClassName .. "=" .. (#d + 1)
    end
    local summaryTxt = table.concat(summary, ", ")
    pcall(warn, ("[CopyMap] GetObjects: %d part, %d script | %s"):format(nParts, nScripts, summaryTxt))
    if loose then
        if nTotal == 0 then return nil, "GetObjects kosong" end
    else
        -- file place: GetObjects sering hanya mengembalikan service tertentu (Lighting dll)
        -- dan membuang isi Workspace. Hasil begitu TIDAK boleh diterima, walau ada script.
        if nParts == 0 then
            return nil, "GetObjects tanpa part (" .. summaryTxt .. ")"
        end
        if expected and expected > 0 and nTotal < expected * 0.5 then
            return nil, ("GetObjects hanya %d dari %d instance"):format(nTotal, expected)
        end
    end

    local stat = {created = 0, skipped = 0, meshFallback = 0, attached = 0,
        parts = nParts, scripts = nScripts, scriptSet = scriptSet, bySvc = bySvc}
    report(40, "Menempelkan ke game...", fmt(#objects) .. " objek level atas")

    local function place(inst, parent) placeInstance(inst, parent, stat) end

    local lastYield = os.clock()
    for i, obj in ipairs(objects) do
        -- hasil GetObjects dari .rbxl biasanya berupa kontainer bernama service
        local okS, svc = pcall(game.GetService, game, obj.ClassName)
        if okS and svc then
            if not UI.ImportSkipServices[obj.ClassName] then
                for _, ch in ipairs(obj:GetChildren()) do place(ch, svc) end
            end
        else
            place(obj, defaultParent(obj))
        end
        if os.clock() - lastYield > 0.03 then
            report(40 + 50 * (i / #objects), "Menempelkan ke game...", fmt(i) .. " / " .. fmt(#objects))
            task.wait(); lastYield = os.clock()
        end
    end

    local count = nTotal
    stat.created = count

    if opts.studioMode then
        report(92, "Mode Studio Lite...", "Anchor part")
        for _, obj in ipairs(objects) do
            local okD, d = pcall(obj.GetDescendants, obj)
            for _, inst in ipairs(okD and d or {}) do
                if inst:IsA("BasePart") then
                    pcall(function()
                        if inst:GetAttribute("SL_Anchored") == nil then
                            inst:SetAttribute("SL_Anchored", inst.Anchored)
                            inst:SetAttribute("SL_CanCollide", inst.CanCollide)
                        end
                        inst.Anchored = true
                    end)
                end
            end
        end
    end
    return stat
end

---------------------------------------------------------------------
-- IMPORT XML (.rbxmx / .rbxlx): cadangan kalau GetObjects tidak bisa membaca file.
-- Mendukung properti umum (string, angka, bool, enum, Content, Color3, Vector, CFrame, UDim, urutan).
-- Mesh / union / terrain tidak bisa dibuat dari XML; untuk itu GetObjects tetap jalur utama.
---------------------------------------------------------------------
local importXml
do
    local function unesc(str)
        str = str:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'")
        str = str:gsub("&#x(%x+);", function(h)
            local ok, ch = pcall(utf8.char, tonumber(h, 16))
            return ok and ch or ""
        end)
        str = str:gsub("&#(%d+);", function(d)
            local ok, ch = pcall(utf8.char, tonumber(d))
            return ok and ch or ""
        end)
        return (str:gsub("&amp;", "&"))
    end

    local function parse(text, tick)
        local root = {tag = "#root", attrs = {}, children = {}}
        local stack = {root}
        local pos, iter = 1, 0
        while true do
            local lt = string.find(text, "<", pos, true)
            if not lt then break end
            if lt > pos then
                local chunk = string.sub(text, pos, lt - 1)
                if chunk:find("%S") then
                    local top = stack[#stack]
                    top.text = (top.text or "") .. unesc(chunk)
                end
            end
            if string.sub(text, lt, lt + 3) == "<!--" then
                local e = string.find(text, "-->", lt + 4, true)
                if not e then break end
                pos = e + 3
            elseif string.sub(text, lt, lt + 8) == "<![CDATA[" then
                local e = string.find(text, "]]>", lt + 9, true)
                if not e then break end
                local top = stack[#stack]
                top.text = (top.text or "") .. string.sub(text, lt + 9, e - 1)
                pos = e + 3
            elseif string.sub(text, lt, lt + 1) == "<?" then
                local e = string.find(text, "?>", lt + 2, true)
                if not e then break end
                pos = e + 2
            elseif string.sub(text, lt + 1, lt + 1) == "/" then
                local e = string.find(text, ">", lt + 2, true)
                if not e then break end
                if #stack > 1 then table.remove(stack) end
                pos = e + 1
            else
                local e = string.find(text, ">", lt + 1, true)
                if not e then break end
                local inner = string.sub(text, lt + 1, e - 1)
                local selfClose = string.sub(inner, -1) == "/"
                if selfClose then inner = string.sub(inner, 1, -2) end
                local tag = inner:match("^[%w_:%.%-]+")
                if tag then
                    local attrs = {}
                    for k, v in inner:gmatch('([%w_:%.%-]+)%s*=%s*"([^"]*)"') do attrs[k] = unesc(v) end
                    local node = {tag = tag, attrs = attrs, children = {}}
                    local top = stack[#stack]
                    top.children[#top.children + 1] = node
                    if not selfClose then stack[#stack + 1] = node end
                end
                pos = e + 1
            end
            iter += 1
            if tick and iter % 4000 == 0 then tick() end
        end
        return root
    end

    local function child(node, tag)
        for _, c in ipairs(node.children) do
            if c.tag == tag then return c end
        end
        return nil
    end
    local function num(node, tag, default)
        local c = child(node, tag)
        return (c and tonumber(c.text or "")) or default
    end
    local function numbers(text)
        local t = {}
        for v in (text or ""):gmatch("%S+") do t[#t + 1] = tonumber(v) or 0 end
        return t
    end

    -- ubah node properti XML jadi nilai Lua. Hasil ke-2 menandai jenis khusus.
    local function value(prop)
        local t, tx = prop.tag, prop.text or ""
        if t == "string" or t == "ProtectedString" then
            return tx
        elseif t == "bool" then
            return tx:lower() == "true"
        elseif t == "int" or t == "int64" or t == "float" or t == "double" or t == "BrickColor" then
            return tonumber(tx)
        elseif t == "token" then
            return tonumber(tx), "enum"
        elseif t == "Content" then
            local u = child(prop, "url")
            return (u and u.text) or "", "content"
        elseif t == "Color3" or t == "Color3uint8" then
            if child(prop, "R") then
                return Color3.new(num(prop, "R", 0), num(prop, "G", 0), num(prop, "B", 0))
            end
            local n = tonumber(tx)
            if n then
                return Color3.fromRGB(bit32.band(bit32.rshift(n, 16), 255),
                    bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
            end
        elseif t == "Vector3" then
            return Vector3.new(num(prop, "X", 0), num(prop, "Y", 0), num(prop, "Z", 0))
        elseif t == "Vector2" then
            return Vector2.new(num(prop, "X", 0), num(prop, "Y", 0))
        elseif t == "UDim2" then
            return UDim2.new(num(prop, "XS", 0), num(prop, "XO", 0), num(prop, "YS", 0), num(prop, "YO", 0))
        elseif t == "UDim" then
            return UDim.new(num(prop, "S", 0), num(prop, "O", 0))
        elseif t == "CoordinateFrame" or t == "CFrame" then
            return CFrame.new(num(prop, "X", 0), num(prop, "Y", 0), num(prop, "Z", 0),
                num(prop, "R00", 1), num(prop, "R01", 0), num(prop, "R02", 0),
                num(prop, "R10", 0), num(prop, "R11", 1), num(prop, "R12", 0),
                num(prop, "R20", 0), num(prop, "R21", 0), num(prop, "R22", 1))
        elseif t == "NumberRange" then
            local n = numbers(tx)
            if #n >= 2 then return NumberRange.new(n[1], n[2]) end
        elseif t == "NumberSequence" then
            local n, kps = numbers(tx), {}
            for i = 1, #n - 2, 3 do kps[#kps + 1] = NumberSequenceKeypoint.new(n[i], n[i + 1], n[i + 2]) end
            if #kps >= 2 then return NumberSequence.new(kps) end
        elseif t == "ColorSequence" then
            local n, kps = numbers(tx), {}
            for i = 1, #n - 4, 5 do
                kps[#kps + 1] = ColorSequenceKeypoint.new(n[i], Color3.new(n[i + 1], n[i + 2], n[i + 3]))
            end
            if #kps >= 2 then return ColorSequence.new(kps) end
        end
        return nil
    end

    local function setProp(inst, name, prop)
        local v, kind = value(prop)
        if v == nil then return false end
        if kind == "enum" then
            return (pcall(function()
                local cur = inst[name]
                inst[name] = cur.EnumType:FromValue(v)
            end))
        end
        local ok = pcall(function() inst[name] = v end)
        if not ok and kind == "content" and Content then
            ok = pcall(function() inst[name] = Content.fromUri(v) end)
        end
        if not ok and type(sethiddenproperty) == "function" then
            ok = pcall(sethiddenproperty, inst, name, v)
        end
        return ok
    end

    local function build(node, parent, opts, stat, tick)
        if node.tag ~= "Item" then return nil end
        local class = node.attrs.class or "?"
        local inst, isService
        local okI, made = pcall(Instance.new, class)
        if okI and made then
            inst = made
        else
            local okS, svc = pcall(game.GetService, game, class)
            if okS and svc then inst, isService = svc, true end
        end
        if not inst then
            stat.skipped += 1
            stat.skippedClasses[class] = (stat.skippedClasses[class] or 0) + 1
            return nil
        end

        for _, c in ipairs(node.children) do
            if c.tag == "Properties" and (not isService or opts.serviceProps) then
                for _, prop in ipairs(c.children) do
                    local name = prop.attrs.name
                    if name == "Source" and inst:IsA("LuaSourceContainer") then
                        local src = prop.text or ""
                        if SC.isPlaceholderSource(src) then stat.placeholder += 1 else stat.realSource += 1 end
                        if SC.usableSource(src) then
                            SC.writeSource(inst, src)
                            if stat.srcDone then stat.srcDone[inst] = true end
                        end
                    elseif name then
                        setProp(inst, name, prop)
                    end
                end
            end
        end

        if not isService then
            stat.created += 1
            if inst:IsA("BasePart") then
                stat.parts += 1
                if opts.studioMode then
                    pcall(function()
                        inst:SetAttribute("SL_Anchored", inst.Anchored)
                        inst:SetAttribute("SL_CanCollide", inst.CanCollide)
                        inst.Anchored = true
                    end)
                end
            elseif inst:IsA("LuaSourceContainer") then
                stat.scripts += 1
                stat.scriptSet[inst] = true
            end
            tick()
        end

        for _, c in ipairs(node.children) do
            if c.tag == "Item" then build(c, inst, opts, stat, tick) end
        end

        if parent and not isService then
            if parent.ClassName ~= nil then placeInstance(inst, parent, stat) end
        end
        return (not isService) and inst or nil
    end

    importXml = function(text, opts, report)
        report(15, "Membaca XML...", fmt(#text) .. " karakter")
        local lastY = os.clock()
        local function tick()
            if os.clock() - lastY > 0.03 then
                task.wait()
                lastY = os.clock()
            end
        end
        local root = parse(text, tick)
        local rbx = child(root, "roblox")
        if not rbx then error("bukan file XML Roblox", 0) end

        local stat = {created = 0, skipped = 0, meshFallback = 0, skippedClasses = {}, attached = 0,
            parts = 0, scripts = 0, placeholder = 0, realSource = 0, scriptSet = {}, bySvc = {}, srcDone = {}}
        local items = {}
        for _, c in ipairs(rbx.children) do
            if c.tag == "Item" then items[#items + 1] = c end
        end
        if #items == 0 then error("file XML tidak berisi objek", 0) end

        for i, node in ipairs(items) do
            report(25 + 70 * (i / #items), "Membuat instance...", (node.attrs.class or "?") .. "  (" .. i .. " / " .. #items .. ")")
            local before = stat.created
            local inst = build(node, nil, opts, stat, tick)
            if inst then placeInstance(inst, defaultParent(inst), stat) end
            local grp = node.attrs.class or "?"
            stat.bySvc[grp] = (stat.bySvc[grp] or 0) + (stat.created - before)
        end
        return stat
    end
end
---------------------------------------------------------------------
-- BACA ISI SCRIPT LANGSUNG DARI FILE (biner .rbxl/.rbxm dan XML .rbxlx/.rbxmx)
-- Hasil: daftar {cls, name, svc, rel, src}. Dipakai untuk mengisi script hasil import,
-- apa pun jalur importnya (GetObjects / parser biner / parser XML).
---------------------------------------------------------------------
SC.extractBinary = function(data, onTick)
    if string.sub(data, 1, 14) ~= "<roblox!\137\255\r\n\26\n" then
        error("Bukan file RBXL/RBXM biner", 0)
    end
    local total = #data
    local rd = newReader(data)
    rd.p = 33
    local classes, nodeClass, nodeName, nodeSrc, svcRef = {}, {}, {}, {}, {}
    local childs, parents
    while rd.p <= total - 15 do
        local cname = string.sub(data, rd.p, rd.p + 3)
        rd.p += 4
        local clen = rd.u32()
        local ulen = rd.u32()
        rd.p += 4
        local payload
        if clen == 0 then
            payload = string.sub(data, rd.p, rd.p + ulen - 1)
            rd.p += ulen
        else
            payload = decompress(string.sub(data, rd.p, rd.p + clen - 1), ulen)
            rd.p += clen
        end
        if cname == "END\0" then break end
        if cname == "INST" then
            local cr = newReader(payload)
            local id = cr.u32()
            local className = cr.str()
            local hasService = cr.u8()
            local n = cr.u32()
            local refs = cr.refs(n)
            classes[id] = {name = className, refs = refs}
            for _, ref in ipairs(refs) do
                nodeClass[ref] = className
                if hasService == 1 then svcRef[ref] = true end
            end
        elseif cname == "PROP" then
            local cr = newReader(payload)
            local cls = classes[cr.u32()]
            local pname = cr.str()
            local tid = cr.u8()
            if cls and tid == 0x01 and (pname == "Name" or (pname == "Source" and SC.SCRIPT_CLASSES[cls.name])) then
                local n = #cls.refs
                local okV, vals = pcall(D[0x01], cr, n)
                if okV and vals then
                    local dst = (pname == "Name") and nodeName or nodeSrc
                    for i = 1, n do dst[cls.refs[i]] = vals[i] end
                end
            end
        elseif cname == "PRNT" then
            local cr = newReader(payload)
            cr.u8()
            local n = cr.u32()
            childs = cr.refs(n)
            parents = cr.refs(n)
        end
        if onTick then onTick() end
    end
    if not childs then error("Struktur file tidak lengkap (PRNT tidak ditemukan)", 0) end

    local kids, roots = {}, {}
    for i = 1, #childs do
        local c, p = childs[i], parents[i]
        if p == -1 then
            roots[#roots + 1] = c
        else
            local k = kids[p]
            if not k then k = {}; kids[p] = k end
            k[#k + 1] = c
        end
    end

    local entries, names = {}, {}
    local function visit(ref, svc)
        local cls = nodeClass[ref]
        local isSvc = svcRef[ref]
        local nm = nodeName[ref] or cls or "?"
        if isSvc then svc = cls else names[#names + 1] = nm end
        if SC.SCRIPT_CLASSES[cls] then
            entries[#entries + 1] = {cls = cls, name = nm, svc = svc, rel = table.concat(names, "\0"), src = nodeSrc[ref] or ""}
        end
        local k = kids[ref]
        if k then
            for _, c in ipairs(k) do visit(c, svc) end
        end
        if not isSvc then names[#names] = nil end
    end
    for _, r in ipairs(roots) do visit(r, nil) end
    return entries
end

SC.xmlUnescape = function(s)
    if not string.find(s, "&", 1, true) then return s end
    s = s:gsub("&#[xX](%x+);", function(h)
        local ok, ch = pcall(utf8.char, tonumber(h, 16))
        return ok and ch or ""
    end)
    s = s:gsub("&#(%d+);", function(d)
        local ok, ch = pcall(utf8.char, tonumber(d))
        return ok and ch or ""
    end)
    s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'")
    return (s:gsub("&amp;", "&"))
end

SC.extractXml = function(text, onTick)
    local entries = {}
    local dName, dCls, dSvc = {}, {}, {}
    local depth, pos, iter = 0, 1, 0
    while true do
        local s, e, closing = string.find(text, "<(/?)Item[ >]", pos)
        if not s then break end
        iter += 1
        if onTick and iter % 2000 == 0 then onTick() end
        if closing == "/" then
            if depth > 0 then
                dName[depth], dCls[depth], dSvc[depth] = nil, nil, nil
                depth -= 1
            end
            pos = e + 1
        else
            local gt = string.find(text, ">", s, true)
            if not gt then break end
            local head = string.sub(text, s, gt)
            local class = SC.xmlUnescape(string.match(head, 'class="([^"]*)"') or "?")
            local selfClose = string.sub(text, gt - 1, gt - 1) == "/"
            local name, block
            pos = gt + 1
            if not selfClose then
                local a, b = string.find(text, "^%s*<Properties>", gt + 1)
                if a then
                    local propEnd = string.find(text, "</Properties>", b + 1, true) or (#text + 1)
                    block = string.sub(text, b + 1, propEnd - 1)
                    local nm = string.match(block, '<string name="Name">(.-)</string>')
                    if nm then name = SC.xmlUnescape(nm) end
                    pos = propEnd + 13
                end
                depth += 1
                dName[depth] = name or class
                dCls[depth] = class
                local isSvc = false
                if depth == 1 then
                    local okS, svc = pcall(game.GetService, game, class)
                    isSvc = okS and svc ~= nil
                end
                dSvc[depth] = isSvc
                if block and SC.SCRIPT_CLASSES[class] then
                    local inner = string.match(block, '<ProtectedString name="Source">(.-)</ProtectedString>')
                    local src = ""
                    if inner then
                        if string.find(inner, "<![CDATA[", 1, true) then
                            local parts = {}
                            for seg in string.gmatch(inner, "<!%[CDATA%[(.-)%]%]>") do parts[#parts + 1] = seg end
                            src = table.concat(parts)
                        else
                            src = SC.xmlUnescape(inner)
                        end
                    end
                    local parts = {}
                    for d = (dSvc[1] and 2 or 1), depth do parts[#parts + 1] = dName[d] end
                    entries[#entries + 1] = {
                        cls = class, name = name or class, svc = dSvc[1] and dCls[1] or nil,
                        rel = table.concat(parts, "\0"), src = src,
                    }
                end
            end
        end
    end
    return entries
end

---------------------------------------------------------------------
-- DAFTAR FILE + TOMBOL IMPORT
---------------------------------------------------------------------
local impBusy, impRunning, impT0 = false, false, 0
local selectedFile
local impCards = {}

local function fileBase(p)
    return ((p:gsub("\\", "/")):match("[^/]+$")) or p
end

local function impReport(pct, title, sub, detail)
    pct = math.clamp(pct or 0, 0, 100)
    if detail then impDetail.Text = detail end
    TweenService:Create(impBar, TweenInfo.new(0.2), {Size = UDim2.fromScale(pct / 100, 1)}):Play()
    impPct.Text = math.floor(pct) .. "%"
    if title then impTitle.Text = title end
    if sub then impSub.Text = sub end
    if pct >= 100 then
        impRunning = false
        impTime.Text = mmss(os.clock() - impT0)
    end
end

local function impBegin()
    impRunning, impT0 = true, os.clock()
    impDetail.Text = ""
    task.spawn(function()
        while impRunning and gui.Parent do
            impTime.Text = mmss(os.clock() - impT0)
            task.wait(0.25)
        end
    end)
end

local function findMapFiles()
    local seen, out = {}, {}
    if type(listfiles) ~= "function" then return out end
    local function norm(p)
        p = p:gsub("\\", "/"):lower()
        p = p:gsub("^%./", ""):gsub("^workspace/", "")
        return p
    end
    local function isDir(p)
        if type(isfolder) == "function" then
            local okF, v = pcall(isfolder, p)
            if okF then return v == true end
        end
        return not p:match("%.[%w]+$")
    end
    local visited = 0
    local function visit(dir, depth)
        local okL, files = pcall(listfiles, dir)
        if not okL or type(files) ~= "table" then return end
        for _, p in ipairs(files) do
            visited += 1
            if visited % 150 == 0 then task.wait() end
            local low = p:lower()
            if isDir(p) then
                if depth < 3 and not low:find("scripts_", 1, true) then visit(p, depth + 1) end
            else
                local isMap = low:match("%.rbxlx?$") or low:match("%.rbxmx?$")
                if not isMap and low:match("%.xml$") and type(readfile) == "function" then
                    local okR, d = pcall(readfile, p)   -- .xml hanya dihitung kalau isinya XML Roblox
                    isMap = okR and type(d) == "string" and string.find(string.sub(d, 1, 600), "<roblox", 1, true) ~= nil
                end
                local key = norm(p)
                if isMap and not seen[key] and not fileBase(low):find("^cm_tmp_") then
                    seen[key] = true
                    out[#out + 1] = p
                end
            end
        end
    end
    for _, dir in ipairs({"", ".", "workspace", "Delta/Workspace", "ZADataStorage", "Copy Map", "MhmmdalviStudio"}) do
        visit(dir, 0)
    end
    table.sort(out, function(a, b) return fileBase(a):lower() < fileBase(b):lower() end)
    return out
end

local allFiles = {}

local function paintFiles()
    for _, c in ipairs(impCards) do
        if c.path then
            local on = c.path == selectedFile
            c.stroke.Color = on and T.AccentLn or T.Line
            c.stroke.Thickness = on and 1.6 or 1
        end
    end
end

local function selectFile(p)
    selectedFile = p
    valFile.Text = fileBase(p)
    valSize.Text = "-"
    valInst.Text = "-"
    valStat.Text = "Siap import"
    paintFiles()
end

local function renderFiles()
    for _, c in ipairs(impCards) do c.frame:Destroy() end
    impCards = {}
    local q = string.lower(impSearch.Text or "")
    local shown = {}
    for _, p in ipairs(allFiles) do
        if q == "" or string.find(string.lower(fileBase(p)), q, 1, true) then shown[#shown + 1] = p end
    end
    lblFileCount.Text = #allFiles .. " FILES"
    if #shown == 0 then
        local lbl = label(impList, {
            Text = (#allFiles == 0) and "Belum ada file .rbxl di folder workspace executor.\nCopy map dulu, lalu tekan tombol refresh."
                or "Tidak ada file yang cocok.",
            TextSize = 9, TextColor3 = T.Muted, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 60),
        })
        impCards[1] = {frame = lbl}
        return
    end
    for idx, p in ipairs(shown) do
        local ext = p:lower():match("%.(%w+)$") or "?"
        local isModel = (ext == "rbxm" or ext == "rbxmx")
        local isXmlFile = (ext == "rbxmx" or ext == "rbxlx" or ext == "xml")
        local card = new("Frame", {
            Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = idx,
        }, impList)
        corner(card, 16)
        local st = stroke(card, T.Line, 1)

        local badge = new("Frame", {
            Position = UDim2.fromOffset(10, 18), Size = UDim2.fromOffset(44, 22),
            BackgroundColor3 = T.Panel, BorderSizePixel = 0,
        }, card)
        corner(badge, 11)
        stroke(badge, T.AccentLn, 1, 0.5)
        label(badge, {Text = (ext == "xml") and "XML" or ext:upper(), Font = Enum.Font.GothamBold, TextSize = 8,
            TextColor3 = T.AccentLn, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1)})

        label(card, {Text = fileBase(p), Font = Enum.Font.GothamBold, TextSize = 10,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(64, 10), Size = UDim2.new(1, -148, 0, 18)})
        label(card, {Text = (ext == "xml") and "File XML Roblox (.xml)" or ((isModel and "Model" or "Place") .. (isXmlFile and " XML" or " biner") .. " (." .. ext .. ")"), TextSize = 8,
            TextColor3 = T.Muted, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(64, 30), Size = UDim2.new(1, -148, 0, 14)})

        local hit = new("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3,
        }, card)
        hit.MouseButton1Click:Connect(function() selectFile(p) end)

        local go = button(card, {
            Text = "IMPORT", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(66, 30), BackgroundColor3 = T.Accent, TextColor3 = T.OnAccent,
            TextSize = 8, ZIndex = 4,
        })
        corner(go, 15)
        stroke(go, T.AccentLn, 1, 0.3)
        go.MouseButton1Click:Connect(function()
            selectFile(p)
            if UI.RunImport then UI.RunImport() end
        end)

        impCards[#impCards + 1] = {frame = card, stroke = st, path = p}
    end
    paintFiles()
end
impSearch:GetPropertyChangedSignal("Text"):Connect(renderFiles)

local function refreshFiles()
    allFiles = findMapFiles()
    renderFiles()
    -- pertahankan pilihan lama kalau filenya masih ada
    local still = false
    for _, p in ipairs(allFiles) do if p == selectedFile then still = true end end
    if still then paintFiles() elseif #allFiles == 1 then selectFile(allFiles[1]) else selectedFile = nil end
end

UI.OnImport = function(path, opts)
    if impBusy then return end
    impBusy = true
    impBar.BackgroundColor3 = T.AccentLn

    local function fail(title, sub)
        impRunning = false
        impBar.BackgroundColor3 = T.Bad
        impReport(100, title, "", sub)   -- pesan lengkap di area rincian
        impPct.Text = "GAGAL"
        valStat.Text = "Gagal"
        impBusy = false
    end

    if type(readfile) ~= "function" then
        return fail("Executor tidak didukung", "Fungsi readfile tidak ditemukan")
    end
    valStat.Text = "Membaca..."
    impReport(2, "Membaca file...", fileBase(path))
    local okR, data = pcall(readfile, path)
    if not okR or type(data) ~= "string" or #data == 0 then
        return fail("File tidak bisa dibaca", tostring(data):sub(1, 70))
    end
    valSize.Text = string.format("%.2f MB", #data / 1048576)

    -- kenali format: XML (rbxmx/rbxlx) atau biner
    local lowp = path:lower()
    local isXml = string.sub(data, 1, 8) ~= "<roblox!" and string.find(string.sub(data, 1, 600), "<roblox", 1, true) ~= nil
    local isPlace = lowp:match("%.rbxlx?$") ~= nil
        or (isXml and string.find(data, 'class="Workspace"', 1, true) ~= nil)
    local loose = (not isPlace) and (isXml or lowp:match("%.rbxm$") ~= nil)   -- model: terima hasil apa pun
    -- perkiraan jumlah instance di dalam file (untuk mendeteksi hasil yang tidak lengkap)
    local expected = 0
    if isXml then
        local _, cnt = string.gsub(data, "<Item ", "")
        expected = cnt
    elseif string.sub(data, 1, 8) == "<roblox!" and #data >= 24 then
        local b1, b2, b3, b4 = string.byte(data, 21, 24)
        expected = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end
    local loadPath, tmp = path, nil
    if isXml and not (lowp:match("%.rbxmx$") or lowp:match("%.rbxlx$")) and type(writefile) == "function" then
        -- executor mengenali format dari ekstensi, jadi salin dulu sebagai .rbxmx
        tmp = "CM_tmp_" .. tostring(os.time()) .. (isPlace and ".rbxlx" or ".rbxmx")
        if pcall(writefile, tmp, data) then loadPath = tmp else tmp = nil end
    end

    impReport(10, "Mencoba import (GetObjects)...", fileBase(path))
    local res, assetErr = importViaAsset(loadPath, opts or {}, impReport, loose, expected)
    if tmp and type(delfile) == "function" then pcall(delfile, tmp) end
    if not res then
        pcall(warn, "[CopyMap] GetObjects gagal: " .. tostring(assetErr))
        if isXml then
            impReport(12, "Cadangan: parser XML...", tostring(assetErr):sub(1, 60))
            local okX, r3 = pcall(importXml, data, opts or {}, impReport)
            if not okX then
                pcall(warn, "[CopyMap] Parser XML gagal: " .. tostring(r3))
                return fail("Import gagal",
                    "GetObjects: " .. tostring(assetErr):sub(1, 40) .. " | XML: " .. (tostring(r3):gsub("^[^:]*:%d+: ", "")):sub(1, 70))
            end
            res = r3
        else
            impReport(12, "Cadangan: parser biner...", tostring(assetErr):sub(1, 60))
            local okI, r2 = pcall(importRbx, data, opts or {}, impReport)
            if not okI then
                pcall(warn, "[CopyMap] Parser biner gagal: " .. tostring(r2))
                return fail("Import gagal",
                    "GetObjects: " .. tostring(assetErr):sub(1, 40) .. " | Parser: " .. (tostring(r2):gsub("^[^:]*:%d+: ", "")):sub(1, 70))
            end
            res = r2
        end
    end

    -- isi script dibaca langsung dari FILE (jalur GetObjects tidak membawa isi script)
    impReport(93, "Membaca isi script dari file...", fileBase(path))
    local fileErr
    do
        local okE, ents = pcall(function()
            local tk = function() task.wait() end
            if isXml then return SC.extractXml(data, tk) end
            return SC.extractBinary(data, tk)
        end)
        if okE and type(ents) == "table" then
            impReport(94, "Memasang isi script...", #ents .. " script di file")
            local okR, errR = pcall(SC.restoreFromFile, ents, res, function(f)
                impReport(94 + 2 * f, "Memasang isi script...", math.floor(f * 100) .. "%")
            end)
            if not okR then fileErr = tostring(errR) end
        else
            fileErr = tostring(ents)
        end
        if fileErr then pcall(warn, "[MhmmdalviStudio] baca script dari file gagal: " .. fileErr) end
    end

    impReport(96, "Memulihkan isi script...", "membaca " .. fileBase(path):gsub("%.[^.]+$", "") .. SC.SCRIPTS_EXT)
    local okSc, sres = pcall(SC.restoreImportedScripts, path, res)
    if not okSc then
        pcall(warn, "[CopyMap] pulihkan script gagal: " .. tostring(sres))
        sres = {total = 0, restored = 0, direct = 0, sidecar = false}
    end

    valInst.Text = fmt(res.created)
    valStat.Text = "Selesai"
    local sub = fmt(res.created) .. " instance dibuat"
    if res.meshFallback > 0 then
        sub ..= ", " .. res.meshFallback .. " mesh jadi Part biasa"
    end
    if res.skipped > 0 then
        sub ..= ", " .. res.skipped .. " dilewati"
    end
    if res.parts then
        sub ..= " (" .. res.parts .. " part, " .. res.scripts .. " script)"
    end
    do
        local fi = res.fileInfo
        local real = (fi and fi.real or 0) + (res.srcApplied or 0)
        local nDone = 0
        for _ in pairs(res.srcDone or {}) do nDone += 1 end
        sub ..= (" | isi script dari file: %d/%d terpasang"):format(nDone, res.scripts or 0)
        if fi and fi.empty > 0 then sub ..= (" (%d kosong di file)"):format(fi.empty) end
        if fileErr then sub ..= " | ⚠ " .. fileErr:gsub("^[^:]*:%d+: ", ""):sub(1, 60) end
    end
    pcall(function()
        UI.ScriptLib = SC.collectLib(res)
        if UI.ScriptsChanged then UI.ScriptsChanged() end
    end)
    if sres.sidecar then
        sub ..= (" | script: %d/%d diisi"):format(sres.restored, sres.total)
        if sres.restored > 0 and sres.direct == 0 then sub ..= " (isi di MH_Source)" end
    elseif (res.placeholder or 0) > 0 then
        sub ..= " | ⚠ " .. res.placeholder .. " script cuma placeholder (file disimpan tanpa decompile)"
    elseif sres.total > 0 then
        sub ..= " | " .. sres.total .. " script (sesuai isi file)"
    end
    -- diagnosa: dari mana asal instance, dan apakah isi Workspace ikut terbawa
    if res.bySvc then
        local arr = {}
        for k, v in pairs(res.bySvc) do arr[#arr + 1] = {k, v} end
        table.sort(arr, function(a, b) return a[2] > b[2] end)
        local out = {}
        for i = 1, math.min(#arr, 5) do out[#out + 1] = arr[i][1] .. " " .. fmt(arr[i][2]) end
        if #out > 0 then sub ..= " | " .. table.concat(out, "  -  ") end
    end
    local warnTxt
    if isPlace and (res.parts or 0) == 0 then
        warnTxt = "⚠ tidak ada part yang ter-import"
        if expected > 0 then warnTxt ..= " (file berisi " .. fmt(expected) .. " instance)" end
        warnTxt ..= ". Cek apakah Workspace ikut tersimpan saat copy."
    elseif expected > 0 and (res.created or 0) < expected * 0.5 then
        warnTxt = "⚠ hanya " .. fmt(res.created) .. " dari " .. fmt(expected) .. " instance terbawa"
        local sk = {}
        for k, v in pairs(res.skippedClasses or {}) do sk[#sk + 1] = {k, v} end
        table.sort(sk, function(a, b) return a[2] > b[2] end)
        local names = {}
        for i = 1, math.min(#sk, 3) do names[#names + 1] = sk[i][1] .. " x" .. sk[i][2] end
        if #names > 0 then warnTxt ..= " (dilewati: " .. table.concat(names, ", ") .. ")" end
    end
    if warnTxt then
        sub ..= " | " .. warnTxt
        impBar.BackgroundColor3 = T.Bad
    end
    impReport(100, warnTxt and "Import selesai (tidak lengkap)" or "Import selesai",
        fmt(res.created or 0) .. " instance  -  " .. (res.parts or 0) .. " part  -  " .. (res.scripts or 0) .. " script", sub)
    impBusy = false
end

UI.RunImport = function()
    if impBusy then return end
    if not selectedFile then
        impTitle.Text = "Belum ada file dipilih"
        impSub.Text = "Pilih file di daftar sebelah kiri"
        return
    end
    if not UI.OnImport then return end
    impReport(0, "Memulai import...", fileBase(selectedFile))
    impBegin()
    task.spawn(UI.OnImport, selectedFile, {studioMode = getStudioMode(), serviceProps = getSvcProps()})
end
btnImport.MouseButton1Click:Connect(function() UI.RunImport() end)

btnRefresh.MouseButton1Click:Connect(refreshFiles)
tabImport.MouseButton1Click:Connect(refreshFiles)
pcall(refreshFiles)

---------------------------------------------------------------------
-- FITUR: OBSTACLE REPLACER (dari v2.1, disatukan + diperbaiki + fitur tambahan)
-- Semua perubahan terjadi di sisi client (hanya terlihat olehmu).
---------------------------------------------------------------------
local function buildReplacer()
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    local conns = {}
    table.insert(UI.Cleanups, function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end)

    local COL_OLD = Color3.fromRGB(255, 184, 28)
    local COL_NEW = Color3.fromRGB(60, 200, 110)
    local WARN = Color3.fromRGB(214, 140, 30)
    local MAX_SELECT, MAX_OUTLINE, MAX_UNDO = 3000, 60, 10
    local SIGNS = {-1, 1}

    local opt = {
        scale = 1,        -- 1 proporsional, 2 ukuran asli
        rot = 1,          -- 1 ikut objek lama, 2 rotasi asli
        hl = true,        -- outline
        scope = 1,        -- 1 seluruh map, 2 folder sama
        crit = 1,         -- 1 nama sama, 2 nama + ukuran
        tap = 1,          -- 1 otomatis (model induk), 2 part saja
        yaw = 0,          -- 0..3 (x90 derajat)
        folderCopy = 1,   -- 1 langsung, 2 salin dulu
        shift = 1,        -- 1 tidak, 2 +X, 3 +Z
        align = 1,        -- 1 tengah, 2 rata bawah, 3 rata atas
        anchor = 1,       -- 1 anchor hasil, 2 biarkan
        nameMode = 1,     -- 1 nama objek baru, 2 ikut nama lama
        scaleMul = 100,   -- persen tambahan
        offY = 0,         -- geser vertikal (stud)
    }

    local newObj, newBox = nil, nil
    local oldList, oldSet, oldBoxes = {}, {}, {}
    local undoStack = {}
    local pickMode = nil
    local oldSource = ""
    local busy = false

    ---------------------------------------------------------------
    -- KERANGKA UI: sidebar + halaman
    ---------------------------------------------------------------
    local root = replacerPage

    local side = new("Frame", {
        Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(112, 360),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0,
    }, root)
    corner(side, 14)
    stroke(side, T.Line, 1)
    new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center}, side)
    new("UIPadding", {PaddingTop = UDim.new(0, 10)}, side)

    local panel = new("Frame", {
        Position = UDim2.fromOffset(134, 10), Size = UDim2.fromOffset(612, 360),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0, ClipsDescendants = true,
    }, root)
    corner(panel, 14)
    stroke(panel, T.Line, 1)

    local tabs, pages = {}, {}
    local function setTab(name)
        for n, p in pairs(pages) do p.Visible = (n == name) end
        for n, b in pairs(tabs) do
            local on = n == name
            b.BackgroundColor3 = on and T.Accent or T.Field
            b.TextColor3 = on and T.OnAccent or T.Muted
        end
    end
    local function makePage(name)
        local p = new("ScrollingFrame", {
            Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
        }, panel)
        new("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 16),
            PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16)}, p)
        new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, p)
        pages[name] = p
        return p
    end
    local function makeTab(name, text, order)
        local b = new("TextButton", {
            LayoutOrder = order, Size = UDim2.new(1, -16, 0, 32), BackgroundColor3 = T.Field,
            Text = text, TextColor3 = T.Muted, TextSize = 10, Font = Enum.Font.GothamBold,
            AutoButtonColor = false, BorderSizePixel = 0,
        }, side)
        corner(b, 10)
        tabs[name] = b
        b.MouseButton1Click:Connect(function() setTab(name) end)
        return b
    end

    -- widget kecil
    local function sec(parent, text, order)
        return label(parent, {
            LayoutOrder = order, Size = UDim2.new(1, 0, 0, 16), Text = text,
            Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.Title,
        })
    end
    local function card(parent, order, h)
        local f = new("Frame", {LayoutOrder = order, Size = UDim2.new(1, 0, 0, h),
            BackgroundColor3 = T.Card, BorderSizePixel = 0}, parent)
        corner(f, 12)
        stroke(f, T.Line, 1)
        new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, f)
        return f
    end
    local function note(parent, order, text)
        local l = label(parent, {
            LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            Text = text, TextSize = 10, TextColor3 = T.Muted, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, Parent = parent,
        })
        return l
    end
    local function rbtn(parent, text, primary, size, pos)
        local b = button(parent, {
            Text = text, Size = size, Position = pos or UDim2.new(),
            BackgroundColor3 = primary and T.Accent or T.Field,
            TextColor3 = primary and T.OnAccent or T.Text, TextSize = 10,
        })
        corner(b, 10)
        if not primary then stroke(b, T.Line, 1) end
        return b
    end
    local function choice(parent, order, prefix, options, init, onChange)
        local i = init or 1
        local b = button(parent, {Text = "", Size = UDim2.new(1, 0, 0, 32), LayoutOrder = order,
            BackgroundColor3 = T.Card, TextSize = 10})
        corner(b, 10)
        stroke(b, T.Line, 1)
        local function paint() b.Text = prefix .. options[i] .. "  ▸" end
        b.MouseButton1Click:Connect(function()
            i = i % #options + 1
            paint()
            onChange(i)
        end)
        paint()
        return b
    end
    local function numRow(parent, order, caption, init, lo, hi, onChange)
        local current = init
        local row = new("Frame", {LayoutOrder = order, Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = T.Card, BorderSizePixel = 0}, parent)
        corner(row, 10)
        stroke(row, T.Line, 1)
        label(row, {Text = caption, TextSize = 10, Font = Enum.Font.GothamBold,
            Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0)})
        local box = new("TextBox", {
            Position = UDim2.new(1, -92, 0.5, -12), Size = UDim2.fromOffset(80, 24),
            BackgroundColor3 = T.Field, BorderSizePixel = 0, Text = tostring(init),
            TextColor3 = T.Text, TextSize = 11, Font = Enum.Font.GothamBold, ClearTextOnFocus = false,
        }, row)
        corner(box, 8)
        box.FocusLost:Connect(function()
            local v = tonumber(box.Text)
            if v then current = math.clamp(v, lo, hi) end
            box.Text = tostring(current)
            onChange(current)
        end)
    end

    ---------------------------------------------------------------
    -- TOAST
    ---------------------------------------------------------------
    local toastId = 0
    local toastLbl = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 44),
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = T.Window, TextColor3 = T.Text, TextSize = 11, Font = Enum.Font.GothamBold,
        Text = "", ZIndex = 40, BorderSizePixel = 0, TextTruncate = Enum.TextTruncate.AtEnd,
    }, root)
    corner(toastLbl, 15)
    local toastStroke = stroke(toastLbl, T.Accent, 1.5)
    new("UIPadding", {PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)}, toastLbl)
    new("UISizeConstraint", {MaxSize = Vector2.new(640, 30)}, toastLbl)
    local function toast(text, color)
        toastId += 1
        local id = toastId
        toastLbl.Text = text
        toastLbl.TextColor3 = color or T.Text
        toastStroke.Color = color or T.Accent
        TweenService:Create(toastLbl, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, 0, 1, -8)}):Play()
        task.delay(2.8, function()
            if id == toastId then
                TweenService:Create(toastLbl, TweenInfo.new(0.25), {Position = UDim2.new(0.5, 0, 1, 44)}):Play()
            end
        end)
        UI.FabNote(text, 3)
    end

    ---------------------------------------------------------------
    -- GEOMETRI (arah & kemiringan dibaca dari BENTUK objek, bukan pivot)
    ---------------------------------------------------------------
    local function allParts(obj)
        if obj:IsA("BasePart") then return {obj} end
        local t = {}
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") and not d:IsA("Terrain") then table.insert(t, d) end
        end
        return t
    end

    local function getSize(obj)
        if obj:IsA("BasePart") then return obj.Size end
        local ok, s = pcall(function() return obj:GetExtentsSize() end)
        if ok and s then return s end
        return Vector3.new(1, 1, 1)
    end

    local function domSign(v)
        local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
        local m = math.max(ax, ay, az)
        local c = (m == ax and v.X) or (m == ay and v.Y) or v.Z
        if c >= 0 then return v else return -v end
    end

    local function getFrame(obj)
        local parts = allParts(obj)
        if #parts == 0 then return nil end
        local main, bv = parts[1], -1
        for _, p in ipairs(parts) do
            local v = p.Size.X * p.Size.Y * p.Size.Z
            if v > bv then main, bv = p, v end
        end
        local cf, msz = main.CFrame, main.Size
        local ax = {{msz.X, cf.RightVector}, {msz.Y, cf.UpVector}, {msz.Z, cf.LookVector}}
        table.sort(ax, function(a, b) return a[1] > b[1] end)
        local L = domSign(ax[1][2])
        local S = ax[3][2]
        if math.abs(S.Y) > .3 then
            if S.Y < 0 then S = -S end
        else
            S = domSign(S)
        end
        local M = S:Cross(L)
        local R = CFrame.fromMatrix(Vector3.new(), L, M, S)

        local INF = math.huge
        local mn, mx = Vector3.new(INF, INF, INF), Vector3.new(-INF, -INF, -INF)
        for i, p in ipairs(parts) do
            local pcf, h = p.CFrame, p.Size * .5
            for _, sx in ipairs(SIGNS) do for _, sy in ipairs(SIGNS) do for _, sz in ipairs(SIGNS) do
                local l = R:PointToObjectSpace(pcf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
                mn = Vector3.new(math.min(mn.X, l.X), math.min(mn.Y, l.Y), math.min(mn.Z, l.Z))
                mx = Vector3.new(math.max(mx.X, l.X), math.max(mx.Y, l.Y), math.max(mx.Z, l.Z))
            end end end
            if i % 3000 == 0 then RunService.Heartbeat:Wait() end
        end
        return {rot = R, size = mx - mn, center = R:PointToWorldSpace((mn + mx) * .5)}
    end

    -- batas Y dunia (untuk rata bawah / rata atas)
    local function worldYBounds(obj)
        local lo, hi = math.huge, -math.huge
        for _, p in ipairs(allParts(obj)) do
            local pcf, h = p.CFrame, p.Size * .5
            for _, sx in ipairs(SIGNS) do for _, sy in ipairs(SIGNS) do for _, sz in ipairs(SIGNS) do
                local y = pcf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y
                if y < lo then lo = y end
                if y > hi then hi = y end
            end end end
        end
        return lo, hi
    end

    local function scaleUniform(obj, f)
        if obj:IsA("Model") then
            pcall(function() obj:ScaleTo(obj:GetScale() * f) end)
        elseif obj:IsA("BasePart") then
            obj.Size = obj.Size * f
        end
    end
    local function rotateAbout(obj, point, delta)
        local m = CFrame.new(point) * delta * CFrame.new(-point)
        if obj:IsA("Model") then obj:PivotTo(m * obj:GetPivot())
        elseif obj:IsA("BasePart") then obj.CFrame = m * obj.CFrame end
    end
    local function shiftBy(obj, v)
        if obj:IsA("Model") then obj:PivotTo(obj:GetPivot() + v)
        elseif obj:IsA("BasePart") then obj.CFrame = obj.CFrame + v end
    end

    ---------------------------------------------------------------
    -- SELEKSI & OUTLINE
    ---------------------------------------------------------------
    local function makeBox(obj, color)
        if not opt.hl then return nil end
        local ok, b = pcall(function()
            local s = Instance.new("SelectionBox")
            s.Adornee = obj
            s.Color3 = color
            s.LineThickness = .04
            s.SurfaceColor3 = color
            s.SurfaceTransparency = .82
            s.Parent = gui
            return s
        end)
        return ok and b or nil
    end

    local newName, oldCount, newHint, btnRep
    local function refreshInfo()
        newName.Text = newObj and ("📦  " .. newObj.Name) or "Belum dipilih"
        if #oldList == 0 then
            oldCount.Text = "Belum dipilih..."
            oldCount.TextColor3 = T.Muted
        else
            oldCount.Text = oldSource .. "  (" .. #oldList .. " objek)"
            oldCount.TextColor3 = T.Text
        end
        if btnRep and not busy then btnRep.Text = "REPLACE " .. #oldList .. " OBSTACLES" end
    end
    local function removeOld(obj, quiet)
        local i = table.find(oldList, obj)
        if i then table.remove(oldList, i) end
        oldSet[obj] = nil
        if oldBoxes[obj] then oldBoxes[obj]:Destroy(); oldBoxes[obj] = nil end
        if not quiet then refreshInfo() end
    end
    local function clearOld()
        for _, b in pairs(oldBoxes) do b:Destroy() end
        oldList, oldSet, oldBoxes = {}, {}, {}
        refreshInfo()
    end
    local function addOld(obj, noBox, quiet)
        if obj == newObj then toast("Itu objek baru, pilih yang lain", T.Bad) return end
        if oldSet[obj] then return end
        oldSet[obj] = true
        table.insert(oldList, obj)
        oldBoxes[obj] = (not noBox) and makeBox(obj, COL_OLD) or nil
        if not quiet then refreshInfo() end
    end
    local function setNew(obj)
        if newBox then newBox:Destroy(); newBox = nil end
        if oldSet[obj] then removeOld(obj) end
        newObj = obj
        newBox = makeBox(obj, COL_NEW)
        refreshInfo()
        toast("Objek baru: " .. obj.Name, T.Ok)
    end
    local function rebuildBoxes()
        if newBox then newBox:Destroy(); newBox = nil end
        for _, b in pairs(oldBoxes) do b:Destroy() end
        oldBoxes = {}
        if newObj and newObj.Parent then newBox = makeBox(newObj, COL_NEW) end
        if #oldList <= MAX_OUTLINE then
            for _, o in ipairs(oldList) do oldBoxes[o] = makeBox(o, COL_OLD) end
        end
    end

    local btnPick, btnAdd, btnFolder, btnName, btnBox, btnSearch, filterBox

    -- area kotak (2 tap)
    local boxFirst = nil
    local selRect = new("Frame", {Visible = false, BackgroundColor3 = COL_OLD, BackgroundTransparency = .75,
        BorderSizePixel = 0, ZIndex = 60}, gui)
    stroke(selRect, COL_OLD, 2)
    local selDot = new("Frame", {Visible = false, Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(.5, .5),
        BackgroundColor3 = COL_OLD, BorderSizePixel = 0, ZIndex = 60}, gui)
    corner(selDot, 8)
    local function boxReset()
        boxFirst = nil
        selRect.Visible = false
        selDot.Visible = false
    end

    local PICK_HINT = {
        new = "Tap objek BARU di dunia 3D",
        old = "Tap objek lama (tap lagi = batal). Tap ⚡ kalau selesai",
        folder = "Tap 1 objek di dalam folder",
        name = "Tap 1 obstacle: semua yang sama ikut terpilih. Tap ⚡ kalau selesai",
        box = "Tap 2 sudut area (jangan geser kamera). Tap ⚡ kalau selesai",
    }
    local function setPick(mode)
        pickMode = mode
        btnPick.Text = (mode == "new") and "BATAL" or "PILIH"
        btnAdd.Text = (mode == "old") and "SELESAI" or "TAMBAH"
        btnFolder.Text = (mode == "folder") and "BATAL" or "FOLDER"
        btnName.Text = (mode == "name") and "SELESAI" or "⚡ SAMA NAMA (SEKALIGUS)"
        btnBox.Text = (mode == "box") and "SELESAI" or "▭ KOTAK (2 TAP)"
        if mode ~= "box" then boxReset() end
        newHint.Text = (mode == "new") and "Tap objek baru di dunia 3D..." or "Tekan PILIH lalu tap objeknya"
    end
    -- mulai memilih: jendela diminimize supaya seluruh layar bebas untuk di-tap
    local function startPick(mode)
        if pickMode == mode then setPick(nil) return end
        setPick(mode)
        UI.Minimize()
        UI.FabNote(PICK_HINT[mode], 6)
    end
    local function endPick()
        setPick(nil)
        UI.Restore()
    end
    UI.OnRestore = function()
        if pickMode then setPick(nil) end
    end

    ---------------------------------------------------------------
    -- PILIH SEKALIGUS: nama sama / cari nama / kotak
    ---------------------------------------------------------------
    local function sizeSig(o)
        local v = getSize(o)
        local t = {v.X, v.Y, v.Z}
        table.sort(t)
        return t
    end
    local function sameSize(a, b)
        for i = 1, 3 do
            if math.abs(a[i] - b[i]) > math.max(.05, b[i] * .05) then return false end
        end
        return true
    end
    local playerChars = {}
    local function refreshChars()
        playerChars = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character then table.insert(playerChars, pl.Character) end
        end
    end
    local function inCharacter(o)
        for _, ch in ipairs(playerChars) do
            if o == ch or o:IsDescendantOf(ch) then return true end
        end
        return false
    end

    -- buang objek yang berada di dalam objek lain yang juga terpilih
    local function dedupeNested(found)
        local set = {}
        for _, d in ipairs(found) do set[d] = true end
        local clean = {}
        for _, d in ipairs(found) do
            local nested, a = false, d.Parent
            while a and a ~= workspace do
                if set[a] then nested = true break end
                a = a.Parent
            end
            if not nested then table.insert(clean, d) end
        end
        return clean
    end

    local function commitFound(found, tag)
        found = dedupeNested(found)
        if #found == 0 then
            toast("Tidak ada yang cocok", WARN)
            return
        end
        if #found > MAX_SELECT then
            toast("Terlalu banyak (" .. #found .. "). Persempit filter/area", T.Bad)
            return
        end
        local noBox = #found > MAX_OUTLINE
        oldSource = (#oldList == 0) and tag or "campuran"
        local added = 0
        for i, d in ipairs(found) do
            if not oldSet[d] then addOld(d, noBox, true); added += 1 end
            if i % 500 == 0 then RunService.Heartbeat:Wait() end
        end
        refreshInfo()
        toast(tag .. " • " .. added .. " objek ditambahkan" .. (noBox and " • outline off" or ""),
            added > 0 and T.Ok or WARN)
        UI.FabNote(tag .. " +" .. added .. " • total " .. #oldList, 4)
    end

    local function addSimilar(ref)
        refreshChars()
        local rootInst = (opt.scope == 2 and ref.Parent) or workspace
        local generic = (ref.Name == ref.ClassName) or ref.Name == "Part" or ref.Name == "Model"
        local needSize = (opt.crit == 2) or generic
        local refSig = needSize and sizeSig(ref) or nil
        local found = {}
        for i, d in ipairs(rootInst:GetDescendants()) do
            if d ~= newObj and d.Name == ref.Name and d.ClassName == ref.ClassName
                and (d:IsA("Model") or d:IsA("BasePart")) and not d:IsA("Terrain")
                and not (newObj and d:IsDescendantOf(newObj)) and not inCharacter(d)
                and (not needSize or sameSize(sizeSig(d), refSig)) then
                table.insert(found, d)
            end
            if i % 4000 == 0 then RunService.Heartbeat:Wait() end
        end
        commitFound(found, "⚡ " .. ref.Name .. (generic and " (cocok ukuran)" or ""))
    end

    local function unitOf(part)
        if opt.tap == 1 and part.Parent and part.Parent ~= workspace and part.Parent:IsA("Model") then
            return part.Parent
        end
        return part
    end

    local function searchByName()
        local q = string.lower(filterBox.Text or "")
        if q == "" then toast("Ketik nama dulu di kolom filter", T.Bad) return end
        refreshChars()
        local found = {}
        for i, d in ipairs(workspace:GetDescendants()) do
            if (d:IsA("Model") or d:IsA("BasePart")) and not d:IsA("Terrain")
                and string.find(string.lower(d.Name), q, 1, true)
                and d ~= newObj and not (newObj and d:IsDescendantOf(newObj)) and not inCharacter(d) then
                table.insert(found, d)
            end
            if i % 4000 == 0 then RunService.Heartbeat:Wait() end
        end
        commitFound(found, "🔎 " .. filterBox.Text)
    end

    local function boxSelect(p1, p2)
        local cam = workspace.CurrentCamera
        if not cam then return end
        refreshChars()
        local x0, x1 = math.min(p1.X, p2.X), math.max(p1.X, p2.X)
        local y0, y1 = math.min(p1.Y, p2.Y), math.max(p1.Y, p2.Y)
        local q = string.lower(filterBox.Text or "")
        local seen, found = {}, {}
        for i, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and not d:IsA("Terrain") then
                local v, on = cam:WorldToViewportPoint(d.Position)
                if on and v.X >= x0 and v.X <= x1 and v.Y >= y0 and v.Y <= y1 then
                    local u = unitOf(d)
                    if not seen[u] then
                        seen[u] = true
                        local sz = getSize(u)
                        if u ~= newObj and not (newObj and u:IsDescendantOf(newObj)) and not inCharacter(u)
                            and math.max(sz.X, sz.Y, sz.Z) <= 400
                            and (q == "" or string.find(string.lower(u.Name), q, 1, true)) then
                            table.insert(found, u)
                        end
                    end
                end
            end
            if i % 4000 == 0 then RunService.Heartbeat:Wait() end
        end
        commitFound(found, "▭ kotak")
    end

    local function boxTap()
        local pos = UserInputService:GetMouseLocation()
        if not boxFirst then
            boxFirst = pos
            selDot.Position = UDim2.fromOffset(pos.X, pos.Y)
            selDot.Visible = true
            UI.FabNote("▭ Sudut 1 ✔  tap sudut seberangnya", 5)
        else
            local p1 = boxFirst
            boxFirst = nil
            selDot.Visible = false
            selRect.Position = UDim2.fromOffset(math.min(p1.X, pos.X), math.min(p1.Y, pos.Y))
            selRect.Size = UDim2.fromOffset(math.abs(p1.X - pos.X), math.abs(p1.Y - pos.Y))
            selRect.Visible = true
            boxSelect(p1, pos)
            task.delay(.8, function() selRect.Visible = false end)
        end
    end

    -- salin folder (map asli tetap aman)
    local function copyContainer(src)
        local cp = src:Clone()
        if not cp then error("folder tidak bisa digandakan") end
        cp.Name = src.Name .. "_COPY"
        if opt.shift ~= 1 then
            local v = (opt.shift == 2) and Vector3.new(400, 0, 0) or Vector3.new(0, 0, 400)
            for _, ch in ipairs(cp:GetChildren()) do
                if ch:IsA("Model") or ch:IsA("BasePart") then shiftBy(ch, v) end
            end
        end
        cp.Parent = src.Parent
        return cp
    end

    -- tap di dunia 3D
    table.insert(conns, Mouse.Button1Down:Connect(function()
        if not pickMode then return end
        if UI.OverGui(UserInputService:GetMouseLocation()) then return end
        if pickMode == "box" then boxTap() return end
        local t = Mouse.Target
        if not t then toast("Tidak ada objek di situ", T.Bad) return end
        if t:IsA("Terrain") then toast("Terrain tidak bisa dipilih", T.Bad) return end
        local obj = unitOf(t)
        if pickMode == "new" then
            setNew(obj)
            endPick()
        elseif pickMode == "old" then
            if #oldList == 0 then oldSource = "✋ manual" elseif oldSource ~= "✋ manual" then oldSource = "campuran" end
            if oldSet[obj] then removeOld(obj) else addOld(obj) end
            UI.FabNote("Terpilih: " .. #oldList .. " objek", 2)
        elseif pickMode == "name" then
            addSimilar(obj)
        elseif pickMode == "folder" then
            local parent = obj.Parent
            clearOld()
            oldSource = "📂 " .. ((parent and parent ~= workspace) and parent.Name or obj.Name)
            if opt.folderCopy == 2 and parent and parent ~= workspace then
                local okc, cp = pcall(copyContainer, parent)
                if okc and cp then
                    parent = cp
                    oldSource = "📋 " .. cp.Name
                else
                    toast("Gagal menyalin folder", T.Bad)
                    return
                end
            end
            local n = 0
            if parent and parent ~= workspace then
                for _, ch in ipairs(parent:GetChildren()) do
                    if (ch:IsA("Model") or ch:IsA("BasePart")) and ch ~= newObj and not ch:IsA("Terrain") then
                        addOld(ch, #parent:GetChildren() > MAX_OUTLINE, true)
                        n += 1
                    end
                end
            else
                addOld(obj, false, true)
                n = 1
            end
            refreshInfo()
            toast(n .. " objek ditambahkan", T.Ok)
            endPick()
        end
    end))

    ---------------------------------------------------------------
    -- REPLACE / HAPUS / UNDO
    ---------------------------------------------------------------
    local function pushUndo(rec)
        if #rec == 0 then return end
        table.insert(undoStack, rec)
        if #undoStack > MAX_UNDO then table.remove(undoStack, 1) end
    end

    local function liveList()
        local list = {}
        for _, o in ipairs(oldList) do
            if o ~= newObj and o.Parent and o:IsDescendantOf(workspace) then table.insert(list, o) end
        end
        return list
    end

    local function doReplace(keep)
        if busy then return end
        if not newObj or not newObj.Parent then toast("Pilih objek baru dulu!", T.Bad) return end
        local list = liveList()
        if #list == 0 then toast("Pilih objek lama dulu!", T.Bad) return end
        busy = true
        setPick(nil)
        pcall(function() newObj.Archivable = true end)
        task.spawn(function()
            local ok, fail, rec = 0, 0, {}
            local firstErr
            for i, old in ipairs(list) do
                local c
                local success, err = pcall(function()
                    if not old.Parent or not old:IsDescendantOf(workspace) then error("objek lama sudah hilang") end
                    local parent = old.Parent
                    local fo = getFrame(old)
                    if not fo then error("objek lama tidak punya part") end
                    c = newObj:Clone()
                    if not c then error("objek baru tidak bisa digandakan") end
                    c.Parent = parent
                    local fn = getFrame(c)
                    if not fn then error("objek baru tidak punya part") end
                    if opt.scale == 1 and fn.size.X > .001 then
                        scaleUniform(c, fo.size.X / fn.size.X)
                        fn = getFrame(c)
                    end
                    if opt.scaleMul ~= 100 then
                        scaleUniform(c, opt.scaleMul / 100)
                        fn = getFrame(c)
                    end
                    if opt.rot == 1 then
                        local target = fo.rot * CFrame.Angles(0, 0, math.rad(90 * opt.yaw))
                        rotateAbout(c, fn.center, target * fn.rot:Inverse())
                        fn = getFrame(c)
                    end
                    shiftBy(c, fo.center - fn.center)
                    if opt.align ~= 1 then
                        local ol, oh = worldYBounds(old)
                        local nl, nh = worldYBounds(c)
                        shiftBy(c, Vector3.new(0, (opt.align == 2) and (ol - nl) or (oh - nh), 0))
                    end
                    if opt.offY ~= 0 then shiftBy(c, Vector3.new(0, opt.offY, 0)) end
                    if opt.nameMode == 2 then c.Name = old.Name end
                    if opt.anchor == 1 then
                        for _, p in ipairs(allParts(c)) do p.Anchored = true end
                    end
                    if keep then
                        table.insert(rec, {old = old, parent = parent, new = c})
                        old.Parent = nil
                    else
                        old:Destroy()
                    end
                end)
                if success then
                    ok += 1
                else
                    fail += 1
                    firstErr = firstErr or tostring(err)
                    warn("[CopyMap/Replacer] gagal:", err)
                    if c then pcall(function() c:Destroy() end) end
                end
                if i % 10 == 0 then
                    btnRep.Text = "MEMPROSES " .. i .. " / " .. #list
                    RunService.Heartbeat:Wait()
                end
            end
            if keep then pushUndo(rec) end
            busy = false
            clearOld()
            if fail == 0 then
                toast("Berhasil mengganti " .. ok .. " obstacle!", T.Ok)
            else
                toast(ok .. " berhasil, " .. fail .. " gagal: " .. string.sub(firstErr or "?", 1, 60), WARN)
            end
        end)
    end

    -- hapus objek terpilih (bisa di-UNDO)
    local function doRemove()
        if busy then return end
        local list = liveList()
        if #list == 0 then toast("Pilih objek yang mau dihapus dulu", T.Bad) return end
        local rec = {}
        for _, o in ipairs(list) do
            table.insert(rec, {old = o, parent = o.Parent})
            pcall(function() o.Parent = nil end)
        end
        pushUndo(rec)
        clearOld()
        toast(#rec .. " objek dihapus (bisa UNDO)", T.Ok)
    end

    local function doUndo()
        local rec = table.remove(undoStack)
        if not rec then toast("Tidak ada yang bisa di-undo", WARN) return end
        local n = 0
        for _, r in ipairs(rec) do
            pcall(function()
                if r.new and r.new.Parent then r.new:Destroy() end
                r.old.Parent = r.parent
                n += 1
            end)
        end
        toast("Undo: " .. n .. " objek dikembalikan  (sisa " .. #undoStack .. ")", T.Ok)
    end

    ---------------------------------------------------------------
    -- HALAMAN: REPLACER
    ---------------------------------------------------------------
    local PR = makePage("replacer")
    sec(PR, "1 • OBJEK BARU (pengganti)", 1)
    local cNew = card(PR, 2, 80)
    newName = label(cNew, {Size = UDim2.new(1, -100, 0, 18), Text = "Belum dipilih",
        Font = Enum.Font.GothamBold, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd})
    newHint = label(cNew, {Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -100, 0, 30),
        Text = "Tekan PILIH lalu tap objeknya", TextSize = 10, TextColor3 = T.Muted,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
    btnPick = rbtn(cNew, "PILIH", true, UDim2.fromOffset(86, 34), UDim2.new(1, -86, 0.5, -17))

    sec(PR, "2 • OBJEK LAMA (yang diganti)", 3)
    local cOld = card(PR, 4, 218)
    oldCount = label(cOld, {Size = UDim2.new(1, 0, 0, 18), Text = "Belum dipilih...",
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Muted})
    label(cOld, {Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 14),
        Text = "Outline kuning = objek lama • hijau = objek baru", TextSize = 9, TextColor3 = T.Muted})
    filterBox = new("TextBox", {
        Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Field,
        TextColor3 = T.Text, PlaceholderText = "Filter nama (contoh: tangga)", PlaceholderColor3 = T.Muted,
        Text = "", TextSize = 11, Font = Enum.Font.GothamMedium, ClearTextOnFocus = false, BorderSizePixel = 0,
    }, cOld)
    corner(filterBox, 8)
    stroke(filterBox, T.Line, 1)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, filterBox)

    local row2 = new("Frame", {Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1}, cOld)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, row2)
    btnBox = rbtn(row2, "▭ KOTAK (2 TAP)", false, UDim2.new(0.5, -3, 1, 0))
    btnSearch = rbtn(row2, "🔎 CARI NAMA", false, UDim2.new(0.5, -3, 1, 0))
    btnName = rbtn(cOld, "⚡ SAMA NAMA (SEKALIGUS)", true, UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 114))
    local row3 = new("Frame", {Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1}, cOld)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, row3)
    btnAdd = rbtn(row3, "TAMBAH", false, UDim2.new(1 / 3, -4, 1, 0))
    btnFolder = rbtn(row3, "FOLDER", false, UDim2.new(1 / 3, -4, 1, 0))
    local btnReset = rbtn(row3, "RESET", false, UDim2.new(1 / 3, -4, 1, 0))

    sec(PR, "3 • EKSEKUSI", 5)
    btnRep = rbtn(PR, "REPLACE 0 OBSTACLES", true, UDim2.new(1, 0, 0, 42))
    btnRep.LayoutOrder = 6
    btnRep.TextSize = 12
    local btnBackup = rbtn(PR, "REPLACE (KEEP BACKUP)", false, UDim2.new(1, 0, 0, 38))
    btnBackup.LayoutOrder = 7
    local rowU = new("Frame", {LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1}, PR)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, rowU)
    local btnUndo = rbtn(rowU, "↶  UNDO", false, UDim2.new(0.5, -3, 1, 0))
    local btnDelete = rbtn(rowU, "🗑  HAPUS TERPILIH", false, UDim2.new(0.5, -3, 1, 0))

    btnPick.MouseButton1Click:Connect(function() startPick("new") end)
    btnAdd.MouseButton1Click:Connect(function() startPick("old") end)
    btnFolder.MouseButton1Click:Connect(function() startPick("folder") end)
    btnName.MouseButton1Click:Connect(function() startPick("name") end)
    btnBox.MouseButton1Click:Connect(function() startPick("box") end)
    btnSearch.MouseButton1Click:Connect(function() task.spawn(searchByName) end)
    btnReset.MouseButton1Click:Connect(function()
        setPick(nil)
        clearOld()
        if newBox then newBox:Destroy(); newBox = nil end
        newObj = nil
        refreshInfo()
        toast("Pilihan direset", T.Muted)
    end)
    btnRep.MouseButton1Click:Connect(function() doReplace(false) end)
    btnBackup.MouseButton1Click:Connect(function() doReplace(true) end)
    btnUndo.MouseButton1Click:Connect(doUndo)
    btnDelete.MouseButton1Click:Connect(doRemove)

    ---------------------------------------------------------------
    -- HALAMAN: OPSI
    ---------------------------------------------------------------
    local PO = makePage("opsi")
    sec(PO, "HASIL PENGGANTIAN", 1)
    choice(PO, 2, "SKALA: ", {"PROPORSIONAL", "UKURAN ASLI"}, 1, function(i) opt.scale = i end)
    note(PO, 3, "PROPORSIONAL = objek baru disesuaikan ukurannya tanpa melar. UKURAN ASLI = ukuran objek baru tidak diubah.")
    numRow(PO, 4, "SKALA TAMBAHAN (%)", 100, 10, 500, function(v) opt.scaleMul = v end)
    choice(PO, 5, "ROTASI: ", {"IKUT OBJEK LAMA", "ROTASI ASLI"}, 1, function(i) opt.rot = i end)
    choice(PO, 6, "PUTAR: ", {"0°", "90°", "180°", "270°"}, 1, function(i) opt.yaw = i - 1 end)
    note(PO, 7, "IKUT OBJEK LAMA = arah dan kemiringan disamakan (dibaca dari bentuk objek, bukan pivot). Kalau objek baru terputar 90°, ubah PUTAR; putarannya terhadap sumbu tegak lurus permukaan.")
    choice(PO, 8, "POSISI VERTIKAL: ", {"TENGAH", "RATA BAWAH", "RATA ATAS"}, 1, function(i) opt.align = i end)
    numRow(PO, 9, "GESER NAIK/TURUN (STUD)", 0, -500, 500, function(v) opt.offY = v end)
    note(PO, 10, "RATA BAWAH = dasar objek baru disamakan dengan dasar objek lama (cocok kalau tingginya beda). Geser dipakai untuk koreksi halus.")
    choice(PO, 11, "ANCHOR HASIL: ", {"YA", "TIDAK"}, 1, function(i) opt.anchor = i end)
    choice(PO, 12, "NAMA HASIL: ", {"NAMA OBJEK BARU", "IKUT NAMA LAMA"}, 1, function(i) opt.nameMode = i end)
    sec(PO, "PILIH SEKALIGUS", 13)
    choice(PO, 14, "LINGKUP: ", {"SELURUH MAP", "FOLDER SAMA"}, 1, function(i) opt.scope = i end)
    choice(PO, 15, "KRITERIA: ", {"NAMA SAMA", "NAMA + UKURAN SAMA"}, 1, function(i) opt.crit = i end)
    note(PO, 16, "Nama umum seperti Part otomatis dicocokkan juga lewat ukuran, supaya tidak ikut mengambil semua part di map. Batas pilihan " .. MAX_SELECT .. " objek.")
    choice(PO, 17, "TAP MEMILIH: ", {"OTOMATIS", "PART SAJA"}, 1, function(i) opt.tap = i end)
    note(PO, 18, "OTOMATIS = kalau part ada di dalam Model, yang dipilih Model-nya.")
    choice(PO, 19, "OUTLINE: ", {"NYALA", "MATI"}, 1, function(i) opt.hl = (i == 1); rebuildBoxes() end)
    sec(PO, "SALINAN (MAP ASLI AMAN)", 20)
    choice(PO, 21, "FOLDER: ", {"LANGSUNG", "SALIN DULU"}, 1, function(i) opt.folderCopy = i end)
    choice(PO, 22, "GESER SALINAN: ", {"TIDAK", "+X 400 STUD", "+Z 400 STUD"}, 1, function(i) opt.shift = i end)
    note(PO, 23, "SALIN DULU = tombol FOLDER menggandakan foldernya lebih dulu, lalu yang diganti adalah salinannya.")

    ---------------------------------------------------------------
    -- HALAMAN: INFO
    ---------------------------------------------------------------
    local PI = makePage("info")
    sec(PI, "CARA PAKAI", 1)
    note(PI, 2, "1. PILIH → jendela mengecil, tap objek BARU di dunia 3D.\n2. Pilih objek LAMA: ⚡ SAMA NAMA (tap 1, semua yang sama ikut), TAMBAH (satu per satu), FOLDER (isi folder), 🔎 CARI NAMA (ketik di filter), atau ▭ KOTAK (tap 2 sudut area). Tap tombol ⚡ melayang untuk kembali.\n3. REPLACE OBSTACLES mengganti. KEEP BACKUP menyimpan objek lama sehingga bisa di-UNDO (sampai " .. MAX_UNDO .. " langkah).")
    sec(PI, "TIPS", 3)
    note(PI, 4, "• Atur SKALA, ROTASI, PUTAR, POSISI VERTIKAL di tab OPSI.\n• SALIN DULU di OPSI menjaga folder asli tetap aman.\n• 🗑 HAPUS TERPILIH juga bisa di-UNDO.\n• Tombol ⚡ melayang bisa digeser. RightCtrl membuka/menutup jendela.\n• Semua perubahan hanya terjadi di sisi client (terlihat olehmu).")

    makeTab("replacer", "REPLACER", 1)
    makeTab("opsi", "OPSI", 2)
    makeTab("info", "INFO", 3)
    setTab("replacer")
    refreshInfo()
end

---------------------------------------------------------------------
-- KIT HALAMAN (dipakai tab Info)
---------------------------------------------------------------------
local function pageKit(root)
    local kit = {}
    local ord = 0
    local function O() ord += 1 return ord end

    local panel = new("Frame", {
        Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(732, 362),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0, ClipsDescendants = true,
    }, root)
    corner(panel, 18)
    stroke(panel, T.Line, 1)

    local pg = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, panel)
    new("UIPadding", {PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16),
        PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 20)}, pg)
    new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, pg)

    kit.pg = pg

    function kit.sec(text)
        return label(pg, {
            LayoutOrder = O(), Size = UDim2.new(1, 0, 0, 18), Text = text,
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = T.Text,
        })
    end
    function kit.note(text)
        return label(pg, {
            LayoutOrder = O(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            Text = text, TextSize = 10, TextColor3 = T.Muted, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
    end
    function kit.entry(placeholder)
        local tb = new("TextBox", {
            LayoutOrder = O(), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.Field, BorderSizePixel = 0,
            Text = "", PlaceholderText = placeholder, PlaceholderColor3 = T.Muted, TextColor3 = T.Text,
            Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true,
        }, pg)
        corner(tb, 12)
        stroke(tb, T.Line, 1)
        new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, tb)
        return tb
    end
    function kit.btn(text, color, textColor)
        local b = button(pg, {
            LayoutOrder = O(), Text = text, Size = UDim2.new(1, 0, 0, 42),
            BackgroundColor3 = color or T.Accent, TextColor3 = textColor or T.OnAccent, TextSize = 12,
        })
        corner(b, 12)
        if color == T.Card then stroke(b, T.Line, 1) end
        return b
    end
    function kit.setStatus(text, color)
        if kit.status then
            kit.status.Text = text
            kit.status.TextColor3 = color or T.Muted
        end
    end
    return kit
end

---------------------------------------------------------------------
-- TAB "SCRIPTS": isi script hasil import selalu bisa dilihat, disalin, dan diekspor
---------------------------------------------------------------------
UI.buildScripts = function()
    local root = scriptsPage
    local list, cards, selected = {}, {}, nil
    local MAXCARDS, MAXVIEW = 300, 60000

    local left = new("Frame", {
        Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(270, 362),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0,
    }, root)
    corner(left, 18)
    stroke(left, T.Line, 1)
    label(left, {Text = "SCRIPT HASIL IMPORT", Font = Enum.Font.GothamBold, TextSize = 10,
        Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -90, 0, 16)})
    local lblCount = label(left, {Text = "0", TextSize = 9, TextColor3 = T.Muted,
        TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -78, 0, 10), Size = UDim2.fromOffset(64, 16)})
    local search = new("TextBox", {
        Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 30), BackgroundColor3 = T.Field,
        BorderSizePixel = 0, Text = "", PlaceholderText = "Cari nama / path script...", PlaceholderColor3 = T.Muted,
        TextColor3 = T.Text, Font = Enum.Font.GothamMedium, TextSize = 11, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true,
    }, left)
    corner(search, 10)
    stroke(search, T.Line, 1)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, search)
    local scroll = new("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 72), Size = UDim2.new(1, -16, 1, -80), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = T.AccentLn,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, left)
    new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
    new("UIPadding", {PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6)}, scroll)

    local right = new("Frame", {
        Position = UDim2.fromOffset(292, 10), Size = UDim2.fromOffset(454, 362),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0,
    }, root)
    corner(right, 18)
    stroke(right, T.Line, 1)
    local lblPath = label(right, {Text = "Pilih script di daftar kiri", Font = Enum.Font.GothamBold, TextSize = 11,
        Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd})
    local lblMeta = label(right, {Text = "Import sebuah map dulu, isi script-nya muncul di sini.", TextSize = 9,
        TextColor3 = T.Muted, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 14),
        TextTruncate = Enum.TextTruncate.AtEnd})
    local view = new("ScrollingFrame", {
        Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, 250), BackgroundColor3 = T.Field,
        BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = T.AccentLn,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ClipsDescendants = true,
    }, right)
    corner(view, 12)
    stroke(view, T.Line, 1)
    new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, view)
    local code = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        BorderSizePixel = 0, MultiLine = true, TextEditable = false, ClearTextOnFocus = false,
        Font = Enum.Font.Code, TextSize = 11, TextColor3 = T.Text, Text = "", TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, view)

    local btnCopy = button(right, {Text = "COPY ISI", Position = UDim2.fromOffset(14, 308), Size = UDim2.fromOffset(130, 38),
        BackgroundColor3 = T.Accent, TextColor3 = T.OnAccent, TextSize = 11})
    corner(btnCopy, 12)
    local btnPath = button(right, {Text = "COPY PATH", Position = UDim2.fromOffset(152, 308), Size = UDim2.fromOffset(120, 38),
        BackgroundColor3 = T.Card, TextSize = 11})
    corner(btnPath, 12)
    stroke(btnPath, T.Line, 1)
    local btnExport = button(right, {Text = "EKSPOR SEMUA .lua", Position = UDim2.fromOffset(280, 308), Size = UDim2.fromOffset(160, 38),
        BackgroundColor3 = T.Card, TextSize = 11})
    corner(btnExport, 12)
    stroke(btnExport, T.Line, 1)
    local lblStatus = label(right, {Text = "", TextSize = 9, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(14, 350), Size = UDim2.new(1, -28, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd})

    local function status(t, c) lblStatus.Text = t; lblStatus.TextColor3 = c or T.Muted end

    local function show(e)
        selected = e
        lblPath.Text = e.path
        lblMeta.Text = string.format("%s  -  %s karakter  -  ditulis via: %s", e.cls, fmt(#e.src), tostring(e.how))
        if #e.src > MAXVIEW then
            code.Text = string.sub(e.src, 1, MAXVIEW) .. "\n\n-- ... [tampilan dipotong, tombol COPY ISI menyalin seluruhnya]"
        else
            code.Text = e.src
        end
        view.CanvasPosition = Vector2.new(0, 0)
        for _, c in ipairs(cards) do
            c.stroke.Color = (c.e == e) and T.AccentLn or T.Line
        end
    end

    local function render()
        for _, c in ipairs(cards) do c.frame:Destroy() end
        cards = {}
        local q = string.lower(search.Text or "")
        local shown = 0
        for _, e in ipairs(list) do
            if q == "" or string.find(string.lower(e.path), q, 1, true) then
                shown += 1
                if shown <= MAXCARDS then
                    local card = new("TextButton", {
                        Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.Card, BorderSizePixel = 0,
                        AutoButtonColor = false, Text = "", LayoutOrder = shown,
                    }, scroll)
                    corner(card, 12)
                    local st = stroke(card, T.Line, 1)
                    local tag = (e.cls == "LocalScript" and "LOCAL") or (e.cls == "ModuleScript" and "MODULE") or "SCRIPT"
                    label(card, {Text = tag, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.AccentLn,
                        Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 12)})
                    label(card, {Text = e.name, Font = Enum.Font.GothamMedium, TextSize = 10,
                        Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 16),
                        TextTruncate = Enum.TextTruncate.AtEnd})
                    card.MouseButton1Click:Connect(function() show(e) end)
                    cards[#cards + 1] = {frame = card, stroke = st, e = e}
                end
            end
        end
        lblCount.Text = (shown > MAXCARDS) and (MAXCARDS .. "+ / " .. #list) or (shown .. " / " .. #list)
    end
    search:GetPropertyChangedSignal("Text"):Connect(render)

    local function clip(t)
        local fn = setclipboard or toclipboard
        if type(fn) ~= "function" and type(getgenv) == "function" then
            local env = getgenv()
            fn = env.setclipboard or env.toclipboard
        end
        if type(fn) ~= "function" then return false end
        return (pcall(fn, t))
    end

    btnCopy.MouseButton1Click:Connect(function()
        if not selected then status("Pilih script dulu.", T.Bad) return end
        if clip(selected.src) then status("Isi script disalin (" .. fmt(#selected.src) .. " karakter).", T.Ok)
        else status("Executor tidak punya setclipboard.", T.Bad) end
    end)
    btnPath.MouseButton1Click:Connect(function()
        if not selected then status("Pilih script dulu.", T.Bad) return end
        if clip(selected.path) then status("Path disalin.", T.Ok) else status("Executor tidak punya setclipboard.", T.Bad) end
    end)
    btnExport.MouseButton1Click:Connect(function()
        if #list == 0 then status("Belum ada script untuk diekspor.", T.Bad) return end
        if type(writefile) ~= "function" then status("Executor tidak punya writefile.", T.Bad) return end
        local dir = "MhmmdalviStudio/Scripts_" .. os.date("%Y%m%d_%H%M%S")
        if type(makefolder) == "function" then
            pcall(makefolder, "MhmmdalviStudio")
            pcall(makefolder, dir)
        end
        local n = 0
        for i, e in ipairs(list) do
            local fname = string.format("%04d_%s.lua", i, (string.gsub(e.name, "[^%w_%-]", "_")))
            if pcall(writefile, dir .. "/" .. fname, "-- " .. e.path .. "\n" .. e.src) then n += 1 end
            if i % 40 == 0 then task.wait() end
        end
        status(n .. " file ditulis ke " .. dir, n > 0 and T.Ok or T.Bad)
    end)

    UI.ScriptsChanged = function()
        list = UI.ScriptLib or {}
        selected = nil
        lblPath.Text = "Pilih script di daftar kiri"
        lblMeta.Text = (#list > 0) and (#list .. " script dari import terakhir.") or "Import sebuah map dulu, isi script-nya muncul di sini."
        code.Text = ""
        status("")
        render()
    end
    UI.ScriptsChanged()
end

---------------------------------------------------------------------
-- TAB "INFO": detail akun & perangkat orang yang memakai script (hanya tampil di layarnya sendiri)
---------------------------------------------------------------------
UI.buildInfo = function()
    local LP = Players.LocalPlayer
    local MarketplaceService = game:GetService("MarketplaceService")
    local RunService = game:GetService("RunService")
    local kit = pageKit(infoPage)

    kit.sec("Info Pengguna")
    kit.note("Detail akun dan perangkat orang yang sedang memakai script ini. Data hanya dibaca dari perangkat ini dan ditampilkan di sini; tidak dikirim ke mana pun.")

    -- kartu profil
    local card = new("Frame", {
        LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = T.Card, BorderSizePixel = 0,
    }, kit.pg)
    corner(card, 14)
    stroke(card, T.Line, 1)
    local pic = new("ImageLabel", {
        Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(72, 72),
        BackgroundColor3 = T.Field, BorderSizePixel = 0, Image = "",
    }, card)
    corner(pic, 36)
    stroke(pic, IS_OWNER and Color3.fromRGB(255, 196, 60) or T.AccentLn, 2)
    task.spawn(function()
        local okT, img = pcall(Players.GetUserThumbnailAsync, Players, LP.UserId,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        if okT and img then pic.Image = img end
    end)
    label(card, {
        Text = LP.DisplayName, Font = Enum.Font.GothamBold, TextSize = 16,
        Position = UDim2.fromOffset(98, 14), Size = UDim2.new(1, -230, 0, 22),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    label(card, {
        Text = "@" .. LP.Name, TextSize = 11, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(98, 38), Size = UDim2.new(1, -230, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local role = new("Frame", {
        Position = UDim2.fromOffset(98, 62), Size = UDim2.fromOffset(IS_OWNER and 86 or 70, 20),
        BackgroundColor3 = IS_OWNER and Color3.fromRGB(255, 196, 60) or T.NavOn, BorderSizePixel = 0,
    }, card)
    corner(role, 10)
    label(role, {
        Text = IS_OWNER and "👑 OWNER" or "PENGGUNA", Font = Enum.Font.GothamBlack, TextSize = 10,
        TextColor3 = IS_OWNER and Color3.fromRGB(40, 26, 0) or T.Text,
        TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
    })

    -- daftar detail
    local rows = {}
    local order = 101
    local function section(title)
        order += 1
        label(kit.pg, {
            LayoutOrder = order, Size = UDim2.new(1, 0, 0, 18), Text = title,
            Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.Title,
        })
    end
    local function row(key, getter)
        order += 1
        local r = new("Frame", {
            LayoutOrder = order, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Card, BorderSizePixel = 0,
        }, kit.pg)
        corner(r, 10)
        label(r, {Text = key, TextSize = 10, TextColor3 = T.Muted,
            Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.38, 0, 1, 0)})
        local v = label(r, {Text = "-", Font = Enum.Font.GothamMedium, TextSize = 11,
            Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -14, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd})
        rows[#rows + 1] = function()
            local okG, val = pcall(getter)
            v.Text = (okG and val ~= nil and tostring(val) ~= "") and tostring(val) or "-"
        end
    end

    local function deviceType()
        local U = UserInputService
        if U.VREnabled then return "VR" end
        if U.GamepadEnabled and not U.KeyboardEnabled and not U.TouchEnabled then return "Konsol / Gamepad" end
        if U.TouchEnabled and not U.KeyboardEnabled then
            local cam = workspace.CurrentCamera
            local sz = cam and cam.ViewportSize or Vector2.new(0, 0)
            return (math.min(sz.X, sz.Y) >= 600) and "Tablet" or "HP (Mobile)"
        end
        return "PC / Laptop"
    end
    local function platformName()
        local okP, p = pcall(function() return UserInputService:GetPlatform() end)
        if okP and p then return (tostring(p):gsub("^Enum%.Platform%.", "")) end
        return "-"
    end
    local function executorName()
        if type(identifyexecutor) == "function" then
            local n, ver = identifyexecutor()
            return tostring(n) .. (ver and (" " .. tostring(ver)) or "")
        end
        return "Tidak terdeteksi"
    end
    local function memberLabel()
        local m = LP.MembershipType
        return (m == Enum.MembershipType.None) and "Standar" or (tostring(m):gsub("^Enum%.MembershipType%.", ""))
    end

    section("AKUN")
    row("Display name", function() return LP.DisplayName end)
    row("Username", function() return LP.Name end)
    row("User ID", function() return LP.UserId end)
    row("Umur akun", function() return LP.AccountAge .. " hari" end)
    row("Membership", memberLabel)
    row("Status script", function() return IS_OWNER and "OWNER" or "Pengguna" end)

    section("PERANGKAT")
    row("Tipe perangkat", deviceType)
    row("Platform", platformName)
    row("Layar", function()
        local sz = workspace.CurrentCamera.ViewportSize
        return math.floor(sz.X) .. " x " .. math.floor(sz.Y) .. " px"
    end)
    row("Input", function()
        local U, t = UserInputService, {}
        if U.TouchEnabled then t[#t + 1] = "Sentuh" end
        if U.KeyboardEnabled then t[#t + 1] = "Keyboard" end
        if U.MouseEnabled then t[#t + 1] = "Mouse" end
        if U.GamepadEnabled then t[#t + 1] = "Gamepad" end
        return table.concat(t, ", ")
    end)
    row("Executor", executorName)
    row("Bahasa Roblox", function() return LP.LocaleId end)

    section("GAME")
    row("Nama game", function()
        return MarketplaceService:GetProductInfo(game.PlaceId).Name
    end)
    row("Place ID", function() return game.PlaceId end)
    row("Server (JobId)", function() return game.JobId ~= "" and game.JobId or "Studio / lokal" end)
    row("Pemain di server", function() return #Players:GetPlayers() .. " / " .. Players.MaxPlayers end)
    row("Ping", function() return math.floor(LP:GetNetworkPing() * 2000) .. " ms" end)
    row("FPS", function() return UI._fps or "-" end)

    local acc, frames = 0, 0
    local conn = RunService.RenderStepped:Connect(function(dt)
        acc += dt
        frames += 1
        if acc >= 1 then
            UI._fps = math.floor(frames / acc + 0.5)
            acc, frames = 0, 0
        end
    end)
    UI.Cleanups[#UI.Cleanups + 1] = function() conn:Disconnect() end

    local function refresh() for _, f in ipairs(rows) do f() end end
    refresh()
    task.spawn(function()
        while gui.Parent do
            task.wait(1)
            if infoPage.Visible then refresh() end
        end
    end)
end

UI.ShowFeatureError = function(page, title, err)
    local box = new("Frame", {
        Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(732, 120),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0,
    }, page)
    corner(box, 18)
    stroke(box, T.Bad, 1.2)
    label(box, {Text = title .. " gagal dimuat", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Bad,
        Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 18)})
    label(box, {Text = tostring(err), TextSize = 10, TextColor3 = T.Muted, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -36, 0, 70)})
    pcall(warn, "[MhmmdalviStudio] " .. title .. ": " .. tostring(err))
end

for _, spec in ipairs({
    {"Replacer", buildReplacer, replacerPage},
    {"Scripts", UI.buildScripts, scriptsPage},
    {"Info", UI.buildInfo, infoPage},
}) do
    local okB, errB = pcall(spec[2])
    if not okB then UI.ShowFeatureError(spec[3], spec[1], errB) end
end

task.spawn(scan)

UI.Gui = gui
openWindow()
return UI
