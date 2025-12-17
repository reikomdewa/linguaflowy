


import json
import os
import re
import glob
import yt_dlp
import time
import random

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/native_videos"

# 1. FULL LANGUAGE LIST
LANGUAGES = {
    # --- Global / European / Asian ---
    'ar': 'Arabic', 'cs': 'Czech', 'da': 'Danish', 'de': 'German', 'el': 'Greek',
    'en': 'English', 'es': 'Spanish', 'fi': 'Finnish', 'fr': 'French', 'hi': 'Hindi',
    'hu': 'Hungarian', 'id': 'Indonesian', 'it': 'Italian', 'ja': 'Japanese',
    'ko': 'Korean', 'nl': 'Dutch', 'no': 'Norwegian', 'pl': 'Polish', 'pt': 'Portuguese',
    'ro': 'Romanian', 'ru': 'Russian', 'sv': 'Swedish', 'th': 'Thai', 'tr': 'Turkish',
    'uk': 'Ukrainian', 'vi': 'Vietnamese', 'zh': 'Chinese',

    # --- African Languages ---
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

# 2. SPECIFIC CURATED CHANNELS (High Quality for Major Langs)
CURATED_CHANNELS = {
    'es': [('VisualPolitik español', 'news'), ('BBC News Mundo', 'news'), ('Luisito Comunica', 'travel'), ('QuantumFracture', 'science')],
    'fr': [('HugoDécrypte', 'news'), ('Nota Bene histoire', 'history'), ('Dr Nozman', 'science'), ('Bruno Maltor', 'travel')],
    'de': [('Simplicissimus', 'society'), ('MrWissen2go', 'news'), ('Terra X', 'environment'), ('Galileo', 'education')],
    'it': [('Breaking Italy', 'news'), ('Nova Lectio', 'society'), ('Geopop', 'science'), ('Podcast Italiano', 'culture')],
    'pt': [('Nexo Jornal', 'news'), ('Manual do Mundo', 'science'), ('Mundo Sem Fim', 'travel'), ('Canal Nostalgia', 'history')],
    'ja': [('ANN news', 'news'), ('Oriental Radio Nakata', 'society'), ('Genki Labo', 'science')],
    'en': [('Vox', 'society'), ('Veritasium', 'science'), ('Vice News', 'news'), ('TED-Ed', 'education')],
}

def get_native_queries(code, name):
    """Generates search queries for native/authentic content."""
    
    # Use curated list if available
    if code in CURATED_CHANNELS:
        return CURATED_CHANNELS[code]
    
    # Generic "Native" Queries for other languages
    # These prioritize authentic content over "learning" content
    return [
        (f"{name} language news", 'news'),
        (f"{name} language documentary", 'documentary'),
        (f"{name} language interview", 'society'),     # Good for natural dialogue
        (f"{name} language comedy", 'comedy'),         # Good for slang/culture
        (f"{name} language music video", 'music'),     # Cultural immersion
        (f"{name} language vlog", 'vlog'),
        (f"{name} language movie", 'cinema'),
        (f"{name} traditional culture", 'culture'),
    ]

# --- HELPERS ---

def time_to_seconds(time_str):
    try:
        parts = time_str.split(':')
        if len(parts) == 3:
            h, m, s = parts
            return int(h) * 3600 + int(m) * 60 + float(s)
        elif len(parts) == 2:
            m, s = parts
            return int(m) * 60 + float(s)
    except:
        return 0.0
    return 0.0

def split_sentences(text):
    if not text: return []
    return re.split(r'(?<=[.!?])\s+', text)

def parse_vtt_to_transcript(vtt_content):
    lines = vtt_content.splitlines()
    transcript = []
    time_pattern = re.compile(r'(\d{2}:\d{2}:\d{2}\.\d{3})\s-->\s(\d{2}:\d{2}:\d{2}\.\d{3})')
    current_entry = None
    
    for line in lines:
        line = line.strip()
        if not line or line == 'WEBVTT' or line.startswith('Kind:') or line.startswith('Language:'):
            continue
        match = time_pattern.search(line)
        if match:
            if current_entry and current_entry['text']:
                transcript.append(current_entry)
            current_entry = {
                'start': time_to_seconds(match.group(1)),
                'end': time_to_seconds(match.group(2)),
                'text': ''
            }
            continue
        if current_entry:
            clean_line = re.sub(r'<[^>]+>', '', line)
            clean_line = clean_line.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')
            if clean_line:
                current_entry['text'] += clean_line + " "

    if current_entry and current_entry['text']:
        transcript.append(current_entry)
    for t in transcript: t['text'] = t['text'].strip()
    return transcript

def analyze_difficulty(transcript):
    # Native content logic: Default to Advanced/Intermediate
    if not transcript: return 'advanced'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'advanced'
    
    avg_len = sum(len(w) for w in words) / len(words)
    
    # Thresholds slightly higher for native content
    if avg_len < 4.0: return 'beginner' # Rare for native content
    if avg_len < 5.0: return 'intermediate'
    return 'advanced'

def get_video_details(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_nat_{lang_code}_{video_id}"
    
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        # Try specific lang, fallback to English (sometimes metadata helps), but logic filters below
        'subtitleslangs': [lang_code], 
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,
        'sleep_interval_requests': 2,
        'extractor_args': {'youtube': {'player_client': ['android', 'web']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            time.sleep(random.uniform(2, 4)) # Pre-request sleep
            
            info = ydl.extract_info(video_url, download=True)
            if not info: return None
            
            # Native content: Allow longer videos (up to 45 mins), ignore Shorts
            duration = info.get('duration', 0)
            if duration < 60 or duration > 2700: 
                return None

            files = glob.glob(f"{temp_filename}*.vtt")
            if not files:
                # Cleanup
                for f in glob.glob(f"{temp_filename}*"): os.remove(f)
                return None
            
            # Use the first VTT found (yt-dlp usually handles the filtering based on opts)
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            
            # Strict filter: Must have substantial text
            if not transcript_data or len(transcript_data) < 10: 
                return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            return {
                "id": f"yt_{video_id}",
                "userId": "system_native",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": "video",
                "difficulty": analyze_difficulty(transcript_data),
                "videoUrl": f"https://youtube.com/watch?v={video_id}",
                "isFavorite": False,
                "progress": 0,
                "genre": genre
            }
    except Exception as e:
        print(f"    ⚠️ Error processing {video_id}: {str(e)[:50]}...")
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    sorted_langs = sorted(LANGUAGES.items())
    
    print(f"🚀 STARTING NATIVE CONTENT EXTRACTION FOR {len(sorted_langs)} LANGUAGES")

    for lang_code, lang_name in sorted_langs:
        
        filepath = os.path.join(OUTPUT_DIR, f"trending_{lang_code}.json")
        
        existing_lessons = []
        existing_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
            except:
                existing_lessons = []

        # SKIP IF FILLED: If we have enough native content (e.g., 15 videos), skip to next lang
        if len(existing_lessons) >= 15:
             print(f"⏭️  Skipping {lang_name} ({lang_code}): Has {len(existing_lessons)} native videos.")
             continue

        print(f"\n==========================================")
        print(f" NATIVE FEED: {lang_name} ({lang_code})")
        print(f"==========================================")

        queries = get_native_queries(lang_code, lang_name)
        # Randomize queries so we don't always get 'news' first if we crash
        random.shuffle(queries)
        
        total_new_for_lang = 0

        for query, genre in queries:
            if total_new_for_lang >= 4: # Limit new videos per run per language
                print(f"  🛑 Native limit reached for {lang_name}.")
                break

            print(f"\n  🔎 Searching: '{query}' ({genre})")
            
            ydl_opts_search = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'sleep_interval': random.uniform(1, 3)
            }
            
            with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
                try:
                    # Search for just 3 candidates per query to keep it fast/safe
                    result = ydl.extract_info(f"ytsearch3:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    time.sleep(5)
                    continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        vid = entry.get('id')
                        title = entry.get('title')
                        lesson_id = f"yt_{vid}"

                        if lesson_id in existing_ids:
                            continue

                        print(f"    ⬇️ Processing: {title[:40]}...")
                        
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang_code, genre)
                        
                        if lesson:
                            existing_lessons.insert(0, lesson)
                            existing_ids.add(lesson_id)
                            total_new_for_lang += 1
                            print(f"       ✅ Added!")
                            
                            # Save immediately
                            try:
                                with open(filepath, 'w', encoding='utf-8') as f:
                                    json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
                            except: pass
                            
                            time.sleep(random.uniform(5, 10))
                        else:
                            print(f"       🚫 Skipped")
                            time.sleep(random.uniform(1, 3))

        print(f"  🏁 Finished {lang_name}. Total: {len(existing_lessons)}")
        
        # Big sleep between languages
        time.sleep(random.uniform(4, 8))

if __name__ == "__main__":
    main()