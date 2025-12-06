import json
import os
import re
import glob
import yt_dlp
import time

# --- CONFIGURATION ---

OUTPUT_DIR = "assets/course_videos"

# --- RELAXED DURATION RULES (In Seconds) ---
DURATION_RULES = {
    # Stories: 1 min to 20 mins (Was 2-10 mins)
    'Stories':      (60, 1200),  
    
    # News: 45 secs to 15 mins (Was 1-5 mins)
    'News':         (45, 900),   
    
    # Bites: 15 secs to 90 secs (Standard Shorts length)
    'Bites':        (15, 90),    
    
    # Grammar: 30 secs to 10 mins (Grammar explanations vary wildly)
    'Grammar tips': (30, 600),   
}

# Search queries (Same as before)
SEARCH_CONFIG = {
    'es': [
        ('Cuentos cortos español', 'Stories'),
        ('Noticias telemundo', 'News'),
        ('Spanish phrase shorts', 'Bites'),
        ('Spanish grammar explained', 'Grammar tips'),
    ],
    'fr': [
        ('Contes français', 'Stories'),
        ('France 24 français', 'News'),
        ('French phrase shorts', 'Bites'),
        ('Grammaire française expliquée', 'Grammar tips'),
    ],
    # ... (Keep your other languages) ...
    'en': [
        ('Short stories English', 'Stories'),
        ('BBC News Review', 'News'),
        ('English idiom shorts', 'Bites'),
        ('English grammar lesson', 'Grammar tips'),
    ]
}

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
    
    if avg_len < 4.5: return 'beginner'
    if avg_len < 5.5: return 'intermediate'
    return 'advanced'

def get_video_details(video_url, lang_code, category):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_course_{video_id}"
    
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
            
            # --- DURATION FILTER ---
            duration = info.get('duration', 0)
            min_dur, max_dur = DURATION_RULES[category]
            
            if not (min_dur <= duration <= max_dur):
                print(f"    ⚠️ Skipping (Duration {duration}s not in {min_dur}-{max_dur}s)")
                return None

            files = glob.glob(f"{temp_filename}*.vtt")
            
            if not files:
                print(f"    ⚠️ No subtitles found.")
                return None
            
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data: return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            # Map category to your app's 'type' field
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
                "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": type_map[category], 
                "difficulty": analyze_difficulty(transcript_data),
                "videoUrl": f"https://youtube.com/watch?v={video_id}",
                "isFavorite": False,
                "progress": 0,
            }
    except Exception as e:
        print(f"    ⚠️ Error: {str(e)[:50]}...")
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, categories in SEARCH_CONFIG.items():
        print(f"\n==========================================")
        print(f" GENERATING COURSE CONTENT: {lang.upper()}")
        print(f"==========================================")
        
        filepath = os.path.join(OUTPUT_DIR, f"{lang}.json")
        
        existing_lessons = []
        existing_ids = set()
        
        # 1. Load Existing Data
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  📚 Loaded {len(existing_lessons)} existing lessons.")
            except:
                print("  🆕 Creating new file.")

        total_new_for_lang = 0

        for query, category in categories:
            print(f"\n  🔎 Category: {category} | Query: '{query}'")
            
            ydl_opts = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'extractor_args': {'youtube': {'player_client': ['android']}}
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # 2. Search for 20 candidates (Deeper search)
                # This helps skip over the ones we already have
                try:
                    result = ydl.extract_info(f"ytsearch20:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    continue
                
                count_added_this_category = 0
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        # Stop if we found 3 NEW videos for this category
                        if count_added_this_category >= 3: 
                            break 
                        
                        vid = entry.get('id')
                        lesson_id = f"yt_{vid}"

                        # 3. Check for duplicates (Skips if ID exists)
                        if lesson_id in existing_ids:
                            continue

                        print(f"    ⬇️ Checking: {entry.get('title')[:40]}...")
                        
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang, category)
                        
                        if lesson:
                            # 4. Insert at TOP (0) so new stuff appears first in app
                            existing_lessons.insert(0, lesson)
                            existing_ids.add(lesson_id)
                            count_added_this_category += 1
                            total_new_for_lang += 1
                            print(f"       ✅ Added!")
                        
                        time.sleep(1) # Be nice to YouTube

        # 5. Save Updated List
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        
        print(f"\n  💾 SAVED {lang.upper()}: Added {total_new_for_lang} new videos.")

if __name__ == "__main__":
    main()