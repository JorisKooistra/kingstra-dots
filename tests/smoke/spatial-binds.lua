local bindings, events, sent = {}, {}, {}
local active={title='App',layout={name='lua:hyprscroll2d'}}
local function dsp(path)
 return setmetatable({}, {
  __index=function(_,key) return dsp(path..'.'..key) end,
  __call=function(_,arg) return {kind=path,arg=arg} end,
 })
end
local spatial={active=function() return active and active.layout.name=='lua:hyprscroll2d' end}
spatial.route=function(message,fallback) return function()
 if spatial.active() then sent[#sent+1]=message elseif fallback then fallback() end
end end
spatial.resize_start=function() sent[#sent+1]='resizestart' end
spatial.resize_stop=function() end
package.loaded['lua.spatial']=spatial
package.loaded['lua.window-close']=assert(loadfile('config/hypr/lua/window-close.lua'))()
_G.hl={
 dsp=dsp('dsp'),dispatch=function(d) sent[#sent+1]=d end,
 exec_cmd=function() end,
 bind=function(keys,handler,options)
  local b={keys=keys,handler=handler,options=options or {},enabled=true}
  function b:set_enabled(value) self.enabled=value end
  bindings[#bindings+1]=b
  return b
 end,
 on=function(name,fn) events[name]=fn end,
 get_active_window=function() return active end,
 define_submap=function(_,fn) fn() end,
}
assert(loadfile('config/hypr/lua/binds.lua'))()
local function find(key,mouse)
 for _,b in ipairs(bindings) do
  if b.keys==key and (not not b.options.mouse)==mouse then return b end
 end
 error('missing bind '..key)
end
local drag=find('SUPER + mouse:272',true)
assert(find('SUPER + Q',false).handler == package.loaded['lua.window-close'].close,
 'Super+Q must use the cursor monitor close handler')
local native_resize=find('SUPER + mouse:273',true)
local custom_resize=find('SUPER + mouse:273',false)
local camera_drag=find('SUPER + CTRL + mouse:272',false)
assert(drag.enabled and not native_resize.enabled and custom_resize.enabled)
active={title='Kingstra Werkvlak',layout={name='floating'}}
events['window.active'](active)
assert(not drag.enabled and not native_resize.enabled and not custom_resize.enabled,'map must receive its own Super+mouse gestures')
assert(not camera_drag.enabled)
active={title='App',layout={name='dwindle'}}
events['window.active'](active)
assert(drag.enabled and native_resize.enabled and not custom_resize.enabled,'native window drag and resize must still work outside spatial layout')
assert(camera_drag.enabled)
for _,b in ipairs(bindings) do assert(b.keys~='SUPER + mouse:274','middle mouse must no longer pan the camera') end
active={title='App',layout={name='lua:hyprscroll2d'}}
events['window.active'](active)
find('SUPER + right',false).handler()
assert(sent[#sent]=='focus right','Super+arrows must retain their existing focus action')
print('ok - overview receives Super gestures; normal windows retain native drag; Super+arrows unchanged')
