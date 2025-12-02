import json
import os
import glob
import re
import yt_dlp

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
            
        # Remove HTML-like tags (e.g. <c.colorE5E5E5>)
        line = re.sub(r'<[^>]+>', '', line)
        
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
    
    # Options to ONLY download subtitles (no video/audio)
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,      # Fallback to auto-generated
        'subtitleslangs': [lang_code],  # Desired language
        'outtmpl': temp_filename,       # Temp filename
        'quiet': True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([f'https://www.youtube.com/watch?v={video_id}'])
            
        # Find the downloaded .vtt file
        # yt-dlp appends the lang code, e.g., temp_ID.en.vtt
        files = glob.glob(f"{temp_filename}*.vtt")
        
        if not files:
            return None
            
        # Read the file
        with open(files[0], 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Clean up (delete temp file)
        for f in files:
            os.remove(f)
            
        return clean_vtt_text(content)
        
    except Exception as e:
        print(f"    ! Download error: {e}")
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
    
    # Search options
    ydl_opts = {
        'quiet': True,
        'extract_flat': True, # Only metadata for search
        'dump_single_json': True,
    }

    lessons = []
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            # Search for 15 videos
            result = ydl.extract_info(f"ytsearch15:{query}", download=False)
            
            if 'entries' not in result:
                return []

            for video in result['entries']:
                video_id = video.get('id')
                title = video.get('title')
                thumbnail = f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"

                print(f"  > Checking: {title}")
                
                # Get Transcript using yt-dlp download method
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
                    print("    - Skipped: No subtitles.")

                if len(lessons) >= 6: 
                    break
                    
        except Exception as e:
            print(f"Search failed: {e}")

    return lessons

def main():
    # Ensure data directory exists
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