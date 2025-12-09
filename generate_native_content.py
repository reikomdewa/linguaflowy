import json
import os
import re
import glob
import yt_dlp
import time

# --- CONFIGURATION FOR NATIVE CONTENT ---

# 1. Output Directory for "Trending/Native" feed
OUTPUT_DIR = "assets/course_videos"

# 2. EXPANDED SEARCH CONFIGURATION
# High-quality native content queries mixed with specific popular channels
SEARCH_CONFIG = {
    'es': [
        # Tech & Science
        ('Curiosamente ciencia', 'science'), # Excellent animated science
        ('Topes de Gama review', 'tech'),
        ('Robot de Platón ciencia', 'science'),
        # Vlogs & Travel
        ('Luisito Comunica viaje', 'vlog'), # The biggest travel vlogger
        ('Ramilla de Aventura', 'vlog'),
        ('Vlog diario españa', 'vlog'),
        # Culture & History
        ('VisualPolitik español', 'news'),
        ('Academia Play historia', 'history'),
        ('Te lo resumo cuentos', 'culture'),
        # Cooking
        ('La capital cocina', 'cooking')
    ],
    'fr': [
        # News & Essays
        ('HugoDécrypte actus', 'news'), # Essential French news
        ('Le Monde video', 'news'),
        ('Arte documentaire français', 'documentary'),
        # History & Science
        ('Nota Bene histoire', 'history'),
        ('C\'est pas sorcier', 'science'), # Classic clear French
        ('Dr Nozman science', 'science'),
        # Lifestyle
        ('Vlog voyage paris', 'vlog'),
        ('Bruno Maltor voyage', 'vlog'),
        ('750g recettes', 'cooking'),
        ('Tech test français', 'tech')
    ],
    'de': [
        # Science & Education (Germany is great for this)
        ('Dinge Erklärt – Kurzgesagt', 'science'), # Best animation
        ('MrWissen2go Geschichte', 'history'),
        ('Galileo deutschland', 'education'),
        ('Simplicissimus video essay', 'news'),
        # Tech & Lifestyle
        ('Technikfaultier review', 'tech'),
        ('Felixba review', 'tech'),
        ('Reisevlog Deutschland', 'vlog'),
        ('Sallys Welt kochen', 'cooking'),
        # Documentary
        ('STRG_F reportage', 'documentary'),
        ('WDR Doku', 'documentary')
    ],
    'it': [
        # Science & History
        ('Nova Lectio storia', 'history'),
        ('Geopop scienze', 'science'),
        ('Entropy for Life', 'science'),
        # News & Culture
        ('Breaking Italy news', 'news'),
        ('Podcast Italiano', 'culture'),
        # Lifestyle
        ('Human Safari viaggi', 'vlog'),
        ('Fatto in casa da Benedetta', 'cooking'),
        ('Galeazzi tech', 'tech')
    ],
    'pt': [
        # Brazil Dominates YouTube PT
        ('Manual do Mundo', 'science'), # Huge science channel
        ('Nostalgia Castanhari', 'history'),
        ('Sérgio Sacani', 'science'),
        # Tech & Vlogs
        ('Loop Infinito tech', 'tech'),
        ('Coisa de Nerd', 'tech'),
        ('Vlog de viagem brasil', 'vlog'),
        ('Receitas de Pai', 'cooking'),
        ('Jovem Nerd', 'culture')
    ],
    'ja': [
        # Vlogs & Culture
        ('Rachel and Jun vlogs', 'vlog'),
        ('Paolo fromTOKYO', 'documentary'),
        ('Kimono Mom cooking', 'cooking'),
        # Tech & News
        ('瀬戸弘司 (Seto Koji)', 'tech'),
        ('ANN news japanese', 'news'),
        # Entertainment
        ('Sushi Ramen Riku', 'science'), # Very visual, good for context
        ('Japanese history animation', 'history')
    ],
    'en': [
        ('Veritasium', 'science'),
        ('Vox video essays', 'news'),
        ('Marques Brownlee', 'tech'),
        ('Architectural Digest open door', 'vlog'),
        ('Gordon Ramsay cooking', 'cooking'),
        ('TED talks', 'education')
    ]
}

# --- HELPERS ---

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
    # Native content is usually Advanced, but we check word length
    if not transcript: return 'advanced'
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'advanced'
    
    avg_len = sum(len(w) for w in words) / len(words)
    
    if avg_len < 4.0: return 'beginner'
    if avg_len < 5.0: return 'intermediate'
    return 'advanced'

def get_video_details(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_native_{video_id}"
    
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
            
            # Filter shorts or very long videos
            duration = info.get('duration', 0)
            if duration < 120 or duration > 1800: 
                print(f"    ⚠️ Skipping (Length {duration}s): {info.get('title')[:30]}...")
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
                "userId": "system_native",
                "title": info.get('title', 'Unknown Title'),
                "language": lang_code,
                "content": full_text,
                "sentences": split_sentences(full_text),
                "transcript": transcript_data,
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg",
                "type": "video",
                "difficulty": analyze_difficulty(transcript_data),
                "videoUrl": f"https://youtube.com/watch?v={video_id}",
                "isFavorite": False,
                "progress": 0,
                "genre": genre
            }
    except Exception as e:
        # print(f"    ⚠️ Error: {str(e)[:50]}")
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
        
        filepath = os.path.join(OUTPUT_DIR, f"trending_{lang}.json")
        
        existing_lessons = []
        existing_ids = set()
        
        # 1. Load Existing Data
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  📚 Loaded {len(existing_lessons)} existing videos.")
            except:
                print("  🆕 No existing file found.")

        total_new_for_lang = 0

        # 2. Search
        for query, genre in categories:
            print(f"\n  🔎 Searching: '{query}' ({genre})")
            
            ydl_opts = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'extractor_args': {'youtube': {'player_client': ['android']}}
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # Search 4 videos per topic to keep the feed diverse
                try:
                    result = ydl.extract_info(f"ytsearch4:{query}", download=False)
                except Exception as e:
                    print(f"    ❌ Search failed: {e}")
                    continue
                
                if 'entries' in result:
                    for entry in result['entries']:
                        if not entry: continue
                        
                        vid = entry.get('id')
                        title = entry.get('title')
                        lesson_id = f"yt_{vid}"

                        # DUPLICATE PROTECTION
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

        # 3. Save
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        
        print(f"\n  💾 SAVED {lang.upper()}: Total {len(existing_lessons)} (+{total_new_for_lang} new).")

if __name__ == "__main__":
    main()