-- Rendering stays optional; config reloads must always redeclare the plugin.
local events, sent, declarations = {}, {}, 0
local monitors = {
 A={name='A',active_workspace={id=1,tiled_layout='lua:hyprscroll2d'}},
 B={name='B',active_workspace={id=2,tiled_layout='lua:hyprscroll2d'}},
 C={name='C',active_workspace={id=3,tiled_layout='dwindle'}},
}
local current, special, is_loaded = monitors.A, false, false
local real_getenv = os.getenv
os.getenv=function(name)
 if name=='KINGSTRA_NATIVE_ZOOM_PLUGIN' then return 'tests/smoke/native-zoom.lua' end
 return real_getenv(name)
end
_G.hl={
 get_loaded_plugins=function() return is_loaded and {{name='spatialoverview'}} or {} end,
 plugin={load=function() declarations=declarations+1 end,spatialoverview={
  _dispatch=function(action,arg) sent[#sent+1]=action..' '..arg end,
 }},
 config=function(c)
  local cfg=c.plugin.spatialoverview.canvas
  assert(not cfg.auto_float and not cfg.auto_place and not cfg.linked_screens)
  assert(cfg.direct_input and cfg.hover_focus and not cfg.remember_layout)
 end,
 dispatch=function() error('plugin commands must not pass nil to hl.dispatch') end,
 on=function(e,fn) events[e]=fn end,
 get_active_special_workspace=function() return special and {} or nil end,
 get_monitor_at_cursor=function() return current end,
 get_active_monitor=function() return current end,
 get_active_workspace=function() return current.active_workspace end,
 get_monitor=function(name) return monitors[name] end,
}
local path='config/hypr/lua/native-zoom.lua'
assert(not assert(loadfile(path))().ready,'first pass may precede deferred plugin load')
is_loaded=true
local zoom=assert(loadfile(path))()
assert(zoom.ready and declarations==2,'reload must declare the already loaded plugin too')
zoom.zoom('out')
assert(sent[1]=='overview open A' and sent[2]=='canvas zoom out')
local first=_G.__kingstra_native_zoom_workspaces['1']
current=monitors.B
zoom.zoom('out');events['workspace.active']()
assert(_G.__kingstra_native_zoom_workspaces['1']==first,'monitor focus must not close its neighbour')
assert(_G.__kingstra_native_zoom_workspaces['2']==first)
zoom.reset()
assert(not _G.__kingstra_native_zoom_workspaces['2'] and _G.__kingstra_native_zoom_workspaces['1']==first)
assert(sent[#sent]=='overview close B')
current=monitors.C
local count=#sent;zoom.zoom('out');assert(#sent==count,'ordinary Dwindle must remain native')
current=monitors.A;special=true;zoom.zoom('out');assert(#sent==count,'special workspace stays native');special=false
monitors.A.active_workspace={id=4,tiled_layout='lua:hyprscroll2d'}
events['workspace.active']()
assert(not next(_G.__kingstra_native_zoom_workspaces) and sent[#sent]=='overview close A')
zoom.zoom('out');zoom.zoom('in')
assert(not next(_G.__kingstra_native_zoom_workspaces),'zooming back to 100% closes native rendering')
zoom.zoom('out');events['config.reloaded']()
assert(not next(_G.__kingstra_native_zoom_workspaces) and sent[#sent]=='overview close all')
print('ok - native zoom preserves tiling, redeclares on reload and handles monitors independently')
