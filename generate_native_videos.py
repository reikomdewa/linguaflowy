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
OUTPUT_DIR = "assets/native_videos"

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

# --- LOGGER ---
class QuietLogger:
    def debug(self, msg): pass
    def warning(self, msg): pass
    def error(self, msg): print(msg)

def get_native_queries(code, name):
    if code in CURATED_CHANNELS:
        return CURATED_CHANNELS[code]
    return [
        (f"{name} language news", 'news'),
        (f"{name} language documentary", 'documentary'),
        (f"{name} language interview", 'society'),
        (f"{name} language comedy", 'comedy'),
        (f"{name} language music video", 'music'),
        (f"{name} language vlog", 'vlog'),
        (f"{name} language movie", 'cinema'),
        (f"{name} traditional culture", 'culture'),
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
    if not transcript: return 'advanced'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'advanced'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.0: return 'beginner' 
    if avg_len < 5.0: return 'intermediate'
    return 'advanced'

def save_lesson_to_file(lang_code, lesson):
    filepath = os.path.join(OUTPUT_DIR, f"trending_{lang_code}.json")
    try:
        existing_lessons = []
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                existing_lessons = json.load(f)
        
        # Check duplicate ID
        if any(l['id'] == lesson['id'] for l in existing_lessons):
            return False

        existing_lessons.insert(0, lesson)
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        return True
    except Exception as e:
        print(f"Error saving file: {e}")
        return False

# --- CORE LOGIC ---

def get_video_details(video_url, lang_code, genre, manual_level=None, max_retries=3):
    # --- CONFIGURATION FOR RETRIES ---
    ydl_opts_base = {
        'skip_download': True,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': False, # Changed to False to catch the error in our try/except
        'logger': QuietLogger(),
        'socket_timeout': 30,  # Increase timeout to 30 seconds
        'retries': 5,          # yt-dlp internal retries
        'nocheckcertificate': True, # Can help with some SSL handshake issues
    }

    info = None
    found_sub_code = None
    is_auto = False

    # --- STEP 1: EXTRACT INFO WITH RETRY ---
    for attempt in range(max_retries):
        try:
            with yt_dlp.YoutubeDL(ydl_opts_base) as ydl:
                info = ydl.extract_info(video_url, download=False)
                if info:
                    break # Success!
        except Exception as e:
            error_msg = str(e).lower()
            if "handshake" in error_msg or "timed out" in error_msg:
                wait_time = (attempt + 1) * 5 # Wait 5, 10, 15 seconds
                print(f"    ⏳ SSL Timeout/Handshake error. Retrying in {wait_time}s... (Attempt {attempt+1}/{max_retries})")
                time.sleep(wait_time)
            else:
                print(f"    ❌ Inspection error: {str(e)[:50]}")
                return None
    
    if not info:
        print(f"    🚫 Failed to fetch info after {max_retries} attempts.")
        return None

    # --- SUBTITLE CHECKING LOGIC ---
    duration = info.get('duration', 0)
    max_dur = 10800 if genre == 'manual' else 1800
    if duration < 60 or duration > max_dur: 
        print(f"    ⚠️ Skipping duration: {duration}s")
        return None

    manual_subs = info.get('subtitles', {})
    for code in manual_subs:
        if code == lang_code or code.startswith(f"{lang_code}-"):
            found_sub_code = code
            break
    
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

    # --- STEP 2: DOWNLOAD SUBTITLES WITH RETRY ---
    video_id = info['id']
    temp_filename = f"temp_nat_{lang_code}_{video_id}"
    
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
                    with open(best_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    break # Success!
        except Exception as e:
            if "handshake" in str(e) or "timeout" in str(e):
                time.sleep((attempt + 1) * 5)
                continue
            break # Non-network error, don't bother retrying

    # Cleanup files
    for f in glob.glob(f"{temp_filename}*"): 
        try: os.remove(f)
        except: pass

    if not content:
        return None
    
    # --- PARSING ---
    transcript_data = parse_vtt_to_transcript(content)
    if not transcript_data or len(transcript_data) < 10: return None
    
    full_text = " ".join([t['text'] for t in transcript_data])
    difficulty = manual_level if manual_level else analyze_difficulty(transcript_data)

    return {
        "id": f"yt_{video_id}",
        "userId": "system_native",
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

def process_manual_link(url, lang_code, genre="manual", manual_level=None):
    if lang_code not in LANGUAGES:
        print(f"❌ Error: Language code '{lang_code}' not found.")
        return

    print(f"\n==========================================")
    print(f" 🖐️ MANUAL MODE: {lang_code} | Genre: {genre}")
    if manual_level: print(f" 🎯 Forced Level: {manual_level}")
    print(f" 🔗 Processing: {url}")
    print(f"==========================================")

    ydl_opts_check = {'extract_flat': True, 'quiet': True, 'logger': QuietLogger()}
    
    # Store objects: { 'id': '...', 'seriesId': '...', 'seriesTitle': '...', 'seriesIndex': int }
    videos_to_process = []

    with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                # It's a Playlist
                playlist_title = info.get('title', 'Unknown Playlist')
                playlist_id = info.get('id')
                print(f"   📂 Detected Playlist: {playlist_title}")
                
                # Iterate entries with index
                for idx, entry in enumerate(info['entries'], start=1):
                    if entry:
                        videos_to_process.append({
                            'id': entry['id'],
                            'seriesId': playlist_id,
                            'seriesTitle': playlist_title,
                            'seriesIndex': idx
                        })
            else:
                # Single Video
                print(f"   🎬 Detected Video: {info.get('title')}")
                videos_to_process.append({
                    'id': info.get('id'),
                    'seriesId': None,
                    'seriesTitle': None,
                    'seriesIndex': None
                })
        except Exception as e:
            print(f"❌ Error extracting link: {e}")
            return

    print(f"   ⬇️  Queue size: {len(videos_to_process)} videos")

    success_count = 0
    for video_data in videos_to_process:
        vid_id = video_data['id']
        vid_url = f"https://www.youtube.com/watch?v={vid_id}"
        
        print(f"   ⏳ Checking: {vid_url}")
        lesson = get_video_details(vid_url, lang_code, genre, manual_level)
        
        if lesson:
            # Inject Series Metadata if present
            if video_data['seriesId']:
                lesson['seriesId'] = video_data['seriesId']
                lesson['seriesTitle'] = video_data['seriesTitle']
                lesson['seriesIndex'] = video_data['seriesIndex']
            
            if save_lesson_to_file(lang_code, lesson):
                print(f"      ✅ Saved: {lesson['title'][:30]}...")
                success_count += 1
            else:
                print(f"      ⏭️  Duplicate skipped.")
        else:
            print(f"      🚫 Skipped (No subs or error)")
        
        time.sleep(1)

    print(f"\n✅ Manual job done. {success_count} lessons added to trending_{lang_code}.json")

def run_automated_scraping():
    sorted_langs = sorted(LANGUAGES.items())
    print(f"🚀 STARTING NATIVE CONTENT EXTRACTION FOR {len(sorted_langs)} LANGUAGES")

    for lang_code, lang_name in sorted_langs:
        filepath = os.path.join(OUTPUT_DIR, f"trending_{lang_code}.json")
        existing_count = 0
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r') as f: existing_count = len(json.load(f))
            except: pass

        if existing_count >= 15:
             print(f"⏭️  Skipping {lang_name} ({lang_code}): Has {existing_count} native videos.")
             continue

        print(f"\n--- NATIVE FEED: {lang_name} ({lang_code}) ---")
        queries = get_native_queries(lang_code, lang_name)
        random.shuffle(queries)
        
        total_new_for_lang = 0

        for query, genre in queries:
            if total_new_for_lang >= 4: break

            print(f"  🔎 '{query}'")
            ydl_opts_search = {'quiet': True, 'extract_flat': True, 'dump_single_json': True, 'logger': QuietLogger(), 'sleep_interval': random.uniform(1, 3)}
            
            with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
                try:
                    result = ydl.extract_info(f"ytsearch3:{query}", download=False)
                except: continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={entry['id']}", lang_code, genre)
                        if lesson:
                            if save_lesson_to_file(lang_code, lesson):
                                print(f"       ✅ Added: {lesson['title'][:30]}")
                                total_new_for_lang += 1
                                time.sleep(random.uniform(5, 10))
                            else:
                                print(f"       ⏭️  Exists")
                        else:
                            time.sleep(1)

        time.sleep(random.uniform(4, 8))

# --- MAIN ---

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str)
    parser.add_argument("--lang", type=str)
    parser.add_argument("--genre", type=str, default="manual")
    parser.add_argument("--level", type=str, help="Force difficulty level (beginner, intermediate, advanced)")
    args = parser.parse_args()

    if args.link:
        if not args.lang:
            print("❌ --lang required with --link")
            sys.exit(1)
        process_manual_link(args.link, args.lang, args.genre, args.level)
    else:
        run_automated_scraping()

if __name__ == "__main__":
    main()