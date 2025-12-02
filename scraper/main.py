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

# --- SAFETY NET DATA ---
# If yt-dlp gets completely blocked (0 results), we use this so the JSON file isn't empty.
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
    """Parses WebVTT content and extracts clean text."""
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
        if line not in seen:
            clean_lines.append(line)
            seen.add(line)
    return " ".join(clean_lines)

def analyze_difficulty(text):
    words = text.split()
    if not words: return 'intermediate'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.5: return 'beginner'
    if avg_len > 6.0: return 'advanced'
    return 'intermediate'

def get_video_data(video_url, lang_code):
    """Downloads metadata and subtitles for a single video."""
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_{video_id}"
    
    # 🚀 THE MAGIC CONFIGURATION
    ydl_opts = {
        'skip_download': True,      # Don't download video
        'writesubtitles': True,     # Download subs
        'writeautomaticsub': True,  # Allow auto-generated
        'subtitleslangs': [lang_code],
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'ignoreerrors': True,       # Don't crash on block
        # Pretend to be an Android device
        'extractor_args': {
            'youtube': {
                'player_client': ['android', 'web']
            }
        }
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=True)
            
            if not info: return None

            # Find the .vtt file
            files = glob.glob(f"{temp_filename}*.vtt")
            if not files: return None
            
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Cleanup
            for f in files: os.remove(f)
            
            clean_text = clean_vtt_text(content)
            if len(clean_text) < 50: return None

            return {
                "id": f"yt_{video_id}",
                "userId": "system",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": clean_text,
                "sentences": [], 
                "createdAt": "2024-01-01T00:00:00.000Z",
                "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": "video",
                "difficulty": analyze_difficulty(clean_text),
                "videoUrl": video_url,
                "isFavorite": False
            }

    except Exception as e:
        # print(f"Error downloading {video_id}: {e}")
        return None

def search_and_scrape(lang_code, query):
    print(f"\n--- Searching: {query} ({lang_code}) ---")
    
    # Use 'flat' extraction for search (faster, less likely to trigger blocks)
    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        'dump_single_json': True,
        'ignoreerrors': True,
    }

    lessons = []
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            # Search 10 videos
            result = ydl.extract_info(f"ytsearch10:{query}", download=False)
            if 'entries' not in result: return []

            for video in result['entries']:
                if len(lessons) >= 5: break
                
                video_id = video.get('id')
                title = video.get('title')
                print(f"  > Checking: {title}")
                
                # Polite delay
                time.sleep(random.uniform(2.0, 5.0))
                
                # Deep fetch
                lesson_data = get_video_data(f"https://www.youtube.com/watch?v={video_id}", lang_code)
                
                if lesson_data:
                    print(f"    + SUCCESS: {len(lesson_data['content'])} chars")
                    lessons.append(lesson_data)
                else:
                    print("    - Skipped (No subs or blocked)")
                    
        except Exception as e:
            print(f"Search error: {e}")

    return lessons

def main():
    if not os.path.exists('data'):
        os.makedirs('data')

    for lang_code, query in LANGUAGES.items():
        lessons = search_and_scrape(lang_code, query)
        
        # If scraper completely failed, inject backup so app doesn't break
        if not lessons:
            print(f"  ! No videos found for {lang_code}. Using Backup.")
            # Inject language code into backup data
            backup = BACKUP_LESSONS.copy()
            for b in backup: b['language'] = lang_code
            lessons = backup

        filename = f"data/lessons_{lang_code}.json"
        
        # Write to file
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(lessons, f, ensure_ascii=False, indent=2)
            
        print(f"Saved {len(lessons)} videos to {filename}")

if __name__ == "__main__":
    main()