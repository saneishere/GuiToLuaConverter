--// SERVICES \\--
local Selection = game:GetService('Selection')

--// REQUIRES \\--
local Utils = require(script.Parent:WaitForChild("utils"))
local G2L = require(script.Parent:WaitForChild("core"))
local Alerts = require(script.Parent:WaitForChild('alerts'))
local Interface = require(script.Parent:WaitForChild('interface'))

--// SETUP \\--
local TITLE = 'GuiToLua'
local Toolbar = plugin:CreateToolbar(TITLE)
local ToggleBtn = Toolbar:CreateButton("Open", "Open Converter", "rbxassetid://10139235293")

-- Initialize UI
local UI = Interface.Create(plugin, TITLE)

--// LOGIC \\--
local function OnConvert()
    if not Utils.HasWriteAccess() then
        Alerts.Error(game:GetService("CoreGui"), TITLE, "Please allow script injection in Plugin Settings.")
        return
    end

    local Selected = Selection:Get()[1]
    if not Selected or not Selected:IsA("ScreenGui") then
        Alerts.Warn(game:GetService("CoreGui"), TITLE, "Please select a ScreenGui first.")
        return
    end
    
    -- Gather Settings
    local Settings = {
        RegName = "G2L",
        Comments = UI.Toggles.Comments.Value,
        Logo = UI.Toggles.Logo.Value,
        Minify = UI.Toggles.Minify.Value
    }
    
    UI.ConvertBtn.Text = "CONVERTING..."
    task.wait() -- Allow UI update
    
    local Res = G2L.Convert(Selected, Settings)
    local Out = Utils.WriteConvertionRes(Res)
    
    Selection:Set({Out})
    plugin:OpenScript(Out)
    
    UI.ConvertBtn.Text = "CONVERT"
    Alerts.Success(game:GetService("CoreGui"), TITLE, "Done! Script generated in StarterPack.")
end

--// BINDINGS \\--
UI.ConvertBtn.MouseButton1Click:Connect(OnConvert)

ToggleBtn.Click:Connect(function()
    UI.Widget.Enabled = not UI.Widget.Enabled
end)
