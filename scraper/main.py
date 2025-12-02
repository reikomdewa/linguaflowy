import json
import os
import glob
import re
import time
import random
import yt_dlp

# --- CONFIGURATION ---
LANGUAGES = {
    'es': 'Spanish comprehensible input',
    'fr': 'French comprehensible input',
    'de': 'German comprehensible input',
    'it': 'Italian comprehensible input',
    'pt': 'Portuguese comprehensible input',
    'ja': 'Japanese comprehensible input',
    'en': 'English stories'
}

MAX_FEED_SIZE = 50  # Keep last 50 videos per language

def clean_vtt_text(vtt_content):
    """
    Parses WebVTT content and extracts clean text.
    Removes timestamps, styling tags, and duplicate lines.
    """
    lines = vtt_content.splitlines()
    clean_lines = []
    seen_lines = set()
    
    # Regex to identify timestamp lines (e.g., 00:00:05.000 --> 00:00:07.000)
    timestamp_pattern = re.compile(r'\d{2}:\d{2}:\d{2}\.\d{3}\s-->\s\d{2}:\d{2}:\d{2}\.\d{3}')
    
    for line in lines:
        line = line.strip()
        # Skip headers, empty lines, timestamps, and numbers
        if (not line or 
            line == 'WEBVTT' or 
            line.startswith('Kind:') or 
            line.startswith('Language:') or 
            timestamp_pattern.search(line) or 
            line.isdigit()):
            continue
            
        # Remove HTML-like tags (e.g. <c.colorE5E5E5> or <b>)
        line = re.sub(r'<[^>]+>', '', line)
        
        # Decode HTML entities if needed (basic ones)
        line = line.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')

        # Simple deduplication (often VTT repeats lines for karaoke effects)
        if line not in seen_lines:
            clean_lines.append(line)
            seen_lines.add(line)
            
    return " ".join(clean_lines)

def download_transcript(video_id, lang_code):
    """
    Uses yt-dlp to download the subtitle file, reads it, and returns text.
    """
    temp_filename = f"temp_{video_id}"
    
    # Core Options
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,      # Fallback to auto-generated
        'subtitleslangs': [lang_code],  # Desired language
        'outtmpl': temp_filename,       # Temp filename
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,
        # SPOOFING: Pretend to be Android to bypass some checks
        'extractor_args': {
            'youtube': {
                'player_client': ['android', 'web']
            }
        }
    }

    # COOKIE INJECTION: If cookies.txt exists (from GitHub Secrets), use it!
    if os.path.exists('cookies.txt'):
        ydl_opts['cookiefile'] = 'cookies.txt'

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([f'https://www.youtube.com/watch?v={video_id}'])
            
        # Find the downloaded .vtt file (yt-dlp appends lang code)
        files = glob.glob(f"{temp_filename}*.vtt")
        
        if not files:
            return None
            
        # Read the file
        with open(files[0], 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Clean up (delete temp file)
        for f in files:
            try:
                os.remove(f)
            except:
                pass
            
        return clean_vtt_text(content)
        
    except Exception as e:
        # print(f"    ! Download error: {e}")
        return None

def analyze_difficulty(text):
    words = text.split()
    if not words: return 'intermediate'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.5: return 'beginner'
    if avg_len > 6.0: return 'advanced'
    return 'intermediate'

def search_and_scrape(lang_code, query):
    print(f"\n--- Searching: {query} ({lang_code}) ---")
    
    # Options for searching metadata
    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        'dump_single_json': True,
        'ignoreerrors': True,
        # Use Android client for search too
        'extractor_args': {
            'youtube': {
                'player_client': ['android']
            }
        }
    }

    # Add cookies to search if available
    if os.path.exists('cookies.txt'):
        ydl_opts['cookiefile'] = 'cookies.txt'

    lessons = []
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            # Search 10 videos
            result = ydl.extract_info(f"ytsearch10:{query}", download=False)
            
            if 'entries' not in result:
                return []

            for video in result['entries']:
                # Safety check for None values
                if not video: continue
                
                video_id = video.get('id')
                title = video.get('title')
                
                if not video_id or not title: continue

                # yt-dlp flat search doesn't always give thumbnails, construct manually
                thumbnail = f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"

                print(f"  > Checking: {title}")
                
                # Polite delay to act human
                time.sleep(random.uniform(2.0, 5.0))
                
                # Download Transcript
                content = download_transcript(video_id, lang_code)
                
                if content and len(content) > 100:
                    print(f"    + SUCCESS: {len(content)} chars")
                    lessons.append({
                        "id": f"yt_{video_id}",
                        "userId": "system",
                        "title": title,
                        "language": lang_code,
                        "content": content,
                        "sentences": [], 
                        "createdAt": "2024-01-01T00:00:00.000Z", # Placeholder date (updated on app load)
                        "imageUrl": thumbnail,
                        "type": "video",
                        "difficulty": analyze_difficulty(content),
                        "videoUrl": f"https://youtube.com/watch?v={video_id}",
                        "isFavorite": False
                    })
                else:
                    # Keep logs clean, don't spam errors
                    print("    - Skipped (No subs or blocked)")

                if len(lessons) >= 5: 
                    break
                    
        except Exception as e:
            print(f"Search failed: {e}")

    return lessons

def main():
    if not os.path.exists('data'):
        os.makedirs('data')

    for lang_code, query in LANGUAGES.items():
        # 1. Scrape new videos
        new_lessons = search_and_scrape(lang_code, query)
        
        filename = f"data/lessons_{lang_code}.json"
        all_lessons = []

        # 2. Load existing feed (History)
        if os.path.exists(filename):
            try:
                with open(filename, 'r', encoding='utf-8') as f:
                    all_lessons = json.load(f)
            except:
                pass

        # 3. Merge: Add new videos to the top, avoiding duplicates
        existing_ids = {l['id'] for l in all_lessons}
        
        for lesson in new_lessons:
            if lesson['id'] not in existing_ids:
                all_lessons.insert(0, lesson) # Add to top
        
        # 4. Limit Feed Size
        all_lessons = all_lessons[:MAX_FEED_SIZE]
        
        # 5. Save
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(all_lessons, f, ensure_ascii=False, indent=2)
            
        print(f"Saved {len(all_lessons)} videos to {filename}")

if __name__ == "__main__":
    main()