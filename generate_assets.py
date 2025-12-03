


import json
import os
import re
import glob
import yt_dlp
import time

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/data"

# Structure: 'lang_code': [('Search Query', 'Genre/Category')]
SEARCH_CONFIG = {
    'es': [
        ('Spanish comprehensible input stories', 'story'),
        ('Spanish fairy tales for beginners', 'fairy_tale'),
        ('Slow Spanish news', 'news'),
        ('Easy Spanish daily life', 'vlog'),
        ('History of Spain in easy spanish', 'history')
    ],
    'fr': [
        ('French stories avec sous-titres', 'story'),
        ('French comprehensible input beginner', 'story'),
        ('Easy French news with subtitles', 'news'),
        ('French fairy tales', 'fairy_tale')
    ],
    'de': [
        ('German comprehensible input', 'story'),
        ('German stories for beginners', 'story'),
        ('Easy German history', 'history'),
        ('Slow German news', 'news')
    ],
    'it': [
        ('Italian comprehensible input stories', 'story'),
        ('Easy Italian stories', 'story'),
        ('Italian culture for beginners', 'culture')
    ],
    'pt': [
        ('Portuguese comprehensible input', 'story'),
        ('Brazilian Portuguese stories', 'story')
    ],
    'ja': [
        ('Japanese comprehensible input', 'story'),
        ('Easy Japanese stories', 'story'),
        ('Japanese folklore stories', 'fairy_tale')
    ],
    'en': [
        ('English stories for learning', 'story'),
        ('History of the world easy english', 'history'),
        ('Daily conversation english', 'vlog')
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
    # Regex lookbehind to keep the punctuation attached to the sentence
    return re.split(r'(?<=[.!?])\s+', text)

def parse_vtt_to_transcript(vtt_content):
    """Parses WebVTT content into a list of objects for Flutter."""
    lines = vtt_content.splitlines()
    transcript = []
    # Pattern to match: 00:00:00.000 --> 00:00:02.000
    time_pattern = re.compile(r'(\d{2}:\d{2}:\d{2}\.\d{3})\s-->\s(\d{2}:\d{2}:\d{2}\.\d{3})')
    
    current_entry = None
    
    for line in lines:
        line = line.strip()
        # Skip metadata
        if not line or line == 'WEBVTT' or line.startswith('Kind:') or line.startswith('Language:'):
            continue
            
        # Check for Timestamp
        match = time_pattern.search(line)
        if match:
            # Save previous entry if it exists
            if current_entry and current_entry['text']:
                transcript.append(current_entry)
            
            # Start new entry
            current_entry = {
                'start': time_to_seconds(match.group(1)),
                'end': time_to_seconds(match.group(2)),
                'text': ''
            }
            continue
            
        # If we are inside a time block, capture text
        if current_entry:
            # Remove HTML tags like <c.color> or <b>
            clean_line = re.sub(r'<[^>]+>', '', line)
            # Fix HTML entities
            clean_line = clean_line.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')
            
            if clean_line:
                current_entry['text'] += clean_line + " "

    # Append last entry
    if current_entry and current_entry['text']:
        transcript.append(current_entry)
        
    # Final cleanup
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
    
    # Adjust these thresholds based on language if needed
    if avg_len < 4.2: return 'beginner'
    if avg_len > 5.8: return 'advanced'
    return 'intermediate'

def get_video_details(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_{video_id}"
    
    # yt-dlp options
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,       # Try manual subs
        'writeautomaticsub': True,    # Fallback to auto subs
        'subtitleslangs': [lang_code], 
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'extractor_args': {'youtube': {'player_client': ['android']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # 1. Download metadata and subtitles
            info = ydl.extract_info(video_url, download=True)
            
            # 2. Find the .vtt file
            # yt-dlp might name it temp_id.en.vtt or temp_id.es.vtt
            files = glob.glob(f"{temp_filename}*.vtt")
            
            if not files:
                return None
            
            # 3. Read content
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 4. Clean up temp files immediately
            for f in files: 
                try: os.remove(f)
                except: pass
            
            # 5. Parse
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data: return None
            
            # 6. Reconstruct full text
            full_text = " ".join([t['text'] for t in transcript_data])

            # 7. Build Object
            return {
                "id": f"yt_{video_id}",
                "userId": "system",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": "2024-01-01T00:00:00.000Z", # You can use info.get('upload_date') to be dynamic
                "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": "video",
                "difficulty": analyze_difficulty(transcript_data),
                "videoUrl": f"https://youtube.com/watch?v={video_id}",
                "isFavorite": False,
                "progress": 0,
                "genre": genre # New Field
            }
    except Exception as e:
        print(f"    ⚠️ Error processing {video_id}: {str(e)[:50]}...")
        # Cleanup if error occurred before deletion
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # Loop through Languages
    for lang, categories in SEARCH_CONFIG.items():
        print(f"\n==========================================")
        print(f" PROCESSING LANGUAGE: {lang.upper()}")
        print(f"==========================================")
        
        filepath = os.path.join(OUTPUT_DIR, f"lessons_{lang}.json")
        
        existing_lessons = []
        existing_ids = set()
        
        # 1. Load Existing Data
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  📚 Loaded {len(existing_lessons)} existing videos from DB.")
            except:
                print("  🆕 No existing file found. Creating new.")

        total_new_for_lang = 0

        # 2. Loop through Categories (Genres)
        for query, genre in categories:
            print(f"\n  🔎 Searching: '{query}' (Genre: {genre})")
            
            ydl_opts = {
                'quiet': True,
                'extract_flat': True, # Don't download yet, just get list
                'dump_single_json': True,
                'extractor_args': {'youtube': {'player_client': ['android']}}
            }
            
            new_added_this_query = 0
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # Search for 8 videos per category
                try:
                    result = ydl.extract_info(f"ytsearch8:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        vid = entry.get('id')
                        title = entry.get('title')
                        lesson_id = f"yt_{vid}"

                        # Check duplication
                        if lesson_id in existing_ids:
                            continue

                        print(f"    ⬇️ Processing: {title[:40]}...")
                        
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang, genre)
                        
                        if lesson:
                            # Add to beginning of list (fresh content first)
                            existing_lessons.insert(0, lesson)
                            existing_ids.add(lesson_id)
                            new_added_this_query += 1
                            total_new_for_lang += 1
                            print(f"       ✅ Added!")
                        else:
                            print(f"       🚫 Skipped (No subs)")
                        
                        # Rate limit slightly to be nice to YouTube
                        time.sleep(1)

        # 3. Save after processing all categories for this language
        with open(filepath, 'w', encoding='utf-8') as f:
            # indent=None is optimal for app size, indent=2 is good for debugging
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        
        print(f"\n  💾 SAVED {lang.upper()}: Total {len(existing_lessons)} lessons (+{total_new_for_lang} new).")

if __name__ == "__main__":
    main()