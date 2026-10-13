from pathlib import Path
import shutil
import tempfile
import unittest
from lupa.lua54 import LuaRuntime
vm=LuaRuntime(unpack_returned_tuples=True)
vm.globals().directory=(Path(__file__).resolve().parents[1]/'Mods/CabinGraphicsProfiles/Scripts').as_posix()
vm.execute('''package.path=directory.."/?.lua;"..package.path;profiles=require("profiles")
    for _,group in ipairs(profiles.groups) do
        for _,quality in ipairs({0,1,3,4}) do local i=profiles.savedIndex(group,quality);assert(profiles.engineQuality(group,i)==quality) end
    end
    assert(profiles.savedIndex(profiles.groups[2],0)==-2 and profiles.savedIndex(profiles.groups[2],1)==-1)
    adapter={values={gi=3,shadows=3,reflections=3,effects=3},writes=0}
    function adapter:read() local r={};for k,v in pairs(self.values) do r[k]=v end;return r end
    function adapter:write(v) self.writes=self.writes+1;if self.fail and self.writes==self.fail then error("engine apply failure") end;for k,value in pairs(v) do if k~="available" then self.values[k]=value end end end
    backup={values={available=false},saves=0};function backup:save(v) self.saves=self.saves+1;self.values=v;return v end
    transaction=require("transaction");transaction.apply(adapter,backup,"balanced");assert(adapter.values.gi==1 and backup.values.gi==3)
    transaction.apply(adapter,backup,"performance");assert(adapter.values.shadows==0 and backup.values.shadows==1)
    transaction.apply(adapter,backup,"restore");assert(adapter.values.effects==1)
    adapter.fail=adapter.writes+1;local ok,cause=pcall(transaction.apply,adapter,backup,"performance");assert(not ok and cause:find("engine apply failure",1,true) and adapter.values.gi==1)
''')


class FString:
    def __init__(self, text):
        self.text = text

    def ToString(self):
        return self.text


TYPED_FIXTURE = r'''
local directory=...
local logs,shared,hooks,ticks={},{},{},{}
local nextid,writes,saves=10,0,0
local function copy(values) local result={};for k,v in pairs(values) do result[k]=v end;return result end
local function object(address) return {IsValid=function() return true end,GetAddress=function() return address end,IsActorBeingDestroyed=function() return false end} end
local pc=object(2)
function pc:IsLocalController() return true end
local qualities={gi=3,shadows=3,reflections=2,effects=4,shading=2,foliage=2,aa=2,textures=2,postprocess=2,distance=2}
local initialqualities=copy(qualities)
local names={'GI Quality','Shading Quality','Foliage Quality','Anti-Aliasing','Texture Detail','Shadow Detail','Reflection Detail','Effects Detail','Particle Detail','Motion Blur','Display','Window Type','Screen Percentage','Max FPS','V-Sync','Color Blind Mode','Color Blind Intensity'}
local live={}
for index,name in ipairs(names) do live[name]=index end
live['GI Quality']=2;live['Shadow Detail']=1;live['Reflection Detail']=1;live['Effects Detail']=3
live['Shading Quality']=1;live['Foliage Quality']=1;live['Anti-Aliasing']=1;live['Texture Detail']=1;live['Particle Detail']=1
live['Motion Blur']=1;live['Display']=6;live['Window Type']=0;live['Screen Percentage']=4;live['Max FPS']=2;live['V-Sync']=0;live['Color Blind Mode']=0;live['Color Blind Intensity']=50
local disk,initialmap=copy(live),copy(live)
local function wrap(value) return {get=function() return value end} end
local keymode='userdata'
local function inputkey(key)
    if type(key)=='userdata' then key=key:ToString() end
    assert(type(key)=='string','native StrProperty input requires Lua string or FString')
    return key
end
local function map(data)
    return {
        Contains=function(_,key) return data[inputkey(key)]~=nil end,
        Find=function(_,key) return wrap(data[inputkey(key)]) end,
        Add=function(_,key,value) data[inputkey(key)]=value end,
        ForEach=function(_,callback)
            for key,value in pairs(data) do
                local raw=keymode=='userdata' and FString(key) or keymode=='bad' and 17 or key
                assert(type(raw)==keymode or keymode=='bad')
                callback(wrap(raw),wrap(value))
            end
        end,
    }
end
local save,settings,gameplay,library=object(3),object(4),object(5),object(6)
save.SavedGraphics=map(live)
local qualitynames={gi='GlobalIllumination',shadows='Shadow',reflections='Reflection',effects='VisualEffect',shading='Shading',foliage='Foliage',aa='AntiAliasing',textures='Texture',postprocess='PostProcessing',distance='ViewDistance'}
for key,name in pairs(qualitynames) do
    settings['Get'..name..'Quality']=function() return qualities[key] end
    settings['Set'..name..'Quality']=function(_,value) writes=writes+1;qualities[key]=value end
end
function settings:ApplyNonResolutionSettings() end
function settings:SaveSettings() end
local cvars={['r.MotionBlurQuality']=4,['r.ScreenPercentage']=90,['t.MaxFPS']=90,['r.DepthOfFieldQuality']=2,['r.LensFlareQuality']=2,['r.SceneColorFringeQuality']=1,['r.BloomQuality']=5,['r.Tonemapper.Sharpen']=-1,['r.Fog']=1,['r.VolumetricFog']=1}
local initialcvars=copy(cvars)
local kismet=object(20)
function kismet:GetConsoleVariableStringValue(name) return cvars[name] and tostring(cvars[name]) or '' end
function kismet:ExecuteConsoleCommand(pc,command,owner) local name,value=command:match('^(%S+) (.+)$');assert(cvars[name]~=nil);cvars[name]=assert(tonumber(value)) end
local screen={X=1600,Y=900};local window,vsync=2,true
function settings:GetScreenResolution() return copy(screen) end
function settings:SetScreenResolution(value) screen=copy(value) end
function settings:GetFullscreenMode() return window end
function settings:SetFullscreenMode(value) window=value end
function settings:IsVSyncEnabled() return vsync end
function settings:SetVSyncEnabled(value) vsync=value end
function settings:ApplyResolutionSettings(value) assert(value==false) end
local widgets=object(21)
function widgets:SetColorVisionDeficiencyType(mode,intensity,correct,show) assert(mode>=0 and mode<=3 and intensity>=0 and intensity<=1 and not correct and not show) end
function gameplay:SaveGameToSlot(value,slot,index) assert(value==save and slot=='SettingsData' and index==0);saves=saves+1;disk=copy(live);return true end
function gameplay:LoadGameFromSlot(slot,index) assert(slot=='SettingsData' and index==0);local result=object(7);result.SavedGraphics=map(disk);return result end
function library:GetSettingsSaveData(owner,slot,out) assert(owner==pc);out.SettingsSaveObject=save end
local transport={}
function transport:GetSharedVariable(key) return shared[key] end
function transport:SetSharedVariable(key,value) shared[key]=value end
local function environment()
    local env,cache={},{}
    setmetatable(env,{__index=_G});env._G=env;env.ModRef=transport;env.package={path=''}
    env.print=function(message) logs[#logs+1]=message end
    env.StaticFindObject=function(path)
        if path=='/Script/Engine.Default__GameUserSettings' then return {GetGameUserSettings=function() return settings end} end
        if path=='/Script/Engine.Default__GameplayStatics' then return gameplay end
        if path=='/Script/Engine.Default__KismetSystemLibrary' then return kismet end
        if path=='/Script/UMG.Default__WidgetBlueprintLibrary' then return widgets end
        if path=='/Game/CabinGameContent/Cabin_Functions.Default__Cabin_Functions_C' then return library end
        return object(100)
    end
    env.FindAllOf=function(kind) if kind=='Cabin_PC_C' then return {pc} end;return {} end
    env.IsInGameThread=function() return true end
    env.IsValidDelayedActionHandle=function(id) return ticks[id]~=nil end
    env.LoopInGameThreadWithDelay=function(ms,callback) nextid=nextid+1;ticks[nextid]=callback;return nextid end
    env.RegisterHook=function(path,pre,post) nextid=nextid+2;hooks[path]={pre=pre,post=post};return nextid,nextid+1 end
    env.FText=function(text) return {ToString=function() return text end} end
    env.require=function(name)
        if cache[name]==nil then cache[name]=assert(loadfile(directory..name..'.lua','t',env))() end
        return cache[name]
    end
    return env
end
local ownerenv=environment()
local owner=assert(loadfile(directory..'main.lua','t',ownerenv))()
local clientenv=environment()
local registry=clientenv.require('cabin_registry').new(transport,function(level,cause) logs[#logs+1]=level..': '..cause end)
local codec=clientenv.require('cabin_codec')
local id='cabin_graphics_profiles'
local function request(profile,action,token)
    local entries=registry:list();local registered
    for _,entry in ipairs(entries) do if entry.definition.id==id then registered=entry end end
    assert(registered);local values=codec.copy(registered.values);values.profile=profile
    registry:request(id,token,registered.revision,values,action)
    assert(not registry:response(id,token),'effect unexpectedly occurred before owning VM tick')
    owner:tick()
    local response=assert(registry:response(id,token),'owning VM acknowledgement absent')
    return response
end
local function custom(changes,action,token)
    owner:tick()
    local registered
    for _,entry in ipairs(registry:list()) do if entry.definition.id=='cabin_graphics_custom' then registered=entry end end
    assert(registered,'custom provider absent')
    local values=codec.copy(registered.values)
    for key,value in pairs(changes) do values[key]=value end
    registry:request('cabin_graphics_custom',token,registered.revision,values,action or '')
    owner:tick()
    return assert(registry:response('cabin_graphics_custom',token))
end
local function title(title,index)
    owner:tick()
    local path='/Game/MenuContent/Settings/WBP_OptionsSlot_SideArrow.WBP_OptionsSlot_SideArrow_C:SetOptionType_E'
    local bound=assert(hooks[path],'owning runtime did not bind Title hook')
    local widget=object(10);widget.Master=object(11);widget.Title=FString(title);widget.CurrentOption=index
    widget.OptionType_T={SetText=function(_,text) widget.text=text:ToString() end}
    widget.LeftArrow_B={SetIsEnabled=function(_,enabled) widget.left=enabled end}
    widget.RightArrow_B={SetIsEnabled=function(_,enabled) widget.right=enabled end}
    bound.pre(wrap(widget))
    return widget
end
return {request=request,title=title,live=live,initialmap=initialmap,qualities=qualities,initialqualities=initialqualities,
    disk=function() return disk end,writes=function() return writes end,saves=function() return saves end,
    keymode=function(mode) keymode=mode end,custom=custom,cvars=cvars,initialcvars=initialcvars,owner=owner,logs=logs,
    settings=settings,registry=registry}
'''


class TypedGraphicsTests(unittest.TestCase):
    def setUp(self):
        repository = Path(__file__).resolve().parents[1]
        scratch_root = repository / "dist"
        scratch_root.mkdir(exist_ok=True)
        self.scratch = tempfile.TemporaryDirectory(prefix="graphics-fstring-", dir=scratch_root)
        self.addCleanup(self.scratch.cleanup)
        source = repository / "Mods/CabinGraphicsProfiles/Scripts"
        scripts = Path(self.scratch.name) / "Scripts"
        scripts.mkdir()
        for path in source.glob("*.lua"):
            shutil.copyfile(path, scripts / path.name)
        self.vm = LuaRuntime(unpack_returned_tuples=True)
        self.vm.globals().FString = FString
        # Distinct wrappers must remain userdata table keys, rather than Lua strings.
        self.vm.execute("local a,b=FString('GI Quality'),FString('GI Quality');assert(type(a)=='userdata' and a~='GI Quality' and a~=b and a:ToString()=='GI Quality')")
        self.fixture = self.vm.execute(TYPED_FIXTURE, scripts.as_posix() + "/")

    def apply_restore(self):
        fx = self.fixture
        response = fx.request("performance", "", "typed-apply")
        self.assertTrue(response.ok, response.error)
        self.assertEqual(len(list(fx.live.items())), 17)
        changed = {key for key, value in fx.initialmap.items() if value != fx.live[key]}
        self.assertEqual(changed, {"GI Quality", "Shadow Detail", "Reflection Detail", "Effects Detail"})
        unrelated = set(dict(fx.initialmap.items())) - changed
        self.assertEqual(len(unrelated), 13)
        for key in unrelated:
            self.assertEqual(fx.live[key], fx.initialmap[key])
            self.assertEqual(fx.disk()[key], fx.initialmap[key])
        self.assertEqual(fx.writes(), 4)
        self.assertEqual(fx.saves(), 1)
        response = fx.request("current", "restore", "typed-restore")
        self.assertTrue(response.ok, response.error)
        self.assertEqual(dict(fx.live.items()), dict(fx.initialmap.items()))
        self.assertEqual(dict(fx.disk().items()), dict(fx.initialmap.items()))
        self.assertEqual(dict(fx.qualities.items()), dict(fx.initialqualities.items()))
        self.assertEqual(fx.writes(), 8)
        self.assertEqual(fx.saves(), 2)

    def test_registered_vm_userdata_keys_apply_and_exact_restore(self):
        self.apply_restore()

    def test_bound_title_hook_userdata_low_medium_and_other_options(self):
        fx = self.fixture
        for title, index, expected, left in (("Shadow Detail", -2, "Low", False), ("Shadow Detail", -1, "Medium", True), ("Reflection Detail", -1, "Low", False), ("Effects Detail", -1, "Low", False)):
            widget = fx.title(title, index)
            self.assertEqual(widget.text, expected)
            self.assertEqual(widget.left, left)
            self.assertTrue(widget.right)
        self.assertEqual(fx.title("Texture Detail", -1).text, "Low")
        self.assertIsNone(fx.title("Particle Detail", -1).text)
        self.assertIsNone(fx.title("Shadow Detail", 0).text)
        self.assertEqual(fx.writes(), 0)
        self.assertEqual(fx.saves(), 0)

    def test_unsupported_key_keeps_original_cause_without_native_writes(self):
        fx = self.fixture
        fx.keymode("bad")
        response = fx.request("performance", "", "typed-bad")
        self.assertFalse(response.ok)
        self.assertIn("original graphics map key type invalid; observed=number; required=string/FString", response.error)
        self.assertEqual(fx.writes(), 0)
        self.assertEqual(fx.saves(), 0)

    def test_lua_string_key_compatibility(self):
        self.fixture.keymode("string")
        self.apply_restore()

    def test_custom_changes_native_groups_effects_and_saved_values_then_restores(self):
        fx = self.fixture
        changes = self.vm.table_from({'gi': 1, 'textures': 0, 'postprocess': 0, 'motion': False,
                                      'screen': 70, 'fps': 60, 'vsync': False, 'color': 2,
                                      'intensity': 75, 'bloom': 1, 'sharpen': 0.5})
        result = fx.custom(changes, '', 'custom-apply')
        self.assertTrue(result.ok, result.error)
        self.assertEqual(fx.qualities.gi, 1)
        self.assertEqual(fx.qualities.textures, 0)
        self.assertEqual(fx.qualities.postprocess, 0)
        self.assertEqual(fx.live['GI Quality'], 1)
        self.assertEqual(fx.live['Texture Detail'], -1)
        self.assertEqual(fx.live['Screen Percentage'], 2)
        self.assertEqual(fx.live['Max FPS'], 1)
        self.assertEqual(fx.cvars['r.MotionBlurQuality'], 0)
        self.assertEqual(fx.cvars['r.BloomQuality'], 1)
        self.assertEqual(fx.cvars['r.Tonemapper.Sharpen'], 0.5)
        self.assertEqual(fx.disk()['Color Blind Mode'], 2)
        result = fx.custom(self.vm.table(), 'restore', 'custom-restore')
        self.assertTrue(result.ok, result.error)
        self.assertEqual(dict(fx.live.items()), dict(fx.initialmap.items()))
        self.assertEqual(dict(fx.qualities.items()), dict(fx.initialqualities.items()))
        self.assertEqual(dict(fx.cvars.items()), dict(fx.initialcvars.items()))
        self.assertFalse(fx.owner.custom.overrides['values'].bloom_active)

    def test_custom_validation_rejects_bad_values_before_native_mutation(self):
        fx = self.fixture
        result = fx.custom(self.vm.table_from({'bloom': 99}), '', 'custom-invalid')
        self.assertFalse(result.ok)
        self.assertIn('Bloom is outside its allowed range', result.error)
        self.assertEqual(fx.writes(), 0)
        self.assertEqual(fx.saves(), 0)

    def test_custom_window_resolution_restore_keeps_native_and_original_indices(self):
        fx = self.fixture
        result = fx.custom(self.vm.table_from({'resolution': 0, 'window': 1}), '', 'custom-display')
        self.assertTrue(result.ok, result.error)
        self.assertEqual(fx.settings.GetScreenResolution(fx.settings).X, 1280)
        self.assertEqual(fx.live['Display'], 0)
        self.assertEqual(fx.live['Window Type'], 1)
        result = fx.custom(self.vm.table(), 'restore', 'custom-display-restore')
        self.assertTrue(result.ok, result.error)
        self.assertEqual(fx.settings.GetScreenResolution(fx.settings).X, 1600)
        self.assertEqual(fx.settings.GetFullscreenMode(fx.settings), 2)
        self.assertEqual(dict(fx.live.items()), dict(fx.initialmap.items()))


# check_lua.py executes this file through runpy as well as direct CI invocation.
result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(TypedGraphicsTests))
assert result.wasSuccessful(), "typed Graphics adapter regression checks failed"
