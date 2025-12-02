# import json
# import os
# import re
# import glob
# import yt_dlp

# # --- CONFIGURATION ---
# OUTPUT_DIR = "assets/data"

# LANGUAGES = {
#     'es': 'Spanish comprehensible input',
#     'fr': 'French comprehensible input',
#     'de': 'German comprehensible input',
#     'it': 'Italian comprehensible input',
#     'pt': 'Portuguese comprehensible input',
#     'ja': 'Japanese comprehensible input',
#     'en': 'English stories'
# }

# def time_to_seconds(time_str):
#     """Converts '00:00:05.500' to 5.5 (float seconds)"""
#     h, m, s = time_str.split(':')
#     return int(h) * 3600 + int(m) * 60 + float(s)

# def parse_vtt(vtt_content):
#     """
#     Parses WebVTT into a list of objects:
#     [{'start': 0.0, 'end': 2.5, 'text': 'Hello world'}]
#     """
#     lines = vtt_content.splitlines()
#     transcript = []
    
#     # Regex for timestamp: 00:00:00.000 --> 00:00:05.000
#     # Capture group 1 = start, group 2 = end
#     time_pattern = re.compile(r'(\d{2}:\d{2}:\d{2}\.\d{3})\s-->\s(\d{2}:\d{2}:\d{2}\.\d{3})')
    
#     current_entry = None
    
#     for line in lines:
#         line = line.strip()
        
#         # Skip headers
#         if not line or line == 'WEBVTT' or line.startswith('Kind:') or line.startswith('Language:'):
#             continue
            
#         # Check for timestamp
#         match = time_pattern.search(line)
#         if match:
#             # If we were building an entry, save it
#             if current_entry and current_entry['text']:
#                 transcript.append(current_entry)
            
#             # Start new entry
#             current_entry = {
#                 'start': time_to_seconds(match.group(1)),
#                 'end': time_to_seconds(match.group(2)),
#                 'text': ''
#             }
#             continue
            
#         # If it's text line (and we have an active timestamp)
#         if current_entry:
#             # Remove HTML tags like <c.color> or <b>
#             clean_line = re.sub(r'<[^>]+>', '', line)
#             # Remove entities
#             clean_line = clean_line.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&#39;', "'").replace('&quot;', '"')
            
#             if clean_line:
#                 current_entry['text'] += clean_line + " "

#     # Append last entry
#     if current_entry and current_entry['text']:
#         transcript.append(current_entry)
        
#     # Clean up whitespace
#     for t in transcript:
#         t['text'] = t['text'].strip()
        
#     return transcript

# def analyze_difficulty(transcript):
#     # Calculate avg word length from all lines
#     if not transcript: return 'intermediate'
#     all_text = " ".join([t['text'] for t in transcript])
#     words = all_text.split()
#     if not words: return 'intermediate'
#     avg_len = sum(len(w) for w in words) / len(words)
#     if avg_len < 4.5: return 'beginner'
#     if avg_len > 6.0: return 'advanced'
#     return 'intermediate'

# def get_video_details(video_url, lang_code):
#     video_id = video_url.split('v=')[-1]
#     temp_filename = f"temp_{video_id}"
    
#     ydl_opts = {
#         'skip_download': True,
#         'writesubtitles': True,
#         'writeautomaticsub': True,
#         'subtitleslangs': [lang_code],
#         'outtmpl': temp_filename,
#         'quiet': True,
#         'no_warnings': True,
#         'extractor_args': {'youtube': {'player_client': ['android']}}
#     }

#     try:
#         with yt_dlp.YoutubeDL(ydl_opts) as ydl:
#             info = ydl.extract_info(video_url, download=True)
            
#             files = glob.glob(f"{temp_filename}*.vtt")
#             if not files: return None
            
#             with open(files[0], 'r', encoding='utf-8') as f:
#                 content = f.read()
            
#             for f in files: os.remove(f)
            
#             # PARSE THE VTT HERE
#             transcript_data = parse_vtt(content)
            
#             if not transcript_data: return None
            
#             # Generate full content for search/display preview
#             full_text = " ".join([t['text'] for t in transcript_data])

#             return {
#                 "id": f"yt_{video_id}",
#                 "userId": "system",
#                 "title": info.get('title', 'Unknown'),
#                 "language": lang_code,
#                 "content": full_text, 
#                 # SAVE STRUCTURED DATA
#                 "transcript": transcript_data, 
#                 "createdAt": "2024-01-01T00:00:00.000Z",
#                 "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
#                 "type": "video",
#                 "difficulty": analyze_difficulty(transcript_data),
#                 "videoUrl": f"https://youtube.com/watch?v={video_id}",
#                 "isFavorite": False,
#                 "progress": 0
#             }
#     except Exception as e:
#         print(f"Error processing {video_id}: {e}")
#         return None

# def main():
#     if not os.path.exists(OUTPUT_DIR):
#         os.makedirs(OUTPUT_DIR)

#     for lang, query in LANGUAGES.items():
#         print(f"\n--- Processing {lang.upper()} ---")
#         ydl_opts = {'quiet': True, 'extract_flat': True, 'dump_single_json': True, 'extractor_args': {'youtube': {'player_client': ['android']}}}
#         lessons = []
        
#         with yt_dlp.YoutubeDL(ydl_opts) as ydl:
#             result = ydl.extract_info(f"ytsearch8:{query}", download=False)
#             if 'entries' in result:
#                 for entry in result['entries']:
#                     title = entry.get('title')
#                     vid = entry.get('id')
#                     print(f"  > Downloading: {title[:40]}...")
#                     lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang)
#                     if lesson:
#                         print(f"    ✅ Success ({len(lesson['transcript'])} lines)")
#                         lessons.append(lesson)
#                     if len(lessons) >= 5: break

#         filepath = os.path.join(OUTPUT_DIR, f"lessons_{lang}.json")
#         with open(filepath, 'w', encoding='utf-8') as f:
#             json.dump(lessons, f, ensure_ascii=False, indent=2)
#         print(f"Saved {len(lessons)} lessons to {filepath}")

# if __name__ == "__main__":
#     main()

import json
import os
import re
import glob
import yt_dlp

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/data"

LANGUAGES = {
    'es': 'Spanish comprehensible input',
    'fr': 'French comprehensible input',
    'de': 'German comprehensible input',
    'it': 'Italian comprehensible input',
    'pt': 'Portuguese comprehensible input',
    'ja': 'Japanese comprehensible input',
    'en': 'English stories'
}

def clean_vtt(vtt_content):
    """Removes timestamps and WebVTT metadata."""
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

# Helper to split text for the Flutter model
def split_sentences(text):
    return re.split(r'(?<=[.!?])\s+', text)

# Helper to parse VTT into time-coded objects (for video seeking)
def time_to_seconds(time_str):
    h, m, s = time_str.split(':')
    return int(h) * 3600 + int(m) * 60 + float(s)

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
        
    for t in transcript: t['text'] = t['text'].strip()
    return transcript

def analyze_difficulty(transcript):
    if not transcript: return 'intermediate'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'intermediate'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.5: return 'beginner'
    if avg_len > 6.0: return 'advanced'
    return 'intermediate'

def get_video_details(video_url, lang_code):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_{video_id}"
    
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
            
            files = glob.glob(f"{temp_filename}*.vtt")
            if not files: return None
            
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            for f in files: os.remove(f)
            
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data: return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            return {
                "id": f"yt_{video_id}",
                "userId": "system",
                "title": info.get('title', 'Unknown'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": "2024-01-01T00:00:00.000Z",
                "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": "video",
                "difficulty": analyze_difficulty(transcript_data),
                "videoUrl": f"https://youtube.com/watch?v={video_id}",
                "isFavorite": False,
                "progress": 0
            }
    except Exception as e:
        print(f"Error processing {video_id}: {e}")
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, query in LANGUAGES.items():
        print(f"\n--- Processing {lang.upper()} ---")
        filepath = os.path.join(OUTPUT_DIR, f"lessons_{lang}.json")
        
        existing_lessons = []
        existing_ids = set() # Sets are instant for lookups
        
        # 1. LOAD FAST
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    # OPTIMIZATION: Use Set Comprehension (Faster than a for loop)
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  Loaded {len(existing_lessons)} existing videos.")
            except:
                print("  Could not load existing file (starting fresh).")

        # 2. SEARCH
        ydl_opts = {
            'quiet': True,
            'extract_flat': True,
            'dump_single_json': True,
            'extractor_args': {'youtube': {'player_client': ['android']}}
        }
        
        new_lessons_added = 0
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Search 10 videos
            result = ydl.extract_info(f"ytsearch10:{query}", download=False)
            
            if 'entries' in result:
                for entry in result['entries']:
                    vid = entry.get('id')
                    title = entry.get('title')
                    lesson_id = f"yt_{vid}"

                    # 3. INSTANT CHECK (O(1) Complexity)
                    if lesson_id in existing_ids:
                        # This line runs instantly, regardless of list size
                        print(f"  • Skipping (Already exists): {title[:30]}...")
                        continue

                    # Only download details if it is NEW
                    print(f"  > Downloading: {title[:40]}...")
                    lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang)
                    
                    if lesson:
                        print(f"    ✅ Success")
                        existing_lessons.insert(0, lesson) # Add to top
                        existing_ids.add(lesson_id)        # Add to set so we don't add it twice in same run
                        new_lessons_added += 1
                    else:
                        print("    ❌ No subtitles found")
                    
                    if new_lessons_added >= 5: break

        # 4. SAVE
        with open(filepath, 'w', encoding='utf-8') as f:
            # indent=None is faster/smaller, but indent=2 is readable. 
            # Use indent=None for production to save space.
            json.dump(existing_lessons, f, ensure_ascii=False, indent=2)
        
        print(f"  Saved total {len(existing_lessons)} lessons (Added {new_lessons_added} new).")

if __name__ == "__main__":
    main()