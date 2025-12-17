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

# 2. SPECIFIC QUERIES FOR MAJOR LANGUAGES
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

def get_audiobook_queries(code, name):
    if code in CURATED_AUDIOBOOKS:
        return CURATED_AUDIOBOOKS[code]
    return [
        (f"{name} language bible audio with text", 'religion'), 
        (f"{name} language audio bible", 'religion'),
        (f"{name} language stories", 'story'), 
        (f"{name} language folktales", 'story'),
        (f"{name} language fairy tales", 'story'),
        (f"{name} gospel song lyrics", 'music'), 
        (f"{name} language poems audio", 'poetry'),
        (f"{name} language reading practice", 'education'),
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

def analyze_difficulty(text, title):
    lower_title = title.lower()
    if "graded reader" in lower_title or "beginner" in lower_title or "level 1" in lower_title:
        return "beginner"
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

def get_audiobook_details(video_url, lang_code, genre, manual_level=None):
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

            # DURATION RULES
            # Manual: Up to 4 hours (14400s)
            # Auto: Up to 2 hours (7200s)
            duration = info.get('duration', 0)
            max_dur = 14400 if genre == 'manual' else 7200
            
            if duration < 120 or duration > max_dur: 
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

    except Exception as e:
        print(f"    ❌ Inspection error: {str(e)[:50]}")
        return None

    video_id = info['id']
    temp_filename = f"temp_aud_{lang_code}_{video_id}"
    
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
            with open(best_file, 'r', encoding='utf-8') as f: content = f.read()
            for f in glob.glob(f"{temp_filename}*"): 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data or len(transcript_data) < 15: return None
            
            full_text = " ".join([t['text'] for t in transcript_data])
            difficulty = manual_level if manual_level else analyze_difficulty(full_text, info.get('title', ''))

            return {
                "id": f"yt_audio_{video_id}",
                "userId": "system_audiobook",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": info.get('thumbnail') or f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg",
                "type": "audio", 
                "videoUrl": f"https://www.youtube.com/watch?v={video_id}",
                "difficulty": difficulty,
                "genre": genre,
                "isFavorite": False,
                "progress": 0
            }
    except Exception as e:
        print(f"    ⚠️ Download error: {str(e)[:50]}")
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

# --- WORKFLOWS ---

def process_manual_link(url, lang_code, genre="manual", manual_level=None):
    if lang_code not in LANGUAGES:
        print(f"❌ Error: Language code '{lang_code}' not found.")
        return

    print(f"\n==========================================")
    print(f" 🎧 MANUAL AUDIO: {lang_code} | Genre: {genre}")
    if manual_level: print(f" 🎯 Forced Level: {manual_level}")
    print(f" 🔗 Processing: {url}")
    print(f"==========================================")

    ydl_opts_check = {'extract_flat': True, 'quiet': True, 'logger': QuietLogger()}
    videos_to_process = []

    with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                # Playlist Detected
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
                # Single Video
                print(f"   🎬 Video: {info.get('title')}")
                videos_to_process.append({
                    'id': info.get('id'),
                    'seriesId': None,
                    'seriesTitle': None,
                    'seriesIndex': None
                })
        except Exception as e:
            print(f"❌ Error extracting link: {e}")
            return

    print(f"   ⬇️  Queue size: {len(videos_to_process)} items")

    count = 0
    for video_data in videos_to_process:
        vid_id = video_data['id']
        vid_url = f"https://www.youtube.com/watch?v={vid_id}"
        
        print(f"   ⏳ Checking: {vid_url}")
        lesson = get_audiobook_details(vid_url, lang_code, genre, manual_level)
        
        if lesson:
            # Inject Playlist Metadata
            if video_data['seriesId']:
                lesson['seriesId'] = video_data['seriesId']
                lesson['seriesTitle'] = video_data['seriesTitle']
                lesson['seriesIndex'] = video_data['seriesIndex']

            if save_lesson_to_file(lang_code, lesson):
                print(f"      ✅ Saved: {lesson['title'][:30]}...")
                count += 1
            else:
                print(f"      ⏭️  Duplicate.")
        else:
            print(f"      🚫 Skipped (No subs/Too short).")
        
        time.sleep(1)

    print(f"\n✅ Manual job done. Added {count} audiobooks to audiobooks_{lang_code}.json")

def run_automated_scraping():
    sorted_langs = sorted(LANGUAGES.items())
    print(f"🎧 STARTING AUDIOBOOK LIBRARY UPDATE FOR {len(sorted_langs)} LANGUAGES")

    for lang_code, lang_name in sorted_langs:
        filepath = os.path.join(OUTPUT_DIR, f"audiobooks_{lang_code}.json")
        existing_count = 0
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r') as f: existing_count = len(json.load(f))
            except: pass

        if existing_count >= 10:
             print(f"⏭️  Skipping {lang_name} ({lang_code}): Has {existing_count} items.")
             continue

        print(f"\n--- AUDIOBOOK FEED: {lang_name} ({lang_code}) ---")
        queries = get_audiobook_queries(lang_code, lang_name)
        random.shuffle(queries)
        
        total_new_for_lang = 0

        for query, genre in queries:
            if total_new_for_lang >= 3: break

            print(f"  🔎 '{query}'")
            ydl_opts_search = {'quiet': True, 'extract_flat': True, 'dump_single_json': True, 'logger': QuietLogger(), 'sleep_interval': random.uniform(1, 3)}
            
            with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
                try:
                    result = ydl.extract_info(f"ytsearch4:{query}", download=False)
                except: continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        lesson = get_audiobook_details(f"https://www.youtube.com/watch?v={entry['id']}", lang_code, genre)
                        
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

    parser = argparse.ArgumentParser(description="Scrape YouTube for Audiobooks")
    parser.add_argument("--link", type=str, help="YouTube Video or Playlist URL")
    parser.add_argument("--lang", type=str, help="Language code (e.g., 'es', 'fr') - Required with --link")
    parser.add_argument("--genre", type=str, default="manual", help="Genre tag for the manual download")
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