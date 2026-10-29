#!/usr/bin/env python3
"""Opt-in integration test: opens a nested compositor with disposable GTK apps.
Requires a real Wayland session, Hyprland 0.56.2 or 0.57.0, the matching native plugin,
python-gobject/GTK4, Pillow, grim, wtype, cc, and wayland-scanner. Never dispatches to the
parent compositor. Retains its /tmp/kz* directory for diagnosis.
"""
import os,sys,json,subprocess,tempfile,time,shutil,re
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[2]
plugin=Path(sys.argv[1] if len(sys.argv)>1 else root/'config/hypr/native-zoom/kingstra-native-zoom.so').resolve()
source=Path(os.getenv('KINGSTRA_ZOOM_TEST_SOURCE',str(root/'tests/integration')))
pointer_tools=source/'tools' if (source/'tools/vpointer.c').exists() else source/'tests/tools'
if not (pointer_tools/'vpointer.c').exists():raise SystemExit('Virtual pointer test fixtures are missing')

run=Path(tempfile.mkdtemp(prefix='kz',dir='/tmp'));run.chmod(0o700)
parent=dict(os.environ);env=dict(parent,AQ_BACKEND='wayland',WAYLAND_DISPLAY=str(Path(parent['XDG_RUNTIME_DIR'])/parent['WAYLAND_DISPLAY']),XDG_RUNTIME_DIR=str(run),XDG_CONFIG_HOME=str(run/'config'),XDG_STATE_HOME=str(run/'state'),XDG_CACHE_HOME=str(run/'cache'),KINGSTRA_NATIVE_ZOOM_PLUGIN=str(plugin))
env['HOME']=str(run/'home');Path(env['HOME']).mkdir()
if abi:=os.getenv('KINGSTRA_TEST_ABI_INDEX'):
 stamp=Path(env['XDG_CONFIG_HOME'])/'hypr/native-zoom/kingstra-native-zoom.so'
 stamp.parent.mkdir(parents=True)
 Path(str(stamp)+'.'+abi+'.abi').write_text(abi+'\n'+str(plugin)+'\n')
 Path(str(stamp)+'.abi').write_text('0000\n/nonexistent/plugin.so\n')
 env.pop('KINGSTRA_NATIVE_ZOOM_PLUGIN')
config=run/'test.lua'
config.write_text('''
hl.monitor({output="",mode="1024x640@60",position="auto",scale=1})
hl.config({misc={disable_hyprland_logo=true,disable_splash_rendering=true,size_limits_tiled=false},ecosystem={no_donation_nag=true},animations={enabled=false},xwayland={enabled=false},general={gaps_in=0,gaps_out=0,border_size=0},input={follow_mouse=1},debug={disable_logs=false}})
-- Parent pointer events would race the test's virtual mouse when the user
-- moves over a nested output. Disable only that backend device in the child.
hl.device({name="wl_pointer",enabled=false})
hl.device({name="wl_keyboard",enabled=false})
hl.device({name="hl-virtual-keyboard-wtype",resolve_binds_by_sym=true})
package.path="@ROOT@/config/hypr/?.lua;"..package.path
_G.__hyprscroll2d_layout_registered=nil; assert(loadfile("@ROOT@/config/hypr/lua/spatial/init.lua"))()
hl.workspace_rule({workspace="1",layout="lua:hyprscroll2d"})
hl.workspace_rule({workspace="2",layout="lua:hyprscroll2d"})
_G.zoom=require("lua.native-zoom")
hl.bind("SUPER + u",function() zoom.zoom("out") end)
hl.bind("SUPER + CTRL + mouse_down",function() zoom.zoom("out") end)
hl.bind("SUPER + CTRL + mouse_up",function() zoom.zoom("in") end)
hl.bind("SUPER + CTRL + mouse:274",function() zoom.reset() end)
_G.spatial=require("lua.spatial")
hl.bind("SUPER + CTRL + mouse:272",spatial.drag_start)
hl.bind("SUPER + mouse:272",hl.dsp.window.drag(),{mouse=true})
hl.bind("mouse:272",spatial.drag_stop,{release=true,ignore_mods=true,non_consuming=true})
hl.bind("SUPER + F24",function() _G.test_mods_ready=true end)
hl.bind("SUPER + CTRL + F24",function() _G.test_mods_ready=true end)
'''.replace('@ROOT@',str(root)))
binary=os.getenv('KINGSTRA_TEST_HYPRLAND','Hyprland')
if os.getenv('KINGSTRA_TEST_UNLINK_BINARY'):
 shutil.copy2(shutil.which(binary) or binary,run/'Hyprland');binary=str(run/'Hyprland')
log=(run/'log').open('w');proc=subprocess.Popen([binary,'-c',str(config)],env=env,stdout=log,stderr=subprocess.STDOUT)
if os.getenv('KINGSTRA_TEST_UNLINK_BINARY'):Path(binary).unlink()
sig=None;qs=None;qs_config=None;qs_log=None;browser=None;browser_log=None
pointer_build=run/'pointer';pointer_build.mkdir()
xml=pointer_tools/'wlr-virtual-pointer-unstable-v1.xml'
pointer_source=(pointer_tools/'vpointer.c').read_text()
old='        if (!strcmp(cmd, "abs") && i + 2 < argc) {'
new='        if (!strcmp(cmd, "wheel") && i + 1 < argc) {\n            int direction = atoi(argv[++i]);\n            zwlr_virtual_pointer_v1_axis_source(pointer, WL_POINTER_AXIS_SOURCE_WHEEL);\n            zwlr_virtual_pointer_v1_axis_discrete(pointer, now_ms(), WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_double(direction * 10), direction);\n        } else if (!strcmp(cmd, "abs") && i + 2 < argc) {'
# A source checkout used for development may already have the wheel helper.
if 'strcmp(cmd, "wheel")' not in pointer_source:pointer_source=pointer_source.replace(old,new)
(pointer_build/'vpointer.c').write_text(pointer_source)
subprocess.run(['wayland-scanner','client-header',str(xml),str(pointer_build/'wlr-virtual-pointer-unstable-v1-client-protocol.h')],check=True)
subprocess.run(['wayland-scanner','private-code',str(xml),str(pointer_build/'protocol.c')],check=True)
subprocess.run(['cc','-O2','-I'+str(pointer_build),str(pointer_build/'vpointer.c'),str(pointer_build/'protocol.c'),'-lwayland-client','-lm','-o',str(pointer_build/'vpointer')],check=True)
vpointer=str(pointer_build/'vpointer')
def ctl(*args):
 r=subprocess.run(['hyprctl','-i',sig,*args],env=env,capture_output=True,text=True,timeout=2)
 if r.returncode or r.stdout.startswith('error'):raise RuntimeError(str(args)+': '+r.stdout+r.stderr)
 return r.stdout.strip()
def check(ok,name):
 print(('PASS ' if ok else 'FAIL ')+name,flush=True)
 if not ok:raise AssertionError(name)
try:
 for i in range(20):
  instances=list((run/'hypr').glob('*/.socket.sock'))
  if instances:
   sig=instances[0].parent.name
   try:
    if 'WAYLAND' in ctl('monitors','-j'):break
   except (RuntimeError,subprocess.TimeoutExpired): pass
  if proc.poll()!=None:raise RuntimeError('compositor died: '+str(run))
  time.sleep(.1)
 check(bool(sig),'isolated compositor started');env['HYPRLAND_INSTANCE_SIGNATURE']=sig
 # First-run helper windows are compositor UI, not fixture applications.
 for w in json.loads(ctl('clients','-j')):
  if w.get('class')=='hyprland-donate-screen':os.kill(w['pid'],15)
 time.sleep(.5)
 print('PLUGINS',ctl('plugin','list','-j'),flush=True)
 check(ctl('repl','return zoom.ready')=='true','zoom module initializes from real startup config')
 time.sleep(.5)
 errs=ctl('configerrors');print('errors:',errs,flush=True);check(not errs,'native plugin and Lua loaded')
 print('monitor fields:',ctl('repl','local m=hl.get_active_monitor(); return tostring(m.active_workspace)..":"..tostring(m.name)'),flush=True)
 for name in ('zoom-A','zoom-B','zoom-C'):
  ctl('dispatch','hl.dsp.exec_cmd('+json.dumps('python3 '+str(root/'tests/integration/native-zoom-app.py')+' '+name+' > '+str(run/name)+'.log 2>&1')+')')
  for i in range(50):
   clients=json.loads(ctl('clients','-j'))
   if any(w['title']==name for w in clients):break
   time.sleep(.1)
 check(len(clients)==3,'three real Wayland apps started')
 print('ACTIVE',ctl('activeworkspace','-j'),flush=True)
 a,b,c=clients
 ctl('dispatch','hl.dsp.layout("place '+b['address']+' 1 0")')
 ctl('dispatch','hl.dsp.layout("place '+c['address']+' 0 -1")')
 ctl('eval','hl.dispatch(hl.dsp.layout("pan left")); hl.dispatch(hl.dsp.layout("pan right"))')
 before=json.loads(ctl('clients','-j'));time.sleep(.25)
 env['WAYLAND_DISPLAY']=next(p.name for p in run.glob('wayland-*') if not p.name.endswith('.lock'))
 km=subprocess.Popen(['wtype','-M','logo','-M','ctrl','-s','650','-m','ctrl','-m','logo'],env=env);time.sleep(.15)
 mm=json.loads(ctl('monitors','-j'))[0]
 subprocess.run([vpointer,str(mm['width']),str(mm['height']),'abs',str(mm['width']//2),str(mm['height']//2),'wheel','1'],env=env,check=True)
 km.wait(timeout=3);time.sleep(.4)
 print('zoom state:',ctl('spatialoverview'),flush=True)
 check(not ctl('configerrors'),'zoom opens without compositor errors')
 now=json.loads(ctl('clients','-j'))
 check(all(not w['floating'] for w in now),'Dwindle windows stay tiled')
 positions=lambda ws:{w['address']:(w['at'],w['size']) for w in ws}
 check(positions(before)==positions(now),'zoom does not resize or relocate app buffers')
 state=json.loads(ctl('spatialoverview'));check(bool(state['screens']),'native rendering is active')
 check(state['screens'][0]['zoom']<1,'desktop is zoomed out')
 check(not state['screens'][0]['navigating'],'applications retain direct input')
 check(json.loads(ctl('getoption','input:follow_mouse','-j'))['int']==1,'zoom preserves global focus-follow-mouse')
 for _ in range(7):ctl('eval','zoom.zoom("out")')
 time.sleep(.6)
 env['WAYLAND_DISPLAY']=next(p.name for p in run.glob('wayland-*') if not p.name.endswith('.lock'))
 subprocess.run(['grim',str(run/'zoom.png')],env=env,check=True)
 m=json.loads(ctl('monitors','-j'))[0];ww,hh=m['width'],m['height']
 state=json.loads(ctl('spatialoverview'));print('VIEW',state,flush=True)
 windows=json.loads(ctl('clients','-j'));print('WINDOWS',[(w['title'],w['at'],w['size']) for w in windows],flush=True)
 image=Image.open(run/'zoom.png').convert('RGB')
 view=state['screens'][0]['view']
 for name,channel in [('zoom-A',0),('zoom-B',1),('zoom-C',2)]:
  window=next(w for w in windows if w['title']==name)
  point=[int((window['at'][i]+window['size'][i]/2-view[i])*[ww,hh][i]/view[i+2]) for i in (0,1)]
  pixel=image.getpixel(tuple(point))
  check(pixel[channel]>max(pixel[j] for j in range(3) if j!=channel)+40,name+' renders its complete offscreen buffer')
 view=state['screens'][0]['view'];target=next(w for w in windows if w['title']=='zoom-B')
 tx=max(view[0]+10,target['at'][0])+min(target['size'][0]/3,100)
 ty=max(view[1]+10,target['at'][1])+min(target['size'][1]/3,100)
 x=int((tx-view[0])*ww/view[2]);y=int((ty-view[1])*hh/view[3])
 print('CLICK',x,y,flush=True)
 subprocess.run([vpointer,str(ww),str(hh),'abs',str(x),str(y),'sleep','180'],env=env,check=True)
 check(json.loads(ctl('activewindow','-j'))['address']==target['address'],'hover selects a zoomed app without clicking')
 subprocess.run([vpointer,str(ww),str(hh),'abs',str(x),str(y),'sleep','100','down','up','sleep','100'],env=env,check=True)
 subprocess.run(['wtype','k'],env=env,check=True);time.sleep(.2)
 print('APPLOG', (run/'zoom-B.log').read_text(),flush=True)
 check('click zoom-B' in (run/'zoom-B.log').read_text(),'scaled click reaches neighbouring app')
 check('key zoom-B k' in (run/'zoom-B.log').read_text(),'typing reaches clicked app while zoomed')
 check(positions(before)==positions(json.loads(ctl('clients','-j'))),'focus on adjacent page does not move the camera')

 def document_offset():
  rows=[line.split() for line in (run/'zoom-B.log').read_text().splitlines() if line.startswith('offset zoom-B ')]
  return float(rows[-1][2]) if rows else 0
 start_offset=document_offset()
 subprocess.run([vpointer,str(ww),str(hh),'abs',str(x),str(y),'sleep','100','wheel','1','sleep','350'],env=env,check=True)
 down_offset=document_offset()
 check(down_offset>start_offset,'wheel scrolls real document down while zoomed')
 subprocess.run([vpointer,str(ww),str(hh),'abs',str(x),str(y),'sleep','100','wheel','-1','sleep','350'],env=env,check=True)
 check(document_offset()<down_offset,'wheel scrolls real document back up while zoomed')
 check(positions(before)==positions(json.loads(ctl('clients','-j'))),'document scrolling keeps workspace camera and window geometry unchanged')
 if shutil.which('firefox'):
  profile=run/'firefox';profile.mkdir()
  (profile/'user.js').write_text('''
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.startup.firstrunSkipsHomepage", true);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.auto", false);
user_pref("general.smoothScroll", false);
''')
  document=run/'scroll-test.html'
  document.write_text('''<!doctype html><title>zoom-scroll-0</title>
<style>body{margin:0;background:#dff0d8;font:24px sans-serif}main{height:8000px;padding:40px;background:repeating-linear-gradient(#dff0d8 0 180px,#98c991 180px 360px)}</style>
<main>Scrolltest voor de uitgezoomde maillezer</main>
<script>addEventListener('scroll',()=>document.title='zoom-scroll-'+Math.round(scrollY));</script>''')
  browser_log=(run/'firefox.log').open('w')
  browser=subprocess.Popen(['firefox','--no-remote','--profile',str(profile),document.as_uri()],
      env=dict(env,MOZ_ENABLE_WAYLAND='1',MOZ_DBUS_REMOTE='0',WAYLAND_DEBUG='client'),stdout=browser_log,stderr=subprocess.STDOUT)
  def browser_window():
   return next((w for w in json.loads(ctl('clients','-j')) if w['title'].startswith('zoom-scroll-')),None)
  for _ in range(150):
   firefox=browser_window()
   if firefox:break
   if browser.poll() is not None:raise RuntimeError('Firefox fixture exited: '+str(run/'firefox.log'))
   time.sleep(.1)
  check(bool(firefox),'isolated Firefox document started')
  view=json.loads(ctl('spatialoverview'))['screens'][0]['view']
  fx=int((firefox['at'][0]+firefox['size'][0]/2-view[0])*ww/view[2])
  fy=int((firefox['at'][1]+firefox['size'][1]*.7-view[1])*hh/view[3])
  def firefox_offset():return int(browser_window()['title'].split('zoom-scroll-')[1].split()[0])
  subprocess.run([vpointer,str(ww),str(hh),'abs',str(fx),str(fy),'sleep','150','wheel','1','sleep','350'],env=env,check=True)
  firefox_down=firefox_offset()
  pointer_log=(run/'firefox.log').read_text()
  wheel_values=re.findall(r'wl_pointer[#@]\d+\.axis_value120\((\d+), (-?\d+)\)',pointer_log)
  check(any(axis=='0' and int(value)>0 for axis,value in wheel_values),'Firefox receives nonzero high-resolution wheel steps')
  legacy_values=re.findall(r'wl_pointer[#@]\d+\.axis_discrete\((\d+), (-?\d+)\)',pointer_log)
  check(any(axis=='0' and value=='1' for axis,value in legacy_values),'legacy wheel events carry one detent rather than 120')
  check(firefox_down>0,'Firefox scrolls document down while zoomed')
  subprocess.run([vpointer,str(ww),str(hh),'abs',str(fx),str(fy),'sleep','100','wheel','-1','sleep','350'],env=env,check=True)
  check(firefox_offset()<firefox_down,'Firefox scrolls document back up while zoomed')
  browser.terminate();browser.wait(timeout=5);browser=None
  time.sleep(.3)
 if os.getenv('KINGSTRA_TEST_SCROLL_ONLY'):
  print('RUNTIME',run,flush=True)
  sys.exit(0)


 def pointer(*commands):
  outputs=json.loads(ctl('monitors','-j'))
  pw=max(m['x']+m['width']/m['scale'] for m in outputs);ph=max(m['y']+m['height']/m['scale'] for m in outputs)
  subprocess.run([vpointer,str(int(pw)),str(int(ph)),*map(str,commands)],env=env,check=True)
 def hold_modifiers(mods):
  ctl('eval','_G.test_mods_ready=false')
  cmd=['wtype']
  for mod in mods:cmd+=['-M',mod]
  cmd+=['-k','F24','-s','2500']
  for mod in reversed(mods):cmd+=['-m',mod]
  keys=subprocess.Popen(cmd,env=env)
  for _ in range(30):
   if ctl('repl','return test_mods_ready')=='true':return keys
   if keys.poll()!=None:break
   time.sleep(.03)
  raise AssertionError('virtual keyboard did not arm drag modifiers')
 def modified_drag(mods,x1,y1,x2,y2):
  keys=hold_modifiers(mods)
  pointer('abs',x1,y1,'sleep',100,'down','sleep',150,'abs',x2,y2,'sleep',350,'up','sleep',150)
  keys.wait(timeout=3)
 m=json.loads(ctl('monitors','-j'))[0];ww,hh=m['width'],m['height']
 camera_before=json.loads((run/'kingstra-spatial-1.json').read_text())
 # Move beyond the layout's proportional page-snap radius on every output size.
 modified_drag(['logo','ctrl'],ww//2,hh//2,ww//2+ww//6,hh//2+hh//6)
 time.sleep(.2)
 camera_after=json.loads((run/'kingstra-spatial-1.json').read_text())
 print('CAMERA',camera_before['camera'],camera_after['camera'],flush=True)
 check(camera_before['camera']!=camera_after['camera'],'real Super+Ctrl drag pans while zoomed')
 # Return to the previous page/camera before testing swap at scaled coordinates.
 ctl('dispatch','hl.dsp.layout("pan up")');ctl('dispatch','hl.dsp.layout("pan down")')
 ctl('dispatch','hl.dsp.layout("center")');time.sleep(.2)
 windows=json.loads(ctl('clients','-j'));state=json.loads(ctl('spatialoverview'));view=state['screens'][0]['view']
 aa=next(w for w in windows if w['title']=='zoom-A');bb=next(w for w in windows if w['title']=='zoom-B')
 def center(w):return [int((w['at'][i]+w['size'][i]/2-view[i])*[ww,hh][i]/view[i+2]) for i in (0,1)]
 source,dest=center(aa),center(bb)
 modified_drag(['logo'],*source,*dest);time.sleep(.2)
 updated=json.loads(ctl('clients','-j'));a_after=next(w for w in updated if w['title']=='zoom-A');b_after=next(w for w in updated if w['title']=='zoom-B')
 print('LOCAL DROP',[(w['title'],w['workspace'],w['at'],w['size']) for w in (a_after,b_after)],source,dest,flush=True)
 check(a_after['at'][0]>b_after['at'][0] and a_after['at'][1]==b_after['at'][1],'cross-page Super drag adds the app beside the target')
 check(not a_after['floating'] and not b_after['floating'],'zoomed drag keeps apps tiled')
 cells={w['address']:(w['col'],w['row']) for w in json.loads((run/'kingstra-spatial-1.json').read_text())['windows'] if not w.get('floating')}
 check(cells[aa['address']]==cells[bb['address']]==(1,0),'target stays on its page and the dragged app joins it')
 # Baseline has deliberately changed through the drag.
 before=updated
 ctl('eval','zoom.reset()');time.sleep(.4)
 check(not json.loads(ctl('spatialoverview'))['screens'],'reset returns to native 100%')
 check(positions(before)==positions(json.loads(ctl('clients','-j'))),'reset preserves pages and sizes')

 # Run the actual reset component against the disposable compositor.
 fd,qs_path=tempfile.mkstemp(prefix='.NativeZoomTest-',suffix='.qml',dir=root/'config/quickshell')
 qs_config=Path(qs_path)
 os.write(fd,b'import Quickshell\nShellRoot { LazyLoader { active: true; source: "desktop/SpatialZoomControl.qml" } }\n');os.close(fd)
 qs_log=(run/'quickshell.log').open('w')
 qs=subprocess.Popen(['quickshell','--no-duplicate','-p',str(qs_config)],env=env,stdout=qs_log,stderr=subprocess.STDOUT)
 ctl('eval','zoom.zoom("out")');time.sleep(.4)
 layers=[]
 for _ in range(30):
  data=json.loads(ctl('layers','-j'))
  layers=[l for monitor in data.values() for level in monitor.get('levels',{}).values() for l in level if l.get('namespace')=='quickshell:kingstra-native-zoom']
  if layers:break
  time.sleep(.1)
 check(bool(layers),'real reset control appears on the zoomed output')
 layer=layers[0];print('RESET LAYER',layer,flush=True);time.sleep(.3)
 subprocess.run(['grim',str(run/'reset-button.png')],env=env,check=True)
 pointer('abs',int(layer['x']+layer['w']/2),int(layer['y']+layer['h']/2),'sleep',120,'down','sleep',60,'up','sleep',200)
 time.sleep(.4)
 print('RESET STATE',ctl('spatialoverview'),flush=True)
 check(not json.loads(ctl('spatialoverview'))['screens'],'clicking the actual reset control restores 100%')
 # Add an independent output with a continuously frame-driven GTK app.
 ctl('output','create','wayland','ZOOM-2')
 for _ in range(100):
  mm=json.loads(ctl('monitors','-j'))
  if len(mm)==2 and all(m['width']>0 and m['height']>0 for m in mm):break
  time.sleep(.1)
 time.sleep(.3)
 mm=json.loads(ctl('monitors','-j'));print('MULTI OUTPUTS',[(m['name'],m['x'],m['y'],m['width'],m['height'],m['activeWorkspace']) for m in mm],flush=True)
 check(len(mm)==2 and all(m['width']>0 and m['height']>0 for m in mm),'two real nested outputs are active')
 second=next(m for m in mm if m['name']=='ZOOM-2');ws2=str(second['activeWorkspace']['id'])
 ctl('dispatch','hl.dsp.exec_cmd('+json.dumps('python3 '+str(root/'tests/integration/native-zoom-app.py')+' zoom-D > '+str(run/'zoom-D.log')+' 2>&1')+')')
 for _ in range(50):
  found=[w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-D']
  if found:break
  time.sleep(.1)
 check(bool(found),'frame-driven app starts')
 d=found[0]
 ctl('dispatch','hl.dsp.window.move({workspace="'+ws2+'",follow=false,window="address:'+d['address']+'"})')
 time.sleep(.4)
 d=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-D')
 check(str(d['workspace']['id'])==ws2,'animated app is on the other output')
 first=next(m for m in mm if m['name']=='WAYLAND-1')
 width=max(m['x']+m['width'] for m in mm);height=max(m['y']+m['height'] for m in mm)
 pointer('abs',str(first['x']+first['width']//2),str(first['y']+first['height']//2))
 ctl('dispatch','hl.dsp.focus({workspace="1"})');time.sleep(.2)
 def frame_count():return sum(l.startswith('frame zoom-D ') for l in (run/'zoom-D.log').read_text().splitlines())
 baseline=frame_count();time.sleep(.5);check(frame_count()>baseline,'other output receives ordinary frame callbacks')
 ctl('eval','zoom.zoom("out")');time.sleep(.3)
 baseline=frame_count();time.sleep(.8)
 print('OTHER OUTPUT FRAMES',baseline,frame_count(),flush=True)
 check(frame_count()>baseline,'other output keeps receiving frame callbacks during zoom')
 # Hover on the ordinary output must switch focus without a click too.
 dx=int(d['at'][0]+d['size'][0]/2);dy=int(d['at'][1]+d['size'][1]/2)
 pointer('abs',str(dx),str(dy),'sleep','180')
 check(json.loads(ctl('activewindow','-j'))['address']==d['address'],'hover on the other monitor selects its app without clicking')
 # Return the pointer and focus to an actually visible zoomed app.
 view=json.loads(ctl('spatialoverview'))['screens'][0]['view']
 first=next(m for m in json.loads(ctl('monitors','-j')) if m['name']=='WAYLAND-1')
 hovered=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-A')
 hx=int(first['x']+(hovered['at'][0]+hovered['size'][0]/2-view[0])*first['width']/view[2])
 hy=int(first['y']+(hovered['at'][1]+hovered['size'][1]/2-view[1])*first['height']/view[3])
 pointer('abs',str(hx),str(hy),'sleep','180')
 check(json.loads(ctl('activewindow','-j'))['address']==hovered['address'],'returning to the zoomed monitor focuses the same app without clicking')

 # A drag can originate on the ordinary output, outside any canvas listener.
 def cross_output_drag(w, dest):
  # Nested Wayland outputs can resize when the parent's layout changes. Read
  # the actual app box and its current zoom immediately before picking it up.
  current=next(c for c in json.loads(ctl('clients','-j')) if c['address']==w['address'])
  monitor=next(m for m in json.loads(ctl('monitors','-j')) if m['id']==current['monitor'])
  screen=next((s for s in json.loads(ctl('spatialoverview'))['screens'] if s['monitor']==monitor['name']),None)
  start=[int(current['at'][i]+current['size'][i]/2) for i in (0,1)]
  if screen:
   start=[int(monitor[['x','y'][i]]+(start[i]-screen['view'][i])*monitor[['width','height'][i]]/screen['view'][i+2]) for i in (0,1)]
  print('DRAG',w['title'],start,dest,flush=True)
  keys=hold_modifiers(['logo'])
  pointer('abs',*map(str,start),'sleep','120','down','sleep','90',
                  'abs',str(start[0]-50),str(start[1]),'sleep','90','abs',*map(str,dest),'sleep','180','up','sleep','180')
  keys.wait(timeout=3);time.sleep(.2)
 cross_camera=json.loads((run/'kingstra-spatial-1.json').read_text())['camera']
 cross_output_drag(d,(hx,hy))
 d=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-D')
 print('IMPORTED APP',d,flush=True)
 check(d['workspace']['id']==1 and not d['floating'],'drag from ordinary output joins the zoomed workspace and stays tiled')
 imported=json.loads((run/'kingstra-spatial-1.json').read_text())
 cells={w['address']:(w['col'],w['row']) for w in imported['windows'] if not w.get('floating')}
 check(cells[d['address']]==cells[hovered['address']],'cross-output drop joins the page under the scaled pointer')
 check(imported['camera']==cross_camera,'cross-output drop preserves the zoomed camera')
 # Reverse the same drag: a canvas grab must also land on an ordinary output
 # with no overview object, including an otherwise empty destination workspace.
 cross_output_drag(d,(dx,dy))
 d=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-D')
 check(str(d['workspace']['id'])==ws2 and not d['floating'],'drag out of zoom returns the tiled app to the ordinary output')
 check(json.loads((run/'kingstra-spatial-1.json').read_text())['camera']==cross_camera,'drag out of zoom preserves the source camera')
 pointer('abs',str(hx),str(hy),'sleep','150')

 # Open a real new application through the same keybind path as Super+Return.
 ctl('dispatch','hl.dsp.focus({workspace="1"})')
 cmd='python3 '+str(root/'tests/integration/native-zoom-app.py')+' zoom-E > '+str(run/'zoom-E.log')+' 2>&1'
 camera_before=json.loads((run/'kingstra-spatial-1.json').read_text())['camera']
 native_before=json.loads(ctl('spatialoverview'))['screens'][0]['view']
 ctl('eval','hl.window_rule({name="test-remember-float",match={title="^zoom-E$"},float=true,size="1800 1000",move="0 0"})')
 ctl('dispatch','hl.dsp.exec_cmd('+json.dumps(cmd)+')')
 for _ in range(50):
  found=[w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-E']
  if found:break
  time.sleep(.1)
 check(bool(found),'terminal launch opens the new app while zoomed')
 check(found[0]['floating'],'remembered floating preference is preserved')
 check(found[0]['workspace']['id']==1,'floating overflow fixture belongs to the zoomed output')
 time.sleep(.3)
 camera_after=json.loads((run/'kingstra-spatial-1.json').read_text())['camera']
 native_after=json.loads(ctl('spatialoverview'))['screens'][0]['view']
 print('NEW APP CAMERA',camera_before,camera_after,native_before,native_after,flush=True)
 check(camera_before==camera_after and native_before==native_after,'opening an app preserves both spatial and native cameras')

 # Gray animated app D fills the other display; green E must not bleed there.
 # Mapping clamps oversized floats in 0.57; explicitly create overflow after
 # checking that merely launching the app leaves both cameras unchanged.
 e=found[0]
 ctl('dispatch','hl.dsp.window.move({x=0,y=0,relative=false,window="address:'+e['address']+'"})')
 time.sleep(.2)
 e=next(w for w in json.loads(ctl('clients','-j')) if w['address']==e['address'])
 check(e['at'][0]+e['size'][0]>second['x'],'floating test window extends beyond its owning output')
 subprocess.run(['grim','-o','ZOOM-2',str(run/'foreign-during-zoom.png')],env=env,check=True)
 sample=Image.open(run/'foreign-during-zoom.png').convert('RGB').getpixel((min(100,second['width']-1),min(100,second['height']-1)))
 print('FOREIGN FLOAT PIXEL DURING ZOOM',sample,flush=True)
 check(max(sample)-min(sample)<20,'oversized floating app stays clipped to its zoomed monitor')
 pointer('abs',str(second['x']+min(100,second['width']-1)),str(second['y']+min(100,second['height']-1)),'sleep','200')
 check(json.loads(ctl('activewindow','-j'))['address']==d['address'],'hidden floating overflow cannot capture focus on the other monitor')
 ctl('eval','zoom.reset("WAYLAND-1")');time.sleep(.2)
 subprocess.run(['grim','-o','ZOOM-2',str(run/'foreign-at-100.png')],env=env,check=True)
 sample=Image.open(run/'foreign-at-100.png').convert('RGB').getpixel((min(100,second['width']-1),min(100,second['height']-1)))
 print('FOREIGN FLOAT PIXEL AT 100%',sample,flush=True)
 check(sample[1]>sample[0]+50,'100% restores normal cross-monitor floating rendering')
 # The oversized floating fixture would otherwise cover the tiled drag source.
 os.kill(e['pid'],15);time.sleep(.2)

 # Importing a floating app must retain its size and place its grabbed point
 # at the inverse-transformed pointer, rather than scaling its buffer.
 pointer('abs',first['x']+first['width']//2,first['y']+first['height']//2)
 ctl('dispatch','hl.dsp.focus({workspace="1"})');ctl('eval','zoom.zoom("out")');time.sleep(.3)
 pointer('abs',dx,dy);ctl('dispatch','hl.dsp.focus({workspace="'+ws2+'"})')
 ctl('eval','hl.window_rule({name="test-import-float",match={title="^zoom-F$"},float=true,size="300 200",move="100 100"})')
 cmd='python3 '+str(root/'tests/integration/native-zoom-app.py')+' zoom-F > '+str(run/'zoom-F.log')+' 2>&1'
 ctl('dispatch','hl.dsp.exec_cmd('+json.dumps(cmd)+')')
 for _ in range(50):
  found=[w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-F']
  if found:break
  time.sleep(.1)
 f=found[0];float_size=f['size']
 view=next(s for s in json.loads(ctl('spatialoverview'))['screens'] if s['monitor']=='WAYLAND-1')['view']
 dest=(first['x']+first['width']//2,first['y']+first['height']//2)
 world=[view[i]+(dest[i]-first[['x','y'][i]])*view[i+2]/first[['width','height'][i]] for i in (0,1)]
 cross_output_drag(f,dest)
 f=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-F')
 check(f['workspace']['id']==1 and f['floating'] and f['size']==float_size,'cross-output floating drop preserves floating mode and size')
 check(all(abs(f['at'][i]+f['size'][i]/2-world[i])<5 for i in (0,1)),'floating app lands at the inverse-scaled pointer position')
 cross_output_drag(f,(dx,dy))
 f=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-F')
 check(str(f['workspace']['id'])==ws2 and f['floating'] and f['size']==float_size,'floating drag out of zoom preserves its mode and size')
 check(all(abs(f['at'][i]+f['size'][i]/2-[dx,dy][i])<5 for i in (0,1)),'floating drag out lands at the ordinary desktop pointer')
 # Keep D unobstructed for the independent zoom-to-zoom route below.
 os.kill(f['pid'],15);time.sleep(.2)

 # The source may itself be zoomed, using a separate canvas drag instead of
 # Hyprland's native grab. Both routes must assign the destination workspace.
 pointer('abs',dx,dy);ctl('dispatch','hl.dsp.focus({workspace="'+ws2+'"})');ctl('eval','zoom.zoom("out")');time.sleep(.3)
 screens=json.loads(ctl('spatialoverview'))['screens']
 check(len(screens)==2,'both physical outputs can be zoomed independently')
 d=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-D')
 cross_output_drag(d,dest)
 d=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-D')
 check(d['workspace']['id']==1 and not d['floating'],'drag between two zoomed outputs transfers the app and keeps it tiled')

 # An ordinary destination can use stock Dwindle instead of the spatial layout.
 ctl('eval','zoom.reset("ZOOM-2")')
 second=next(m for m in json.loads(ctl('monitors','-j')) if m['name']=='ZOOM-2')
 pointer('abs',second['x']+second['width']//2,second['y']+second['height']//2,'sleep','120')
 ctl('dispatch','hl.dsp.focus({workspace="'+ws2+'"})');ctl('dispatch','hl.dsp.focus({workspace="3"})')
 cmd='python3 '+str(root/'tests/integration/native-zoom-app.py')+' zoom-G > '+str(run/'zoom-G.log')+' 2>&1'
 ctl('dispatch','hl.dsp.exec_cmd('+json.dumps(cmd)+')')
 for _ in range(50):
  found=[w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-G']
  if found:break
  time.sleep(.1)
 g=found[0]
 print('DWINDLE FIXTURE',g['workspace'],g['floating'],flush=True)
 check(g['workspace']['id']==3 and not g['floating'],'ordinary Dwindle destination is ready')
 d=next(w for w in json.loads(ctl('clients','-j')) if w['title']=='zoom-D')
 dest=[int(g['at'][i]+g['size'][i]/2) for i in (0,1)]
 cross_output_drag(d,dest)
 windows=json.loads(ctl('clients','-j'));d=next(w for w in windows if w['title']=='zoom-D');g=next(w for w in windows if w['title']=='zoom-G')
 print('DWINDLE DROP',[(w['title'],w['workspace']['id'],w['floating'],w['at'],w['size']) for w in (d,g)],flush=True)
 check(d['workspace']['id']==g['workspace']['id']==3 and not d['floating'] and not g['floating'],'drag out of zoom inserts into stock Dwindle without exchanging apps')
 overlap=[min(d['at'][i]+d['size'][i],g['at'][i]+g['size'][i])-max(d['at'][i],g['at'][i]) for i in (0,1)]
 check(min(overlap)<=0,'ordinary Dwindle tiles the dropped app beside its existing app')
 check('Lua error' not in (run/'hypr'/sig/'hyprland.log').read_text(),'no Lua runtime errors during real input')
 print('RUNTIME',run,flush=True)
finally:
 if browser and browser.poll()==None:
  browser.terminate()
  try:browser.wait(timeout=5)
  except subprocess.TimeoutExpired:browser.kill()
 if browser_log:browser_log.close()
 if qs and qs.poll()==None:
  qs.terminate()
  try:qs.wait(timeout=5)
  except subprocess.TimeoutExpired:qs.kill()
 if qs_log:qs_log.close()
 if qs_config:qs_config.unlink(missing_ok=True)
 if sig and proc.poll()==None:
  try:ctl('dispatch','hl.dsp.exit()')
  except Exception:proc.terminate()
 try:proc.wait(timeout=5)
 except subprocess.TimeoutExpired:proc.kill()
 log.close();print('TESTLOG',run,flush=True)
