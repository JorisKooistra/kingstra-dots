-- A package update builds for the installed headers while the old compositor
-- can remain active. Each session must select its own ABI, including migration.
local real_open,real_getenv=io.open,os.getenv
local base='/virtual/hypr/native-zoom/kingstra-native-zoom.so'
local running,files,selected,config
os.getenv=function(k)
 if k=='KINGSTRA_NATIVE_ZOOM_PLUGIN' then return nil end
 if k=='HYPRLAND_INSTANCE_SIGNATURE' then return running..'_session' end
 if k=='XDG_CONFIG_HOME' then return '/virtual' end
 if k=='XDG_RUNTIME_DIR' then return nil end
 return real_getenv(k)
end
io.open=function(path,mode)
 local data=files[path]
 if not data then return nil end
 local row=0
 return {read=function() row=row+1;return data[row] end,close=function() end}
end
_G.hl={get_loaded_plugins=function() return {{name='spatialoverview'}} end,
 plugin={load=function(p) selected=p end,spatialoverview={_backend=function() return 'kingstra-0.57' end,_dispatch=function() end}},
 config=function(c) config=c end,on=function() end}
local function load(abi,entries)
 running,files,selected,config=abi,entries,nil,nil
 return assert(loadfile('config/hypr/lua/native-zoom.lua'))()
end
local entries={
 [base..'.abi']={'bbbb','/new.so'},
 [base..'.aaaa.abi']={'aaaa','/old.so'},
 [base..'.bbbb.abi']={'bbbb','/new.so'},
 ['/old.so']={},['/new.so']={},
}
assert(load('aaaa',entries).ready and selected=='/old.so','running old session keeps its old build')
assert(load('bbbb',entries).ready and selected=='/new.so','new session selects its new build')
assert(config.plugin.spatialoverview.canvas.hover_focus and not config.plugin.spatialoverview.layout,'modern backend does not get legacy render settings')
assert(not load('cccc',entries).ready and not selected,'unknown ABI never loads an incompatible native binary')
entries[base..'.aaaa.abi']=nil;entries[base..'.abi']={'aaaa','/old.so'}
assert(load('aaaa',entries).ready and selected=='/old.so','single-entry stamp remains backward compatible')
entries[base..'.aaaa.abi']={'bbbb','/new.so'}
assert(not load('aaaa',entries).ready and not selected,'incorrect indexed ABI is rejected')
io.open,os.getenv=real_open,real_getenv
print('ok - native zoom selects the running ABI before and after package updates')
