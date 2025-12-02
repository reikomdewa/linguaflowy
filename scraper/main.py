import json
import os
import glob
import re
import yt_dlp
import time
import random

# Define languages and queries
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
    """
    Parses WebVTT content and extracts clean text.
    """
    lines = vtt_content.splitlines()
    clean_lines = []
    seen_lines = set()
    
    timestamp_pattern = re.compile(r'\d{2}:\d{2}:\d{2}\.\d{3}\s-->\s\d{2}:\d{2}:\d{2}\.\d{3}')
    
    for line in lines:
        line = line.strip()
        if (not line or 
            line == 'WEBVTT' or 
            line.startswith('Kind:') or 
            line.startswith('Language:') or 
            timestamp_pattern.search(line) or 
            line.isdigit()):
            continue
            
        line = re.sub(r'<[^>]+>', '', line)
        
        if line not in seen_lines:
            clean_lines.append(line)
            seen_lines.add(line)
            
    return " ".join(clean_lines)

def download_transcript(video_id, lang_code):
    temp_filename = f"temp_{video_id}"
    
    # 🔴 THE FIX: Use the ANDROID client to bypass 'Sign in' checks
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        'subtitleslangs': [lang_code],
        'outtmpl': temp_filename,
        'quiet': True,
        # This tells YouTube we are an Android phone, not a server
        'extractor_args': {
            'youtube': {
                'player_client': ['android', 'ios']
            }
        }
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([f'https://www.youtube.com/watch?v={video_id}'])
            
        files = glob.glob(f"{temp_filename}*.vtt")
        
        if not files:
            return None
            
        with open(files[0], 'r', encoding='utf-8') as f:
            content = f.read()
            
        for f in files:
            os.remove(f)
            
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
    
    # Use Android client for search too
    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        'dump_single_json': True,
        'extractor_args': {
            'youtube': {
                'player_client': ['android']
            }
        }
    }

    lessons = []
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            # Add 'subtitles' to query to increase chance of success
            search_query = f"ytsearch15:{query}"
            result = ydl.extract_info(search_query, download=False)
            
            if 'entries' not in result:
                return []

            for video in result['entries']:
                video_id = video.get('id')
                title = video.get('title')
                thumbnail = f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"

                print(f"  > Checking: {title}")
                
                # Sleep briefly to avoid hammering the API
                time.sleep(random.uniform(1.0, 2.0))
                
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
                    # Don't print failures to keep logs clean, it is expected
                    print("    - Skipped (No subs or blocked)")

                if len(lessons) >= 6: 
                    break
                    
        except Exception as e:
            print(f"Search failed: {e}")

    return lessons

def main():
    if not os.path.exists('data'):
        os.makedirs('data')

    for lang_code, query in LANGUAGES.items():
        lessons = search_and_scrape(lang_code, query)
        
        filename = f"data/lessons_{lang_code}.json"
        
        # Save to JSON
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(lessons, f, ensure_ascii=False, indent=2)
            
        print(f"Saved {len(lessons)} videos to {filename}")

if __name__ == "__main__":
    main()