
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
OUTPUT_DIR = "assets/guided_courses"

# 1. COMPREHENSIVE LANGUAGE LIST
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

# 2. SPECIFIC OVERRIDES
SPECIFIC_SEARCH_CONFIG = {
    'es': [('Spanish comprehensible input stories', 'story'), ('BBC Mundo', 'news')],
    'fr': [('French comprehensible input', 'story'), ('HugoDécrypte', 'news')],
    'de': [('Dinge Erklärt – Kurzgesagt', 'science'), ('Easy German', 'vlog')],
    'it': [('Learn Italian with Lucrezia', 'vlog'), ('Podcast Italiano', 'culture')],
    'pt': [('Speaking Brazilian', 'vlog'), ('Manual do Mundo', 'science')],
    'ja': [('Comprehensible Japanese', 'story'), ('Miku Real Japanese', 'vlog')],
    'en': [('TED-Ed', 'education'), ('Kurzgesagt', 'science')],
}

# --- LOGGER ---
class QuietLogger:
    """Silences the annoying SABR/Warning logs from yt-dlp"""
    def debug(self, msg): pass
    def warning(self, msg): pass
    def error(self, msg): print(msg)

def get_queries_for_language(code, name):
    if code in SPECIFIC_SEARCH_CONFIG:
        return SPECIFIC_SEARCH_CONFIG[code]
    return [
        (f"{name} language stories", 'story'),
        (f"Learn {name} language conversation", 'education'),
        (f"{name} language news", 'news'),
        (f"{name} language cartoon", 'fairy_tale'),
        (f"{name} gospel song lyrics", 'culture'),
    ]

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
        
        # Avoid duplicates
        if any(l['id'] == lesson['id'] for l in existing_lessons):
            return False

        existing_lessons.insert(0, lesson)
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        return True
    except Exception as e:
        print(f"Error saving file: {e}")
        return False

# --- CORE LOGIC WITH IMPROVED SUBTITLE DETECTION ---

def get_video_details(video_url, lang_code, genre):
    """
    Two-phase process:
    1. Inspect metadata to find exact subtitle dialect (e.g. 'fr-FR').
    2. Download specifically that subtitle file.
    """
    
    # --- PHASE 1: INSPECTION (No Download) ---
    ydl_opts_check = {
        'skip_download': True,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,
        'logger': QuietLogger(), # Silence warnings
    }

    found_sub_code = None
    is_auto = False
    info = None

    try:
        with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
            # Random sleep to avoid hammering
            time.sleep(random.uniform(1, 2))
            try:
                info = ydl.extract_info(video_url, download=False)
            except DownloadError: return None
            
            if not info: return None

            # Skip long videos
            if info.get('duration', 0) > 3600: # 1 hour limit
                print(f"    ⚠️ Skipping (Too long): {info.get('title')[:30]}...")
                return None

            # 1. Check Manual Subtitles (Preferred)
            # Match 'fr', 'fr-FR', 'fr-CA' etc.
            manual_subs = info.get('subtitles', {})
            for code in manual_subs:
                if code == lang_code or code.startswith(f"{lang_code}-"):
                    found_sub_code = code
                    break
            
            # 2. Check Auto Subtitles (Fallback)
            if not found_sub_code:
                auto_subs = info.get('automatic_captions', {})
                for code in auto_subs:
                    if code == lang_code or code.startswith(f"{lang_code}-"):
                        found_sub_code = code
                        is_auto = True
                        break
            
            if not found_sub_code:
                print(f"    ⚠️ No '{lang_code}' subtitles found (Manual or Auto).")
                return None

    except Exception as e:
        print(f"    ❌ Info check error: {str(e)[:50]}")
        return None

    # --- PHASE 2: DOWNLOAD ---
    video_id = info['id']
    temp_filename = f"temp_{lang_code}_{video_id}"
    
    ydl_opts_download = {
        'skip_download': True,
        'writesubtitles': not is_auto,
        'writeautomaticsub': is_auto,
        'subtitleslangs': [found_sub_code], # Use the EXACT code we found
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
            
            # Find the file
            files = glob.glob(f"{temp_filename}*.vtt")
            
            if not files:
                for f in glob.glob(f"{temp_filename}*"): os.remove(f)
                return None
            
            # Pick largest file (best quality)
            best_file = max(files, key=os.path.getsize)
            
            with open(best_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Clean up
            for f in glob.glob(f"{temp_filename}*"): 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            
            if not transcript_data or len(transcript_data) < 5: 
                print("    ⚠️ Transcript too short/empty.")
                return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            return {
                "id": f"yt_{info.get('id')}",
                "userId": "system",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": info.get('thumbnail') or f"https://img.youtube.com/vi/{info.get('id')}/mqdefault.jpg",
                "type": "video",
                "difficulty": analyze_difficulty(transcript_data),
                "videoUrl": f"https://www.youtube.com/watch?v={info.get('id')}",
                "isFavorite": False,
                "progress": 0,
                "genre": genre
            }
    except Exception as e:
        print(f"    ⚠️ Download error: {str(e)[:50]}...")
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

# --- WORKFLOWS ---

def process_manual_link(url, lang_code, genre="manual"):
    if lang_code not in LANGUAGES:
        print(f"❌ Error: Language code '{lang_code}' not found.")
        return

    print(f"\n==========================================")
    print(f" 🖐️ MANUAL MODE: {lang_code} | Genre: {genre}")
    print(f" 🔗 Processing: {url}")
    print(f"==========================================")

    # Use QuietLogger here too
    ydl_opts_check = {'extract_flat': True, 'quiet': True, 'logger': QuietLogger()}
    videos_to_process = []

    with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                print(f"   📂 Detected Playlist: {info.get('title')}")
                for entry in info['entries']:
                    if entry: videos_to_process.append(f"https://www.youtube.com/watch?v={entry['id']}")
            else:
                print(f"   🎬 Detected Video: {info.get('title')}")
                videos_to_process.append(url)
        except Exception as e:
            print(f"❌ Could not retrieve info: {e}")
            return

    print(f"   ⬇️  Queue size: {len(videos_to_process)} videos")

    success_count = 0
    for vid_url in videos_to_process:
        print(f"   ⏳ Checking: {vid_url}")
        lesson = get_video_details(vid_url, lang_code, genre)
        
        if lesson:
            saved = save_lesson_to_file(lang_code, lesson)
            if saved:
                print(f"      ✅ Saved: {lesson['title'][:30]}...")
                success_count += 1
            else:
                print(f"      ⏭️  Duplicate skipped.")
        else:
            print(f"      🚫 Skipped (No subs or error)")
        
        time.sleep(1)

    print(f"\n✅ Manual job done. {success_count} lessons added to lessons_{lang_code}.json")

def run_automated_scraping():
    sorted_langs = sorted(LANGUAGES.items())
    print(f"🚀 STARTING AUTOMATED EXTRACTION FOR {len(sorted_langs)} LANGUAGES")

    for lang_code, lang_name in sorted_langs:
        filepath = os.path.join(OUTPUT_DIR, f"lessons_{lang_code}.json")
        
        existing_count = 0
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r') as f: existing_count = len(json.load(f))
            except: pass

        if existing_count >= 20:
             print(f"⏭️  Skipping {lang_name} ({lang_code}): Has {existing_count} videos.")
             continue

        print(f"\n--- PROCESSING: {lang_name} ({lang_code}) ---")
        queries = get_queries_for_language(lang_code, lang_name)
        total_new_for_lang = 0

        for query, genre in queries:
            if total_new_for_lang >= 5: break

            print(f"  🔎 '{query}'")
            # QuietLogger injected here
            ydl_opts_search = {'quiet': True, 'extract_flat': True, 'dump_single_json': True, 'logger': QuietLogger(), 'sleep_interval': random.uniform(1, 3)}
            
            with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
                try:
                    result = ydl.extract_info(f"ytsearch5:{query}", download=False)
                except: continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={entry['id']}", lang_code, genre)
                        if lesson:
                            if save_lesson_to_file(lang_code, lesson):
                                print(f"       ✅ Added: {lesson['title'][:30]}")
                                total_new_for_lang += 1
                                time.sleep(random.uniform(5, 12))
                            else:
                                print(f"       ⏭️  Exists")
                        else:
                            # Short sleep on failure
                            time.sleep(1)

        time.sleep(random.uniform(5, 10))

# --- MAIN ---

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    parser = argparse.ArgumentParser(description="Scrape YouTube for Language Learning")
    parser.add_argument("--link", type=str, help="YouTube Video or Playlist URL")
    parser.add_argument("--lang", type=str, help="Language code (e.g., 'es', 'fr') - Required with --link")
    parser.add_argument("--genre", type=str, default="manual", help="Genre tag for the manual download")
    
    args = parser.parse_args()

    if args.link:
        if not args.lang:
            print("❌ Error: When using --link, you MUST specify --lang (e.g., --lang es)")
            sys.exit(1)
        process_manual_link(args.link, args.lang, args.genre)
    else:
        run_automated_scraping()

if __name__ == "__main__":
    main()