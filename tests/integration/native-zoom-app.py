import sys,gi
from pathlib import Path
gi.require_version('Gtk','4.0')
from gi.repository import Gtk,Gdk,Gio
name=sys.argv[1]
def activate(app):
 w=Gtk.ApplicationWindow(application=app,title=name);w.set_default_size(640,400)
 box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL);box.append(Gtk.Label(label=name)); area=Gtk.DrawingArea();area.set_hexpand(True);area.set_vexpand(True)
 colors={'zoom-A':(0.9,0.2,0.2),'zoom-B':(0.2,0.8,0.3),'zoom-C':(0.2,0.3,0.9),'zoom-E':(0.2,0.9,0.2)}
 def draw(a,cr,ww,hh): cr.set_source_rgb(*colors.get(name,(0.5,0.5,0.5)));cr.paint()
 area.set_draw_func(draw)
 if name=='zoom-B':
  # A real scrolling document, like the mail reader that exposed lost wheel input.
  scroller=Gtk.ScrolledWindow();scroller.set_hexpand(True);scroller.set_vexpand(True)
  area.set_content_height(4000);scroller.set_child(area);box.append(scroller)
  adjustment=scroller.get_vadjustment()
  adjustment.connect('value-changed',lambda a: print(f'offset {name} {a.get_value():.2f}',flush=True))
 else:box.append(area)
 w.set_child(box)
 frame=[0]
 def tick(widget,clock):
  frame[0]+=1;widget.queue_draw()
  if frame[0]%12==0:print(f'frame {name} {frame[0]}',flush=True)
  return True
 if name=='zoom-D':area.add_tick_callback(tick)
 click=Gtk.GestureClick();click.connect('pressed',lambda g,n,x,y: print(f'click {name} {x:.0f} {y:.0f}',flush=True));area.add_controller(click)
 keys=Gtk.EventControllerKey();keys.connect('key-pressed',lambda c,k,code,state: print(f'key {name} {Gdk.keyval_name(k)}',flush=True) or False);w.add_controller(keys)
 w.present()
a=Gtk.Application(application_id='dev.kingstra.zoomtest',flags=Gio.ApplicationFlags.NON_UNIQUE);a.connect('activate',activate);a.run(None)
