# import json
# import os
# import re
# import glob
# import yt_dlp
# import time

# # --- CONFIGURATION ---

# OUTPUT_DIR = "assets/course_videos"

# # --- DURATION RULES (In Seconds) ---
# DURATION_RULES = {
#     # Stories: 1 min to 25 mins (Extended slightly for deeper stories)
#     'Stories':      (60, 1500),  
    
#     # News: 45 secs to 15 mins
#     'News':         (45, 900),   
    
#     # Bites: 10 secs to 90 secs (Strictly Shorts/Reels style)
#     'Bites':        (10, 90),    
    
#     # Grammar: 30 secs to 12 mins
#     'Grammar tips': (30, 720),   
# }

# # --- EXPANDED SEARCH QUERIES ---
# # Format: 'lang_code': [('Query', 'Category')]
# # We mix specific topics to ensure the course has variety.
# SEARCH_CONFIG = {
#     'es': [
#         # --- STORIES ---
#         ('Spanish comprehensible input beginner', 'Stories'),
#         ('Cuentos de hadas españoles', 'Stories'),
#         ('Dreaming Spanish superbeginner', 'Stories'),
#         ('Hola Spanish stories', 'Stories'),
#         ('Spanish stories slow audio', 'Stories'),
#         # --- NEWS ---
#         ('BBC News Mundo', 'News'),
#         ('CNN en Español 5 cosas', 'News'),
#         ('Noticias Telemundo', 'News'),
#         ('Euronews español', 'News'),
#         # --- BITES (Shorts/Vocab) ---
#         ('Spanish slang shorts', 'Bites'),
#         ('Spanish word of the day', 'Bites'),
#         ('Mexican spanish phrases', 'Bites'),
#         ('Common spanish idioms', 'Bites'),
#         # --- GRAMMAR (Specific Topics) ---
#         ('Por vs Para explained', 'Grammar tips'),
#         ('Ser vs Estar spanish', 'Grammar tips'),
#         ('Spanish subjunctive mood explained', 'Grammar tips'),
#         ('Spanish past tense preterite imperfect', 'Grammar tips'),
#         ('Spanish reflexives explained', 'Grammar tips'),
#         ('Direct object pronouns spanish', 'Grammar tips')
#     ],
#     'fr': [
#         # --- STORIES ---
#         ('French comprehensible input', 'Stories'),
#         ('Contes de fées français', 'Stories'),
#         ('Alice Ayel french stories', 'Stories'),
#         ('French stories with subtitles', 'Stories'),
#         # --- NEWS ---
#         ('France 24 français', 'News'),
#         ('HugoDécrypte actus', 'News'),
#         ('Le Monde video', 'News'),
#         ('Brut officiel', 'News'),
#         # --- BITES ---
#         ('French slang shorts', 'Bites'),
#         ('French pronunciation tips', 'Bites'),
#         ('French idioms explained', 'Bites'),
#         # --- GRAMMAR ---
#         ('Passé Composé vs Imparfait', 'Grammar tips'),
#         ('French subjunctive explained', 'Grammar tips'),
#         ('French pronouns y and en', 'Grammar tips'),
#         ('French gender rules', 'Grammar tips')
#     ],
#     'de': [
#         # --- STORIES ---
#         ('German stories for beginners', 'Stories'),
#         ('Dino lernt Deutsch', 'Stories'),
#         ('Märchen für kinder deutsch', 'Stories'),
#         ('Natürlich German stories', 'Stories'),
#         # --- NEWS ---
#         ('Logo! Nachrichten', 'News'), # Kid's news (easier)
#         ('Tagesschau in 100 sekunden', 'News'),
#         ('DW Deutsch lernen nachrichten', 'News'),
#         # --- BITES ---
#         ('German compound words funny', 'Bites'),
#         ('German idioms shorts', 'Bites'),
#         ('German false friends', 'Bites'),
#         # --- GRAMMAR ---
#         ('German cases explained nominative accusative', 'Grammar tips'),
#         ('German sentence structure', 'Grammar tips'),
#         ('German two way prepositions', 'Grammar tips'),
#         ('Der Die Das rules', 'Grammar tips')
#     ],
#     'it': [
#         ('Storie italiane per stranieri', 'Stories'),
#         ('Learn Italian with Lucrezia', 'Stories'),
#         ('Easy Italian news', 'News'),
#         ('Fanpage.it stories', 'News'),
#         ('Italian hand gestures shorts', 'Bites'),
#         ('Italian slang shorts', 'Bites'),
#         ('Italian prepositions explained', 'Grammar tips'),
#         ('Passato prossimo vs imperfetto', 'Grammar tips')
#     ],
#     'pt': [
#         ('Histórias em português brasil', 'Stories'),
#         ('Turma da Mônica', 'Stories'),
#         ('Speaking Brazilian', 'Stories'),
#         ('CNN Brasil soft news', 'News'),
#         ('Brazilian slang shorts', 'Bites'),
#         ('Portuguese pronunciation tips', 'Bites'),
#         ('Por vs Para português', 'Grammar tips'),
#         ('Ser vs Estar português', 'Grammar tips')
#     ],
#     'ja': [
#         ('Japanese folklore stories subtitles', 'Stories'),
#         ('Comprehensible Japanese', 'Stories'),
#         ('ANN news japanese', 'News'),
#         ('Japanese candy review shorts', 'Bites'),
#         ('Japanese onomatopoeia', 'Bites'),
#         ('Japanese particles wa ga', 'Grammar tips'),
#         ('Japanese te-form conjugation', 'Grammar tips')
#     ],
#     'en': [
#         ('English short stories for learning', 'Stories'),
#         ('VOA Learning English', 'News'),
#         ('BBC Learning English news review', 'News'),
#         ('English idioms shorts', 'Bites'),
#         ('American vs British english shorts', 'Bites'),
#         ('English phrasal verbs explained', 'Grammar tips'),
#         ('Present perfect tense english', 'Grammar tips')
#     ]
# }

# # --- HELPERS ---

# def time_to_seconds(time_str):
#     """Converts HH:MM:SS.mmm or MM:SS.mmm to seconds."""
#     try:
#         time_str = time_str.replace(',', '.')
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
#     """Parses VTT, handling flexible timestamps for Shorts."""
#     lines = vtt_content.splitlines()
#     transcript = []
    
#     # Matches 00:00:00.000 OR 00:00.000
#     time_pattern = re.compile(r'((?:\d{2}:)?\d{2}:\d{2}[.,]\d{3})\s-->\s((?:\d{2}:)?\d{2}:\d{2}[.,]\d{3})')
    
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
#     if not transcript: return 'intermediate'
#     all_text = " ".join([t['text'] for t in transcript])
#     words = all_text.split()
#     if not words: return 'intermediate'
    
#     avg_len = sum(len(w) for w in words) / len(words)
    
#     if avg_len < 4.5: return 'beginner'
#     if avg_len < 5.5: return 'intermediate'
#     return 'advanced'

# def get_video_details(video_url, lang_code, category):
#     video_id = video_url.split('v=')[-1]
#     temp_filename = f"temp_course_{video_id}"
    
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
            
#             # Duration Check
#             duration = info.get('duration', 0)
#             min_dur, max_dur = DURATION_RULES.get(category, (30, 600))
            
#             if not (min_dur <= duration <= max_dur):
#                 # print(f"    ⚠️ Skip: Length {duration}s not in range {min_dur}-{max_dur}")
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

#             # Map to app types
#             type_map = {
#                 'Stories': 'story',
#                 'News': 'news',
#                 'Bites': 'bite',
#                 'Grammar tips': 'grammar'
#             }

#             return {
#                 "id": f"yt_{video_id}",
#                 "userId": "system_course",
#                 "title": info.get('title', 'Unknown Title'),
#                 "language": lang_code,
#                 "content": full_text,
#                 "sentences": split_sentences(full_text),
#                 "transcript": transcript_data,
#                 "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
#                 "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
#                 "type": type_map.get(category, 'video'), 
#                 "difficulty": analyze_difficulty(transcript_data),
#                 "videoUrl": f"https://youtube.com/watch?v={video_id}",
#                 "isFavorite": False,
#                 "progress": 0,
#             }
#     except Exception as e:
#         # print(f"    ⚠️ Error: {str(e)[:20]}")
#         for f in glob.glob(f"{temp_filename}*"):
#             try: os.remove(f)
#             except: pass
#         return None

# def main():
#     if not os.path.exists(OUTPUT_DIR):
#         os.makedirs(OUTPUT_DIR)

#     for lang, categories in SEARCH_CONFIG.items():
#         print(f"\n==========================================")
#         print(f" GENERATING COURSE: {lang.upper()}")
#         print(f"==========================================")
        
#         filepath = os.path.join(OUTPUT_DIR, f"{lang}.json")
        
#         existing_lessons = []
#         existing_ids = set()
        
#         # 1. Load Existing (Duplicate Handling)
#         if os.path.exists(filepath):
#             try:
#                 with open(filepath, 'r', encoding='utf-8') as f:
#                     existing_lessons = json.load(f)
#                     existing_ids = {l['id'] for l in existing_lessons}
#                 print(f"  📚 Loaded {len(existing_lessons)} existing lessons.")
#             except:
#                 print("  🆕 Creating new course file.")

#         total_new_for_lang = 0

#         # 2. Iterate through specific queries
#         for query, category in categories:
#             print(f"\n  🔎 {category}: '{query}'")
            
#             ydl_opts = {
#                 'quiet': True,
#                 'extract_flat': True,
#                 'dump_single_json': True,
#                 'extractor_args': {'youtube': {'player_client': ['android']}}
#             }
            
#             with yt_dlp.YoutubeDL(ydl_opts) as ydl:
#                 # Search 10 candidates per query
#                 try:
#                     result = ydl.extract_info(f"ytsearch10:{query}", download=False)
#                 except Exception as e:
#                     print(f"    ❌ Search error: {e}")
#                     continue
                
#                 added_this_query = 0
                
#                 if 'entries' in result:
#                     for entry in result['entries']:
#                         if not entry: continue
                        
#                         # LIMIT: Only add 2 videos per specific query to ensure variety
#                         # (e.g. 2 Por vs Para, then move to Subjunctive)
#                         if added_this_query >= 2: 
#                             break 
                        
#                         vid = entry.get('id')
#                         lesson_id = f"yt_{vid}"

#                         # DUPLICATE CHECK
#                         if lesson_id in existing_ids:
#                             continue

#                         print(f"    ⬇️ Processing: {entry.get('title', '')[:40]}...")
                        
#                         lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang, category)
                        
#                         if lesson:
#                             existing_lessons.append(lesson) # Append to end for courses
#                             existing_ids.add(lesson_id)
#                             added_this_query += 1
#                             total_new_for_lang += 1
#                             print(f"       ✅ Added!")
#                         else:
#                             print(f"       🚫 Skipped")
                        
#                         time.sleep(1)

#         # 3. Save
#         with open(filepath, 'w', encoding='utf-8') as f:
#             json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        
#         print(f"\n  💾 SAVED {lang.upper()}: +{total_new_for_lang} new lessons. Total: {len(existing_lessons)}")

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

OUTPUT_DIR = "assets/course_videos"

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

# --- DURATION RULES (In Seconds) ---
DURATION_RULES = {
    'Stories':      (60, 1800),  # Up to 30 mins
    'News':         (45, 1200),  # Up to 20 mins
    'Bites':        (10, 120),   # Shorts/Reels (up to 2 mins)
    'Grammar tips': (60, 900),   # 1 min to 15 mins
}

# --- CURATED CONFIG (Major Languages) ---
CURATED_CONFIG = {
    'es': [
        ('Spanish comprehensible input beginner', 'Stories'),
        ('BBC News Mundo', 'News'),
        ('Spanish slang shorts', 'Bites'),
        ('Por vs Para explained', 'Grammar tips'),
        ('Ser vs Estar spanish', 'Grammar tips'),
    ],
    'fr': [
        ('French comprehensible input', 'Stories'),
        ('HugoDécrypte actus', 'News'),
        ('French slang shorts', 'Bites'),
        ('Passé Composé vs Imparfait', 'Grammar tips'),
    ],
    'de': [
        ('German stories for beginners', 'Stories'),
        ('Logo! Nachrichten', 'News'),
        ('German idioms shorts', 'Bites'),
        ('German cases explained', 'Grammar tips'),
    ],
    'it': [
        ('Storie italiane per stranieri', 'Stories'),
        ('Easy Italian news', 'News'),
        ('Italian hand gestures shorts', 'Bites'),
        ('Italian prepositions explained', 'Grammar tips'),
    ],
    'pt': [
        ('Histórias em português brasil', 'Stories'),
        ('CNN Brasil soft news', 'News'),
        ('Brazilian slang shorts', 'Bites'),
        ('Por vs Para português', 'Grammar tips'),
    ],
    'ja': [
        ('Japanese folklore stories subtitles', 'Stories'),
        ('ANN news japanese', 'News'),
        ('Japanese onomatopoeia', 'Bites'),
        ('Japanese particles wa ga', 'Grammar tips'),
    ],
    'en': [
        ('English short stories for learning', 'Stories'),
        ('VOA Learning English', 'News'),
        ('English idioms shorts', 'Bites'),
        ('English phrasal verbs explained', 'Grammar tips'),
    ]
}

def get_queries_for_lang(code, name):
    """
    Returns specific queries for major langs, 
    or generic 'template' queries for the rest (African/Local).
    """
    if code in CURATED_CONFIG:
        return CURATED_CONFIG[code]
    
    # Generic Template for African/Niche Languages
    # We broaden "Grammar" to "Lessons" and "Bites" to "Shorts/Music"
    return [
        (f"{name} language stories", 'Stories'),
        (f"{name} language folklore", 'Stories'),
        
        (f"{name} language news", 'News'),
        (f"{name} language tv", 'News'),
        
        (f"Learn {name} language lesson", 'Grammar tips'), # "Lesson" finds more than "Grammar"
        (f"{name} language basic phrases", 'Grammar tips'),
        
        (f"{name} language funny short", 'Bites'),
        (f"{name} language song lyrics", 'Bites'), # Lyrics videos are usually short-ish
    ]

# --- HELPERS ---

def time_to_seconds(time_str):
    try:
        time_str = time_str.replace(',', '.')
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
    time_pattern = re.compile(r'((?:\d{2}:)?\d{2}:\d{2}[.,]\d{3})\s-->\s((?:\d{2}:)?\d{2}:\d{2}[.,]\d{3})')
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
    if not transcript: return 'intermediate'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'intermediate'
    avg_len = sum(len(w) for w in words) / len(words)
    
    if avg_len < 4.5: return 'beginner'
    if avg_len < 5.5: return 'intermediate'
    return 'advanced'

def get_video_details(video_url, lang_code, category):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_course_{lang_code}_{video_id}"
    
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        'subtitleslangs': [lang_code], 
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,
        'sleep_interval_requests': 2, # Throttling inside ydl
        'extractor_args': {'youtube': {'player_client': ['android', 'web']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Pre-fetch sleep
            time.sleep(random.uniform(2, 4))
            
            info = ydl.extract_info(video_url, download=True)
            if not info: return None
            
            duration = info.get('duration', 0)
            min_dur, max_dur = DURATION_RULES.get(category, (30, 900))
            
            # Duration Check
            if not (min_dur <= duration <= max_dur):
                return None

            files = glob.glob(f"{temp_filename}*.vtt")
            if not files:
                for f in glob.glob(f"{temp_filename}*"): os.remove(f)
                return None
            
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            
            # Content Check: Must have enough text to be a "lesson"
            if not transcript_data or len(transcript_data) < 5: 
                return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            type_map = {
                'Stories': 'story',
                'News': 'news',
                'Bites': 'bite',
                'Grammar tips': 'grammar'
            }

            return {
                "id": f"yt_{video_id}",
                "userId": "system_course",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": info.get('thumbnail') or f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": type_map.get(category, 'video'), 
                "difficulty": analyze_difficulty(transcript_data),
                "videoUrl": f"https://youtube.com/watch?v={video_id}",
                "isFavorite": False,
                "progress": 0,
            }
    except Exception as e:
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    sorted_langs = sorted(LANGUAGES.items())
    
    print(f"🚀 STARTING COURSE GENERATION FOR {len(sorted_langs)} LANGUAGES")

    for lang_code, lang_name in sorted_langs:
        
        filepath = os.path.join(OUTPUT_DIR, f"{lang_code}.json") # e.g. es.json
        
        existing_lessons = []
        existing_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
            except:
                existing_lessons = []

        # Optimization: If course is already robust (e.g. 40 videos), skip
        if len(existing_lessons) >= 40:
             print(f"⏭️  Skipping {lang_name} ({lang_code}): Course full ({len(existing_lessons)} lessons).")
             continue

        print(f"\n==========================================")
        print(f" GENERATING: {lang_name} ({lang_code})")
        print(f"==========================================")

        queries = get_queries_for_lang(lang_code, lang_name)
        # Randomize order of categories to ensure we don't only get Stories if we crash
        random.shuffle(queries)
        
        total_new_for_lang = 0

        for query, category in queries:
            if total_new_for_lang >= 4: # Add max 4 new videos per language per run
                print(f"  🛑 Reached batch limit for {lang_name}.")
                break
            
            print(f"\n  🔎 {category}: '{query}'")
            
            ydl_opts_search = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'sleep_interval': random.uniform(1, 3)
            }
            
            with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
                try:
                    # Search 5 candidates
                    result = ydl.extract_info(f"ytsearch5:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search error: {e}")
                    time.sleep(5)
                    continue
                
                added_this_query = 0
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        # Only 1 video per query to ensure variety in the course
                        if added_this_query >= 1: 
                            break 
                        
                        vid = entry.get('id')
                        lesson_id = f"yt_{vid}"

                        if lesson_id in existing_ids:
                            continue

                        print(f"    ⬇️ Processing: {entry.get('title', 'Unknown')[:40]}...")
                        
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang_code, category)
                        
                        if lesson:
                            existing_lessons.append(lesson)
                            existing_ids.add(lesson_id)
                            added_this_query += 1
                            total_new_for_lang += 1
                            print(f"       ✅ Added!")
                            
                            # Incremental Save
                            try:
                                with open(filepath, 'w', encoding='utf-8') as f:
                                    json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
                            except: pass
                            
                            # Good sleep to prevent block
                            time.sleep(random.uniform(5, 10))
                        else:
                            print(f"       🚫 Skipped")
                            time.sleep(random.uniform(1, 3))

        print(f"  🏁 Finished {lang_name}. Total: {len(existing_lessons)}")
        
        # Long sleep between languages
        time.sleep(random.uniform(4, 8))

if __name__ == "__main__":
    main()