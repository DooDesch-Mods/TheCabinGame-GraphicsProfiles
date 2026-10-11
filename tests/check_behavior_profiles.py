from pathlib import Path
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
