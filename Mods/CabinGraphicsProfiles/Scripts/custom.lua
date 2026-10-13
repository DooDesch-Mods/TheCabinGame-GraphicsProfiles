local storage = require("cabin_store")
local codec = require("cabin_codec")
local profiles = require("profiles")
local M = {}

M.qualities = {
    {id="gi",key="GI Quality",getter="GetGlobalIlluminationQuality",setter="SetGlobalIlluminationQuality",mapping="triangular"},
    {id="shading",key="Shading Quality",getter="GetShadingQuality",setter="SetShadingQuality",offset=1},
    {id="foliage",key="Foliage Quality",getter="GetFoliageQuality",setter="SetFoliageQuality",offset=1},
    {id="aa",key="Anti-Aliasing",getter="GetAntiAliasingQuality",setter="SetAntiAliasingQuality",offset=1},
    {id="textures",key="Texture Detail",getter="GetTextureQuality",setter="SetTextureQuality",offset=1},
    {id="shadows",key="Shadow Detail",getter="GetShadowQuality",setter="SetShadowQuality",offset=2},
    {id="reflections",key="Reflection Detail",getter="GetReflectionQuality",setter="SetReflectionQuality",offset=1},
    {id="effects",key="Effects Detail",getter="GetVisualEffectQuality",setter="SetVisualEffectQuality",offset=1},
    {id="postprocess",getter="GetPostProcessingQuality",setter="SetPostProcessingQuality",label="Postprocessing"},
    {id="distance",getter="GetViewDistanceQuality",setter="SetViewDistanceQuality",label="View distance"},
}
M.extras = {
    {id="depth",label="Depth of field",cvar="r.DepthOfFieldQuality",min=0,max=4,default=2},
    {id="flare",label="Lens flare",cvar="r.LensFlareQuality",min=0,max=3,default=2},
    {id="fringe",label="Chromatic aberration",cvar="r.SceneColorFringeQuality",min=0,max=1,default=1},
    {id="bloom",label="Bloom",cvar="r.BloomQuality",min=0,max=5,default=5},
    {id="sharpen",label="Sharpen",cvar="r.Tonemapper.Sharpen",min=-1,max=2,default=-1,options={{value=-1,label="Game default"},{value=0,label="Off"},{value=0.25,label="0.25"},{value=0.5,label="0.5"},{value=0.75,label="0.75"},{value=1,label="1"},{value=1.5,label="1.5"},{value=2,label="2"}}},
    {id="fog",label="Fog",cvar="r.Fog",min=0,max=1,default=1},
    {id="volumetric",label="Volumetric fog",cvar="r.VolumetricFog",min=0,max=1,default=1},
}
M.resolutions = {{1280,720},{1280,1024},{1366,768},{1440,900},{1536,864},{1600,900},{1920,1080},{2560,1440},{3440,1440}}
local function choice(id,label,default,options)
    return {key=id,label=label,type="choice",default=default,options=options}
end
local function indexed(labels,start)
    local result={}
    for i,label in ipairs(labels) do result[i]={value=i-1+(start or 0),label=label} end
    return result
end
function M.definition()
    local fields={}
    for _,spec in ipairs(M.qualities) do
        local options=indexed({"Low","Medium","High","Epic","Maximum"})
        if spec.id=="gi" then options={{value=0,label="Low"},{value=1,label="Medium"},{value=3,label="High"},{value=4,label="Maximum"}} end
        fields[#fields+1]=choice(spec.id,spec.label or spec.key,spec.id=="gi" and 1 or 2,options)
    end
    fields[#fields+1]=choice("particles","Particle Detail",1,indexed({"Low","Medium","High","Maximum"}))
    fields[#fields+1]={key="motion",label="Motion blur",type="boolean",default=true}
    local resolutions={}
    for i,size in ipairs(M.resolutions) do resolutions[i]={value=i-1,label=size[1].." x "..size[2]} end
    fields[#fields+1]=choice("resolution","Display resolution",6,resolutions)
    fields[#fields+1]=choice("window","Window type",2,{{value=2,label="Windowed"},{value=1,label="Windowed fullscreen"},{value=0,label="Fullscreen"}})
    fields[#fields+1]=choice("screen","Render scale",90,{{value=50,label="50 %"},{value=60,label="60 %"},{value=70,label="70 %"},{value=80,label="80 %"},{value=90,label="90 %"},{value=100,label="100 %"}})
    fields[#fields+1]=choice("fps","Max FPS",90,{{value=30,label="30"},{value=60,label="60"},{value=90,label="90"},{value=120,label="120"},{value=-1,label="Unlimited"}})
    fields[#fields+1]={key="vsync",label="V-Sync",type="boolean",default=true}
    fields[#fields+1]=choice("color","Color blind mode",0,indexed({"None","Deuteranope","Protanope","Tritanope"}))
    fields[#fields+1]={key="intensity",label="Color blind intensity",type="number",integer=true,min=0,max=100,default=50}
    for _,spec in ipairs(M.extras) do
        fields[#fields+1]=spec.options and choice(spec.id,spec.label,spec.default,spec.options) or {key=spec.id,label=spec.label,type="number",integer=true,min=spec.min,max=spec.max,default=spec.default}
    end
    fields[#fields+1]={key="restore",label="Restore previous custom settings",type="action"}
    return {id="cabin_graphics_custom",name="Graphics Profiles - Custom",hint="Changes take effect with Apply. Particle Detail currently has no effect in the base game.",fields=fields}
end

function M.start(mod,directory,dependencies)
    local definition=M.definition()
    local log=function(level,cause) mod:log(level,cause) end
    local overrideFields={}
    for _,spec in ipairs(M.extras) do
        overrideFields[#overrideFields+1]={key=spec.id,type="number",label=spec.label,default=spec.default}
        overrideFields[#overrideFields+1]={key=spec.id.."_active",type="boolean",label=spec.label.." override",default=false}
    end
    for _,id in ipairs({"postprocess","distance"}) do
        overrideFields[#overrideFields+1]={key=id,type="number",label=id,integer=true,min=0,max=4,default=2}
        overrideFields[#overrideFields+1]={key=id.."_active",type="boolean",label=id.." override",default=false}
    end
    local overrides=storage.new(directory.."custom_overrides.dat",overrideFields,log)
    local backupFields={{key="available",type="boolean",label="Custom backup",default=false}}
    for _,field in ipairs(definition.fields) do
        if field.type~="action" then
            -- Backups accept native values outside the control's selectable range.
            backupFields[#backupFields+1]={key=field.key,type=field.type=="boolean" and "boolean" or "number",label=field.label,default=field.default}
        end
    end
    local mapKeys={"GI Quality","Shading Quality","Foliage Quality","Anti-Aliasing","Texture Detail","Shadow Detail","Reflection Detail","Effects Detail","Particle Detail","Motion Blur","Display","Window Type","Screen Percentage","Max FPS","V-Sync","Color Blind Mode","Color Blind Intensity"}
    for i,key in ipairs(mapKeys) do backupFields[#backupFields+1]={key="saved_"..i,label=key,type="number",integer=true,default=0} end
    for _,id in ipairs({"width","height","native_window","motion_native","screen_native","fps_native"}) do backupFields[#backupFields+1]={key=id,label=id,type="number",default=0} end
    for _,field in ipairs(overrideFields) do
        local copy=codec.copy(field);copy.key="override_"..field.key;backupFields[#backupFields+1]=copy
    end
    local previous=storage.new(directory.."previous_custom.dat",backupFields,log)
    local kismet=StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local function text(value) return type(value)=="string" and value or value:ToString() end
    local function cvar(name)
        local raw=text(kismet:GetConsoleVariableStringValue(name))
        local value=tonumber(raw)
        assert(value and value==value and math.abs(value)<math.huge,"graphics console variable unavailable: "..name.."; observed="..raw)
        return value
    end
    local function command(pc,name,value)
        kismet:ExecuteConsoleCommand(pc,name.." "..string.format("%.9g",value),pc)
        local actual=cvar(name)
        assert(math.abs(actual-value)<0.0001,"graphics console readback differs: "..name.."; observed="..actual.."; required="..value)
    end
    local function snapshot()
        local settings,save=dependencies.engine(),dependencies.game()
        local result={}
        for _,spec in ipairs(M.qualities) do result[spec.id]=settings[spec.getter](settings) end
        local function saved(key) return dependencies.readMap(save.SavedGraphics,key) end
        result.particles=saved("Particle Detail")
        result.motion=cvar("r.MotionBlurQuality")~=0
        result.resolution=saved("Display")
        result.window=settings:GetFullscreenMode()
        result.screen=50+10*saved("Screen Percentage")
        result.fps=({30,60,90,120,-1})[saved("Max FPS")+1]
        result.vsync=settings:IsVSyncEnabled()
        result.color=saved("Color Blind Mode");result.intensity=saved("Color Blind Intensity")
        for _,spec in ipairs(M.extras) do result[spec.id]=cvar(spec.cvar) end
        for i,key in ipairs(mapKeys) do result["saved_"..i]=saved(key) end
        local size=settings:GetScreenResolution()
        result.width,result.height=size.X,size.Y
        result.native_window=result.window
        result.motion_native=cvar("r.MotionBlurQuality");result.screen_native=cvar("r.ScreenPercentage");result.fps_native=cvar("t.MaxFPS")
        for key,value in pairs(overrides.values) do result["override_"..key]=value end
        return result
    end
    local function userValues(snapshot)
        local result={}
        for _,field in ipairs(definition.fields) do if field.type~="action" then result[field.key]=snapshot[field.key] end end
        return result
    end
    local function localController()
        local pc
        for _,candidate in ipairs(FindAllOf("Cabin_PC_C") or {}) do
            if dependencies.valid(candidate) and candidate:IsLocalController() and not candidate:IsActorBeingDestroyed() then
                assert(not pc,"custom graphics local controller ambiguous");pc=candidate
            end
        end
        return pc
    end
    local function write(target,before,restore)
        local pc=assert(localController(),"custom graphics controller unavailable")
        local settings,save=dependencies.engine(),dependencies.game()
        local map=save.SavedGraphics
        local function changed(id) return restore or target[id]~=before[id] end
        for _,spec in ipairs(M.qualities) do
            if changed(spec.id) then
                settings[spec.setter](settings,target[spec.id])
                if spec.key and not restore then map:Add(spec.key,profiles.savedIndex(spec,target[spec.id])) end
            end
        end
        if not restore then
            if changed("particles") then map:Add("Particle Detail",target.particles) end
            if changed("motion") then map:Add("Motion Blur",target.motion and 1 or 0) end
            if changed("resolution") then map:Add("Display",target.resolution) end
            if changed("window") then map:Add("Window Type",2-target.window) end
            if changed("screen") then map:Add("Screen Percentage",(target.screen-50)//10) end
            if changed("fps") then for i,value in ipairs({30,60,90,120,-1}) do if value==target.fps then map:Add("Max FPS",i-1) end end end
            if changed("vsync") then map:Add("V-Sync",target.vsync and 0 or 1) end
            if changed("color") then map:Add("Color Blind Mode",target.color) end
            if changed("intensity") then map:Add("Color Blind Intensity",target.intensity) end
        else for i,key in ipairs(mapKeys) do map:Add(key,target["saved_"..i]) end end
        if changed("vsync") then settings:SetVSyncEnabled(target.vsync) end
        local resize=restore and (before.width~=target.width or before.height~=target.height or before.native_window~=target.native_window) or not restore and (changed("resolution") or changed("window"))
        if resize then
            local size=restore and {target.width,target.height} or M.resolutions[target.resolution+1]
            assert(size,"custom resolution index unavailable")
            settings:SetScreenResolution({X=size[1],Y=size[2]})
            settings:SetFullscreenMode(restore and target.native_window or target.window)
            settings:ApplyResolutionSettings(false)
        end
        settings:ApplyNonResolutionSettings()
        if changed("color") or changed("intensity") then StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary"):SetColorVisionDeficiencyType(target.color,target.intensity/100,false,false) end
        command(pc,"r.MotionBlurQuality",restore and target.motion_native or changed("motion") and (target.motion and 4 or 0) or before.motion_native)
        command(pc,"r.ScreenPercentage",restore and target.screen_native or changed("screen") and target.screen or before.screen_native)
        command(pc,"t.MaxFPS",restore and target.fps_native or changed("fps") and target.fps or before.fps_native)
        -- Scalability application can reset individual effects, so retain every explicit value.
        for _,spec in ipairs(M.extras) do command(pc,spec.cvar,target[spec.id]) end
        settings:SaveSettings()
        local gameplay=StaticFindObject("/Script/Engine.Default__GameplayStatics")
        assert(gameplay:SaveGameToSlot(save,"SettingsData",0),"custom graphics SaveGameToSlot failed")
        local disk=gameplay:LoadGameFromSlot("SettingsData",0)
        assert(dependencies.valid(disk),"custom graphics disk readback unavailable")
        for _,key in ipairs(mapKeys) do assert(dependencies.readMap(disk.SavedGraphics,key)==dependencies.readMap(map,key),"custom graphics disk differs: "..key) end
        for _,spec in ipairs(M.qualities) do
            if changed(spec.id) then assert(settings[spec.getter](settings)==target[spec.id],"custom engine readback differs: "..spec.id) end
        end
        if changed("vsync") then assert(settings:IsVSyncEnabled()==target.vsync,"custom V-Sync readback differs") end
        if resize then
            local size=settings:GetScreenResolution();local required=restore and {target.width,target.height} or M.resolutions[target.resolution+1]
            assert(size.X==required[1] and size.Y==required[2],"custom resolution readback differs")
            assert(settings:GetFullscreenMode()==(restore and target.native_window or target.window),"custom window mode readback differs")
        end
    end
    local revision,signature=0,nil
    local function read()
        local values=userValues(snapshot())
        local encoded=codec.encode(values)
        if encoded~=signature then signature=encoded;revision=revision+1 end
        return values,revision
    end
    local adapter={read=read}
    function adapter.apply(values,action)
        assert(action=="" or action=="restore","invalid custom graphics action")
        values=storage.validate(definition.fields,values)
        local before=snapshot()
        local target=values
        local nextOverrides=codec.copy(overrides.values)
        if action=="restore" then
            assert(previous.values.available,"No previous custom graphics settings")
            target=previous.values
            for key in pairs(nextOverrides) do nextOverrides[key]=target["override_"..key] end
        else
            local backup=codec.copy(before);backup.available=true;previous:save(backup)
            for _,spec in ipairs(M.extras) do
                nextOverrides[spec.id]=values[spec.id];nextOverrides[spec.id.."_active"]=true
            end
            for _,id in ipairs({"postprocess","distance"}) do
                nextOverrides[id]=values[id];nextOverrides[id.."_active"]=true
            end
        end
        local ok,cause=xpcall(function() write(target,before,action=="restore");overrides:save(nextOverrides) end,debug.traceback)
        if not ok then
            local restored,why=xpcall(function() write(before,snapshot(),true) end,debug.traceback)
            error("custom graphics apply failed: "..tostring(cause)..(restored and "; previous graphics restored" or "; rollback failed: "..tostring(why)))
        end
        return read()
    end
    local registered,lastPc=false,nil
    local function reapply()
        local pc=localController();if not pc then return end
        local settings=dependencies.engine()
        local qualityChanged=false
        for _,spec in ipairs(M.qualities) do
            if overrides.values[spec.id.."_active"] then settings[spec.setter](settings,overrides.values[spec.id]);qualityChanged=true end
        end
        if qualityChanged then
            settings:ApplyNonResolutionSettings()
            local save=dependencies.game()
            command(pc,"r.MotionBlurQuality",dependencies.readMap(save.SavedGraphics,"Motion Blur")==1 and 4 or 0)
        end
        for _,spec in ipairs(M.extras) do
            if overrides.values[spec.id.."_active"] then command(pc,spec.cvar,overrides.values[spec.id]) end
        end
    end
    for _,name in ipairs({"LoadGraphics","LoadVideoSettings"}) do
        mod:bind("/Game/CabinGameContent/PlayerContent/Cabin_PC.Cabin_PC_C:"..name,function(context)
            if registered and context:get():IsLocalController() then reapply() end
        end)
    end
    mod:observe("custom graphics",function()
        local pc=localController()
        if not pc then lastPc=nil;return end
        if not registered then
            for _,spec in ipairs(M.extras) do cvar(spec.cvar) end
            mod.registry:register(definition,adapter);registered=true
            log("info","custom graphics registered from current native values")
        end
        if lastPc~=pc:GetAddress() then reapply();lastPc=pc:GetAddress() end
        local old=signature;read()
        if old~=signature then mod.registry:publish(definition.id) end
    end)
    return {definition=definition,adapter=adapter,overrides=overrides,previous=previous,reapply=reapply}
end
return M
