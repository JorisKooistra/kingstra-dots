#!/usr/bin/env python3
"""Live-omzetter voor kingstra-dictate.

Leest de wav die pw-record/parecord aan het schrijven is, knipt die bij
pauzes in stukjes en zet elk stukje meteen om met whisper.cpp. Zo staat de
tekst al klaar (of wordt hij al getypt) terwijl je nog praat.

Gebruik: kingstra-dictate-live.py WERKMAP

Bestanden in WERKMAP (door kingstra-dictate gezet):
  opname.wav   groeiende opname (16 kHz, mono, s16)
  live         bestaat: getypt mag meteen (tik-modus)
  stop         bestaat: opname is klaar, rest afmaken en stoppen
  cancel       bestaat: alles weggooien
Omgeving: KD_WHISPER, KD_MODEL, KD_LANG, KD_TYPE (commando dat tekst op
stdin typt).
"""
import array
import math
import os
import re
import subprocess
import sys
import time
import wave

RATE = 16000
FRAME = 480                 # 30 ms
PAUSE_FRAMES = 20           # 0,6 s stilte sluit een zin af
MIN_SPEECH_FRAMES = 10      # minder dan 0,3 s spraak: overslaan
MAX_SEGMENT_FRAMES = 300    # na 9 s toch knippen (bij een stilste moment)
POLL = 0.1
LIVE_LIMIT = float(os.environ.get("KD_LIVE_LIMIT", "300"))

work = sys.argv[1]
audio_path = os.path.join(work, "opname.wav")
whisper = os.environ.get("KD_WHISPER", "whisper-cli")
model = os.environ.get("KD_MODEL", "")
lang = os.environ.get("KD_LANG", "nl")
type_cmd = os.environ.get("KD_TYPE", "")


def flag(name):
    return os.path.exists(os.path.join(work, name))


def log(msg):
    with open(os.path.join(work, "live.log"), "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")


def data_offset(fh):
    """Zoek het begin van het data-blok; None zolang de kop nog niet compleet is."""
    fh.seek(0)
    head = fh.read(4096)
    if len(head) < 12 or head[:4] != b"RIFF":
        return None
    pos = 12
    while pos + 8 <= len(head):
        cid = head[pos:pos + 4]
        size = int.from_bytes(head[pos + 4:pos + 8], "little")
        if cid == b"data":
            return pos + 8
        pos += 8 + size + (size & 1)
    return None


def rms(samples):
    if not samples:
        return 0.0
    return math.sqrt(sum(s * s for s in samples) / len(samples))


NOISE = re.compile(r"\[[^\]]*\]|\([^)]*\)|\*[^*]*\*")
# Bekende whisper-verzinsels op stilte.
HALLUCINATIONS = {
    "ondertiteling", "ondertitels", "bedankt voor het kijken", "dank u wel voor het kijken",
    "thank you", "thanks for watching", "you",
}


def transcribe(samples):
    path = os.path.join(work, "stuk.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(array.array("h", samples).tobytes())
    try:
        out = subprocess.run(
            [whisper, "-m", model, "-l", lang, "-nt", "-np", "-f", path],
            capture_output=True, text=True, timeout=120).stdout
    except Exception as exc:  # noqa: BLE001 — nooit de hele dicteersessie laten crashen
        log("whisper mislukt: %s" % exc)
        return ""
    text = NOISE.sub(" ", out.replace("\n", " "))
    text = re.sub(r"\s+", " ", text).strip()
    if text.lower().strip(" .!?,") in HALLUCINATIONS:
        return ""
    return text


typed_any = False
pending = []
stop_seen = None
# Na loslaten van Super+H nog even wachten: zolang Super ingedrukt is, zou
# getypte tekst als Super+letter binnenkomen.
RELEASE_GRACE = 0.6


def can_type():
    global stop_seen
    if flag("live"):
        return True
    if flag("stop"):
        if stop_seen is None:
            stop_seen = time.time()
        return time.time() - stop_seen >= RELEASE_GRACE
    return False


def flush():
    if can_type() and not flag("cancel"):
        while pending:
            type_out(pending.pop(0))


def type_out(text):
    global typed_any
    chunk = (" " if typed_any else "") + text
    typed_any = True
    subprocess.run(["sh", "-c", type_cmd], input=chunk, text=True)
    with open(os.path.join(work, "getypt.txt"), "a") as f:
        f.write(chunk)


def emit(text):
    if text:
        pending.append(text)
    flush()


def main():
    # Wachten tot de opname bestaat en een kop heeft.
    fh = None
    offset = None
    deadline = time.time() + 5
    while time.time() < deadline and not flag("cancel"):
        if os.path.exists(audio_path):
            fh = open(audio_path, "rb")
            offset = data_offset(fh)
            if offset is not None:
                break
            fh.close()
            fh = None
        if flag("stop"):
            break
        time.sleep(0.05)
    if fh is None or offset is None:
        log("geen opname gevonden")
        finish()
        return

    pos = offset
    leftover = b""
    segment = []            # samples van de huidige zin (incl. stukje stilte ervoor)
    frames_rms = []         # rms per frame in segment
    speech_frames = 0
    silence_run = 0
    noise_floor = None
    in_speech = False
    lead = []               # 0,3 s voorloop zodat het eerste woord niet wordt afgekapt

    def cut(upto=None):
        nonlocal segment, frames_rms, speech_frames, silence_run, in_speech
        take = segment if upto is None else segment[:upto * FRAME]
        rest = [] if upto is None else segment[upto * FRAME:]
        if os.environ.get("KD_DEBUG"):
            log("knip: %d frames, %d spraak" % (len(take) // FRAME, speech_frames))
        if speech_frames >= MIN_SPEECH_FRAMES:
            emit(transcribe(take))
        segment, frames_rms = rest, frames_rms[upto:] if upto is not None else []
        speech_frames = sum(1 for r in frames_rms if r > threshold())
        silence_run = 0
        in_speech = bool(segment)

    def threshold():
        return max(350.0, (noise_floor or 150.0) * 3.0)

    live_since = None
    auto_stopped = False
    while True:
        if flag("cancel"):
            fh.close()
            return
        if flag("live") and live_since is None:
            live_since = time.time()
        if live_since and not auto_stopped and time.time() - live_since > LIVE_LIMIT:
            # Vergeten uit te zetten: na vijf minuten zelf stoppen.
            auto_stopped = True
            subprocess.Popen([os.path.join(os.path.dirname(os.path.realpath(__file__)), "kingstra-dictate"), "toggle"],
                             start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        stopping = flag("stop")
        fh.seek(pos)
        data = fh.read()
        pos += len(data)
        data = leftover + data
        usable = len(data) - (len(data) % (FRAME * 2))
        leftover = data[usable:]
        samples = array.array("h")
        samples.frombytes(data[:usable])
        for i in range(0, len(samples), FRAME):
            frame = samples[i:i + FRAME].tolist()
            level = rms(frame)
            # Ruisvloer volgt langzaam de stilste frames.
            if noise_floor is None:
                noise_floor = level
            elif level < noise_floor * 2:
                noise_floor = noise_floor * 0.95 + level * 0.05
            loud = level > threshold()
            if not in_speech:
                lead = (lead + frame)[-FRAME * 10:]
                if loud:
                    in_speech = True
                    segment = list(lead)
                    frames_rms = [threshold() * 0.5] * (len(lead) // FRAME)
                    speech_frames = 1
                    silence_run = 0
                continue
            segment.extend(frame)
            frames_rms.append(level)
            if loud:
                speech_frames += 1
                silence_run = 0
            else:
                silence_run += 1
            if silence_run >= PAUSE_FRAMES:
                cut()
                lead = []
            elif len(frames_rms) >= MAX_SEGMENT_FRAMES:
                # Knippen op het stilste frame in de laatste 3 s.
                window = frames_rms[-100:]
                quiet = len(frames_rms) - 100 + window.index(min(window)) + 1
                cut(quiet)
        if stopping and not samples and not leftover:
            # Opname klaar en alles gelezen: laatste zin afmaken.
            if in_speech:
                cut()
            break
        if stopping and len(data) < FRAME * 2:
            if in_speech:
                cut()
            break
        flush()
        time.sleep(POLL)
    fh.close()
    finish()


def finish():
    # Wachten op loslaten (vasthoud-modus): dan pas typen.
    while pending and not can_type() and not flag("cancel"):
        time.sleep(0.05)
    flush()
    open(os.path.join(work, "klaar"), "w").close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        log("fout: %r" % exc)
        open(os.path.join(work, "klaar"), "w").close()
