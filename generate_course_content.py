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

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/course_videos"

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

# --- DURATION RULES (In Seconds) ---
DURATION_RULES = {
    'Stories':      (60, 1800),
    'News':         (45, 1200),
    'Bites':        (10, 120),
    'Grammar tips': (60, 900),
    'Manual':       (5, 10800), 
}

CURATED_CONFIG = {
    'es': [('Spanish comprehensible input beginner', 'Stories'), ('BBC News Mundo', 'News'), ('Spanish slang shorts', 'Bites'), ('Por vs Para explained', 'Grammar tips')],
    'fr': [('French comprehensible input', 'Stories'), ('HugoDécrypte actus', 'News'), ('French slang shorts', 'Bites'), ('Passé Composé vs Imparfait', 'Grammar tips')],
    'en': [('English short stories for learning', 'Stories'), ('VOA Learning English', 'News'), ('English idioms shorts', 'Bites'), ('English phrasal verbs explained', 'Grammar tips')],
}

# --- DATE CHEATING LOGIC ---

def get_automated_date(is_pinned=False):
    """
    If pinned: Year 2030 (Top)
    If not pinned: Year 2024 (Bottom)
    """
    year = 2030 if is_pinned else 2024
    base_date = datetime(year, 1, 1)
    # Add random offset (up to 30 days) to keep items in a batch unique
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
        time_str = time_str.replace(',', '.')
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
    if avg_len < 4.5: return 'beginner'
    if avg_len < 5.5: return 'intermediate'
    return 'advanced'

def save_lesson_to_file(lang_code, lesson):
    filepath = os.path.join(OUTPUT_DIR, f"{lang_code}.json")
    try:
        existing_lessons = []
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                existing_lessons = json.load(f)
        if any(l['id'] == lesson['id'] for l in existing_lessons):
            return False
        existing_lessons.insert(0, lesson) # Insert at top of JSON
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        return True
    except Exception as e:
        print(f"Error saving file: {e}")
        return False

# --- CORE LOGIC WITH RETRY ---

def get_video_details(video_url, lang_code, category, manual_level=None, max_retries=3, is_pinned=False):
    ydl_opts_base = {
        'skip_download': True,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': False, 
        'logger': QuietLogger(),
        'socket_timeout': 40,
        'retries': 10,
        'nocheckcertificate': True,
    }

    info, found_sub_code, is_auto = None, None, False

    # PHASE 1: INSPECTION
    for attempt in range(max_retries):
        try:
            with yt_dlp.YoutubeDL(ydl_opts_base) as ydl:
                info = ydl.extract_info(video_url, download=False)
                if info: break
        except Exception as e:
            err_msg = str(e).lower()
            if any(x in err_msg for x in ["handshake", "timeout", "connection"]):
                wait = (attempt + 1) * 6
                print(f"    ⏳ Network issue during info check. Retrying in {wait}s... ({attempt+1}/{max_retries})")
                time.sleep(wait)
            else:
                print(f"    ❌ Inspection error: {str(e)[:50]}")
                return None
    
    if not info: return None

    # Duration Check
    duration = info.get('duration', 0)
    min_dur, max_dur = DURATION_RULES.get(category, DURATION_RULES['Manual'])
    if not (min_dur <= duration <= max_dur):
        print(f"    ⚠️ Duration mismatch ({duration}s).")
        return None

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
    
    if not found_sub_code:
        print(f"    ⚠️ No '{lang_code}' subtitles found.")
        return None

    # PHASE 2: DOWNLOAD
    video_id = info['id']
    temp_filename = f"temp_course_{lang_code}_{video_id}"
    ydl_opts_download = {
        **ydl_opts_base,
        'writesubtitles': not is_auto,
        'writeautomaticsub': is_auto,
        'subtitleslangs': [found_sub_code],
        'outtmpl': temp_filename,
        'extractor_args': {'youtube': {'player_client': ['android', 'web']}}
    }

    content = None
    for attempt in range(max_retries):
        try:
            with yt_dlp.YoutubeDL(ydl_opts_download) as ydl:
                ydl.extract_info(video_url, download=True)
                files = glob.glob(f"{temp_filename}*.vtt")
                if files:
                    best_file = max(files, key=os.path.getsize)
                    with open(best_file, 'r', encoding='utf-8') as f: content = f.read()
                    break
                else: raise Exception("VTT not found")
        except Exception as e:
            print(f"    ⚠️ Download error (Attempt {attempt+1}): {str(e)[:50]}...")
            for f in glob.glob(f"{temp_filename}*"):
                try: os.remove(f)
                except: pass
            if any(x in str(e).lower() for x in ["handshake", "timeout", "vtt"]):
                time.sleep((attempt + 1) * 6); continue
            return None

    for f in glob.glob(f"{temp_filename}*"):
        try: os.remove(f)
        except: pass

    if not content: return None
    
    transcript_data = parse_vtt_to_transcript(content)
    if not transcript_data or len(transcript_data) < 5: return None
    
    full_text = " ".join([t['text'] for t in transcript_data])
    type_map = {'Stories': 'story', 'News': 'news', 'Bites': 'bite', 'Grammar tips': 'grammar', 'Manual': 'video'}

    return {
        "id": f"yt_{video_id}", "userId": "system_course",
        "title": info.get('title', 'Unknown Title'), "language": lang_code,
        "content": full_text, "sentences": split_sentences(full_text),
        "transcript": transcript_data, 
        # 🔥 PINNING LOGIC APPLIED HERE
        "createdAt": get_automated_date(is_pinned=is_pinned),
        "imageUrl": info.get('thumbnail') or "", "type": type_map.get(category, 'video'), 
        "difficulty": manual_level or analyze_difficulty(transcript_data),
        "videoUrl": f"https://www.youtube.com/watch?v={video_id}",
        "isFavorite": False, "progress": 0,
    }

# --- WORKFLOWS ---

def process_manual_link(url, lang_code, category="Manual", manual_level=None, is_pinned=False):
    if lang_code not in LANGUAGES: return print(f"❌ Error: Lang '{lang_code}' not found.")
    print(f"\n🖐️ MANUAL MODE: {lang_code} | Cat: {category} | Pinned: {is_pinned}")

    ydl_opts = {'extract_flat': True, 'quiet': True, 'logger': QuietLogger()}
    videos = []
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                for idx, entry in enumerate(info['entries'], start=1):
                    if entry: videos.append({'id': entry['id'], 'seriesId': info.get('id'), 'seriesTitle': info.get('title'), 'seriesIndex': idx})
            else:
                videos.append({'id': info.get('id'), 'seriesId': None, 'seriesTitle': None, 'seriesIndex': None})
        except: return print("❌ Invalid URL.")

    count = 0
    for v_data in videos:
        v_url = f"https://www.youtube.com/watch?v={v_data['id']}"
        print(f"   ⏳ Checking: {v_url}")
        lesson = get_video_details(v_url, lang_code, category, manual_level, is_pinned=is_pinned)
        if lesson:
            if v_data['seriesId']:
                lesson.update({'seriesId': v_data['seriesId'], 'seriesTitle': v_data['seriesTitle'], 'seriesIndex': v_data['seriesIndex']})
            if save_lesson_to_file(lang_code, lesson):
                print(f"      ✅ Saved: {lesson['title'][:30]}"); count += 1
            else: print(f"      ⏭️  Exists")
        else: print("      ⚠️ Skipped.")
        time.sleep(1)
    print(f"\n🎉 Finished. Added {count} lessons.")

def run_automated_scraping(is_pinned=False):
    for lang_code, lang_name in sorted(LANGUAGES.items()):
        filepath = os.path.join(OUTPUT_DIR, f"{lang_code}.json")
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                if len(json.load(f)) >= 40: continue

        print(f"\n=== {lang_name} ({lang_code}) ===")
        queries = CURATED_CONFIG.get(lang_code, [ (f"{lang_name} stories", 'Stories'), (f"{lang_name} news", 'News') ])
        added = 0
        for query, category in queries:
            if added >= 4: break
            print(f"  🔎 {category}: '{query}'")
            with yt_dlp.YoutubeDL({'quiet': True, 'extract_flat': True, 'logger': QuietLogger()}) as ydl:
                try: result = ydl.extract_info(f"ytsearch5:{query}", download=False)
                except: continue
                for entry in result.get('entries', []):
                    if not entry: continue
                    l = get_video_details(f"https://www.youtube.com/watch?v={entry['id']}", lang_code, category, is_pinned=is_pinned)
                    if l and save_lesson_to_file(lang_code, l):
                        print("       ✅ Added."); added += 1; time.sleep(6)
                        if added >= 4: break
        time.sleep(10)

def main():
    if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str)
    parser.add_argument("--lang", type=str)
    parser.add_argument("--category", type=str, default="Manual")
    parser.add_argument("--level", type=str)
    parser.add_argument("--pinned", action="store_true", help="Set date to 2030 to pin to top")
    
    args = parser.parse_args()
    if args.link:
        if not args.lang: sys.exit(print("❌ --lang required"))
        process_manual_link(args.link, args.lang, args.category, args.level, is_pinned=args.pinned)
    else: 
        run_automated_scraping(is_pinned=args.pinned)

if __name__ == "__main__":
    main()