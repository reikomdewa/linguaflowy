import json
import os
import re
import glob
import yt_dlp
import time
import random

# --- CONFIGURATION FOR NATIVE CONTENT ---

# 1. Output Directory for "Trending/Native" feed
OUTPUT_DIR = "assets/native_videos"

# 2. EXPANDED SEARCH CONFIGURATION
# Mapped to the specific genreMap provided:
# history, news, crime, fiction, environment, education, documentary, biography, 
# philosophy, health, vlog, cinema, comedy, society, culture, travel, literature, 
# music, science, tech.

SEARCH_CONFIG = {
    'es': [
        # Society, News & Info
        ('VisualPolitik español', 'news'),
        ('BBC News Mundo', 'news'),
        ('Esquizofrenia Natural', 'society'),
        # True Crime & Fiction
        ('Relatos de la Noche', 'crime'),
        ('Leyendas Legendarias', 'crime'),
        ('Te lo resumo cuentos', 'fiction'), # Often summarizes plots narratively
        # Science, Tech & Environment
        ('QuantumFracture', 'science'),
        ('Robot de Platón', 'science'),
        ('Topes de Gama', 'tech'),
        ('Ecología Verde', 'environment'),
        # History & Culture
        ('Academia Play', 'history'),
        ('Ter arquitectura', 'culture'),
        ('Jaime Altozano musica', 'music'), # Music analysis (best for language)
        ('Zepfilms cine', 'cinema'),
        # Lifestyle, Health & Vlogs
        ('Luisito Comunica', 'travel'),
        ('Doctor Vic salud', 'health'),
        ('La Capital cocina', 'vlog'), # Cooking/Lifestyle
        ('Ramilla de Aventura', 'travel'),
        # Education & Philosophy
        ('Migala filosofía', 'philosophy'),
        ('Curiosamente', 'education'),
        ('Adictos a la Filosofía', 'philosophy')
    ],
    'fr': [
        # Society, News & Info
        ('HugoDécrypte', 'news'),
        ('Le Monde actualité', 'news'),
        ('Osons Causer', 'society'),
        # True Crime & Mystery
        ('McSkyz histoire de crime', 'crime'),
        ('Hondelatte Raconte', 'crime'),
        ('Le Grand JD paranormal', 'fiction'),
        # Science, Tech & Environment
        ('Dr Nozman', 'science'),
        ('DirtyBiology', 'science'),
        ('Micode', 'tech'),
        ('Le Réveilleur climat', 'environment'),
        # History & Culture
        ('Nota Bene histoire', 'history'),
        ('Le Fossoyeur de Films', 'cinema'),
        ('LinksTheSun culture', 'culture'),
        ('PV Nova analyse musicale', 'music'),
        # Lifestyle, Health & Vlogs
        ('Bruno Maltor voyage', 'travel'),
        ('Dans Ton Corps santé', 'health'),
        ('Vilebrequin auto', 'vlog'),
        ('L\'atelier de Roxane', 'vlog'),
        # Education & Philosophy
        ('C\'est pas sorcier', 'education'),
        ('Cyrus North philo', 'philosophy'),
        ('Arte biographie', 'biography')
    ],
    'de': [
        # Society, News & Info
        ('Simplicissimus', 'society'),
        ('MrWissen2go', 'news'),
        ('STRG_F reportage', 'documentary'),
        # True Crime
        ('Mordlust Podcast', 'crime'),
        ('Der Fall Kriminalfälle', 'crime'),
        # Science, Tech & Environment
        ('Dinge Erklärt – Kurzgesagt', 'science'),
        ('Breaking Lab', 'science'),
        ('Technikfaultier', 'tech'),
        ('Terra X Natur & Geschichte', 'environment'),
        # History & Culture
        ('MrWissen2go Geschichte', 'history'),
        ('Cinema Strikes Back', 'cinema'),
        ('Kulturzeit 3sat', 'culture'),
        ('Marti Fischer Musik', 'music'),
        # Lifestyle & Vlogs
        ('Sallys Welt', 'vlog'),
        ('Leeroy will wissen', 'biography'), # Great interview/portraits
        ('MaiLab health', 'health'),
        ('Reisevlog Deutschland', 'travel'),
        # Philosophy & Edu
        ('Scobel 3sat', 'philosophy'),
        ('Musstewissen', 'education')
    ],
    'it': [
        # Society & News
        ('Breaking Italy', 'news'),
        ('Nova Lectio', 'society'),
        ('Cartoni Morti', 'society'), # Satire/Society
        # True Crime
        ('Elisa True Crime', 'crime'),
        ('Blu Notte misteri', 'crime'),
        # Science & Tech
        ('Geopop', 'science'),
        ('Entropy for Life', 'science'),
        ('Galeazzi tech', 'tech'),
        ('Link4Universe', 'environment'),
        # History & Culture
        ('Alessandro Barbero storia', 'history'),
        ('Podcast Italiano cultura', 'culture'),
        ('Yotobi film', 'cinema'),
        # Lifestyle
        ('Human Safari', 'travel'),
        ('Fatto in casa da Benedetta', 'vlog'),
        ('Project Happiness', 'biography'),
        # Philosophy/Edu
        ('Rick DuFer', 'philosophy'),
        ('Weschool educazione', 'education')
    ],
    'pt': [
        # Society & News
        ('Nexo Jornal', 'news'),
        ('BBC News Brasil', 'news'),
        ('Canal Nostalgia', 'society'),
        # Crime & Mystery
        ('Jaqueline Guerreiro', 'crime'),
        ('Operação Policial', 'crime'),
        # Science & Tech
        ('Manual do Mundo', 'science'),
        ('Sérgio Sacani', 'science'),
        ('Loop Infinito', 'tech'),
        # History & Culture
        ('Buenas Ideias história', 'history'),
        ('Pipocando cinema', 'cinema'),
        ('Gaveta entretenimento', 'culture'),
        ('Cifra Club teoria', 'music'),
        # Lifestyle
        ('Mundo Sem Fim', 'travel'),
        ('Drauzio Varella', 'health'),
        ('Jovem Nerd', 'vlog'),
        # Philo/Edu
        ('Casa do Saber', 'philosophy'),
        ('Seu Leitura livros', 'literature')
    ],
    'ja': [
        # Society & News
        ('ANN news', 'news'),
        ('Oriental Radio Nakata', 'society'),
        # Science & Tech
        ('Genki Labo', 'science'),
        ('Seto Koji', 'tech'),
        # History & Culture
        ('Cocotama history', 'history'),
        ('Utamaru cinema', 'cinema'),
        # Lifestyle
        ('Kimono Mom', 'vlog'),
        ('Rachel and Jun', 'travel'),
        ('Suit Travel', 'travel'),
        # Edu/Lit
        ('HonTame literature', 'literature'),
        ('Yobikou education', 'education')
    ],
    'en': [
        ('Vox', 'society'),
        ('Veritasium', 'science'),
        ('LEMMiNO', 'documentary'),
        ('JCS - Criminal Psychology', 'crime'),
        ('Architectural Digest', 'culture'),
        ('Wisecrack', 'philosophy'),
        ('Nerdwriter1', 'cinema'),
        ('Adam Neely', 'music'),
        ('TED-Ed', 'education'),
        ('Bald and Bankrupt', 'travel'),
        ('Kurzgesagt – In a Nutshell', 'environment')
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
    # Basic sentence splitting
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
            # Clean HTML tags and entities
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
    # Native content logic:
    # High word count per second = Advanced
    # Low word count / simple words = Intermediate
    if not transcript: return 'advanced'
    
    all_text = " ".join([t['text'] for t in transcript])
    words = all_text.split()
    if not words: return 'advanced'
    
    # Calculate average word length as a proxy for complexity
    avg_len = sum(len(w) for w in words) / len(words)
    
    if avg_len < 4.2: return 'beginner'
    if avg_len < 5.2: return 'intermediate'
    return 'advanced'

def get_video_details(video_url, lang_code, genre):
    video_id = video_url.split('v=')[-1]
    temp_filename = f"temp_native_{video_id}"
    
    # YT-DLP configuration
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        'subtitleslangs': [lang_code], 
        'outtmpl': temp_filename,
        'quiet': True,
        'no_warnings': True,
        # Use Android client to avoid some age-gating/throttling
        'extractor_args': {'youtube': {'player_client': ['android']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                info = ydl.extract_info(video_url, download=True)
            except Exception:
                return None
            
            # Filter shorts (<60s) or very long videos (>45min)
            duration = info.get('duration', 0)
            if duration < 60 or duration > 2700: 
                # print(f"    ⚠️ Skipping length: {duration}s")
                return None

            # Find the VTT file
            files = glob.glob(f"{temp_filename}*.vtt")
            if not files:
                return None
            
            # Read and parse VTT
            with open(files[0], 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Cleanup
            for f in files: 
                try: os.remove(f)
                except: pass
            
            transcript_data = parse_vtt_to_transcript(content)
            if not transcript_data or len(transcript_data) < 5: return None
            
            full_text = " ".join([t['text'] for t in transcript_data])

            # Construct the video object matching the App's NativeVideo model
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
                "genre": genre # Dynamic genre from search config
            }
    except Exception as e:
        # Cleanup on error
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
        
        # 1. Load Existing Data to avoid duplicates
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  📚 Loaded {len(existing_lessons)} existing videos.")
            except:
                print("  🆕 No existing file found.")

        total_new_for_lang = 0

        # 2. Shuffle categories so we don't always start with the same topic if interrupted
        random.shuffle(categories)

        # 3. Search Loop
        for query, genre in categories:
            print(f"\n  🔎 Searching: '{query}' ({genre})")
            
            ydl_opts = {
                'quiet': True,
                'extract_flat': True,
                'dump_single_json': True,
                'extractor_args': {'youtube': {'player_client': ['android']}}
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # Limit to 3 videos per specific channel/query to keep variety high
                try:
                    result = ydl.extract_info(f"ytsearch3:{query}", download=False)
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
                            print(f"       🚫 Skipped (No subs or bad length)")
                        
                        # Be polite to YouTube API
                        time.sleep(1.5)

        # 4. Save updates to JSON
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
        
        print(f"\n  💾 SAVED {lang.upper()}: Total {len(existing_lessons)} (+{total_new_for_lang} new).")

if __name__ == "__main__":
    main()