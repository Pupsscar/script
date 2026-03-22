local _0x5f2a = {game, os, math, table, task}
local _0x1a = _0x5f2a[1]:GetService("\67\111\114\101\71\117\105")
local _0x2b = _0x5f2a[1]:GetService("\80\108\97\121\101\114\115")
local _0x3c = _0x5f2a[1]:GetService("\82\117\110\83\101\114\118\105\99\101")

local _0x_key_vault = function(q, w, e) 
    local r = (q * w) + e
    return r 
end

local _0x_date_val = 1742850000 -- 25.03.2026
local _0x_panic = function() 
    local _ = _0x2b.LocalPlayer 
    if _ then _:Kick("\65\85\84\72\95\69\82\82") end
    _0x5f2a[5].wait(0.1)
    while true do _0x5f2a[3].random() end
end

if not _0x_date_val or (_0x5f2a[2].time() > _0x_date_val) then _0x_panic() end

local _0x_gate = function(_in_val)
    local _base = _0x_key_vault(0x2, 0x96, 0x2C) -- 344
    if _in_val ~= _base then return false end
    return true
end

local function _0x_init_vm()
    local _0x_proxy = setmetatable({}, {
        __index = function(t, k)
            return function(...) return _0x5f2a[1]:GetService(k) end
        end
    })

    local _0x_cache = {
        ["\105"] = "\66\101\114\101\116\116\97",
        ["\115"] = "\67\111\114\114\101\110\116\83\116\111\99\107\115",
        ["\104"] = "\72\117\109\97\110\111\105\100\82\111\111\116\80\97\114\116"
    }

    local _0x_scr = Instance.new("\83\99\114\101\101\110\71\117\105", _0x1a)
    _0x_scr.Name = "\88\90\95\76\79\65\68"

    local _0x_root = Instance.new("\70\114\97\109\101", _0x_scr)
    _0x_root.Size = UDim2.new(0, 260, 0, 100)
    _0x_root.Position = UDim2.new(0.5, -130, 0, 50)
    _0x_root.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    _0x_root.Active, _0x_root.Draggable = true, true

    local _0x_box = Instance.new("\84\101\120\116\66\111\120", _0x_root)
    _0x_box.Size = UDim2.new(0.9, 0, 0.4, 0)
    _0x_box.Position = UDim2.new(0.05, 0, 0.1, 0)
    _0x_box.Text = _0x_cache["\105"]
    _0x_box.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    _0x_box.TextColor3 = Color3.new(1,1,1)

    local _0x_status = Instance.new("\84\101\120\116\76\97\98\101\108", _0x_root)
    _0x_status.Size = UDim2.new(1, 0, 0.5, 0)
    _0x_status.Position = UDim2.new(0, 0, 0.5, 0)
    _0x_status.BackgroundTransparency = 1
    _0x_status.TextColor3 = Color3.fromRGB(0, 255, 120)

    local _0x_esp = Drawing.new("\76\105\110\101")
    _0x_esp.Thickness = 2
    _0x_esp.Color = Color3.new(1, 0.9, 0)

    local _0x_runtime = function()
        local _v_cam = workspace.CurrentCamera
        local _v_shop = workspace:WaitForChild("\77\97\112"):WaitForChild("\83\104\111\112\122")
        local _v_chr = _0x2b.LocalPlayer.Character
        local _v_pos = (_v_chr and _v_chr:FindFirstChild(_0x_cache["\104"])) and _v_chr[_0x_cache["\104"]].Position or Vector3.new(0,0,0)
        
        local _total, _dist, _target = 0, math.huge, nil

        for _, _d in pairs(_v_shop:GetChildren()) do
            local _st = _d:FindFirstChild(_0x_cache["\115"])
            if _st then
                local _it = _st:FindFirstChild(_0x_box.Text)
                if _it and (_it.Value > 0) then
                    _total = _total + _it.Value
                    local _r = _d:FindFirstChild(_0x_cache["\104"]) or _d:FindFirstChildWhichIsA("\66\97\115\101\80\97\114\116")
                    if _r then
                        local _m = (_r.Position - _v_pos).Magnitude
                        if _m < _dist then _dist = _m; _target = _r end
                    end
                end
            end
        end

        if _target then
            local _p, _on = _v_cam:WorldToViewportPoint(_target.Position)
            _0x_esp.From = Vector2.new(_v_cam.ViewportSize.X/2, _v_cam.ViewportSize.Y)
            _0x_esp.To = Vector2.new(_p.X, _p.Y)
            _0x_esp.Visible = _on
        else _0x_esp.Visible = false end
        _0x_status.Text = _total > 0 and (_total .. " \73\78\32\83\84\79\67\75") or "\78\79\78\69"
    end

    _0x_box.FocusLost:Connect(function() _0x_cache["\105"] = _0x_box.Text end)
    _0x3c.RenderStepped:Connect(_0x_runtime)
end

local _0x_auth_gui = Instance.new("\83\99\114\101\101\110\71\117\105", _0x1a)
local _0x_auth_f = Instance.new("\84\101\120\116\66\111\120", _0x_auth_gui)
_0x_auth_f.Size = UDim2.new(0, 150, 0, 50)
_0x_auth_f.Position = UDim2.new(0.5, -75, 0.4, 0)
_0x_auth_f.PlaceholderText = "\80\87\68"

_0x_auth_f.FocusLost:Connect(function(_ent)
    if _ent then
        local _input = tonumber(_0x_auth_f.Text)
        if _input and _0x_gate(_input) then
            _0x_auth_gui:Destroy()
            _0x_init_vm()
        else
            _0x_panic()
        end
    end
end)
