-- FLOW: Convert -> Buffer -> Join -> Return
-- Optimized for speed using table buffers instead of string concatenation.

--// REQUIRES \\--
local RbxApi = require(script.Parent.rbxapi)
local Utils = require(script.Parent.utils)
local RequireProxy = script.Parent.assets.require
local Logo = script.Parent.assets.logo.Value
local CollectionService = game:GetService("CollectionService")

--// CONFIG \\--
local BLACKLIST = {
    Source = true,
    Parent = true,
    ImageContent = true,
    Capabilities = true, -- New internal property that breaks shit
    DefinesCapabilities = true
}

--// TYPES \\--
type Settings = {
    RegName: string,
    Comments: boolean,
    Logo: boolean,
    Minify: boolean
}

type ConvertionRes = {
    Gui: ScreenGui,
    Settings: Settings,
    Buffer: {string}, -- The string buffer
    _INST: {[number]: any},
    _LUA: {any},
    _MOD: {any},
    HasTags: boolean,
    NumTags: number
}

--// HELPERS \\--
local function PrettifyNumber(n: number): any
    if n == 0 then return "0" end -- Save bytes
    local s = string.format("%.4f", n)
    return (s:gsub("%.?0+$", "")) -- Strip trailing zeros
end

local function EncapsulateString(Str: string)
    -- Handle complex nesting for long strings
    local Level = ""
    while true do
        if Str:find("]" .. Level .. "]") then
            Level = Level .. "="
        else
            break
        end
    end
    return "[" .. Level .. "[" .. Str .. "]" .. Level .. "]"
end

--// TRANSPILER \\--
local function TranspileValue(Raw: any): string
    local Type = typeof(Raw)
    
    if Type == 'string' then return EncapsulateString(Raw)
    elseif Type == 'boolean' then return tostring(Raw)
    elseif Type == 'number' then return PrettifyNumber(Raw)
    elseif Type == 'EnumItem' then return tostring(Raw)
    
    elseif Type == 'Vector2' then return string.format("Vector2.new(%s, %s)", PrettifyNumber(Raw.X), PrettifyNumber(Raw.Y))
    elseif Type == 'Vector3' then return string.format("Vector3.new(%s, %s, %s)", PrettifyNumber(Raw.X), PrettifyNumber(Raw.Y), PrettifyNumber(Raw.Z))
    elseif Type == 'UDim2' then return string.format("UDim2.new(%s, %s, %s, %s)", PrettifyNumber(Raw.X.Scale), PrettifyNumber(Raw.X.Offset), PrettifyNumber(Raw.Y.Scale), PrettifyNumber(Raw.Y.Offset))
    elseif Type == 'UDim' then return string.format("UDim.new(%s, %s)", PrettifyNumber(Raw.Scale), PrettifyNumber(Raw.Offset))
    elseif Type == 'Rect' then return string.format("Rect.new(%s, %s, %s, %s)", PrettifyNumber(Raw.Min.X), PrettifyNumber(Raw.Min.Y), PrettifyNumber(Raw.Max.X), PrettifyNumber(Raw.Max.Y))
    elseif Type == 'Color3' then 
        local R, G, B = math.round(Raw.R*255), math.round(Raw.G*255), math.round(Raw.B*255)
        return string.format("Color3.fromRGB(%d, %d, %d)", R, G, B)
    elseif Type == 'Font' then
        return string.format("Font.new(%s, %s, %s)", EncapsulateString(Raw.Family), tostring(Raw.Weight), tostring(Raw.Style))
    end
    
    -- Fallback for complex types usually just works with tostring or specialized parsers if you add them later
    return "nil --[[Unsupported Type: " .. Type .. "]]"
end

local function TranspileProperties(Res: ConvertionRes, Inst: any)
    local PropsBuffer = {}
    local Members = RbxApi.GetProperties(Inst.Instance.ClassName)
    
    for Member, Default in pairs(Members) do
        if BLACKLIST[Member] then continue end
        
        local Success, CurrentValue = pcall(function() return Inst.Instance[Member] end)
        if not Success then continue end -- Security permissions or deprecated shit
        
        -- Check if default
        if CurrentValue == Default.Value then continue end
        
        local ValStr = TranspileValue(CurrentValue)
        if ValStr and ValStr ~= "nil" then
            table.insert(PropsBuffer, string.format('%s["%s"]["%s"] = %s;', Res.Settings.RegName, Inst.Id, Member, ValStr))
        end
    end
    
    return table.concat(PropsBuffer, "\n")
end

--// PIPELINE \\--

local function LoadDescendants(Res: ConvertionRes, Inst: Instance, Parent: any)
    local Size = #Res._INST + 1
    local RegInst = {
        Parent = Parent,
        Instance = Inst,
        Id = string.format("%x", Size) -- Hex ID
    }
    Res._INST[Size] = RegInst
    
    if Inst:IsA("LocalScript") then table.insert(Res._LUA, RegInst)
    elseif Inst:IsA("ModuleScript") then table.insert(Res._MOD, RegInst)
    end
    
    for _, Child in pairs(Inst:GetChildren()) do
        LoadDescendants(Res, Child, RegInst)
    end
end

local function WriteInstances(Res: ConvertionRes)
    local B = Res.Buffer
    local Reg = Res.Settings.RegName
    
    for _, Inst in ipairs(Res._INST) do
        if Res.Settings.Comments and not Res.Settings.Minify then
            table.insert(B, string.format("\n-- %s", Inst.Instance.Name))
        end
        
        local ParentStr
        if Inst.Parent == nil then
            ParentStr = 'game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")'
        else
            ParentStr = string.format('%s["%s"]', Reg, Inst.Parent.Id)
        end
        
        local Props = TranspileProperties(Res, Inst)
        
        -- Instance creation
        table.insert(B, string.format('\n%s["%s"] = Instance.new("%s");', Reg, Inst.Id, Inst.Instance.ClassName))
        table.insert(B, string.format('\n%s["%s"].Parent = %s;', Reg, Inst.Id, ParentStr))
        if Props ~= "" then
            table.insert(B, "\n" .. Props)
        end
    end
end

local function WriteScripts(Res: ConvertionRes)
    local B = Res.Buffer
    local Reg = Res.Settings.RegName
    
    -- Modules
    if #Res._MOD > 0 then
        table.insert(B, "\n\n" .. RequireProxy.Source)
        for _, Mod in ipairs(Res._MOD) do
            local Source = Mod.Instance.Source
            table.insert(B, string.format('\nG2L_MODULES[%s["%s"]] = { Closure = function() local script = %s["%s"]; %s end };', 
                Reg, Mod.Id, Reg, Mod.Id, Source))
        end
    end
    
    -- LocalScripts
    for _, Script in ipairs(Res._LUA) do
        if Script.Instance.Disabled then continue end
        local FuncName = "C_" .. Script.Id
        local Source = Script.Instance.Source
        
        table.insert(B, string.format('\nlocal function %s()\nlocal script = %s["%s"];\n%s\nend; task.spawn(%s);', 
            FuncName, Reg, Script.Id, Source, FuncName))
    end
end

--// EXPORT \\--

local function Convert(Gui: ScreenGui, Settings: Settings)
    local Res: ConvertionRes = {
        Gui = Gui,
        Settings = Settings,
        Buffer = {},
        _INST = {},
        _LUA = {},
        _MOD = {},
        HasTags = false,
        NumTags = 0
    }
    
    -- Header
    if Settings.Logo and not Settings.Minify then
        table.insert(Res.Buffer, Logo .. "\n")
    end
    
    table.insert(Res.Buffer, string.format("local %s = {};", Settings.RegName))
    
    -- Process
    LoadDescendants(Res, Gui, nil)
    WriteInstances(Res)
    WriteScripts(Res)
    
    -- Footer
    table.insert(Res.Buffer, string.format('\nreturn %s["%s"], require;', Settings.RegName, Res._INST[1].Id))
    
    return {
        Gui = Res.Gui,
        Source = table.concat(Res.Buffer, "")
    }
end

return { Convert = Convert }
