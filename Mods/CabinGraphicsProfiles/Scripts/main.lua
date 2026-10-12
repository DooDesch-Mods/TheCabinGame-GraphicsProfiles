local directory = assert(debug.getinfo(1,"S").source:match("^@(.+[/\\])"))
package.path = directory .. "?.lua;" .. package.path
local runtime = require("cabin_runtime")
local mod = runtime.start(directory,require("definition"))
local profiles,storage = require("profiles"),require("cabin_store")
local keys = {"gi","shadows","reflections","effects"}
local fields = {{key="available",label="Previous profile",type="boolean",default=false}}
for _,key in ipairs(keys) do
    fields[#fields+1]={key=key,label=key,type="number",integer=true,min=0,max=4,default=0}
    fields[#fields+1]={key=key.."_saved",label=key.." saved",type="number",integer=true,default=0}
end
local previous = storage.new(directory .. "previous_graphics.dat",fields,function(level,cause) mod:log(level,cause) end)
local function engine()
    local object = StaticFindObject("/Script/Engine.Default__GameUserSettings"):GetGameUserSettings()
    assert(runtime.valid(object),"GameUserSettings unavailable")
    return object
end
local function game()
    local pc
    for _,menu in ipairs(FindAllOf("Menu_WBP_C") or {}) do
        if runtime.valid(menu) and menu:IsInViewport() then
            assert(not pc,"visible graphics menu ambiguous")
            pc=menu:GetOwningPlayer()
        end
    end
    if not pc then
        for _,candidate in ipairs(FindAllOf("Cabin_PC_C") or {}) do
            if runtime.valid(candidate) and candidate:IsLocalController() then
                assert(not pc,"local graphics controller ambiguous");pc=candidate
            end
        end
    end
    assert(runtime.valid(pc) and pc:IsLocalController(),"local graphics controller unavailable")
    local slotOut,objectOut = {},{}
    local library = StaticFindObject("/Game/CabinGameContent/Cabin_Functions.Default__Cabin_Functions_C")
    assert(runtime.valid(library),"original settings library unavailable")
    library:GetSettingsSaveData(pc,slotOut,objectOut)
    local save = objectOut.SettingsSaveObject
    assert(runtime.valid(save) and save.SavedGraphics,"original settings SaveGame unavailable")
    return save
end
local function readMap(map,key)
    assert(map:Contains(key),"original graphics key absent: " .. key)
    local value = map:Find(key):get()
    assert(math.type(value)=="integer","original graphics index invalid: " .. key)
    return value
end
local function graphicsKey(value,label)
    local kind=type(value)
    assert(kind=="string" or kind=="userdata",label .. " type invalid; observed=" .. kind .. "; required=string/FString")
    local key=kind=="string" and value or value:ToString()
    assert(type(key)=="string",label .. " conversion invalid; observed=" .. type(key) .. "; source=" .. kind)
    return key
end
local adapter = {}
function adapter:read()
    local settings,save = engine(),game()
    local result = {}
    for index,group in ipairs(profiles.groups) do
        result[keys[index]] = settings[group.getter](settings)
        result[keys[index].."_saved"] = readMap(save.SavedGraphics,group.key)
    end
    return result
end
function adapter:write(target)
    local settings,save = engine(),game()
    local graphics = save.SavedGraphics
    local unchanged = {}
    graphics:ForEach(function(key,value) unchanged[graphicsKey(key:get(),"original graphics map key")]=value:get() end)
    for index,group in ipairs(profiles.groups) do
        local quality = assert(target[keys[index]])
        settings[group.setter](settings,quality)
        graphics:Add(group.key,target[keys[index].."_saved"] or profiles.savedIndex(group,quality))
        unchanged[group.key] = nil
    end
    settings:ApplyNonResolutionSettings()
    settings:SaveSettings()
    local gameplay = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    assert(gameplay:SaveGameToSlot(save,"SettingsData",0),"original graphics SaveGameToSlot failed")
    local disk = gameplay:LoadGameFromSlot("SettingsData",0)
    assert(runtime.valid(disk),"graphics SaveGame readback unavailable")
    for index,group in ipairs(profiles.groups) do
        assert(settings[group.getter](settings)==target[keys[index]],"engine graphics readback differs: " .. group.key)
        assert(readMap(disk.SavedGraphics,group.key)==readMap(graphics,group.key),"saved graphics readback differs: " .. group.key)
    end
    for key,value in pairs(unchanged) do assert(readMap(disk.SavedGraphics,key)==value,"unrelated graphics option changed: " .. key) end
    mod:log("info","four engine groups and original SaveGame read back; restart acceptance pending")
end
function mod:apply(values,action)
    assert(action=="" or action=="restore","invalid graphics action")
    values = storage.validate(self.definition.fields,values)
    local selected = action=="restore" and "restore" or values.profile
    if selected=="current" then return self.store:save(values) end
    local before = require("transaction").apply(adapter,previous,selected)
    if selected=="restore" then values.profile="current" end
    local ok,result,revision = pcall(self.store.save,self.store,values)
    if not ok then
        local restored,cause = pcall(adapter.write,adapter,before)
        error("graphics mod settings save failed: " .. tostring(result) .. (restored and "; graphics restored" or "; graphics rollback failed: " .. tostring(cause)))
    end
    return result,revision
end
local SLOT = "/Game/MenuContent/Settings/WBP_OptionsSlot_SideArrow.WBP_OptionsSlot_SideArrow_C:SetOptionType_E"
mod:bind(SLOT,function(context)
    local widget = context:get()
    if not runtime.valid(widget) or not runtime.valid(widget.Master) then return end
    local title=graphicsKey(widget.Title,"original graphics option Title")
    for _,group in ipairs(profiles.groups) do
        if title==group.key and widget.CurrentOption<0 and group.offset then
            local quality = widget.CurrentOption+group.offset
            assert(quality==0 or quality==1,"graphics menu quality index invalid")
            widget.OptionType_T:SetText(FText(quality==0 and "Low" or "Medium"))
            widget.LeftArrow_B:SetIsEnabled(quality>0)
            widget.RightArrow_B:SetIsEnabled(true)
        end
    end
end)
return mod
