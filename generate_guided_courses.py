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
from datetime import datetime, timedelta  # Added for pinning logic

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/guided_courses"

# 1. COMPREHENSIVE LANGUAGE LIST
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
    If is_pinned=True: Year 2030 (Always at the top)
    If is_pinned=False: Year 2024 (Always at the bottom)
    """
    year = 2030 if is_pinned else 2024
    base_date = datetime(year, 1, 1)
    # Add a random offset (up to 30 days) so items in the same batch have unique times
    random_offset = random.randint(0, 2592000) 
    final_date = base_date + timedelta(seconds=random_offset)
    return final_date.strftime('%Y-%m-%dT%H:%M:%S.000Z')

# --- LOGGER ---
class QuietLogger:
    def debug(self, msg): pass
    def warning(self, msg): pass
    def error(self, msg): print(msg)

# --- HELPERS ---

def time_to_seconds(time_str):
    try:
        parts = time_str.split(':')
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

def save_lesson_to_file(lang_code, lesson):
    filepath = os.path.join(OUTPUT_DIR, f"lessons_{lang_code}.json")
    try:
        existing_lessons = []
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                existing_lessons = json.load(f)
        if any(l['id'] == lesson['id'] for l in existing_lessons):
            return False
        # Insert at 0 so newest is at the top of the JSON list
        existing_lessons.insert(0, lesson)
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        return True
    except Exception as e:
        print(f"Error saving file: {e}")
        return False

# --- CORE LOGIC ---

def get_video_details(video_url, lang_code, genre, manual_level=None, is_pinned=False):
    ydl_opts_base = {
        'skip_download': True,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': False,
        'logger': QuietLogger(),
        'socket_timeout': 30,
        'retries': 5,
        'nocheckcertificate': True,
    }

    info, found_sub_code, is_auto = None, None, False

    # PHASE 1: INFO EXTRACTION
    try:
        with yt_dlp.YoutubeDL(ydl_opts_base) as ydl:
            info = ydl.extract_info(video_url, download=False)
    except: return None
    
    if not info: return None

    # Subtitles
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

    # PHASE 2: SUBTITLE DOWNLOAD
    video_id = info['id']
    temp_filename = f"temp_{lang_code}_{video_id}"
    ydl_opts_download = {
        **ydl_opts_base,
        'writesubtitles': not is_auto,
        'writeautomaticsub': is_auto,
        'subtitleslangs': [found_sub_code],
        'outtmpl': temp_filename,
    }

    content = None
    try:
        with yt_dlp.YoutubeDL(ydl_opts_download) as ydl:
            ydl.extract_info(video_url, download=True)
            files = glob.glob(f"{temp_filename}*.vtt")
            if files:
                with open(max(files, key=os.path.getsize), 'r', encoding='utf-8') as f: 
                    content = f.read()
    finally:
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass

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
        # 🔥 THE PINNING LOGIC APPLIED HERE
        "createdAt": get_automated_date(is_pinned=is_pinned),
        "imageUrl": info.get('thumbnail') or "",
        "type": "video",
        "difficulty": difficulty,
        "videoUrl": f"https://www.youtube.com/watch?v={video_id}",
        "isFavorite": False,
        "progress": 0,
        "genre": genre
    }

# --- WORKFLOWS ---

def process_manual_link(url, lang_code, genre="manual", manual_level=None, is_pinned=False):
    ydl_opts_check = {'extract_flat': True, 'quiet': True, 'logger': QuietLogger()}
    videos_to_process = [] 

    with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                for idx, entry in enumerate(info['entries'], start=1):
                    if entry: videos_to_process.append({'id': entry['id'], 'seriesId': info.get('id'), 'seriesTitle': info.get('title'), 'seriesIndex': idx})
            else:
                videos_to_process.append({'id': info.get('id'), 'seriesId': None, 'seriesTitle': None, 'seriesIndex': None})
        except: return

    for video_data in videos_to_process:
        lesson = get_video_details(f"https://www.youtube.com/watch?v={video_data['id']}", lang_code, genre, manual_level, is_pinned=is_pinned)
        if lesson:
            if video_data['seriesId']:
                lesson.update({'seriesId': video_data['seriesId'], 'seriesTitle': video_data['seriesTitle'], 'seriesIndex': video_data['seriesIndex']})
            save_lesson_to_file(lang_code, lesson)
        time.sleep(1)

def main():
    if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str)
    parser.add_argument("--lang", type=str)
    parser.add_argument("--genre", type=str, default="manual")
    parser.add_argument("--level", type=str)
    # 🔥 ADDED PINNED FLAG
    parser.add_argument("--pinned", action="store_true", help="Set date to 2030 to pin to top")
    
    args = parser.parse_args()

    if args.link:
        if not args.lang: sys.exit(print("❌ --lang required"))
        process_manual_link(args.link, args.lang, args.genre, args.level, is_pinned=args.pinned)
    else:
        print("Scraping logic can also use --pinned if implemented there.")

if __name__ == "__main__":
    main()