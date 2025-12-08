import json
import os
import re
import glob
import yt_dlp
import time

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/data"

# EXPANDED SEARCH CONFIGURATION
# Format: 'lang_code': [('Search Query', 'Genre')]
# Genres: story, news, vlog, history, culture, science, tech, education
SEARCH_CONFIG = {
    'es': [
        # Stories & Comprehensible Input
        ('Spanish comprehensible input stories beginner', 'story'),
        ('Dreaming Spanish superbeginner', 'story'),
        ('BookBox Spanish stories', 'story'),
        ('Fabulas de Esopo español', 'fairy_tale'),
        # Vlogs & Daily Life
        ('Easy Spanish street interviews', 'vlog'),
        ('Spanish After Hours vlog', 'vlog'),
        ('Luisito Comunica viajes', 'vlog'), # Native/Advanced
        # Education & Science
        ('Curiosamente ciencia', 'science'), # Great clear audio
        ('Magic Markers explicacion', 'education'),
        # News & History
        ('BBC Mundo noticias', 'news'),
        ('Historia de España para niños', 'history'),
        ('Tedx Talks en español', 'education')
    ],
    'fr': [
        # Stories
        ('French comprehensible input stories', 'story'),
        ('BookBox French', 'story'),
        ('Contes de fées français', 'fairy_tale'),
        # Vlogs & Culture
        ('Easy French street interviews', 'vlog'),
        ('Piece of French vlog', 'vlog'),
        ('InnerFrench podcast video', 'culture'),
        # News & Science
        ('HugoDécrypte actus du jour', 'news'), # Fast/Native
        ('1 jour 1 question', 'education'), # Kids news/edu
        ('C\'est pas sorcier science', 'science'), # Classic science show
        ('L\'histoire de France racontée', 'history')
    ],
    'de': [
        # Stories
        ('German comprehensible input beginner', 'story'),
        ('Hallo Deutschschule stories', 'story'),
        ('Märchen für kinder deutsch', 'fairy_tale'),
        # Vlogs
        ('Easy German street interviews', 'vlog'),
        ('Dinge Erklärt – Kurzgesagt', 'science'), # High quality science
        ('MrWissen2go Geschichte', 'history'),
        # News
        ('Langsam gesprochene Nachrichten DW', 'news'), # Specifically slow news
        ('Logo! Nachrichten für Kinder', 'news'),
        ('Galileo deutschland', 'education')
    ],
    'it': [
        # Stories
        ('Italian comprehensible input', 'story'),
        ('Learn Italian with Lucrezia vlog', 'vlog'),
        ('Podcast Italiano video', 'culture'),
        # Culture & News
        ('Storia d\'Italia semplice', 'history'),
        ('Geopop it', 'science'), # Italian science/geo
        ('Easy Italian street interviews', 'vlog'),
        ('Fiabe italiane', 'fairy_tale')
    ],
    'pt': [
        # Brazil
        ('Portuguese comprehensible input', 'story'),
        ('Speaking Brazilian vlog', 'vlog'),
        ('Turma da Mônica', 'story'), # Cultural cartoon
        ('Nostalgia castanhari', 'history'), # Pop culture history
        ('Manual do Mundo', 'science'), # Huge science channel
        # Portugal
        ('Portuguese from Portugal stories', 'story'),
        ('RTP noticias portugal', 'news')
    ],
    'ja': [
        # Beginners
        ('Comprehensible Japanese', 'story'),
        ('Japanese fairy tales with subtitles', 'fairy_tale'),
        ('Miku Real Japanese', 'vlog'),
        ('Onomappu Japanese', 'education'),
        # Advanced/Native
        ('Japanese history animation', 'history'),
        ('Dogen japanese phonetics', 'education'),
        ('ANN news japanese', 'news'),
        ('Cooking with Dog japanese', 'culture')
    ],
    'en': [
        ('TED-Ed', 'education'),
        ('Vox video essays', 'news'),
        ('Easy English street interviews', 'vlog'),
        ('History of the entire world i guess', 'history'),
        ('Kurzgesagt – In a Nutshell', 'science'),
        ('Short stories for learning english', 'story')
    ]
}

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
    """Splits text for the Flutter model (keeping punctuation)."""
    if not text: return []
    # Regex to split by . ! ? but keep the punctuation attached to the previous sentence
    # clean_text = re.sub(r'\s+', ' ', text)
    return re.split(r'(?<=[.!?])\s+', text)

def parse_vtt_to_transcript(vtt_content):
    """Parses WebVTT content into a list of objects for Flutter."""
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
    """Heuristic to determine difficulty based on avg word length."""
    if not transcript: return 'intermediate'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'intermediate'
    
    avg_len = sum(len(w) for w in words) / len(words)
    
    # Specific adjustments per language could go here
    if avg_len < 4.2: return 'beginner'
    if avg_len > 6.0: return 'advanced' # Bumped up slightly
    return 'intermediate'

def get_video_details(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_gen_{video_id}" # Distinct temp name
    
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,    
        'subtitleslangs': [lang_code], 
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'extractor_args': {'youtube': {'player_client': ['android']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=True)
            
            # Skip videos longer than 20 mins to save space/processing
            if info.get('duration', 0) > 1200:
                print(f"    ⚠️ Skipping (Too long): {info.get('title')}")
                return None

            files = glob.glob(f"{temp_filename}*.vtt")
            
            if not files:
                return None
            
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data: return None
            
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

    for lang, categories in SEARCH_CONFIG.items():
        print(f"\n==========================================")
        print(f" PROCESSING LANGUAGE: {lang.upper()}")
        print(f"==========================================")
        
        filepath = os.path.join(OUTPUT_DIR, f"lessons_{lang}.json")
        
        existing_lessons = []
        existing_ids = set()
        
        # 1. LOAD EXISTING
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  📚 Loaded {len(existing_lessons)} existing videos.")
            except:
                print("  🆕 No valid existing file found. Starting fresh.")
                existing_lessons = []

        total_new_for_lang = 0

        # 2. SEARCH NEW
        for query, genre in categories:
            print(f"\n  🔎 Searching: '{query}' ({genre})")
            
            ydl_opts = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'extractor_args': {'youtube': {'player_client': ['android']}}
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # Search for 6 videos per query (Keep it balanced)
                try:
                    result = ydl.extract_info(f"ytsearch6:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        vid = entry.get('id')
                        title = entry.get('title')
                        lesson_id = f"yt_{vid}"

                        # DUPLICATE CHECK
                        if lesson_id in existing_ids:
                            continue

                        print(f"    ⬇️ Processing: {title[:40]}...")
                        
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang, genre)
                        
                        if lesson:
                            # Prepend to list (Newest first)
                            existing_lessons.insert(0, lesson)
                            existing_ids.add(lesson_id)
                            total_new_for_lang += 1
                            print(f"       ✅ Added!")
                        else:
                            print(f"       🚫 Skipped (No subs/Error)")
                        
                        time.sleep(1)

        # 3. SAVE
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
            print(f"\n  💾 SAVED {lang.upper()}: +{total_new_for_lang} new. Total: {len(existing_lessons)}")
        except Exception as e:
            print(f"  ❌ Error saving file: {e}")

if __name__ == "__main__":
    main()