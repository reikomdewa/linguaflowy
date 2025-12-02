import json
import os
import glob
import re
import yt_dlp
import time
import random

LANGUAGES = {
    'es': 'Spanish comprehensible input',
    'fr': 'French comprehensible input',
    'de': 'German comprehensible input',
    'it': 'Italian comprehensible input',
    'pt': 'Portuguese comprehensible input',
    'ja': 'Japanese comprehensible input',
    'en': 'English stories'
}

def clean_vtt_text(vtt_content):
    lines = vtt_content.splitlines()
    clean_lines = []
    seen_lines = set()
    timestamp_pattern = re.compile(r'\d{2}:\d{2}:\d{2}\.\d{3}\s-->\s\d{2}:\d{2}:\d{2}\.\d{3}')
    
    for line in lines:
        line = line.strip()
        if (not line or line == 'WEBVTT' or line.startswith('Kind:') or 
            line.startswith('Language:') or timestamp_pattern.search(line) or line.isdigit()):
            continue
        line = re.sub(r'<[^>]+>', '', line)
        if line not in seen_lines:
            clean_lines.append(line)
            seen_lines.add(line)
    return " ".join(clean_lines)

def download_transcript(video_id, lang_code):
    temp_filename = f"temp_{video_id}"
    
    # Robust Options
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        'subtitleslangs': [lang_code],
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        'extractor_args': {'youtube': {'player_client': ['android', 'web']}},
        'socket_timeout': 10,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([f'https://www.youtube.com/watch?v={video_id}'])
            
        files = glob.glob(f"{temp_filename}*.vtt")
        if not files: return None
            
        with open(files[0], 'r', encoding='utf-8') as f:
            content = f.read()
            
        for f in files: os.remove(f)
        return clean_vtt_text(content)
        
    except Exception:
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
    
    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        'dump_single_json': True,
        'extractor_args': {'youtube': {'player_client': ['android']}}
    }

    lessons = []
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            # Search fewer items to reduce block chance
            result = ydl.extract_info(f"ytsearch10:{query}", download=False)
            
            if 'entries' not in result: return []

            for video in result['entries']:
                video_id = video.get('id')
                title = video.get('title')
                thumbnail = f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"

                print(f"  > Checking: {title}")
                
                # Randomized sleep is crucial for avoiding blocks
                time.sleep(random.uniform(2.0, 5.0))
                
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
                        "createdAt": "2024-01-01T00:00:00.000Z",
                        "imageUrl": thumbnail,
                        "type": "video",
                        "difficulty": analyze_difficulty(content),
                        "videoUrl": f"https://youtube.com/watch?v={video_id}",
                        "isFavorite": False
                    })
                else:
                    print("    - Skipped")

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
        
        # Merge with existing data if possible
        if os.path.exists(filename):
            try:
                with open(filename, 'r', encoding='utf-8') as f:
                    old_data = json.load(f)
                    # Filter out duplicates
                    existing_ids = {l['id'] for l in old_data}
                    for l in lessons:
                        if l['id'] not in existing_ids:
                            old_data.insert(0, l)
                    lessons = old_data[:50] # Keep last 50
            except:
                pass

        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(lessons, f, ensure_ascii=False, indent=2)
            
        print(f"Saved {len(lessons)} videos to {filename}")

if __name__ == "__main__":
    main()