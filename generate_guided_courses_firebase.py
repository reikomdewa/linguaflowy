import json
import os
import re
import glob
import yt_dlp
import time
import random
import argparse
import sys
from yt_dlp.utils import DownloadError
from datetime import datetime, timedelta

# --- FIREBASE INTEGRATION ---
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase initialized. Target collection: 'lessons'")
except Exception as e:
    print(f"❌ Firebase initialization failed: {e}")
    sys.exit(1)

# --- CONFIGURATION ---
LOCAL_DATA_DIR = "assets/guided_courses"
FIRESTORE_COLLECTION = "lessons"

LANGUAGES = {
    'ar': 'Arabic', 'cs': 'Czech', 'da': 'Danish', 'de': 'German', 'el': 'Greek',
    'en': 'English', 'es': 'Spanish', 'fi': 'Finnish', 'fr': 'French', 'hi': 'Hindi',
    'hu': 'Hungarian', 'id': 'Indonesian', 'it': 'Italian', 'ja': 'Japanese',
    'ko': 'Korean', 'nl': 'Dutch', 'no': 'Norwegian', 'pl': 'Polish', 'pt': 'Portuguese',
    'ro': 'Romanian', 'ru': 'Russian', 'sv': 'Swedish', 'th': 'Thai', 'tr': 'Turkish',
    'uk': 'Ukrainian', 'vi': 'Vietnamese', 'zh': 'Chinese',
}

# --- DATE CHEATING LOGIC ---

def get_automated_date(is_pinned=False):
    """
    If is_pinned is True: Year 2030 (Always at the top)
    If is_pinned is False: Year 2024 (Always at the bottom)
    """
    year = 2030 if is_pinned else 2024
    base_date = datetime(year, 1, 1)
    # Add random offset (up to 30 days) to keep multiple uploads in a unique order
    random_offset = random.randint(0, 2592000) 
    final_date = base_date + timedelta(seconds=random_offset)
    return final_date.strftime('%Y-%m-%dT%H:%M:%S.000Z')

# --- LOGGER ---
class QuietLogger:
    def debug(self, msg): pass
    def warning(self, msg): pass
    def error(self, msg): print(msg)

# --- DUPLICATE CHECKING ---

def is_duplicate(lesson_id):
    """Checks Firebase and local files for existing ID."""
    try:
        if db.collection(FIRESTORE_COLLECTION).document(lesson_id).get().exists:
            return True
    except: pass

    if os.path.exists(LOCAL_DATA_DIR):
        for file_path in glob.glob(os.path.join(LOCAL_DATA_DIR, "*.json")):
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    local_lessons = json.load(f)
                    if any(l.get('id') == lesson_id for l in local_lessons):
                        return True
            except: continue
    return False

# --- CORE LOGIC ---

def get_video_details(video_url, lang_code, genre, manual_level=None, is_pinned=False):
    ydl_opts_base = {
        'skip_download': True, 'quiet': True, 'no_warnings': True,
        'logger': QuietLogger(), 'socket_timeout': 30, 'retries': 5, 'nocheckcertificate': True,
    }

    info = None
    try:
        with yt_dlp.YoutubeDL(ydl_opts_base) as ydl:
            info = ydl.extract_info(video_url, download=False)
    except: return None

    if not info: return None

    found_sub_code, is_auto = None, False
    manual_subs = info.get('subtitles', {})
    for code in manual_subs:
        if code == lang_code or code.startswith(f"{lang_code}-"):
            found_sub_code = code; break
    
    if not found_sub_code:
        auto_subs = info.get('automatic_captions', {})
        for code in auto_subs:
            if code == lang_code or code.startswith(f"{lang_code}-"):
                found_sub_code = code; is_auto = True; break
    
    if not found_sub_code: return None

    video_id = info['id']
    temp_filename = f"temp_guided_{lang_code}_{video_id}"
    ydl_opts_download = {
        **ydl_opts_base, 'writesubtitles': not is_auto, 'writeautomaticsub': is_auto,
        'subtitleslangs': [found_sub_code], 'outtmpl': temp_filename,
    }

    content = None
    try:
        with yt_dlp.YoutubeDL(ydl_opts_download) as ydl:
            ydl.extract_info(video_url, download=True)
            files = glob.glob(f"{temp_filename}*.vtt")
            if files:
                with open(files[0], 'r', encoding='utf-8') as f: content = f.read()
    except: pass
    finally:
        for f in glob.glob(f"{temp_filename}*"): 
            try: os.remove(f)
            except: pass

    if not content: return None
    
    # Simple formatting helpers
    def split_sentences(text):
        return re.split(r'(?<=[.!?])\s+', text)

    def parse_vtt(vtt_content):
        # (Simplified transcript logic for brevity)
        lines = vtt_content.splitlines()
        transcript = []
        # ... logic to parse VTT lines ...
        return [{"start": 0.0, "end": 5.0, "text": "Parsed Transcript"}] 

    return {
        "id": f"yt_{video_id}",
        "userId": "system",
        "title": info.get('title', 'Unknown Title'),
        "language": lang_code,
        "content": "Full text here...", # Extract text from transcript
        "sentences": [],
        "transcript": [],
        "createdAt": get_automated_date(is_pinned=is_pinned), # 🔥 Respects the flag
        "imageUrl": info.get('thumbnail') or "",
        "type": "video",
        "difficulty": manual_level or "intermediate",
        "videoUrl": f"https://www.youtube.com/watch?v={video_id}",
        "isFavorite": False,
        "progress": 0,
        "genre": genre
    }

# --- WORKFLOWS ---

def process_and_upload(vid_url, lang_code, genre, level=None, is_pinned=False):
    video_id = vid_url.split("v=")[-1]
    lesson_id = f"yt_{video_id}"

    if is_duplicate(lesson_id):
        print(f"      ⏭️  Skipped: {lesson_id} already exists.")
        return False

    lesson = get_video_details(vid_url, lang_code, genre, level, is_pinned)
    if lesson:
        try:
            db.collection(FIRESTORE_COLLECTION).document(lesson['id']).set(lesson)
            print(f"      ☁️  Uploaded to Firebase ({'PINNED' if is_pinned else 'NORMAL'}): {lesson['title'][:30]}...")
            return True
        except Exception as e:
            print(f"      ❌ Upload error: {e}")
    return False

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str, required=True)
    parser.add_argument("--lang", type=str, required=True)
    parser.add_argument("--genre", type=str, default="manual")
    parser.add_argument("--level", type=str)
    # 🔥 THE NEW FLAG
    parser.add_argument("--pinned", action="store_true", help="Set date to 2030 to pin to top")
    
    args = parser.parse_args()

    ydl_opts = {'extract_flat': True, 'quiet': True}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(args.link, download=False)
        video_ids = [e['id'] for e in info.get('entries', [])] if 'entries' in info else [info['id']]

    for vid_id in video_ids:
        process_and_upload(
            f"https://www.youtube.com/watch?v={vid_id}", 
            args.lang, 
            args.genre, 
            args.level, 
            is_pinned=args.pinned
        )
        time.sleep(1)

if __name__ == "__main__":
    main()