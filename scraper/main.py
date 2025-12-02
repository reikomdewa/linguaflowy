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

MAX_FEED_SIZE = 50

# --- BACKUP DATA ---
BACKUP_LESSONS = [
    {
        "id": "yt_backup_demo",
        "userId": "system",
        "title": "YouTube Blocking Active - Showing Backup",
        "language": "en",
        "content": "YouTube has blocked the scraper IP. This is a backup lesson to keep the app UI working while the block persists.",
        "sentences": [], 
        "createdAt": "2024-01-01T00:00:00.000Z",
        "imageUrl": "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        "type": "video",
        "difficulty": "beginner",
        "videoUrl": "https://youtube.com/watch?v=dQw4w9WgXcQ",
        "isFavorite": False
    }
]

def clean_vtt_text(vtt_content):
    lines = vtt_content.splitlines()
    clean_lines = []
    seen = set()
    timestamp_pattern = re.compile(r'\d{2}:\d{2}:\d{2}\.\d{3}\s-->\s\d{2}:\d{2}:\d{2}\.\d{3}')
    
    for line in lines:
        line = line.strip()
        if (not line or line == 'WEBVTT' or line.startswith('Kind:') or 
            line.startswith('Language:') or timestamp_pattern.search(line) or line.isdigit()):
            continue
        line = re.sub(r'<[^>]+>', '', line)
        line = line.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')
        if line not in seen:
            clean_lines.append(line)
            seen.add(line)
    return " ".join(clean_lines)

def download_transcript(video_id, target_lang):
    temp_filename = f"temp_{video_id}"
    
    # 1. Check Cookies
    use_cookies = os.path.exists('cookies.txt')
    
    # 2. Options: Download ALL subs to avoid "Format not available" errors
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        'subtitleslangs': ['all', '-live_chat'], # Grab everything
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,
        'extractor_args': {'youtube': {'player_client': ['android', 'web']}}
    }

    if use_cookies:
        ydl_opts['cookiefile'] = 'cookies.txt'

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([f'https://www.youtube.com/watch?v={video_id}'])
            
        # 3. Find the best matching file
        # yt-dlp saves as temp_ID.lang.vtt
        all_files = glob.glob(f"{temp_filename}*.vtt")
        
        if not all_files:
            return None, None

        selected_file = None
        detected_lang = target_lang

        # Try exact target match (e.g., .es.vtt)
        for f in all_files:
            if f".{target_lang}." in f:
                selected_file = f
                break
        
        # Try generic match (e.g. .es-MX.vtt)
        if not selected_file:
            for f in all_files:
                if f".{target_lang}" in f:
                    selected_file = f
                    break

        # Fallback to English if target not found (better than nothing)
        if not selected_file:
            for f in all_files:
                if ".en." in f:
                    selected_file = f
                    detected_lang = "en" # Mark that we fell back
                    break
        
        # Last resort: take the first file found
        if not selected_file and all_files:
            selected_file = all_files[0]

        if not selected_file:
            return None, None

        # Read content
        with open(selected_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Cleanup ALL temp files
        for f in all_files:
            try: os.remove(f)
            except: pass
            
        return clean_vtt_text(content), detected_lang
        
    except Exception:
        return None, None

def analyze_difficulty(text):
    words = text.split()
    if not words: return 'intermediate'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.5: return 'beginner'
    if avg_len > 6.0: return 'advanced'
    return 'intermediate'

def search_and_scrape(lang_code, query):
    print(f"\n--- Searching: {query} ({lang_code}) ---")
    
    # Check if cookies exist
    if os.path.exists('cookies.txt'):
        print("  ℹ️  Cookies found. Using authenticated session.")
    else:
        print("  ⚠️  No cookies.txt found. Running anonymously (Higher ban risk).")

    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        'dump_single_json': True,
        'ignoreerrors': True,
        'extractor_args': {'youtube': {'player_client': ['android']}}
    }
    
    if os.path.exists('cookies.txt'):
        ydl_opts['cookiefile'] = 'cookies.txt'

    lessons = []
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            result = ydl.extract_info(f"ytsearch10:{query}", download=False)
            if 'entries' not in result: return []

            for video in result['entries']:
                if not video: continue
                video_id = video.get('id')
                title = video.get('title')
                
                if not video_id or not title: continue

                print(f"  > Checking: {title[:50]}...")
                
                # Polite delay
                time.sleep(random.uniform(2.0, 4.0))
                
                # Download Transcript
                content, actual_lang = download_transcript(video_id, lang_code)
                
                if content and len(content) > 100:
                    # If we fell back to English, maybe skip or tag it? 
                    # For now we keep it but log it.
                    lang_status = "Target" if actual_lang == lang_code else f"Fallback ({actual_lang})"
                    print(f"    + SUCCESS: {len(content)} chars [{lang_status}]")
                    
                    lessons.append({
                        "id": f"yt_{video_id}",
                        "userId": "system",
                        "title": title,
                        "language": lang_code, # Keep requested lang code for filtering
                        "content": content,
                        "sentences": [], 
                        "createdAt": "2024-01-01T00:00:00.000Z",
                        "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                        "type": "video",
                        "difficulty": analyze_difficulty(content),
                        "videoUrl": f"https://youtube.com/watch?v={video_id}",
                        "isFavorite": False
                    })
                else:
                    print("    - Skipped (No text or Blocked)")

                if len(lessons) >= 5: break
                    
        except Exception as e:
            print(f"Search failed: {e}")

    return lessons

def main():
    if not os.path.exists('data'):
        os.makedirs('data')

    for lang_code, query in LANGUAGES.items():
        lessons = search_and_scrape(lang_code, query)
        
        filename = f"data/lessons_{lang_code}.json"
        all_lessons = []

        # Load history
        if os.path.exists(filename):
            try:
                with open(filename, 'r', encoding='utf-8') as f:
                    all_lessons = json.load(f)
            except: pass

        # Merge
        existing_ids = {l['id'] for l in all_lessons}
        for lesson in lessons:
            if lesson['id'] not in existing_ids:
                all_lessons.insert(0, lesson)
        
        # If empty (Blocked), inject Backup
        if not all_lessons:
            print(f"  ! Scraping blocked. Injecting Backup for {lang_code}")
            backup = BACKUP_LESSONS.copy()
            for b in backup: b['language'] = lang_code
            all_lessons = backup

        # Limit size
        all_lessons = all_lessons[:MAX_FEED_SIZE]
        
        # Save
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(all_lessons, f, ensure_ascii=False, indent=2)
            
        print(f"Saved {len(all_lessons)} videos to {filename}")

if __name__ == "__main__":
    main()