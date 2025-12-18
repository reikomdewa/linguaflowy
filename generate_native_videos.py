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
LOCAL_DATA_DIR = "assets/native_videos" # Used for duplicate checking only
FIRESTORE_COLLECTION = "lessons"        # Unified collection

# 1. FULL LANGUAGE LIST
LANGUAGES = {
    'ar': 'Arabic', 'cs': 'Czech', 'da': 'Danish', 'de': 'German', 'el': 'Greek',
    'en': 'English', 'es': 'Spanish', 'fi': 'Finnish', 'fr': 'French', 'hi': 'Hindi',
    'hu': 'Hungarian', 'id': 'Indonesian', 'it': 'Italian', 'ja': 'Japanese',
    'ko': 'Korean', 'nl': 'Dutch', 'no': 'Norwegian', 'pl': 'Polish', 'pt': 'Portuguese',
    'ro': 'Romanian', 'ru': 'Russian', 'sv': 'Swedish', 'th': 'Thai', 'tr': 'Turkish',
    'uk': 'Ukrainian', 'vi': 'Vietnamese', 'zh': 'Chinese',
    'ach': 'Acholi', 'ada': 'Adangme', 'adh': 'Adhola', 'af': 'Afrikaans', 'alz': 'Alur',
    'am': 'Amharic', 'anu': 'Anuak', 'bem': 'Bemba', 'bxk': 'Bukusu', 'cce': 'Rukiga',
    'dag': 'Dagbani', 'dga': 'Dagaare', 'dje': 'Zarma', 'ee': 'Ewe', 'fat': 'Fanti',
    'ff': 'Fula', 'gaa': 'Ga', 'gjn': 'Gonja', 'gur': 'Frafra', 'guz': 'Gusii',
    'ha': 'Hausa', 'ha-ne': 'Hausa (Niger)', 'hz': 'Herero', 'kam': 'Kamba',
    'kdj': 'Karamojong', 'keo': 'Kakwa', 'ki': 'Kikuyu', 'kj': 'Kuanyama',
    'kln': 'Kalenjin', 'koo': 'Konjo', 'kpz': 'Kupsabiny', 'kr': 'Kanuri',
    'kwn': 'Kwangali', 'laj': 'Lango', 'lg': 'Luganda', 'lgg': 'Lugbara',
    'lgg-official': 'Lugbara (Official)', 'lko': 'Olukhayo', 'loz': 'Lozi',
    'lsm': 'Saamia', 'luc': 'Aringa', 'luo': 'Luo', 'lwg': 'Wanga', 'mas': 'Maasai',
    'mer': 'Meru', 'mhi': 'Ma\'di', 'mhw': 'Mbukushu', 'myx': 'Masaba', 'naq': 'Nama',
    'ng': 'Ndonga', 'nle': 'Lunyole', 'nr': 'South Ndebele',
    'nso': 'Northern Sotho (Sepedi)', 'nuj': 'Nyole', 'ny': 'Chichewa',
    'nyn': 'Runyankore', 'nyu': 'Runyoro', 'nzi': 'Nzema', 'om': 'Oromo',
    'rw': 'Kinyarwanda', 'saq': 'Samburu', 'so': 'Somali', 'ss': 'Swati',
    'st': 'Southern Sotho', 'sw': 'Swahili', 'teo': 'Teso', 'ti': 'Tigrinya',
    'tn': 'Tswana', 'toh': 'Gitonga', 'toi': 'Tonga (Zambia)', 'ts': 'Tsonga',
    'tsc': 'Tswa', 'ttj': 'Rutooro', 'tuv': 'Turkana', 'tw-akua': 'Twi (Akuapem)',
    'tw-asan': 'Twi (Asante)', 've': 'Venda', 'xh': 'Xhosa', 'xog': 'Soga',
    'xsm': 'Kasem', 'yo': 'Yoruba', 'zne': 'Zande', 'zu': 'Zulu',
}

# 2. SPECIFIC CURATED CHANNELS
CURATED_CHANNELS = {
    'es': [('VisualPolitik español', 'news'), ('BBC News Mundo', 'news'), ('Luisito Comunica', 'travel'), ('QuantumFracture', 'science')],
    'fr': [('HugoDécrypte', 'news'), ('Nota Bene histoire', 'history'), ('Dr Nozman', 'science'), ('Bruno Maltor', 'travel')],
    'de': [('Simplicissimus', 'society'), ('MrWissen2go', 'news'), ('Terra X', 'environment'), ('Galileo', 'education')],
    'it': [('Breaking Italy', 'news'), ('Nova Lectio', 'society'), ('Geopop', 'science'), ('Podcast Italiano', 'culture')],
    'pt': [('Nexo Jornal', 'news'), ('Manual do Mundo', 'science'), ('Mundo Sem Fim', 'travel'), ('Canal Nostalgia', 'history')],
    'ja': [('ANN news', 'news'), ('Oriental Radio Nakata', 'society'), ('Genki Labo', 'science')],
    'en': [('Vox', 'society'), ('Veritasium', 'science'), ('Vice News', 'news'), ('TED-Ed', 'education')],
}

# --- DATE CHEATING LOGIC ---

def get_automated_date(is_pinned=False):
    """
    Pinned: Year 2030 (Top of list)
    Normal: Year 2024 (Bottom of list)
    """
    year = 2030 if is_pinned else 2024
    base_date = datetime(year, 1, 1)
    # Random offset (up to 30 days) to keep items in batch unique
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
    """Checks Firebase and then local files to see if document exists."""
    try:
        doc = db.collection(FIRESTORE_COLLECTION).document(lesson_id).get()
        if doc.exists:
            return True
    except Exception: pass

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
    if not transcript: return 'advanced'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'advanced'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.0: return 'beginner' 
    if avg_len < 5.0: return 'intermediate'
    return 'advanced'

# --- CORE LOGIC ---

def get_video_details(video_url, lang_code, genre, manual_level=None, max_retries=3, is_pinned=False):
    ydl_opts_base = {
        'skip_download': True, 'quiet': True, 'no_warnings': True,
        'logger': QuietLogger(), 'socket_timeout': 30, 'retries': 5, 'nocheckcertificate': True,
    }

    info, found_sub_code, is_auto = None, None, False

    for attempt in range(max_retries):
        try:
            with yt_dlp.YoutubeDL(ydl_opts_base) as ydl:
                info = ydl.extract_info(video_url, download=False)
                if info: break
        except Exception: time.sleep(5)
    
    if not info: return None

    duration = info.get('duration', 0)
    max_dur = 10800 if genre == 'manual' else 1800
    if duration < 60 or duration > max_dur: return None

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
    temp_filename = f"temp_nat_{lang_code}_{video_id}"
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
    finally:
        for f in glob.glob(f"{temp_filename}*"): 
            try: os.remove(f)
            except: pass

    if not content: return None
    
    transcript_data = parse_vtt_to_transcript(content)
    if not transcript_data or len(transcript_data) < 10: return None
    
    full_text = " ".join([t['text'] for t in transcript_data])
    difficulty = manual_level if manual_level else analyze_difficulty(transcript_data)

    return {
        "id": f"yt_{video_id}", "userId": "system_native",
        "title": info.get('title', 'Unknown Title'), "language": lang_code,
        "content": full_text, "sentences": split_sentences(full_text),
        "transcript": transcript_data, 
        # 🔥 PINNING LOGIC APPLIED HERE
        "createdAt": get_automated_date(is_pinned=is_pinned),
        "imageUrl": info.get('thumbnail') or "", "type": "video",
        "difficulty": difficulty, "videoUrl": f"https://www.youtube.com/watch?v={video_id}",
        "isFavorite": False, "progress": 0, "genre": genre
    }

# --- WORKFLOWS ---

def process_and_upload(vid_url, lang_code, genre, level=None, series_data=None, is_pinned=False):
    video_id = vid_url.split("v=")[-1]
    lesson_id = f"yt_{video_id}"

    if is_duplicate(lesson_id):
        print(f"      ⏭️  Skipped: {lesson_id} exists.")
        return False

    lesson = get_video_details(vid_url, lang_code, genre, level, is_pinned=is_pinned)
    if lesson:
        if series_data:
            lesson.update(series_data)
        try:
            db.collection(FIRESTORE_COLLECTION).document(lesson['id']).set(lesson)
            print(f"      ☁️  Uploaded to Firebase ({'PINNED' if is_pinned else 'NORMAL'}): {lesson['title'][:30]}...")
            return True
        except Exception as e:
            print(f"      ❌ Upload error: {e}")
    return False

def process_manual_link(url, lang_code, genre="manual", manual_level=None, is_pinned=False):
    print(f"\n🖐️ MANUAL MODE: {lang_code} | Link: {url} | Pinned: {is_pinned}")
    ydl_opts = {'extract_flat': True, 'quiet': True}
    videos = []
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                for idx, entry in enumerate(info['entries'], start=1):
                    if entry: videos.append({
                        'url': f"https://www.youtube.com/watch?v={entry['id']}",
                        'series': {'seriesId': info.get('id'), 'seriesTitle': info.get('title'), 'seriesIndex': idx}
                    })
            else:
                videos.append({'url': url, 'series': None})
        except: return print("❌ Error fetching URL")

    for v in videos:
        process_and_upload(v['url'], lang_code, genre, manual_level, v['series'], is_pinned)
        time.sleep(1)

def run_automated_scraping(is_pinned=False):
    for lang_code, lang_name in sorted(LANGUAGES.items()):
        print(f"\n--- NATIVE FEED: {lang_name} ({lang_code}) ---")
        
        if lang_code in CURATED_CHANNELS: queries = CURATED_CHANNELS[lang_code]
        else: queries = [(f"{lang_name} news", 'news'), (f"{lang_name} vlog", 'vlog')]
        
        added = 0
        for query, genre in queries:
            if added >= 4: break
            with yt_dlp.YoutubeDL({'quiet': True, 'extract_flat': True}) as ydl:
                try: result = ydl.extract_info(f"ytsearch3:{query}", download=False)
                except: continue
                for entry in result.get('entries', []):
                    if not entry: continue
                    v_url = f"https://www.youtube.com/watch?v={entry['id']}"
                    if process_and_upload(v_url, lang_code, genre, is_pinned=is_pinned):
                        added += 1; time.sleep(6)
                        if added >= 4: break

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str)
    parser.add_argument("--lang", type=str)
    parser.add_argument("--genre", type=str, default="manual")
    parser.add_argument("--level", type=str)
    parser.add_argument("--pinned", action="store_true", help="Pin to top (Year 2030)")
    args = parser.parse_args()

    if args.link:
        if not args.lang: sys.exit(print("❌ --lang required"))
        process_manual_link(args.link, args.lang, args.genre, args.level, args.pinned)
    else:
        run_automated_scraping(args.pinned)

if __name__ == "__main__":
    main()