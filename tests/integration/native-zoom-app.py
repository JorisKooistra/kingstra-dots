import sys,gi
from pathlib import Path
gi.require_version('Gtk','4.0')
from gi.repository import Gtk,Gdk,Gio
name=sys.argv[1]
def activate(app):
 w=Gtk.ApplicationWindow(application=app,title=name);w.set_default_size(640,400)
 box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL);box.append(Gtk.Label(label=name)); area=Gtk.DrawingArea();area.set_hexpand(True);area.set_vexpand(True)
 colors={'zoom-A':(0.9,0.2,0.2),'zoom-B':(0.2,0.8,0.3),'zoom-C':(0.2,0.3,0.9)}
 def draw(a,cr,ww,hh): cr.set_source_rgb(*colors.get(name,(0.5,0.5,0.5)));cr.paint()
 area.set_draw_func(draw);box.append(area);w.set_child(box)
 click=Gtk.GestureClick();click.connect('pressed',lambda g,n,x,y: print(f'click {name} {x:.0f} {y:.0f}',flush=True));area.add_controller(click)
 keys=Gtk.EventControllerKey();keys.connect('key-pressed',lambda c,k,code,state: print(f'key {name} {Gdk.keyval_name(k)}',flush=True) or False);w.add_controller(keys)
 w.present()
a=Gtk.Application(application_id='dev.kingstra.zoomtest',flags=Gio.ApplicationFlags.NON_UNIQUE);a.connect('activate',activate);a.run(None)
