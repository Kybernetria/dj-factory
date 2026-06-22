import json
import os
import shutil
import sys

if len(sys.argv) < 2:
    print("Error: No target directory provided.")
    sys.exit(1)

target_dir = os.path.expanduser(sys.argv[1])
ffmpeg_bin = os.environ.get("FFMPEG_BIN") or shutil.which("ffmpeg") or "ffmpeg"

DESIRED_SETTINGS = {
    "download_base_path": target_dir,
    "skip_existing": False,
    "video_download": False,
    "path_binary_ffmpeg": ffmpeg_bin,
    "extract_flac": True,
    "symlink_to_track": False,
    "quality_audio": "HI_RES_LOSSLESS",
    "format_playlist": "{artist_name} - {track_title}",
    "format_track": "{artist_name} - {track_title}",
    "format_album": "{artist_name} - {track_title}"
}

possible_paths = [
    os.path.expanduser("~/.config/tidal_dl_ng/settings.json"),
    os.path.expanduser("~/.tidal-dl.json")
]

config_found = False

for config_path in possible_paths:
    if os.path.exists(config_path):
        print(f"Found config at: {config_path}")
        try:
            with open(config_path, 'r') as f:
                data = json.load(f)

            for key, value in DESIRED_SETTINGS.items():
                data[key] = value

            with open(config_path, 'w') as f:
                json.dump(data, f, indent=4)

            print("✅ Config updated successfully.")
            config_found = True
            break
        except Exception as e:
            print(f"⚠️ Failed to update {config_path}: {e}")

if not config_found:
    default_path = possible_paths[0]
    print(f"No config found. Creating new at: {default_path}")

    try:
        os.makedirs(os.path.dirname(default_path), exist_ok=True)
        with open(default_path, 'w') as f:
            json.dump(DESIRED_SETTINGS, f, indent=4)
        print("✅ New config created.")
    except Exception as e:
        print(f"❌ Critical Error creating config: {e}")
        sys.exit(1)
