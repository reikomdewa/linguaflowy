import json
import os
import re
import glob
import yt_dlp
import time

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/youtube_audio_library"

# Searches specifically for content that is "Audio-first" (Audiobooks, Stories)
# and ensures they have subtitles.
SEARCH_CONFIG = {
    'es': [
        ('Spanish audiobook with text', 'audiobook'),
        ('Spanish stories for beginners with subtitles', 'story'),
        ('Audiolibro español letra', 'audiobook'),
    ],
    'fr': [
        ('French audiobook with text', 'audiobook'),
        ('Livre audio français texte', 'audiobook'),
        ('French stories with subtitles', 'story'),
    ],
    'de': [
        ('German audiobook with text', 'audiobook'),
        ('Hörbuch deutsch mit text', 'audiobook'),
        ('German stories for beginners', 'story'),
    ],
    'it': [
        ('Italian audiobook with text', 'audiobook'),
        ('Audiolibro italiano con testo', 'audiobook'),
    ],
    'pt': [
        ('Portuguese audiobook with text', 'audiobook'),
        ('Audiolivro com texto portugues', 'audiobook'),
    ],
    'ja': [
        ('Japanese audiobook with subtitles', 'audiobook'),
        ('Japanese stories for learning', 'story'),
    ],
    'en': [
        ('English audiobook with text', 'audiobook'),
        ('Short stories with subtitles', 'story'),
    ]
}

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
            # Clean HTML tags often found in subs
            clean_line = re.sub(r'<[^>]+>', '', line)
            clean_line = clean_line.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')
            if clean_line:
                current_entry['text'] += clean_line + " "

    if current_entry and current_entry['text']:
        transcript.append(current_entry)
    
    # Clean up whitespace
    for t in transcript: t['text'] = t['text'].strip()
    return transcript

def process_audiobook_video(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_audio_{video_id}"
    
    # Only get videos that have subtitles (subs) or auto-subs (writeautomaticsub)
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        'subtitleslangs': [lang_code], 
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=True)
            
            # Skip if it's too short (likely not a book) or too long (over 1 hour can break memory)
            duration = info.get('duration', 0)
            if duration < 180: return None # < 3 mins
            
            files = glob.glob(f"{temp_filename}*.vtt")
            if not files:
                return None
            
            # Read Transcript
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Cleanup temp files
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data: return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            return {
                "id": f"yt_audio_{video_id}",
                "userId": "system_audiobook",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text, # Full text for searching/reading
                "sentences": split_sentences(full_text),
                "transcript": transcript_data, # Synced timestamps
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": info.get('thumbnail'),
                "type": "audio", # Treat as audio in your app logic
                "videoUrl": f"https://youtube.com/watch?v={video_id}", # Use YT player as audio engine
                "difficulty": "intermediate", 
                "genre": genre,
                "isFavorite": False,
                "progress": 0
            }
    except Exception as e:
        print(f"    ⚠️ Error: {str(e)[:50]}")
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, categories in SEARCH_CONFIG.items():
        print(f"\nProcessing Audiobooks: {lang.upper()}")
        filepath = os.path.join(OUTPUT_DIR, f"audiobooks_{lang}.json")
        
        existing_lessons = []
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                existing_lessons = json.load(f)

        existing_ids = {l['id'] for l in existing_lessons}

        for query, genre in categories:
            print(f"  🔍 Query: '{query}'")
            
            ydl_opts = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'extractor_args': {'youtube': {'player_client': ['android']}}
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                try:
                    # Get top 3 results per query
                    result = ydl.extract_info(f"ytsearch3:{query}", download=False)
                except: continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        vid = entry.get('id')
                        lesson_id = f"yt_audio_{vid}"

                        if lesson_id in existing_ids: continue

                        print(f"    ⬇️ Fetching: {entry.get('title')[:40]}...")
                        lesson = process_audiobook_video(f"https://www.youtube.com/watch?v={vid}", lang, genre)
                        
                        if lesson:
                            existing_lessons.append(lesson)
                            existing_ids.add(lesson_id)
                            print("       ✅ Saved")
                        
                        time.sleep(1)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)

if __name__ == "__main__":
    main()