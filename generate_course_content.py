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
import argparse
import sys
from yt_dlp.utils import DownloadError

# --- CONFIGURATION ---

OUTPUT_DIR = "assets/course_videos"

LANGUAGES = {
    'ar': 'Arabic', 'cs': 'Czech', 'da': 'Danish', 'de': 'German', 'el': 'Greek',
    'en': 'English', 'es': 'Spanish', 'fi': 'Finnish', 'fr': 'French', 'hi': 'Hindi',
    'hu': 'Hungarian', 'id': 'Indonesian', 'it': 'Italian', 'ja': 'Japanese',
    'ko': 'Korean', 'nl': 'Dutch', 'no': 'Norwegian', 'pl': 'Polish', 'pt': 'Portuguese',
    'ro': 'Romanian', 'ru': 'Russian', 'sv': 'Swedish', 'th': 'Thai', 'tr': 'Turkish',
    'uk': 'Ukrainian', 'vi': 'Vietnamese', 'zh': 'Chinese',
    # (Add other languages here if needed)
}

DURATION_RULES = {
    'Stories':      (60, 1800),
    'News':         (45, 1200),
    'Bites':        (10, 120),
    'Grammar tips': (60, 900),
    'Manual':       (5, 7200),
}

CURATED_CONFIG = {
    'es': [('Spanish comprehensible input beginner', 'Stories'), ('BBC News Mundo', 'News'), ('Spanish slang shorts', 'Bites'), ('Por vs Para explained', 'Grammar tips')],
    'fr': [('French comprehensible input', 'Stories'), ('HugoDécrypte actus', 'News'), ('French slang shorts', 'Bites'), ('Passé Composé vs Imparfait', 'Grammar tips')],
    # (Add others as needed)
}

# --- UTILS ---

class QuietLogger:
    """Silences the annoying SABR/Warning logs from yt-dlp"""
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
    ]

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

def load_existing_lessons(filepath):
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r', encoding='utf-8') as f: return json.load(f)
        except: return []
    return []

def save_lessons(filepath, lessons):
    try:
        with open(filepath, 'w', encoding='utf-8') as f: json.dump(lessons, f, ensure_ascii=False, indent=None)
    except Exception as e: print(f"Error saving: {e}")

# --- CORE LOGIC ---

def get_video_details(video_url, lang_code, category):
    """
    1. Checks metadata first to find the EXACT subtitle code (e.g. 'fr', 'fr-FR', 'fr-orig').
    2. Downloads only that specific subtitle.
    """
    
    # 1. INSPECTION PHASE (No Download)
    ydl_opts_check = {
        'skip_download': True,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,
        'logger': QuietLogger(), # Silence SABR warnings
    }

    found_sub_code = None
    is_auto = False
    info = None

    try:
        with yt_dlp.YoutubeDL(ydl_opts_check) as ydl:
            try:
                info = ydl.extract_info(video_url, download=False)
            except DownloadError: return None
            
            if not info: return None

            # A. Check Manual Subtitles (Preferred)
            # Look for 'fr', 'fr-FR', 'fr-CA' etc.
            manual_subs = info.get('subtitles', {})
            for code in manual_subs:
                if code == lang_code or code.startswith(f"{lang_code}-"):
                    found_sub_code = code
                    break
            
            # B. Check Auto Subtitles (Fallback)
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
        print(f"    ❌ Info check error: {e}")
        return None

    # 2. DOWNLOAD PHASE
    video_id = info['id']
    temp_filename = f"temp_course_{lang_code}_{video_id}"
    
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
            
            # --- FILE PROCESSING ---
            files = glob.glob(f"{temp_filename}*.vtt")
            if not files:
                # Cleanup and return
                for f in glob.glob(f"{temp_filename}*"): os.remove(f)
                print(f"    ⚠️ Download failed for subtitle '{found_sub_code}'.")
                return None
            
            # Pick largest file (best quality)
            best_file = max(files, key=os.path.getsize)
            
            with open(best_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Cleanup
            for f in glob.glob(f"{temp_filename}*"): 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            
            if not transcript_data or len(transcript_data) < 5: 
                print("    ⚠️ Transcript too short/empty.")
                return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            type_map = {'Stories': 'story', 'News': 'news', 'Bites': 'bite', 'Grammar tips': 'grammar', 'Manual': 'video'}

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
                "difficulty": analyze_difficulty(transcript_data),
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

# --- MAIN LOOPS ---

def process_manual_link(url, lang_code, category="Manual"):
    if lang_code not in LANGUAGES:
        print(f"❌ Error: Language code '{lang_code}' not found.")
        return

    filepath = os.path.join(OUTPUT_DIR, f"{lang_code}.json")
    existing_lessons = load_existing_lessons(filepath)
    existing_ids = {l['id'] for l in existing_lessons}
    
    print(f"🔎 Analyzing Link: {url}...")

    # We use basic opts just to get the list of videos
    ydl_opts_list = {'extract_flat': True, 'quiet': True, 'logger': QuietLogger()}
    
    videos_to_process = []
    with yt_dlp.YoutubeDL(ydl_opts_list) as ydl:
        try:
            info = ydl.extract_info(url, download=False)
            if 'entries' in info:
                print(f"   📂 Playlist: {info.get('title', 'Unknown')}")
                for entry in info['entries']: 
                    if entry: videos_to_process.append(entry['id'])
            else:
                print(f"   🎬 Video: {info.get('title', 'Unknown')}")
                videos_to_process.append(info['id'])
        except:
            print("❌ Invalid URL.")
            return

    print(f"   ⬇️ Processing {len(videos_to_process)} videos...")
    count = 0
    for vid in videos_to_process:
        lesson_id = f"yt_{vid}"
        if lesson_id in existing_ids:
            print(f"   ⏭️ Exists: {vid}")
            continue
        
        print(f"   ⏳ Processing: https://youtu.be/{vid}")
        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang_code, category)
        if lesson:
            existing_lessons.append(lesson)
            existing_ids.add(lesson_id)
            save_lessons(filepath, existing_lessons)
            print(f"      ✅ Saved!")
            count += 1
            time.sleep(1)
        else:
            print("      ⚠️ Skipped.")

    print(f"\n🎉 Finished. Added {count} lessons.")

def run_automated_scraping():
    sorted_langs = sorted(LANGUAGES.items())
    print(f"🚀 STARTING AUTO-SCRAPE FOR {len(sorted_langs)} LANGUAGES")

    for lang_code, lang_name in sorted_langs:
        filepath = os.path.join(OUTPUT_DIR, f"{lang_code}.json")
        existing_lessons = load_existing_lessons(filepath)
        if len(existing_lessons) >= 40: continue

        print(f"\n=== {lang_name} ({lang_code}) ===")
        queries = get_queries_for_lang(lang_code, lang_name)
        random.shuffle(queries)
        
        added = 0
        for query, category in queries:
            if added >= 4: break
            print(f"  🔎 {category}: '{query}'")
            
            ydl_opts = {'quiet': True, 'extract_flat': True, 'dump_single_json': True, 'logger': QuietLogger()}
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                try: result = ydl.extract_info(f"ytsearch5:{query}", download=False)
                except: continue
                
                if result and 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        vid = entry.get('id')
                        if any(l['id'] == f"yt_{vid}" for l in existing_lessons): continue
                        
                        print(f"    ⬇️ Try: {entry.get('title', '')[:30]}...")
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang_code, category)
                        if lesson:
                            existing_lessons.append(lesson)
                            save_lessons(filepath, existing_lessons)
                            print("       ✅ Added.")
                            added += 1
                            time.sleep(5)
                            break
                        else:
                            time.sleep(1)

def main():
    if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)
    parser = argparse.ArgumentParser()
    parser.add_argument("--link", type=str)
    parser.add_argument("--lang", type=str)
    parser.add_argument("--category", type=str, default="Manual")
    args = parser.parse_args()

    if args.link:
        if not args.lang:
            print("❌ --lang required with --link")
            sys.exit(1)
        process_manual_link(args.link, args.lang, args.category)
    else:
        run_automated_scraping()

if __name__ == "__main__":
    main()