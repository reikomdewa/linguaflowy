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
    'Manual':       (5, 10800), # Up to 3 hours for manual
}

CURATED_CONFIG = {
    'es': [('Spanish comprehensible input beginner', 'Stories'), ('BBC News Mundo', 'News'), ('Spanish slang shorts', 'Bites'), ('Por vs Para explained', 'Grammar tips')],
    'fr': [('French comprehensible input', 'Stories'), ('HugoDécrypte actus', 'News'), ('French slang shorts', 'Bites'), ('Passé Composé vs Imparfait', 'Grammar tips')],
    'en': [('English short stories for learning', 'Stories'), ('VOA Learning English', 'News'), ('English idioms shorts', 'Bites'), ('English phrasal verbs explained', 'Grammar tips')],
    # Add others as needed...
}

# --- LOGGER ---
class QuietLogger:
    def debug(self, msg): pass
    def warning(self, msg): pass
    def error(self, msg): print(msg)

def get_queries_for_lang(code, name):
    if code in CURATED_CONFIG:
        return CURATED_CONFIG[code]
    return [
        (f"{name} language stories", 'Stories'),
        (f"{name} language folklore", 'Stories'),
        (f"{name} language news", 'News'),
        (f"Learn {name} language lesson", 'Grammar tips'),
    ]

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
    # This script uses just "{lang}.json" based on previous context
    filepath = os.path.join(OUTPUT_DIR, f"{lang_code}.json")
    try:
        existing_lessons = []
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                existing_lessons = json.load(f)
        
        # Avoid duplicates
        if any(l['id'] == lesson['id'] for l in existing_lessons):
            return False

        existing_lessons.append(lesson) # Guided courses usually append to end
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        return True
    except Exception as e:
        print(f"Error saving file: {e}")
        return False

# --- CORE LOGIC ---

def get_video_details(video_url, lang_code, category, manual_level=None):
    """
    Two-Phase process: Inspect for subtitle dialect, then download.
    Allows Playlist tracking & Manual Levels.
    """
    
    # --- PHASE 1: INSPECTION ---
    ydl_opts_check = {
        'skip_download': True,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,
        'logger': QuietLogger(),
    }

    found_sub_code = None
    is_auto = False
    info = None

    try:
        with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
            time.sleep(random.uniform(1, 2))
            try:
                info = ydl.extract_info(video_url, download=False)
            except DownloadError: return None
            
            if not info: return None

            # DURATION CHECK
            duration = info.get('duration', 0)
            min_dur, max_dur = DURATION_RULES.get(category, DURATION_RULES['Manual'])
            
            # If manual link, we are lenient. If automated, we are strict.
            if not (min_dur <= duration <= max_dur):
                print(f"    ⚠️ Duration mismatch ({duration}s).")
                return None

            # 1. Manual Subtitles
            manual_subs = info.get('subtitles', {})
            for code in manual_subs:
                if code == lang_code or code.startswith(f"{lang_code}-"):
                    found_sub_code = code
                    break
            
            # 2. Auto Subtitles
            if not found_sub_code:
                auto_subs = info.get('automatic_captions', {})
                for code in auto_subs:
                    if code == lang_code or code.startswith(f"{lang_code}-"):
                        found_sub_code = code
                        is_auto = True
                        break
            
            if not found_sub_code:
                print(f"    ⚠️ No '{lang_code}' subtitles found.")
                return None

    except Exception as e:
        print(f"    ❌ Inspection error: {str(e)[:50]}")
        return None

    # --- PHASE 2: DOWNLOAD ---
    video_id = info['id']
    temp_filename = f"temp_course_{lang_code}_{video_id}"
    
    ydl_opts_download = {
        'skip_download': True,
        'writesubtitles': not is_auto,
        'writeautomaticsub': is_auto,
        'subtitleslangs': [found_sub_code],
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,
        'logger': QuietLogger(),
        'extractor_args': {'youtube': {'player_client': ['android', 'web']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts_download) as ydl:
            ydl.extract_info(video_url, download=True)
            
            files = glob.glob(f"{temp_filename}*.vtt")
            if not files:
                for f in glob.glob(f"{temp_filename}*"): os.remove(f)
                return None
            
            best_file = max(files, key=os.path.getsize)
            
            with open(best_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            for f in glob.glob(f"{temp_filename}*"): 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            
            if not transcript_data or len(transcript_data) < 5: 
                print("    ⚠️ Transcript too short.")
                return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            type_map = {
                'Stories': 'story',
                'News': 'news',
                'Bites': 'bite',
                'Grammar tips': 'grammar',
                'Manual': 'video'
            }

            difficulty = manual_level if manual_level else analyze_difficulty(transcript_data)

            return {
                "id": f"yt_{info['id']}",
                "userId": "system_course",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": info.get('thumbnail') or "",
                "type": type_map.get(category, 'video'), 
                "difficulty": difficulty,
                "videoUrl": f"https://www.youtube.com/watch?v={info['id']}",
                "isFavorite": False,
                "progress": 0,
            }
    except Exception as e:
        print(f"    ❌ Error processing: {e}")
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

# --- WORKFLOWS ---

def process_manual_link(url, lang_code, category="Manual", manual_level=None):
    if lang_code not in LANGUAGES:
        print(f"❌ Error: Language code '{lang_code}' not found.")
        return

    print(f"\n==========================================")
    print(f" 🖐️ MANUAL MODE: {lang_code} | Cat: {category}")
    if manual_level: print(f" 🎯 Forced Level: {manual_level}")
    print(f" 🔗 Processing: {url}")
    print(f"==========================================")

    ydl_opts_check = {'extract_flat': True, 'quiet': True, 'logger': QuietLogger()}
    
    videos_to_process = []

    with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                # PLAYLIST DETECTED
                playlist_title = info.get('title', 'Unknown Playlist')
                playlist_id = info.get('id')
                print(f"   📂 Detected Playlist: {playlist_title}")
                
                for idx, entry in enumerate(info['entries'], start=1):
                    if entry: 
                        videos_to_process.append({
                            'id': entry['id'],
                            'seriesId': playlist_id,
                            'seriesTitle': playlist_title,
                            'seriesIndex': idx
                        })
            else:
                # SINGLE VIDEO
                print(f"   🎬 Detected Video: {info.get('title')}")
                videos_to_process.append({
                    'id': info.get('id'),
                    'seriesId': None,
                    'seriesTitle': None,
                    'seriesIndex': None
                })
        except:
            print("❌ Invalid URL.")
            return

    print(f"   ⬇️ Processing {len(videos_to_process)} videos...")
    
    count = 0
    for vid_data in videos_to_process:
        vid_id = vid_data['id']
        vid_url = f"https://www.youtube.com/watch?v={vid_id}"
        
        print(f"   ⏳ Checking: {vid_url}")
        lesson = get_video_details(vid_url, lang_code, category, manual_level)
        
        if lesson:
            # Inject Playlist Data
            if vid_data['seriesId']:
                lesson['seriesId'] = vid_data['seriesId']
                lesson['seriesTitle'] = vid_data['seriesTitle']
                lesson['seriesIndex'] = vid_data['seriesIndex']

            if save_lesson_to_file(lang_code, lesson):
                print(f"      ✅ Saved: {lesson['title'][:30]}")
                count += 1
            else:
                print(f"      ⏭️  Exists")
        else:
            print("      ⚠️ Skipped.")
        
        time.sleep(1)

    print(f"\n🎉 Finished. Added {count} lessons.")

def run_automated_scraping():
    sorted_langs = sorted(LANGUAGES.items())
    print(f"🚀 STARTING AUTO-SCRAPE FOR {len(sorted_langs)} LANGUAGES")

    for lang_code, lang_name in sorted_langs:
        filepath = os.path.join(OUTPUT_DIR, f"{lang_code}.json")
        
        existing_count = 0
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f: existing_count = len(json.load(f))
            except: pass

        if existing_count >= 40:
             print(f"⏭️  Skipping {lang_name} ({lang_code}): Full.")
             continue

        print(f"\n=== {lang_name} ({lang_code}) ===")
        queries = get_queries_for_lang(lang_code, lang_name)
        random.shuffle(queries)
        
        added = 0
        for query, category in queries:
            if added >= 4: break
            print(f"  🔎 {category}: '{query}'")
            
            ydl_opts = {'quiet': True, 'extract_flat': True, 'dump_single_json': True, 'logger': QuietLogger(), 'sleep_interval': random.uniform(1, 3)}
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                try: result = ydl.extract_info(f"ytsearch5:{query}", download=False)
                except: continue
                
                if result and 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={entry['id']}", lang_code, category)
                        if lesson:
                            if save_lesson_to_file(lang_code, lesson):
                                print("       ✅ Added.")
                                added += 1
                                time.sleep(5)
                                break
                        else:
                            time.sleep(1)

def main():
    if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str, help="Video/Playlist Link")
    parser.add_argument("--lang", type=str, help="Language Code")
    parser.add_argument("--category", type=str, default="Manual")
    parser.add_argument("--level", type=str, help="Force level (beginner, intermediate, advanced)")
    
    args = parser.parse_args()

    if args.link:
        if not args.lang:
            print("❌ --lang required with --link")
            sys.exit(1)
        process_manual_link(args.link, args.lang, args.category, args.level)
    else:
        run_automated_scraping()

if __name__ == "__main__":
    main()