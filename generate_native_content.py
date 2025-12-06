import json
import os
import re
import glob
import yt_dlp
import time

# --- CONFIGURATION FOR NATIVE CONTENT ---

# 1. Change Output Directory so it doesn't mix with lessons
OUTPUT_DIR = "assets/course_videos"

# 2. Search Config: Native topics (Science, Tech, Vlogs, Culture)
# Note: Queries are in the target language to find native content.
SEARCH_CONFIG = {
    'es': [
        ('Documentales interesantes en español', 'Stories'),
        ('Reseñas de tecnología celulares', 'News'),
        ('Vlog de viajes méxico españa', 'Bites'),
        ('Entrevistas a famosos españoles', 'Grammar tips'),
    ],
    'fr': [
        ('Documentaire arte français', 'documentary'),
        ('High tech test français', 'tech'),
        ('Vlog voyage paris', 'vlog'),
        ('HugoDécrypte actus', 'news'), # Popular French news YouTuber
        ('Recette cuisine française simple', 'cooking')
    ],
    'de': [
        ('Doku deutsch', 'documentary'),
        ('Technik review deutsch', 'tech'),
        ('Reisevlog deutschland', 'vlog'),
        ('Wissen macht Ah', 'science'),
        ('Interessante fakten deutsch', 'education')
    ],
    'it': [
        ('Documentario italiano', 'documentary'),
        ('Recensione tecnologia italiano', 'tech'),
        ('Vlog viaggio italia', 'vlog'),
        ('Intervista italiano', 'interview'),
        ('Ricette cucina italiana', 'cooking')
    ],
    'pt': [
        ('Documentário brasileiro', 'documentary'),
        ('Review tecnologia brasil', 'tech'),
        ('Vlog de viagem portugal brasil', 'vlog'),
        ('Podcast cortes brasil', 'interview')
    ],
    'ja': [
        ('日本のドキュメンタリー', 'documentary'), # Japanese Documentary
        ('ガジェットレビュー', 'tech'),           # Gadget Review
        ('日本旅行 Vlog', 'vlog'),              # Japan Travel Vlog
        ('日本の料理レシピ', 'cooking')           # Japanese Cooking Recipes
    ],
    'en': [
        ('TED talks', 'education'),
        ('MKBHD tech reviews', 'tech'),
        ('Travel documentary 4k', 'documentary'),
        ('Celebrity interviews', 'interview')
    ]
}

# --- HELPERS (Identical to your Lesson script) ---

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
    # Native content is usually Advanced or Intermediate
    if not transcript: return 'advanced'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'advanced'
    
    avg_len = sum(len(w) for w in words) / len(words)
    
    # Adjusted thresholds for native content
    if avg_len < 4.0: return 'beginner'
    if avg_len < 5.0: return 'intermediate'
    return 'advanced'

def get_video_details(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_native_{video_id}" # Changed temp name to avoid conflicts
    
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
            
            # Filter out "Shorts" or very short videos (less than 2 mins)
            duration = info.get('duration', 0)
            if duration < 120: 
                print(f"    ⚠️ Skipping (Too short/Shorts): {info.get('title')}")
                return None

            files = glob.glob(f"{temp_filename}*.vtt")
            
            if not files:
                return None
            
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data: return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            return {
                "id": f"yt_{video_id}",
                "userId": "system_native", # Mark as native system content
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": "video_native", # New Type identifier
                "difficulty": analyze_difficulty(transcript_data),
                "videoUrl": f"https://youtube.com/watch?v={video_id}",
                "isFavorite": False,
                "progress": 0,
                "genre": genre
            }
    except Exception as e:
        print(f"    ⚠️ Error processing {video_id}: {str(e)[:50]}...")
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, categories in SEARCH_CONFIG.items():
        print(f"\n==========================================")
        print(f" PROCESSING NATIVE CONTENT: {lang.upper()}")
        print(f"==========================================")
        
        # CHANGED: Filename is now 'trending_{lang}.json'
        filepath = os.path.join(OUTPUT_DIR, f"trending_{lang}.json")
        
        existing_lessons = []
        existing_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  📚 Loaded {len(existing_lessons)} existing videos.")
            except:
                print("  🆕 No existing file found.")

        total_new_for_lang = 0

        for query, genre in categories:
            print(f"\n  🔎 Searching: '{query}' (Genre: {genre})")
            
            ydl_opts = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'extractor_args': {'youtube': {'player_client': ['android']}}
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # Search for 5 videos per topic (fewer than lessons, keeps it fresh)
                try:
                    result = ydl.extract_info(f"ytsearch5:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        vid = entry.get('id')
                        title = entry.get('title')
                        lesson_id = f"yt_{vid}"

                        if lesson_id in existing_ids:
                            continue

                        print(f"    ⬇️ Processing: {title[:40]}...")
                        
                        lesson = get_video_details(f"https://www.youtube.com/watch?v={vid}", lang, genre)
                        
                        if lesson:
                            existing_lessons.insert(0, lesson)
                            existing_ids.add(lesson_id)
                            total_new_for_lang += 1
                            print(f"       ✅ Added!")
                        else:
                            print(f"       🚫 Skipped")
                        
                        time.sleep(1)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        
        print(f"\n  💾 SAVED {lang.upper()}: Total {len(existing_lessons)} videos.")

if __name__ == "__main__":
    main()