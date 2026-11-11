#!/usr/bin/env python3
"""Smoke-test kingstra-battery-watch met een nep-/sys/class/power_supply.

Muisbatterij (scope Device) telt niet, drempels 20/10/5 elk één keer,
lader erin sluit de melding en zet alles terug, en bij 3% telt hij af
(slapen wordt hier vervangen door een teller).
"""
import importlib.machinery
import importlib.util
import os
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
tmp = tempfile.mkdtemp()
ps = os.path.join(tmp, "ps")
os.environ["KINGSTRA_POWER_SUPPLY"] = ps
os.environ["XDG_CONFIG_HOME"] = os.path.join(tmp, "cfg")
os.environ["PATH"] = os.path.join(tmp, "bin") + os.pathsep + os.environ["PATH"]
log = os.path.join(tmp, "notify.log")
os.makedirs(os.path.join(tmp, "bin"))
for name, body in (("notify-send", 'echo "$*" >> %s; echo 7' % log),
                   ("gdbus", 'echo "close $*" >> %s' % log),
                   ("pw-play", "true"), ("paplay", "true")):
    path = os.path.join(tmp, "bin", name)
    with open(path, "w") as fh:
        fh.write("#!/bin/sh\n%s\n" % body)
    os.chmod(path, 0o755)


def write(dev, **vals):
    d = os.path.join(ps, dev)
    os.makedirs(d, exist_ok=True)
    for k, v in vals.items():
        with open(os.path.join(d, k), "w") as fh:
            fh.write("%s\n" % v)


loader = importlib.machinery.SourceFileLoader(
    "bw", os.path.join(REPO, "config/shared/scripts/kingstra-battery-watch"))
spec = importlib.util.spec_from_loader("bw", loader)
bw = importlib.util.module_from_spec(spec)
loader.exec_module(bw)
bw.COUNTDOWN = 0

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


def lines():
    try:
        with open(log) as fh:
            return fh.read().splitlines()
    except OSError:
        return []


# Alleen een muis: geen laptopbatterij.
write("hidpp_battery_0", type="Battery", scope="Device", capacity=5, status="Discharging")
check(bw.read_battery() is None, "muisbatterij telde als laptopbatterij")

write("AC", type="Mains", online=0)
write("BAT0", type="Battery", status="Discharging", energy_full=50000000, energy_now=11000000,
      power_now=10000000)
bat = bw.read_battery()
check(bat and bat["percent"] == 22 and not bat["charging"], "stand verkeerd: %r" % bat)
check(bat and bat["minutes"] == 66, "resttijd verkeerd: %r" % bat)

w = bw.Watch()
slept = []
bw.do_sleep = lambda cfg: slept.append(1)
cfg = bw.load_config()


def at(pct, charging=False):
    write("BAT0", energy_now=pct * 500000, status="Charging" if charging else "Discharging")
    write("AC", online=1 if charging else 0)
    w.tick(cfg, bw.read_battery())


at(22); check(len(lines()) == 0, "melding boven 20%")
at(20); check(len(lines()) == 1 and "Batterij op 20%" in lines()[-1] and "-u normal" in lines()[-1], "20%%: %r" % lines())
at(19); check(len(lines()) == 1, "20% twee keer gemeld")
at(10); check(len(lines()) == 2 and "-u critical" in lines()[-1] and "-r 7" in lines()[-1], "10%%: %r" % lines()[-1:])
at(5); check("bijna leeg: 5%" in lines()[-1] and "Bij 3%" in lines()[-1], "5%%: %r" % lines()[-1:])
n = len(lines())
at(5, charging=True); check(any(l.startswith("close") for l in lines()[n:]), "lader sloot melding niet")
check(not w.fired, "drempels niet teruggezet na laden")
os.remove(log)
at(4); check(len(lines()) == 1 and "bijna leeg: 4%" in lines()[0], "na laden geen nieuwe melding: %r" % lines())
at(3); check(slept == [1], "niet geslapen bij 3%")
at(3); check(slept == [1], "direct na wakker worden opnieuw geslapen")

# Start op 4%: alleen de laagste melding, niet drie tegelijk.
os.remove(log)
w = bw.Watch()
at(4)
check(len(lines()) == 1 and "bijna leeg: 4%" in lines()[0], "start op 4%%: %r" % lines())

# Uit via batterij.json.
os.makedirs(os.path.join(tmp, "cfg/kingstra"), exist_ok=True)
with open(os.path.join(tmp, "cfg/kingstra/batterij.json"), "w") as fh:
    fh.write('{"aan": false}')
cfg = bw.load_config()
w = bw.Watch()
os.remove(log)
at(4)
check(not any("Batterij" in l for l in lines()), "meldt terwijl uitgezet")

if fails:
    print("FAIL battery-watch:\n  " + "\n  ".join(fails))
    sys.exit(1)
print("ok battery-watch")
