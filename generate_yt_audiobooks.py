# import json
# import os
# import re
# import glob
# import yt_dlp
# import time

# # --- CONFIGURATION ---
# OUTPUT_DIR = "assets/youtube_audio_library"

# # EXPANDED SEARCH CONFIGURATION
# # Focus: "Read Along", "Audiobook with Text", "Subtitled Stories"
# # Strategies:
# # 1. Search for "Audiobook with text" (High chance of perfect sync)
# # 2. Search for "Graded Reader" (Simplified content for learners)
# # 3. Search for specific classic authors
# SEARCH_CONFIG = {
#     'es': [
#         ('Audiolibro español con texto en pantalla', 'audiobook'),
#         ('Spanish graded reader level 1', 'audiobook'),
#         ('Cuentos cortos para dormir español', 'story'),
#         ('Historia de España para niños', 'history'),
#         ('Spanish audiobook for beginners', 'audiobook'),
#         ('Don Quijote audiolibro resumen', 'classic'),
#         ('Gabriel García Márquez audiolibro voz humana', 'classic')
#     ],
#     'fr': [
#         ('Livre audio français avec texte', 'audiobook'),
#         ('French graded reader A1 A2', 'audiobook'),
#         ('Contes de Perrault audio texte', 'classic'),
#         ('Le Petit Prince livre audio complet', 'classic'),
#         ('Lupin livre audio français', 'mystery'),
#         ('Maupassant audio nouvelle', 'classic'),
#         ('French short stories for beginners', 'story')
#     ],
#     'de': [
#         ('Hörbuch deutsch mit text', 'audiobook'),
#         ('German graded reader A1', 'audiobook'),
#         ('Märchen der Gebrüder Grimm hörspiel', 'classic'),
#         ('Deutsch lernen durch hören', 'story'),
#         ('Kafka Die Verwandlung hörbuch', 'classic'),
#         ('Short stories in German for beginners', 'story')
#     ],
#     'it': [
#         ('Audiolibro italiano con testo', 'audiobook'),
#         ('Italian graded reader A1', 'audiobook'),
#         ('Pinocchio audiolibro completo', 'classic'),
#         ('Favole al telefono Rodari', 'story'),
#         ('Italian short stories for beginners', 'story')
#     ],
#     'pt': [
#         ('Audiolivro com texto portugues brasil', 'audiobook'),
#         ('Portuguese graded reader', 'audiobook'),
#         ('Machado de Assis audiolibro', 'classic'),
#         ('Turma da Mônica audiodescrição', 'story'),
#         ('Lendas brasileiras animação', 'story')
#     ],
#     'ja': [
#         ('Japanese audiobook with subtitles', 'audiobook'),
#         ('Japanese graded reader', 'audiobook'),
#         ('Japanese folklore stories subtitles', 'story'),
#         ('Miyazawa Kenji audiobook', 'classic'),
#         ('Soseki Natsume audiobook', 'classic')
#     ],
#     'en': [
#         ('English audiobook with text on screen', 'audiobook'),
#         ('Sherlock Holmes audiobook with text', 'classic'),
#         ('English short stories for learning', 'story'),
#         ('History of English language documentary', 'history')
#     ]
# }

# def time_to_seconds(time_str):
#     """Converts HH:MM:SS.mmm OR MM:SS.mmm to seconds."""
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
#     return re.split(r'(?<=[.!?])\s+', text)

# def parse_vtt_to_transcript(vtt_content):
#     lines = vtt_content.splitlines()
#     transcript = []
#     # Regex to catch standard VTT timestamps (00:00:00.000)
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
#             # Clean HTML tags often found in subs
#             clean_line = re.sub(r'<[^>]+>', '', line)
#             clean_line = clean_line.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')
#             if clean_line:
#                 current_entry['text'] += clean_line + " "

#     if current_entry and current_entry['text']:
#         transcript.append(current_entry)
    
#     # Clean up whitespace
#     for t in transcript: t['text'] = t['text'].strip()
#     return transcript

# def process_audiobook_video(video_url, lang_code, genre):
#     video_id = video_url.split('v=')[-1]
#     temp_filename = f"temp_audio_{video_id}"
    
#     # Only get videos that have subtitles (subs) or auto-subs (writeautomaticsub)
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
            
#             # Duration Filter: 
#             # Skip if < 2 mins (likely intro/promo) 
#             # Skip if > 90 mins (too heavy for mobile app typically)
#             duration = info.get('duration', 0)
#             if duration < 120 or duration > 5400: 
#                 print(f"    ⚠️ Skipping duration: {duration}s")
#                 return None
            
#             files = glob.glob(f"{temp_filename}*.vtt")
#             if not files:
#                 return None
            
#             # Read Transcript
#             with open(files[0], 'r', encoding='utf-8') as f:
#                 content = f.read()
            
#             # Cleanup temp files immediately
#             for f in files: 
#                 try: os.remove(f)
#                 except: pass
            
#             transcript_data = parse_vtt_to_transcript(content)
#             if not transcript_data: return None
            
#             full_text = " ".join([t['text'] for t in transcript_data])

#             # Difficulty Heuristic
#             words = full_text.split()
#             avg_len = sum(len(w) for w in words) / len(words) if words else 5
#             difficulty = "intermediate"
#             if "graded reader" in info.get('title', '').lower(): difficulty = "beginner"
#             elif avg_len > 5.5: difficulty = "advanced"

#             return {
#                 "id": f"yt_audio_{video_id}",
#                 "userId": "system_audiobook",
#                 "title": info.get('title', 'Unknown Title'),
#                 "language": lang_code,
#                 "content": full_text, # Full text for searching/reading
#                 "sentences": split_sentences(full_text),
#                 "transcript": transcript_data, # Synced timestamps
#                 "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
#                 "imageUrl": info.get('thumbnail'),
#                 "type": "audio", # Treat as audio in your app logic
#                 "videoUrl": f"https://youtube.com/watch?v={video_id}", # Use YT player as audio engine
#                 "difficulty": difficulty, 
#                 "genre": genre,
#                 "isFavorite": False,
#                 "progress": 0
#             }
#     except Exception as e:
#         # print(f"    ⚠️ Error: {str(e)[:50]}")
#         # Clean up if error occurred
#         for f in glob.glob(f"{temp_filename}*"):
#             try: os.remove(f)
#             except: pass
#         return None

# def main():
#     if not os.path.exists(OUTPUT_DIR):
#         os.makedirs(OUTPUT_DIR)

#     for lang, categories in SEARCH_CONFIG.items():
#         print(f"\n==========================================")
#         print(f" PROCESSING AUDIOBOOKS: {lang.upper()}")
#         print(f"==========================================")
        
#         filepath = os.path.join(OUTPUT_DIR, f"audiobooks_{lang}.json")
        
#         existing_lessons = []
#         existing_ids = set()
        
#         # 1. LOAD EXISTING DATA (Handling Duplicates)
#         if os.path.exists(filepath):
#             try:
#                 with open(filepath, 'r', encoding='utf-8') as f:
#                     existing_lessons = json.load(f)
#                     existing_ids = {l['id'] for l in existing_lessons}
#                 print(f"  📚 Loaded {len(existing_lessons)} existing audiobooks.")
#             except:
#                 print("  🆕 No existing file found.")

#         total_new = 0

#         # 2. SEARCH NEW CONTENT
#         for query, genre in categories:
#             print(f"\n  🔍 Query: '{query}' ({genre})")
            
#             ydl_opts = {
#                 'quiet': True,
#                 'extract_flat': True,
#                 'dump_single_json': True,
#                 'extractor_args': {'youtube': {'player_client': ['android']}}
#             }
            
#             with yt_dlp.YoutubeDL(ydl_opts) as ydl:
#                 try:
#                     # Get top 3 results per query (keeps library high quality)
#                     result = ydl.extract_info(f"ytsearch3:{query}", download=False)
#                 except Exception as e:
#                     print(f"    ❌ Search failed: {e}")
#                     continue
                
#                 if 'entries' in result:
#                     for entry in result['entries']:
#                         if not entry: continue
                        
#                         vid = entry.get('id')
#                         lesson_id = f"yt_audio_{vid}"

#                         # DUPLICATE PROTECTION
#                         if lesson_id in existing_ids:
#                             continue

#                         print(f"    ⬇️ Fetching: {entry.get('title', '')[:40]}...")
#                         lesson = process_audiobook_video(f"https://www.youtube.com/watch?v={vid}", lang, genre)
                        
#                         if lesson:
#                             existing_lessons.append(lesson)
#                             existing_ids.add(lesson_id)
#                             total_new += 1
#                             print("       ✅ Saved")
#                         else:
#                             print("       🚫 Skipped")
                        
#                         time.sleep(1)

#         # 3. SAVE FILE
#         with open(filepath, 'w', encoding='utf-8') as f:
#             json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
            
#         print(f"\n  💾 SAVED {lang.upper()}: Added {total_new} new items.")

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
OUTPUT_DIR = "assets/youtube_audio_library"

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

# 2. SPECIFIC QUERIES FOR MAJOR LANGUAGES
# Optimized for "Learner Content"
CURATED_AUDIOBOOKS = {
    'es': [('Audiolibro español con texto', 'audiobook'), ('Spanish graded reader', 'audiobook'), ('Cuentos para dormir español', 'story')],
    'fr': [('Livre audio français avec texte', 'audiobook'), ('French graded reader', 'audiobook'), ('Le Petit Prince audio', 'classic')],
    'de': [('Hörbuch deutsch mit text', 'audiobook'), ('German graded reader', 'audiobook'), ('Märchen hörspiel', 'classic')],
    'it': [('Audiolibro italiano con testo', 'audiobook'), ('Italian graded reader', 'audiobook'), ('Favole al telefono', 'story')],
    'pt': [('Audiolivro com texto portugues', 'audiobook'), ('Portuguese graded reader', 'audiobook'), ('Lendas brasileiras', 'story')],
    'ja': [('Japanese audiobook with subtitles', 'audiobook'), ('Japanese folklore stories', 'story')],
    'en': [('English audiobook with text', 'audiobook'), ('Sherlock Holmes audiobook', 'classic')],
}

def get_audiobook_queries(code, name):
    """
    Generates queries suitable for finding 'listening practice' content.
    For African languages, we pivot to Bible/Folktales as they are the 
    most common sources of high-quality audio+text.
    """
    if code in CURATED_AUDIOBOOKS:
        return CURATED_AUDIOBOOKS[code]
    
    # Generic Strategy for African/Other languages
    return [
        # The Bible is often the ONLY source of high-quality, text-synced audio for many African languages
        (f"{name} language bible audio with text", 'religion'), 
        (f"{name} language audio bible", 'religion'),
        
        # Oral tradition / Storytelling
        (f"{name} language stories", 'story'), 
        (f"{name} language folktales", 'story'),
        (f"{name} language fairy tales", 'story'),
        
        # Music with lyrics is a great proxy for "Audiobook" reading practice
        (f"{name} gospel song lyrics", 'music'), 
        
        # General literature
        (f"{name} language poems audio", 'poetry'),
        (f"{name} language reading practice", 'education'),
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

def analyze_difficulty(text, title):
    # Simple heuristic
    lower_title = title.lower()
    if "graded reader" in lower_title or "beginner" in lower_title or "level 1" in lower_title:
        return "beginner"
    
    words = text.split()
    if not words: return "intermediate"
    avg_len = sum(len(w) for w in words) / len(words)
    
    if avg_len < 4.5: return "beginner"
    if avg_len > 6.0: return "advanced"
    return "intermediate"

def process_audiobook_video(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_aud_{lang_code}_{video_id}"
    
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        # Try to find specific lang subs, fallback to auto
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
            # Random sleep before extracting info
            time.sleep(random.uniform(2, 4))
            
            info = ydl.extract_info(video_url, download=True)
            if not info: return None
            
            # Duration: Allow longer files for Audiobooks (up to 2 hours)
            # But skip very short ones (< 2 mins)
            duration = info.get('duration', 0)
            if duration < 120 or duration > 7200: 
                return None
            
            files = glob.glob(f"{temp_filename}*.vtt")
            if not files:
                # Cleanup
                for f in glob.glob(f"{temp_filename}*"): os.remove(f)
                return None
            
            # Read Transcript
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Cleanup
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            
            # Strict Filter: Audiobooks must have good text density
            if not transcript_data or len(transcript_data) < 15: 
                return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            return {
                "id": f"yt_audio_{video_id}",
                "userId": "system_audiobook",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": info.get('thumbnail') or f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": "audio", 
                "videoUrl": f"https://youtube.com/watch?v={video_id}",
                "difficulty": analyze_difficulty(full_text, info.get('title', '')), 
                "genre": genre,
                "isFavorite": False,
                "progress": 0
            }
    except Exception as e:
        print(f"    ⚠️ Error processing {video_id}: {str(e)[:50]}")
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    sorted_langs = sorted(LANGUAGES.items())
    
    print(f"🎧 STARTING AUDIOBOOK LIBRARY UPDATE FOR {len(sorted_langs)} LANGUAGES")

    for lang_code, lang_name in sorted_langs:
        
        filepath = os.path.join(OUTPUT_DIR, f"audiobooks_{lang_code}.json")
        
        existing_lessons = []
        existing_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
            except:
                existing_lessons = []

        # SKIP IF FILLED: If we have enough audiobooks (e.g., 10), skip to next lang
        if len(existing_lessons) >= 10:
             print(f"⏭️  Skipping {lang_name} ({lang_code}): Library full ({len(existing_lessons)} items).")
             continue

        print(f"\n==========================================")
        print(f" PROCESSING: {lang_name} ({lang_code})")
        print(f"==========================================")
        
        queries = get_audiobook_queries(lang_code, lang_name)
        # Randomize so we don't always search Bible first if script restarts
        random.shuffle(queries)
        
        total_new_for_lang = 0

        for query, genre in queries:
            if total_new_for_lang >= 3: # Limit new items per run to keep it distributed
                print(f"  🛑 Limit reached for {lang_name} this run.")
                break

            print(f"\n  🔍 Query: '{query}' ({genre})")
            
            ydl_opts_search = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'sleep_interval': random.uniform(1, 3)
            }
            
            with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
                try:
                    # Search for top 4 candidates
                    result = ydl.extract_info(f"ytsearch4:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    time.sleep(5)
                    continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        vid = entry.get('id')
                        lesson_id = f"yt_audio_{vid}"

                        if lesson_id in existing_ids:
                            continue

                        print(f"    ⬇️ Fetching: {entry.get('title', 'Unknown')[:40]}...")
                        lesson = process_audiobook_video(f"https://www.youtube.com/watch?v={vid}", lang_code, genre)
                        
                        if lesson:
                            existing_lessons.append(lesson)
                            existing_ids.add(lesson_id)
                            total_new_for_lang += 1
                            print("       ✅ Saved")
                            
                            # Incremental Save
                            try:
                                with open(filepath, 'w', encoding='utf-8') as f:
                                    json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
                            except: pass
                            
                            time.sleep(random.uniform(5, 10))
                        else:
                            print("       🚫 Skipped (No text/Subs)")
                            time.sleep(random.uniform(1, 3))

        print(f"  🏁 Finished {lang_name}. Total: {len(existing_lessons)}")
        
        # Big sleep between languages
        time.sleep(random.uniform(4, 8))

if __name__ == "__main__":
    main()