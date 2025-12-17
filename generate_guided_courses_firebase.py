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
LOCAL_DATA_DIR = "assets/guided_courses" # Used for duplicate checking only
FIRESTORE_COLLECTION = "lessons"

LANGUAGES = {
    'ar': 'Arabic', 'cs': 'Czech', 'da': 'Danish', 'de': 'German', 'el': 'Greek',
    'en': 'English', 'es': 'Spanish', 'fi': 'Finnish', 'fr': 'French', 'hi': 'Hindi',
    'hu': 'Hungarian', 'id': 'Indonesian', 'it': 'Italian', 'ja': 'Japanese',
    'ko': 'Korean', 'nl': 'Dutch', 'no': 'Norwegian', 'pl': 'Polish', 'pt': 'Portuguese',
    'ro': 'Romanian', 'ru': 'Russian', 'sv': 'Swedish', 'th': 'Thai', 'tr': 'Turkish',
    'uk': 'Ukrainian', 'vi': 'Vietnamese', 'zh': 'Chinese',
}

# --- LOGGER ---
class QuietLogger:
    def debug(self, msg): pass
    def warning(self, msg): pass
    def error(self, msg): print(msg)

# --- DUPLICATE CHECKING ---

def is_duplicate(lesson_id):
    """Checks Firebase and then local files to see if document exists."""
    # 1. Check Firebase (Primary Source)
    try:
        doc = db.collection(FIRESTORE_COLLECTION).document(lesson_id).get()
        if doc.exists:
            return True
    except Exception as e:
        print(f"      ⚠️ Firebase check error: {e}")

    # 2. Check Local Files (Fallback for legacy data)
    if os.path.exists(LOCAL_DATA_DIR):
        for file_path in glob.glob(os.path.join(LOCAL_DATA_DIR, "*.json")):
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    local_lessons = json.load(f)
                    if any(l.get('id') == lesson_id for l in local_lessons):
                        return True
            except: continue
    return False

# --- HELPERS ---

def time_to_seconds(time_str):
    try:
        parts = time_str.replace(',', '.').split(':')
        if len(parts) == 3: return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
        elif len(parts) == 2: return int(parts[0]) * 60 + float(parts[1])
    except: return 0.0
    return 0.0

def split_sentences(text):
    if not text: return []
    return re.split(r'(?<=[.!?])\s+', text)

def parse_vtt_to_transcript(vtt_content):
    lines = vtt_content.splitlines()
    transcript = []
    time_pattern = re.compile(r'((?:\d{2}:)?\d{2}:\d{2}[.,]\d{3})\s-->\s((?:\d{2}:)?\d{2}:\d{2}[.,]\d{3})')
    current_entry = None
    for line in lines:
        line = line.strip()
        if not line or line == 'WEBVTT' or line.startswith('Kind:') or line.startswith('Language:'): continue
        match = time_pattern.search(line)
        if match:
            if current_entry and current_entry['text']: transcript.append(current_entry)
            current_entry = {'start': time_to_seconds(match.group(1)), 'end': time_to_seconds(match.group(2)), 'text': ''}
            continue
        if current_entry:
            clean_line = re.sub(r'<[^>]+>', '', line).replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')
            if clean_line: current_entry['text'] += clean_line + " "
    if current_entry and current_entry['text']: transcript.append(current_entry)
    for t in transcript: t['text'] = t['text'].strip()
    return transcript

def analyze_difficulty(transcript):
    if not transcript: return 'intermediate'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'intermediate'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.2: return 'beginner'
    if avg_len > 6.0: return 'advanced' 
    return 'intermediate'

# --- CORE LOGIC ---

def get_video_details(video_url, lang_code, genre, manual_level=None):
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

    # Check for subs
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
        for f in glob.glob(f"{temp_filename}*"): os.remove(f)

    if not content: return None
    
    transcript_data = parse_vtt_to_transcript(content)
    if not transcript_data or len(transcript_data) < 5: return None
    
    full_text = " ".join([t['text'] for t in transcript_data])
    difficulty = manual_level if manual_level else analyze_difficulty(transcript_data)

    return {
        "id": f"yt_{video_id}",
        "userId": "system",
        "title": info.get('title', 'Unknown Title'),
        "language": lang_code,
        "content": full_text,
        "sentences": split_sentences(full_text),
        "transcript": transcript_data,
        "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
        "imageUrl": info.get('thumbnail') or "",
        "type": "video",
        "difficulty": difficulty,
        "videoUrl": f"https://www.youtube.com/watch?v={video_id}",
        "isFavorite": False,
        "progress": 0,
        "genre": genre
    }

# --- WORKFLOWS ---

def process_and_upload(vid_url, lang_code, genre, level=None):
    # Extract ID first to check for duplicate before processing
    video_id = vid_url.split("v=")[-1]
    lesson_id = f"yt_{video_id}"

    if is_duplicate(lesson_id):
        print(f"      ⏭️  Skipped: {lesson_id} already exists.")
        return False

    lesson = get_video_details(vid_url, lang_code, genre, level)
    if lesson:
        try:
            db.collection(FIRESTORE_COLLECTION).document(lesson['id']).set(lesson)
            print(f"      ☁️  Uploaded to Firebase: {lesson['title'][:30]}...")
            return True
        except Exception as e:
            print(f"      ❌ Upload error: {e}")
    return False

def process_manual_link(url, lang_code, genre="manual", manual_level=None):
    ydl_opts_check = {'extract_flat': True, 'quiet': True}
    videos_to_process = [] 
    with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                for entry in info['entries']: videos_to_process.append(entry['id'])
            else:
                videos_to_process.append(info['id'])
        except: return print("❌ URL error.")

    for vid_id in videos_to_process:
        process_and_upload(f"https://www.youtube.com/watch?v={vid_id}", lang_code, genre, manual_level)
        time.sleep(1)

def run_automated_scraping():
    # Example logic for automated loop
    for lang_code, lang_name in sorted(LANGUAGES.items()):
        print(f"\n--- SCRAPING: {lang_name} ---")
        query = f"learn {lang_name} with stories"
        with yt_dlp.YoutubeDL({'quiet': True, 'extract_flat': True}) as ydl:
            try:
                res = ydl.extract_info(f"ytsearch5:{query}", download=False)
                for entry in res.get('entries', []):
                    process_and_upload(f"https://www.youtube.com/watch?v={entry['id']}", lang_code, "story")
                    time.sleep(random.uniform(5, 10))
            except: continue

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str)
    parser.add_argument("--lang", type=str)
    parser.add_argument("--genre", type=str, default="manual")
    parser.add_argument("--level", type=str)
    args = parser.parse_args()

    if args.link:
        if not args.lang: sys.exit(print("❌ --lang required"))
        process_manual_link(args.link, args.lang, args.genre, args.level)
    else:
        run_automated_scraping()

if __name__ == "__main__":
    main()