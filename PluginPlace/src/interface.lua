local Interface = {}

function Interface.Create(plugin, Title)
    local Info = DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Float,
        false, -- Enabled initially
        false, -- Override
        300, 400, -- Size
        200, 300 -- Min Size
    )
    
    local Widget = plugin:CreateDockWidgetPluginGui("G2L_Main", Info)
    Widget.Title = Title
    
    local Gui = Instance.new("ScreenGui")
    Gui.Parent = Widget
    
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.fromScale(1, 1)
    Frame.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
    Frame.Parent = Gui
    
    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 10)
    ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = Frame
    
    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 20)
    Padding.Parent = Frame
    
    -- Helper to make buttons/toggles
    local function CreateToggle(Text, Default, Order)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(0.9, 0, 0, 40)
        Container.BackgroundColor3 = Color3.fromRGB(50, 54, 62)
        Container.LayoutOrder = Order
        Container.Parent = Frame
        Instance.new("UICorner", Container).CornerRadius = UDim.new(0, 6)
        
        local Label = Instance.new("TextLabel")
        Label.Text = Text
        Label.Size = UDim2.new(0.7, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Color3.new(1,1,1)
        Label.Font = Enum.Font.GothamBold
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Position = UDim2.new(0, 10, 0, 0)
        Label.Parent = Container
        
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(0, 24, 0, 24)
        Button.AnchorPoint = Vector2.new(1, 0.5)
        Button.Position = UDim2.new(1, -10, 0.5, 0)
        Button.BackgroundColor3 = Default and Color3.fromRGB(114, 137, 218) or Color3.fromRGB(30, 30, 30)
        Button.Text = ""
        Button.Parent = Container
        Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 4)
        
        local Value = Instance.new("BoolValue")
        Value.Value = Default
        Value.Name = "ConfigValue"
        Value.Parent = Container
        
        Button.MouseButton1Click:Connect(function()
            Value.Value = not Value.Value
            Button.BackgroundColor3 = Value.Value and Color3.fromRGB(114, 137, 218) or Color3.fromRGB(30, 30, 30)
        end)
        
        return Value
    end
    
    local function CreateButton(Text, Color, Order)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0.9, 0, 0, 50)
        Btn.BackgroundColor3 = Color
        Btn.Text = Text
        Btn.TextColor3 = Color3.new(1,1,1)
        Btn.Font = Enum.Font.GothamBlack
        Btn.TextSize = 18
        Btn.LayoutOrder = Order
        Btn.Parent = Frame
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
        return Btn
    end

    return {
        Widget = Widget,
        Toggles = {
            Comments = CreateToggle("Include Comments", true, 1),
            Logo = CreateToggle("Include ASCII Logo", true, 2),
            Minify = CreateToggle("Minify Output", false, 3),
        },
        ConvertBtn = CreateButton("CONVERT", Color3.fromRGB(67, 181, 129), 10)
    }
end

return Interface
