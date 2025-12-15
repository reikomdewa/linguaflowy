# import json
# import os
# import re
# import glob
# import yt_dlp
# import time

# # --- CONFIGURATION ---
# OUTPUT_DIR = "assets/guided_courses"

# # EXPANDED SEARCH CONFIGURATION
# # Format: 'lang_code': [('Search Query', 'Genre')]
# # Genres: story, news, vlog, history, culture, science, tech, education
# SEARCH_CONFIG = {
#     'es': [
#         # Stories & Comprehensible Input
#         ('Spanish comprehensible input stories beginner', 'story'),
#         ('Dreaming Spanish superbeginner', 'story'),
#         ('BookBox Spanish stories', 'story'),
#         ('Fabulas de Esopo español', 'fairy_tale'),
#         # Vlogs & Daily Life
#         ('Easy Spanish street interviews', 'vlog'),
#         ('Spanish After Hours vlog', 'vlog'),
#         ('Luisito Comunica viajes', 'vlog'), # Native/Advanced
#         # Education & Science
#         ('Curiosamente ciencia', 'science'), # Great clear audio
#         ('Magic Markers explicacion', 'education'),
#         # News & History
#         ('BBC Mundo noticias', 'news'),
#         ('Historia de España para niños', 'history'),
#         ('Tedx Talks en español', 'education')
#     ],
#     'fr': [
#         # Stories
#         ('French comprehensible input stories', 'story'),
#         ('BookBox French', 'story'),
#         ('Contes de fées français', 'fairy_tale'),
#         # Vlogs & Culture
#         ('Easy French street interviews', 'vlog'),
#         ('Piece of French vlog', 'vlog'),
#         ('InnerFrench podcast video', 'culture'),
#         # News & Science
#         ('HugoDécrypte actus du jour', 'news'), # Fast/Native
#         ('1 jour 1 question', 'education'), # Kids news/edu
#         ('C\'est pas sorcier science', 'science'), # Classic science show
#         ('L\'histoire de France racontée', 'history')
#     ],
#     'de': [
#         # Stories
#         ('German comprehensible input beginner', 'story'),
#         ('Hallo Deutschschule stories', 'story'),
#         ('Märchen für kinder deutsch', 'fairy_tale'),
#         # Vlogs
#         ('Easy German street interviews', 'vlog'),
#         ('Dinge Erklärt – Kurzgesagt', 'science'), # High quality science
#         ('MrWissen2go Geschichte', 'history'),
#         # News
#         ('Langsam gesprochene Nachrichten DW', 'news'), # Specifically slow news
#         ('Logo! Nachrichten für Kinder', 'news'),
#         ('Galileo deutschland', 'education')
#     ],
#     'it': [
#         # Stories
#         ('Italian comprehensible input', 'story'),
#         ('Learn Italian with Lucrezia vlog', 'vlog'),
#         ('Podcast Italiano video', 'culture'),
#         # Culture & News
#         ('Storia d\'Italia semplice', 'history'),
#         ('Geopop it', 'science'), # Italian science/geo
#         ('Easy Italian street interviews', 'vlog'),
#         ('Fiabe italiane', 'fairy_tale')
#     ],
#     'pt': [
#         # Brazil
#         ('Portuguese comprehensible input', 'story'),
#         ('Speaking Brazilian vlog', 'vlog'),
#         ('Turma da Mônica', 'story'), # Cultural cartoon
#         ('Nostalgia castanhari', 'history'), # Pop culture history
#         ('Manual do Mundo', 'science'), # Huge science channel
#         # Portugal
#         ('Portuguese from Portugal stories', 'story'),
#         ('RTP noticias portugal', 'news')
#     ],
#     'ja': [
#         # Beginners
#         ('Comprehensible Japanese', 'story'),
#         ('Japanese fairy tales with subtitles', 'fairy_tale'),
#         ('Miku Real Japanese', 'vlog'),
#         ('Onomappu Japanese', 'education'),
#         # Advanced/Native
#         ('Japanese history animation', 'history'),
#         ('Dogen japanese phonetics', 'education'),
#         ('ANN news japanese', 'news'),
#         ('Cooking with Dog japanese', 'culture')
#     ],
#     'en': [
#         ('TED-Ed', 'education'),
#         ('Vox video essays', 'news'),
#         ('Easy English street interviews', 'vlog'),
#         ('History of the entire world i guess', 'history'),
#         ('Kurzgesagt – In a Nutshell', 'science'),
#         ('Short stories for learning english', 'story')
#     ]
# }

# # --- HELPERS ---

# def time_to_seconds(time_str):
#     """Converts HH:MM:SS.mmm to seconds (float)."""
#     try:
#         parts = time_str.split(':')
#         if len(parts) == 3:
#             h, m, s = parts
#             return int(h) * 3600 + int(m) * 60 + float(s)
#         elif len(parts) == 2:
#             m, s = parts
#             return int(m) * 60 + float(s)
#     except:
#         return 0.0
#     return 0.0

# def split_sentences(text):
#     """Splits text for the Flutter model (keeping punctuation)."""
#     if not text: return []
#     # Regex to split by . ! ? but keep the punctuation attached to the previous sentence
#     # clean_text = re.sub(r'\s+', ' ', text)
#     return re.split(r'(?<=[.!?])\s+', text)

# def parse_vtt_to_transcript(vtt_content):
#     """Parses WebVTT content into a list of objects for Flutter."""
#     lines = vtt_content.splitlines()
#     transcript = []
#     time_pattern = re.compile(r'(\d{2}:\d{2}:\d{2}\.\d{3})\s-->\s(\d{2}:\d{2}:\d{2}\.\d{3})')
    
#     current_entry = None
    
#     for line in lines:
#         line = line.strip()
#         if not line or line == 'WEBVTT' or line.startswith('Kind:') or line.startswith('Language:'):
#             continue
            
#         match = time_pattern.search(line)
#         if match:
#             if current_entry and current_entry['text']:
#                 transcript.append(current_entry)
            
#             current_entry = {
#                 'start': time_to_seconds(match.group(1)),
#                 'end': time_to_seconds(match.group(2)),
#                 'text': ''
#             }
#             continue
            
#         if current_entry:
#             clean_line = re.sub(r'<[^>]+>', '', line)
#             clean_line = clean_line.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')
#             if clean_line:
#                 current_entry['text'] += clean_line + " "

#     if current_entry and current_entry['text']:
#         transcript.append(current_entry)
        
#     for t in transcript: 
#         t['text'] = t['text'].strip()
        
#     return transcript

# def analyze_difficulty(transcript):
#     """Heuristic to determine difficulty based on avg word length."""
#     if not transcript: return 'intermediate'
#     all_text = " ".join([t['text'] for t in transcript])
#     words = all_text.split()
#     if not words: return 'intermediate'
    
#     avg_len = sum(len(w) for w in words) / len(words)
    
#     # Specific adjustments per language could go here
#     if avg_len < 4.2: return 'beginner'
#     if avg_len > 6.0: return 'advanced' # Bumped up slightly
#     return 'intermediate'

# def get_video_details(video_url, lang_code, genre):
#     video_id = video_url.split('v=')[-1]
#     temp_filename = f"temp_gen_{video_id}" # Distinct temp name
    
#     ydl_opts = {
#         'skip_download': True,
#         'writesubtitles': True,
#         'writeautomaticsub': True,    
#         'subtitleslangs': [lang_code], 
#         'outtmpl': temp_filename,
#         'quiet': True,
#         'no_warnings': True,
#         'extractor_args': {'youtube': {'player_client': ['android']}}
#     }

#     try:
#         with yt_dlp.YoutubeDL(ydl_opts) as ydl:
#             info = ydl.extract_info(video_url, download=True)
            
#             # Skip videos longer than 20 mins to save space/processing
#             if info.get('duration', 0) > 1200:
#                 print(f"    ⚠️ Skipping (Too long): {info.get('title')}")
#                 return None

#             files = glob.glob(f"{temp_filename}*.vtt")
            
#             if not files:
#                 return None
            
#             with open(files[0], 'r', encoding='utf-8') as f:
#                 content = f.read()
            
#             for f in files: 
#                 try: os.remove(f)
#                 except: pass
            
#             transcript_data = parse_vtt_to_transcript(content)
#             if not transcript_data: return None
            
#             full_text = " ".join([t['text'] for t in transcript_data])

#             return {
#                 "id": f"yt_{video_id}",
#                 "userId": "system",
#                 "title": info.get('title', 'Unknown Title'),
#                 "language": lang_code,
#                 "content": full_text,
#                 "sentences": split_sentences(full_text),
#                 "transcript": transcript_data,
#                 "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
#                 "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
#                 "type": "video",
#                 "difficulty": analyze_difficulty(transcript_data),
#                 "videoUrl": f"https://youtube.com/watch?v={video_id}",
#                 "isFavorite": False,
#                 "progress": 0,
#                 "genre": genre
#             }
#     except Exception as e:
#         print(f"    ⚠️ Error processing {video_id}: {str(e)[:50]}...")
#         for f in glob.glob(f"{temp_filename}*"):
#             try: os.remove(f)
#             except: pass
#         return None

# def main():
#     if not os.path.exists(OUTPUT_DIR):
#         os.makedirs(OUTPUT_DIR)

#     for lang, categories in SEARCH_CONFIG.items():
#         print(f"\n==========================================")
#         print(f" PROCESSING LANGUAGE: {lang.upper()}")
#         print(f"==========================================")
        
#         filepath = os.path.join(OUTPUT_DIR, f"lessons_{lang}.json")
        
#         existing_lessons = []
#         existing_ids = set()
        
#         # 1. LOAD EXISTING
#         if os.path.exists(filepath):
#             try:
#                 with open(filepath, 'r', encoding='utf-8') as f:
#                     existing_lessons = json.load(f)
#                     existing_ids = {l['id'] for l in existing_lessons}
#                 print(f"  📚 Loaded {len(existing_lessons)} existing videos.")
#             except:
#                 print("  🆕 No valid existing file found. Starting fresh.")
#                 existing_lessons = []

#         total_new_for_lang = 0

#         # 2. SEARCH NEW
#         for query, genre in categories:
#             print(f"\n  🔎 Searching: '{query}' ({genre})")
            
#             ydl_opts = {
#                 'quiet': True,
#                 'extract_flat': True,
#                 'dump_single_json': True,
#                 'extractor_args': {'youtube': {'player_client': ['android']}}
#             }
            
#             with yt_dlp.YoutubeDL(ydl_opts) as ydl:
#                 # Search for 6 videos per query (Keep it balanced)
#                 try:
#                     result = ydl.extract_info(f"ytsearch6:{query}", download=False)
#                 except Exception as e:
#                     print(f"    ❌ Search failed: {e}")
#                     continue
                
#                 if 'entries' in result:
#                     for entry in result['entries']:
#                         if not entry: continue
                        
#                         vid = entry.get('id')
#                         title = entry.get('title')
#                         lesson_id = f"yt_{vid}"

#                         # DUPLICATE CHECK
#                         if lesson_id in existing_ids:
#                             continue

#                         print(f"    ⬇️ Processing: {title[:40]}...")
                        
#                         lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang, genre)
                        
#                         if lesson:
#                             # Prepend to list (Newest first)
#                             existing_lessons.insert(0, lesson)
#                             existing_ids.add(lesson_id)
#                             total_new_for_lang += 1
#                             print(f"       ✅ Added!")
#                         else:
#                             print(f"       🚫 Skipped (No subs/Error)")
                        
#                         time.sleep(1)

#         # 3. SAVE
#         try:
#             with open(filepath, 'w', encoding='utf-8') as f:
#                 json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
#             print(f"\n  💾 SAVED {lang.upper()}: +{total_new_for_lang} new. Total: {len(existing_lessons)}")
#         except Exception as e:
#             print(f"  ❌ Error saving file: {e}")

# if __name__ == "__main__":
#     main()





import json
import os
import re
import glob
import yt_dlp
import time
import random

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/guided_courses"

# 1. COMPREHENSIVE LANGUAGE LIST (Name -> Code mapping included)
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

# 2. SPECIFIC OVERRIDES FOR MAJOR LANGUAGES (High quality curated lists)
SPECIFIC_SEARCH_CONFIG = {
    'es': [('Spanish comprehensible input stories', 'story'), ('BBC Mundo', 'news')],
    'fr': [('French comprehensible input', 'story'), ('HugoDécrypte', 'news')],
    'de': [('Dinge Erklärt – Kurzgesagt', 'science'), ('Easy German', 'vlog')],
    'it': [('Learn Italian with Lucrezia', 'vlog'), ('Podcast Italiano', 'culture')],
    'pt': [('Speaking Brazilian', 'vlog'), ('Manual do Mundo', 'science')],
    'ja': [('Comprehensible Japanese', 'story'), ('Miku Real Japanese', 'vlog')],
    'en': [('TED-Ed', 'education'), ('Kurzgesagt', 'science')],
}

def get_queries_for_language(code, name):
    """Generates search queries dynamically for any language."""
    # If we have a curated list, use it
    if code in SPECIFIC_SEARCH_CONFIG:
        return SPECIFIC_SEARCH_CONFIG[code]
    
    # Otherwise, generate standard queries for discovery
    # Using "language" explicitly helps avoid unrelated results (e.g. "Ga" the element vs "Ga" the language)
    return [
        (f"{name} language stories", 'story'),
        (f"Learn {name} language conversation", 'education'),
        (f"{name} language news", 'news'),
        (f"{name} language cartoon", 'fairy_tale'),
        (f"{name} language documentary", 'history'),
        (f"{name} gospel song lyrics", 'culture'), # Gospel often has subtitles in African context
    ]

# --- HELPERS ---

def time_to_seconds(time_str):
    """Converts HH:MM:SS.mmm to seconds (float)."""
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
        
    for t in transcript: 
        t['text'] = t['text'].strip()
        
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

def get_video_details(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_{lang_code}_{video_id}"
    
    # ROBUST DL OPTIONS
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,    
        # We try to get the specific language, but also auto-generated
        'subtitleslangs': [lang_code, 'en'], # Fetching EN too can sometimes help if it's a dual sub, but logic below handles VTT
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True, # Don't crash on private videos
        # RANDOM SLEEP TO PREVENT BLOCKING
        'sleep_interval_requests': 2,
        'sleep_interval': 3,
        'extractor_args': {'youtube': {'player_client': ['android', 'web']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Random sleep before processing details
            time.sleep(random.uniform(2, 5))
            
            info = ydl.extract_info(video_url, download=True)
            
            if not info: return None

            # Skip long videos (likely full movies or church services without good subs)
            if info.get('duration', 0) > 1800: # 30 mins limit
                print(f"    ⚠️ Skipping (Too long): {info.get('title')}")
                return None

            # Look for the specific language VTT
            files = glob.glob(f"{temp_filename}*.{lang_code}.vtt")
            
            # Fallback: if no specific lang, check if we got ANY vtt (sometimes code differs slightly)
            if not files:
                files = glob.glob(f"{temp_filename}*.vtt")

            if not files:
                # Cleanup and return
                for f in glob.glob(f"{temp_filename}*"): os.remove(f)
                return None
            
            # Prefer the one matching lang_code, else take first
            selected_file = files[0]
            for f in files:
                if f".{lang_code}.vtt" in f:
                    selected_file = f
                    break

            with open(selected_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Clean up immediately
            for f in glob.glob(f"{temp_filename}*"): 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            
            # Filter: If transcript is empty or too short
            if not transcript_data or len(transcript_data) < 5: 
                return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            return {
                "id": f"yt_{video_id}",
                "userId": "system",
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

    # Sort languages to keep logs tidy
    sorted_langs = sorted(LANGUAGES.items())

    print(f"🚀 STARTING EXTRACTION FOR {len(sorted_langs)} LANGUAGES")
    print(f"ℹ️  This process is throttled to prevent IP bans. It will take time.")

    for lang_code, lang_name in sorted_langs:
        
        filepath = os.path.join(OUTPUT_DIR, f"lessons_{lang_code}.json")
        
        # Load Existing
        existing_lessons = []
        existing_ids = set()
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
            except:
                existing_lessons = []

        # If we already have plenty of content for this language, skip to save time/quota
        # (e.g., if we already have 20 videos, move to the next language)
        if len(existing_lessons) >= 20:
             print(f"⏭️  Skipping {lang_name} ({lang_code}): Already has {len(existing_lessons)} videos.")
             continue

        print(f"\n==========================================")
        print(f" PROCESSING: {lang_name} ({lang_code})")
        print(f"==========================================")

        queries = get_queries_for_language(lang_code, lang_name)
        total_new_for_lang = 0

        for query, genre in queries:
            # Stop if we hit a quota per language for this run
            if total_new_for_lang >= 5: 
                print(f"  🛑 Reached new video limit for {lang_name}. Moving on.")
                break

            print(f"\n  🔎 Searching: '{query}'")
            
            # SEARCH OPTIONS
            ydl_opts_search = {
                'quiet': True,
                'extract_flat': True, 
                'dump_single_json': True,
                # Random sleep minimizes pattern detection
                'sleep_interval': random.uniform(1, 3) 
            }
            
            with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
                try:
                    # Search for 5 videos. Keeping it low decreases blockage risk.
                    result = ydl.extract_info(f"ytsearch5:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    # Long sleep if search fails (possible soft block)
                    time.sleep(10)
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
                        
                        # PROCESS VIDEO
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang_code, genre)
                        
                        if lesson:
                            existing_lessons.insert(0, lesson)
                            existing_ids.add(lesson_id)
                            total_new_for_lang += 1
                            print(f"       ✅ Added!")
                            
                            # Save immediately after every success to prevent data loss
                            try:
                                with open(filepath, 'w', encoding='utf-8') as f:
                                    json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
                            except: pass

                            # IMPORTANT: Sleep between downloads
                            sleep_time = random.uniform(5, 12)
                            print(f"       💤 Sleeping {sleep_time:.1f}s...")
                            time.sleep(sleep_time)
                        else:
                            print(f"       🚫 Skipped (No subs/Error)")
                            # Short sleep even on failure
                            time.sleep(random.uniform(1, 3))

        print(f"  🏁 Finished {lang_name}. Total videos: {len(existing_lessons)}")
        
        # Larger sleep between Languages to reset connection heuristics
        long_sleep = random.uniform(5, 10)
        print(f"  💤 Big nap between languages ({long_sleep:.1f}s)...")
        time.sleep(long_sleep)

if __name__ == "__main__":
    main()