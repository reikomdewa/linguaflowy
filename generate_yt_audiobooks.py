import json
import os
import re
import glob
import yt_dlp
import time

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/youtube_audio_library"

# EXPANDED SEARCH CONFIGURATION
# Focus: "Read Along", "Audiobook with Text", "Subtitled Stories"
# Strategies:
# 1. Search for "Audiobook with text" (High chance of perfect sync)
# 2. Search for "Graded Reader" (Simplified content for learners)
# 3. Search for specific classic authors
SEARCH_CONFIG = {
    'es': [
        ('Audiolibro español con texto en pantalla', 'audiobook'),
        ('Spanish graded reader level 1', 'audiobook'),
        ('Cuentos cortos para dormir español', 'story'),
        ('Historia de España para niños', 'history'),
        ('Spanish audiobook for beginners', 'audiobook'),
        ('Don Quijote audiolibro resumen', 'classic'),
        ('Gabriel García Márquez audiolibro voz humana', 'classic')
    ],
    'fr': [
        ('Livre audio français avec texte', 'audiobook'),
        ('French graded reader A1 A2', 'audiobook'),
        ('Contes de Perrault audio texte', 'classic'),
        ('Le Petit Prince livre audio complet', 'classic'),
        ('Lupin livre audio français', 'mystery'),
        ('Maupassant audio nouvelle', 'classic'),
        ('French short stories for beginners', 'story')
    ],
    'de': [
        ('Hörbuch deutsch mit text', 'audiobook'),
        ('German graded reader A1', 'audiobook'),
        ('Märchen der Gebrüder Grimm hörspiel', 'classic'),
        ('Deutsch lernen durch hören', 'story'),
        ('Kafka Die Verwandlung hörbuch', 'classic'),
        ('Short stories in German for beginners', 'story')
    ],
    'it': [
        ('Audiolibro italiano con testo', 'audiobook'),
        ('Italian graded reader A1', 'audiobook'),
        ('Pinocchio audiolibro completo', 'classic'),
        ('Favole al telefono Rodari', 'story'),
        ('Italian short stories for beginners', 'story')
    ],
    'pt': [
        ('Audiolivro com texto portugues brasil', 'audiobook'),
        ('Portuguese graded reader', 'audiobook'),
        ('Machado de Assis audiolibro', 'classic'),
        ('Turma da Mônica audiodescrição', 'story'),
        ('Lendas brasileiras animação', 'story')
    ],
    'ja': [
        ('Japanese audiobook with subtitles', 'audiobook'),
        ('Japanese graded reader', 'audiobook'),
        ('Japanese folklore stories subtitles', 'story'),
        ('Miyazawa Kenji audiobook', 'classic'),
        ('Soseki Natsume audiobook', 'classic')
    ],
    'en': [
        ('English audiobook with text on screen', 'audiobook'),
        ('Sherlock Holmes audiobook with text', 'classic'),
        ('English short stories for learning', 'story'),
        ('History of English language documentary', 'history')
    ]
}

def time_to_seconds(time_str):
    """Converts HH:MM:SS.mmm OR MM:SS.mmm to seconds."""
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
    # Regex to catch standard VTT timestamps (00:00:00.000)
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
        'extractor_args': {'youtube': {'player_client': ['android']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=True)
            
            # Duration Filter: 
            # Skip if < 2 mins (likely intro/promo) 
            # Skip if > 90 mins (too heavy for mobile app typically)
            duration = info.get('duration', 0)
            if duration < 120 or duration > 5400: 
                print(f"    ⚠️ Skipping duration: {duration}s")
                return None
            
            files = glob.glob(f"{temp_filename}*.vtt")
            if not files:
                return None
            
            # Read Transcript
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Cleanup temp files immediately
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data: return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            # Difficulty Heuristic
            words = full_text.split()
            avg_len = sum(len(w) for w in words) / len(words) if words else 5
            difficulty = "intermediate"
            if "graded reader" in info.get('title', '').lower(): difficulty = "beginner"
            elif avg_len > 5.5: difficulty = "advanced"

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
                "difficulty": difficulty, 
                "genre": genre,
                "isFavorite": False,
                "progress": 0
            }
    except Exception as e:
        # print(f"    ⚠️ Error: {str(e)[:50]}")
        # Clean up if error occurred
        for f in glob.glob(f"{temp_filename}*"):
            try: os.remove(f)
            except: pass
        return None

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, categories in SEARCH_CONFIG.items():
        print(f"\n==========================================")
        print(f" PROCESSING AUDIOBOOKS: {lang.upper()}")
        print(f"==========================================")
        
        filepath = os.path.join(OUTPUT_DIR, f"audiobooks_{lang}.json")
        
        existing_lessons = []
        existing_ids = set()
        
        # 1. LOAD EXISTING DATA (Handling Duplicates)
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  📚 Loaded {len(existing_lessons)} existing audiobooks.")
            except:
                print("  🆕 No existing file found.")

        total_new = 0

        # 2. SEARCH NEW CONTENT
        for query, genre in categories:
            print(f"\n  🔍 Query: '{query}' ({genre})")
            
            ydl_opts = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'extractor_args': {'youtube': {'player_client': ['android']}}
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                try:
                    # Get top 3 results per query (keeps library high quality)
                    result = ydl.extract_info(f"ytsearch3:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        vid = entry.get('id')
                        lesson_id = f"yt_audio_{vid}"

                        # DUPLICATE PROTECTION
                        if lesson_id in existing_ids:
                            continue

                        print(f"    ⬇️ Fetching: {entry.get('title', '')[:40]}...")
                        lesson = process_audiobook_video(f"https://www.youtube.com/watch?v={vid}", lang, genre)
                        
                        if lesson:
                            existing_lessons.append(lesson)
                            existing_ids.add(lesson_id)
                            total_new += 1
                            print("       ✅ Saved")
                        else:
                            print("       🚫 Skipped")
                        
                        time.sleep(1)

        # 3. SAVE FILE
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
            
        print(f"\n  💾 SAVED {lang.upper()}: Added {total_new} new items.")

if __name__ == "__main__":
    main()