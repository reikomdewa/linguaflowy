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

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/youtube_audio_library"

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

# 2. CURATED QUERIES
CURATED_AUDIOBOOKS = {
    'es': [('Audiolibro español con texto', 'audiobook'), ('Spanish graded reader', 'audiobook'), ('Cuentos para dormir español', 'story')],
    'fr': [('Livre audio français avec texte', 'audiobook'), ('French graded reader', 'audiobook'), ('Le Petit Prince audio', 'classic')],
    'de': [('Hörbuch deutsch mit text', 'audiobook'), ('German graded reader', 'audiobook'), ('Märchen hörspiel', 'classic')],
    'it': [('Audiolibro italiano con testo', 'audiobook'), ('Italian graded reader', 'audiobook'), ('Favole al telefono', 'story')],
    'pt': [('Audiolivro com texto portugues', 'audiobook'), ('Portuguese graded reader', 'audiobook'), ('Lendas brasileiras', 'story')],
    'ja': [('Japanese audiobook with subtitles', 'audiobook'), ('Japanese folklore stories', 'story')],
    'en': [('English audiobook with text', 'audiobook'), ('Sherlock Holmes audiobook', 'classic')],
}

# --- LOGGER ---
class QuietLogger:
    def debug(self, msg): pass
    def warning(self, msg): pass
    def error(self, msg): print(msg)

# --- HELPERS ---
def get_audiobook_queries(code, name):
    if code in CURATED_AUDIOBOOKS:
        return CURATED_AUDIOBOOKS[code]
    return [
        (f"{name} language stories", 'story'), 
        (f"{name} language folktales", 'story'),
        (f"{name} language fairy tales", 'story'),
        (f"{name} reading practice", 'education'),
    ]

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

def analyze_difficulty(text, title):
    lower_title = title.lower()
    if any(x in lower_title for x in ["graded reader", "beginner", "level 1"]): return "beginner"
    words = text.split()
    if not words: return "intermediate"
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.5: return "beginner"
    if avg_len > 6.0: return "advanced"
    return "intermediate"

def save_lesson_to_file(lang_code, lesson):
    filepath = os.path.join(OUTPUT_DIR, f"audiobooks_{lang_code}.json")
    try:
        existing_lessons = []
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                existing_lessons = json.load(f)
        if any(l['id'] == lesson['id'] for l in existing_lessons): return False
        existing_lessons.insert(0, lesson)
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        return True
    except Exception as e:
        print(f"Error saving file: {e}")
        return False

# --- CORE LOGIC WITH RETRY SYSTEM ---

def get_audiobook_details(video_url, lang_code, genre, manual_level=None, max_retries=3):
    ydl_opts_base = {
        'skip_download': True, 'quiet': True, 'no_warnings': True,
        'ignoreerrors': False, 'logger': QuietLogger(),
        'socket_timeout': 40, 'retries': 10, 'nocheckcertificate': True,
    }

    info, found_sub_code, is_auto = None, None, False

    # PHASE 1: INFO EXTRACTION
    for attempt in range(max_retries):
        try:
            with yt_dlp.YoutubeDL(ydl_opts_base) as ydl:
                info = ydl.extract_info(video_url, download=False)
                if info: break
        except Exception as e:
            if any(x in str(e).lower() for x in ["handshake", "timeout", "connection"]):
                wait = (attempt + 1) * 6
                print(f"    ⏳ SSL/Timeout during info extraction. Retrying in {wait}s... ({attempt+1}/{max_retries})")
                time.sleep(wait)
            else:
                print(f"    ❌ Extraction error: {str(e)[:50]}")
                return None
    if not info: return None

    # Filter by duration
    duration = info.get('duration', 0)
    if duration < 120 or duration > (14400 if genre == 'manual' else 7200):
        print(f"    ⚠️ Skipping duration: {duration}s")
        return None

    # Subtitle Matching
    for code, subs in info.get('subtitles', {}).items():
        if code == lang_code or code.startswith(f"{lang_code}-"):
            found_sub_code = code; break
    if not found_sub_code:
        for code, subs in info.get('automatic_captions', {}).items():
            if code == lang_code or code.startswith(f"{lang_code}-"):
                found_sub_code = code; is_auto = True; break
    
    if not found_sub_code:
        print(f"    ⚠️ No '{lang_code}' subtitles found.")
        return None

    # PHASE 2: SUBTITLE DOWNLOAD
    video_id = info['id']
    temp_filename = f"temp_aud_{lang_code}_{video_id}"
    ydl_opts_dl = {
        **ydl_opts_base, 'writesubtitles': not is_auto, 'writeautomaticsub': is_auto,
        'subtitleslangs': [found_sub_code], 'outtmpl': temp_filename,
    }

    content = None
    for attempt in range(max_retries):
        try:
            with yt_dlp.YoutubeDL(ydl_opts_dl) as ydl:
                ydl.extract_info(video_url, download=True)
                files = glob.glob(f"{temp_filename}*.vtt")
                if files:
                    with open(max(files, key=os.path.getsize), 'r', encoding='utf-8') as f: content = f.read()
                    break
        except Exception as e:
            print(f"    ⚠️ Download error (Attempt {attempt+1}): {str(e)[:50]}...")
            for f in glob.glob(f"{temp_filename}*"): os.remove(f)
            if any(x in str(e).lower() for x in ["handshake", "timeout", "vtt"]):
                time.sleep((attempt + 1) * 6); continue
            return None

    for f in glob.glob(f"{temp_filename}*"):
        try: os.remove(f)
        except: pass
    
    if not content: return None
    
    transcript = parse_vtt_to_transcript(content)
    if not transcript or len(transcript) < 15: return None
    full_text = " ".join([t['text'] for t in transcript])
    
    return {
        "id": f"yt_audio_{video_id}", "userId": "system_audiobook",
        "title": info.get('title', 'Unknown Title'), "language": lang_code,
        "content": full_text, "sentences": split_sentences(full_text),
        "transcript": transcript, "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
        "imageUrl": info.get('thumbnail') or "", "type": "audio", 
        "videoUrl": f"https://www.youtube.com/watch?v={video_id}",
        "difficulty": manual_level or analyze_difficulty(full_text, info.get('title', '')),
        "genre": genre, "isFavorite": False, "progress": 0
    }

# --- WORKFLOWS ---

def process_manual_link(url, lang_code, genre="manual", manual_level=None):
    if lang_code not in LANGUAGES: return print(f"❌ Lang code '{lang_code}' not found.")
    print(f"\n🎧 MANUAL AUDIO: {lang_code} | Link: {url}")
    
    ydl_opts = {'extract_flat': True, 'quiet': True, 'logger': QuietLogger()}
    videos = []
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                for idx, e in enumerate(info['entries'], 1):
                    if e: videos.append({'id': e['id'], 'seriesId': info.get('id'), 'seriesTitle': info.get('title'), 'seriesIndex': idx})
            else:
                videos.append({'id': info['id'], 'seriesId': None, 'seriesTitle': None, 'seriesIndex': None})
        except Exception as e: return print(f"❌ Extraction error: {e}")

    count = 0
    for v_data in videos:
        v_url = f"https://www.youtube.com/watch?v={v_data['id']}"
        print(f"   ⏳ Checking: {v_url}")
        lesson = get_audiobook_details(v_url, lang_code, genre, manual_level)
        if lesson:
            if v_data['seriesId']:
                lesson.update({'seriesId': v_data['seriesId'], 'seriesTitle': v_data['seriesTitle'], 'seriesIndex': v_data['seriesIndex']})
            if save_lesson_to_file(lang_code, lesson):
                print(f"      ✅ Saved: {lesson['title'][:30]}..."); count += 1
            else: print(f"      ⏭️  Duplicate.")
        else: print(f"      🚫 Skipped (No subs/error).")
        time.sleep(1)
    print(f"\n✅ Done. Added {count} items.")

def run_automated_scraping():
    for lang_code, lang_name in sorted(LANGUAGES.items()):
        filepath = os.path.join(OUTPUT_DIR, f"audiobooks_{lang_code}.json")
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                if len(json.load(f)) >= 12: continue

        print(f"\n--- AUDIO FEED: {lang_name} ---")
        queries = get_audiobook_queries(lang_code, lang_name)
        random.shuffle(queries)
        added = 0
        for query, genre in queries:
            if added >= 3: break
            print(f"  🔎 '{query}'")
            with yt_dlp.YoutubeDL({'quiet': True, 'extract_flat': True, 'logger': QuietLogger()}) as ydl:
                try: res = ydl.extract_info(f"ytsearch4:{query}", download=False)
                except: continue
                for entry in res.get('entries', []):
                    if not entry: continue
                    l = get_audiobook_details(f"https://www.youtube.com/watch?v={entry['id']}", lang_code, genre)
                    if l and save_lesson_to_file(lang_code, l):
                        print(f"       ✅ Added: {l['title'][:30]}"); added += 1
                        time.sleep(random.uniform(5, 10))
                        if added >= 3: break
        time.sleep(5)

def main():
    if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str)
    parser.add_argument("--lang", type=str)
    parser.add_argument("--genre", type=str, default="manual")
    parser.add_argument("--level", type=str)
    args = parser.parse_args()

    if args.link:
        if not args.lang: sys.exit(print("❌ --lang required"))
        process_manual_link(args.link, args.lang, args.genre, args.level)
    else: run_automated_scraping()

if __name__ == "__main__":
    main()