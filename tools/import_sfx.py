#!/usr/bin/env python3
"""Builds audio/sfx and audio/music from the downloaded CC0 files: picks the sounds listed in SFX,
converts them to mono 44.1 kHz WAV, trims leading/trailing silence and evens out their loudness;
copies the MUSIC tracks (WAV tracks are encoded to OGG). Also writes audio/CREDITS.md.
Needs ffmpeg on the PATH; no Python dependencies.

Usage: python3 tools/import_sfx.py <downloads_dir> [project_dir]
<downloads_dir> holds each pack unpacked in its own folder (see PACKS for the folder names) and
the music files, under their original names, in music/. Run tools/synth_sfx.py as well for the
synthesized sounds. Output files are named <id>_<n>.wav; scripts/autoload/audio.gd lists how many
variations each id has and which music file each track uses.
"""
import array
import math
import os
import subprocess
import sys
import tempfile

TARGET_RMS_DB = -16.0
PEAK_LIMIT_DB = -1.0

# key: (title, author, page, folder inside downloads_dir)
PACKS = {
    "kenney_rpg": ("50 RPG sound effects", "Kenney (kenney.nl)",
                   "https://opengameart.org/content/50-rpg-sound-effects", "kenney_rpg/OGG"),
    "kenney_ui": ("Interface Sounds", "Kenney (kenney.nl)",
                  "https://opengameart.org/content/interface-sounds", "kenney_ui/Audio"),
    "artisticdude": ("RPG Sound Pack", "artisticdude",
                     "https://opengameart.org/content/rpg-sound-pack", "artisticdude_rpg/RPG Sound Pack"),
    "rd_creature": ("80 CC0 creature SFX", "rubberduck",
                    "https://opengameart.org/content/80-cc0-creature-sfx", "rubberduck_creature"),
    "rd_hits": ("75 CC0 breaking / falling / hit sfx", "rubberduck",
                "https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx", "rubberduck_hits"),
    "rd_100": ("100 CC0 SFX", "rubberduck",
               "https://opengameart.org/content/100-cc0-sfx", "rubberduck_100"),
}

# Sound id -> variations (pack, file inside the pack folder).
SFX = {
    "swing": [("artisticdude", "battle/swing.wav"), ("artisticdude", "battle/swing2.wav"),
              ("artisticdude", "battle/swing3.wav")],
    "hit": [("kenney_rpg", "knifeSlice.ogg"), ("kenney_rpg", "knifeSlice2.ogg"), ("kenney_rpg", "chop.ogg")],
    "kill_bone": [("rd_hits", "bfh1_wood_breaking_01.ogg"), ("rd_hits", "bfh1_wood_breaking_03.ogg"),
                  ("rd_hits", "bfh1_wood_breaking_04.ogg"), ("rd_hits", "bfh1_breaking_02.ogg")],
    "kill_flesh": [("rd_creature", "hurt_01.ogg"), ("rd_creature", "hurt_02.ogg"), ("rd_creature", "hurt_05.ogg")],
    "kill_heavy": [("rd_hits", "bfh1_rock_breaking_01.ogg"), ("rd_hits", "bfh1_rock_breaking_02.ogg"),
                   ("rd_hits", "bfh1_rock_breaking_03.ogg")],
    "player_hurt": [("rd_hits", "bfh1_hit_07.ogg"), ("rd_100", "hit_03.ogg"), ("rd_hits", "bfh1_wood_hit_03.ogg")],
    "player_death": [("rd_100", "gong_02.ogg")],
    "gold": [("artisticdude", "inventory/coin.wav"), ("artisticdude", "inventory/coin3.wav"),
             ("kenney_rpg", "handleCoins2.ogg")],
    "chest": [("rd_100", "wooded_box_open.ogg")],
    "item": [("artisticdude", "inventory/metal-ringing.wav")],
    "boon": [("kenney_ui", "confirmation_001.ogg"), ("kenney_ui", "confirmation_004.ogg")],
    "soul_chain": [("artisticdude", "inventory/chainmail1.wav"), ("kenney_rpg", "metalLatch.ogg")],
    "frost_nova": [("rd_hits", "bfh1_glass_breaking_02.ogg"), ("rd_hits", "bfh1_glass_breaking_05.ogg"),
                   ("rd_hits", "bfh1_glass_breaking_01.ogg")],
    "bone_shield": [("artisticdude", "inventory/beads.wav"), ("rd_hits", "bfh1_wood_hit_01.ogg")],
    "slam": [("rd_100", "slam_02.ogg"), ("rd_100", "slam_03.ogg")],
    "war_cry": [("rd_creature", "roar_02.ogg"), ("rd_creature", "troll_02.ogg")],
    "thunder": [("rd_100", "explosion.ogg")],
    "sword_drop": [("rd_hits", "bfh1_metal_hit_02.ogg"), ("rd_hits", "bfh1_metal_hit_04.ogg"),
                   ("rd_hits", "bfh1_metal_hit_06.ogg")],
    "blade": [("artisticdude", "battle/sword-unsheathe.wav"), ("artisticdude", "battle/sword-unsheathe3.wav"),
              ("artisticdude", "battle/sword-unsheathe4.wav")],
    "boss_roar": [("rd_creature", "monster_04.ogg"), ("rd_creature", "monster_07.ogg")],
    "boss_growl": [("artisticdude", "NPC/giant/giant2.wav"), ("artisticdude", "NPC/giant/giant5.wav"),
                   ("artisticdude", "NPC/ogre/ogre3.wav")],
    "boss_summon": [("artisticdude", "NPC/shade/shade12.wav"), ("artisticdude", "NPC/shade/shade7.wav")],
    "gong": [("rd_100", "gong_01.ogg")],
    "bell": [("rd_100", "bell_01.ogg")],
    "extract": [("rd_100", "bell_03.ogg")],
    "howl": [("rd_creature", "howl.ogg")],
    "bong": [("kenney_ui", "bong_001.ogg")],
    "gate_break": [("kenney_ui", "error_006.ogg")],
    "equip": [("artisticdude", "inventory/armor-light.wav"), ("artisticdude", "inventory/chainmail2.wav")],
    "unequip": [("artisticdude", "inventory/cloth-heavy.wav")],
    "tick": [("kenney_ui", "tick_004.ogg")],
    "ui_click": [("kenney_ui", "click_001.ogg"), ("kenney_ui", "click_003.ogg")],
    "ui_hover": [("kenney_ui", "tick_001.ogg")],
    "ui_confirm": [("kenney_ui", "confirmation_002.ogg")],
    "ui_error": [("kenney_ui", "error_004.ogg")],
    "ui_back": [("kenney_ui", "back_002.ogg")],
    "ui_tab": [("kenney_ui", "switch_002.ogg")],
    "ui_open": [("kenney_ui", "open_002.ogg")],
    "ui_close": [("kenney_ui", "close_002.ogg")],
}

SYNTHESIZED = ["xp", "level_up", "core", "gate_hum", "heartbeat", "fire_wave"]

# (output file, title, author, page, original file in downloads_dir/music, where it plays)
MUSIC = [
    ("dark_shrine_loop.ogg", "Dark Shrine Loop", "qubodup (remix of yd's \"Shrine\")",
     "https://opengameart.org/node/12501", "qubodup-yd-DarkShrineLoop-OpenGameArt.ogg", "in the camp"),
    ("dungeon_ambience.ogg", "Dungeon Ambience", "yd",
     "https://opengameart.org/content/dungeon-ambience", "dungeon002_0.ogg", "during runs"),
    ("epic_boss_battle.ogg", "Boss Battle Music (Epic Boss Battle)", "Juhani Junkala (SubspaceAudio)",
     "https://opengameart.org/node/55649", "Juhani Junkala - Epic Boss Battle [Seamlessly Looping].wav",
     "during boss fights and the final escape"),
]
# FFmpeg's built-in Vorbis encoder pads the end to a multiple of this many samples; trimming the
# input to such a multiple keeps the decoded length exact, so a seamless loop stays seamless.
VORBIS_BLOCK = 64

TRIM = ("silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.004,"
        "areverse,silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.03,areverse")


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def levels(path):
    """Peak and RMS in dBFS of a 16-bit mono WAV (data chunk read through ffmpeg)."""
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    samples = array.array("h")
    samples.frombytes(raw[: len(raw) // 2 * 2])
    peak = max((abs(s) for s in samples), default=1) / 32768.0
    rms = math.sqrt(sum(s * s for s in samples) / max(len(samples), 1)) / 32768.0
    to_db = lambda v: 20.0 * math.log10(v) if v > 0 else -120.0
    return to_db(peak), to_db(rms)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    downloads = sys.argv[1]
    project = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(project, "audio", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    with tempfile.TemporaryDirectory() as tmp:
        for sound_id, variations in SFX.items():
            for index, (pack, name) in enumerate(variations, start=1):
                source = os.path.join(downloads, PACKS[pack][3], name)
                trimmed = os.path.join(tmp, "trimmed.wav")
                ffmpeg("-i", source, "-ac", "1", "-ar", "44100", "-af", TRIM, "-c:a", "pcm_s16le", trimmed)
                peak, rms = levels(trimmed)
                gain = min(TARGET_RMS_DB - rms, PEAK_LIMIT_DB - peak)
                target = os.path.join(out_dir, "%s_%d.wav" % (sound_id, index))
                ffmpeg("-i", trimmed, "-af", "volume=%.2fdB" % gain, "-c:a", "pcm_s16le", target)
                rows.append((os.path.basename(target), pack, name))
                print("%-22s <- %s/%s  (gain %+.1f dB)" % (os.path.basename(target), pack, name, gain))
    import_music(downloads, project)
    write_credits(project, rows)


def import_music(downloads, project):
    out_dir = os.path.join(project, "audio", "music")
    os.makedirs(out_dir, exist_ok=True)
    for target, _title, _author, _page, name, _use in MUSIC:
        source = os.path.join(downloads, "music", name)
        destination = os.path.join(out_dir, target)
        if name.lower().endswith(".ogg"):
            ffmpeg("-i", source, "-c:a", "copy", destination)
        else:
            frames = int(subprocess.run(
                ["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=duration_ts",
                 "-of", "csv=p=0", source], capture_output=True, check=True, text=True).stdout.strip())
            keep = frames // VORBIS_BLOCK * VORBIS_BLOCK
            ffmpeg("-i", source, "-af", "atrim=end_sample=%d" % keep, "-c:a", "vorbis", "-strict", "experimental",
                   "-q:a", "6", destination)
        print("%-22s <- music/%s" % (target, name))


def write_credits(project, rows):
    lines = [
        "# Audio Credits",
        "",
        "All sound effects and music come from CC0 (public domain) releases on OpenGameArt; no",
        "attribution is required, but the authors are listed here with thanks. Sound effects were",
        "trimmed, converted to mono WAV and loudness-matched by `tools/import_sfx.py`.",
        "",
        "## Sound effect packs",
        "",
    ]
    for key, (title, author, page, _folder) in PACKS.items():
        lines.append("- [%s](%s) by %s, CC0" % (title, page, author))
    lines += [
        "",
        "## Synthesized",
        "",
        "Made for this project by `tools/synth_sfx.py` (same license as the project): %s." % ", ".join(
            "`%s`" % s for s in SYNTHESIZED),
        "",
        "## Music",
        "",
    ]
    for target, title, author, page, name, use in MUSIC:
        note = " (converted to OGG)" if not name.lower().endswith(".ogg") else ""
        lines.append("- `%s`: [%s](%s) by %s, CC0; plays %s%s" % (target, title, page, author, use, note))
    lines += [
        "",
        "## Sound effect sources",
        "",
        "| File | Pack | Original file |",
        "|---|---|---|",
    ]
    for target, pack, name in rows:
        lines.append("| `%s` | %s | `%s` |" % (target, PACKS[pack][0], name))
    with open(os.path.join(project, "audio", "CREDITS.md"), "w") as out:
        out.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
