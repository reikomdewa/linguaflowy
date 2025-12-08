import requests
import json
import os
import xml.etree.ElementTree as ET
import time
import re

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/audio_library"

# EXPANDED SEARCH CONFIGURATION
# Designed to find a wide variety of content (Fiction, Non-fiction, Short Stories, Classics)
SEARCH_CONFIG = {
    'fr': [
        {'q': 'fables', 'genre': 'fables'},           # La Fontaine
        {'q': 'maupassant', 'genre': 'literature'},   # Short stories (Great for learners)
        {'q': 'verne', 'genre': 'adventure'},         # Jules Verne
        {'q': 'leblanc', 'genre': 'mystery'},         # Arsène Lupin
        {'q': 'comtesse de segur', 'genre': 'kids'},  # Children's books (Easier vocab)
        {'q': 'perrault', 'genre': 'stories'},        # Fairy Tales
        {'q': 'hugo', 'genre': 'literature'},         # Victor Hugo
        {'q': 'dumas', 'genre': 'adventure'},         # Three Musketeers
        {'q': 'zola', 'genre': 'drama'},              # Emile Zola
        {'q': 'voltaire', 'genre': 'philosophy'}      # Candide etc.
    ],
    'es': [
        {'q': 'cuentos', 'genre': 'stories'},         # General short stories
        {'q': 'quiroga', 'genre': 'literature'},      # Horacio Quiroga (Jungle tales)
        {'q': 'poesia', 'genre': 'poetry'},           # Poetry
        {'q': 'cervantes', 'genre': 'classics'},      # Don Quixote
        {'q': 'benavente', 'genre': 'drama'},
        {'q': 'ruben dario', 'genre': 'poetry'},
        {'q': 'ibanez', 'genre': 'novel'},
        {'q': 'bazan', 'genre': 'literature'}
    ],
    'de': [
        {'q': 'grimm', 'genre': 'stories'},           # Brothers Grimm (Essential)
        {'q': 'kafka', 'genre': 'literature'},        # Franz Kafka
        {'q': 'goethe', 'genre': 'classics'},
        {'q': 'heine', 'genre': 'poetry'},
        {'q': 'rilke', 'genre': 'poetry'},
        {'q': 'zweig', 'genre': 'novel'},
        {'q': 'spyri', 'genre': 'kids'},              # Heidi
        {'q': 'märchen', 'genre': 'stories'}          # General Fairy Tales
    ],
    'it': [
        {'q': 'collodi', 'genre': 'kids'},            # Pinocchio
        {'q': 'fiabe', 'genre': 'stories'},           # Fables
        {'q': 'pirandello', 'genre': 'literature'},
        {'q': 'salgari', 'genre': 'adventure'},       # Italian adventure novels
        {'q': 'deledda', 'genre': 'novel'},
        {'q': 'dante', 'genre': 'classics'},
        {'q': 'verga', 'genre': 'drama'}
    ],
    'pt': [
        {'q': 'machado de assis', 'genre': 'literature'},
        {'q': 'contos', 'genre': 'stories'},
        {'q': 'pessoa', 'genre': 'poetry'},
        {'q': 'eca de queiros', 'genre': 'novel'},
        {'q': 'lobato', 'genre': 'kids'},             # Sítio do Picapau Amarelo
        {'q': 'bilac', 'genre': 'poetry'}
    ],
    'en': [
        {'q': 'aesop', 'genre': 'fables'},
        {'q': 'twain', 'genre': 'adventure'},
        {'q': 'doyle', 'genre': 'mystery'},           # Sherlock Holmes
        {'q': 'austen', 'genre': 'romance'},
        {'q': 'london', 'genre': 'adventure'},        # Call of the Wild
        {'q': 'wells', 'genre': 'scifi'},
        {'q': 'poe', 'genre': 'horror'}
    ],
    'ja': [
        # Note: LibriVox has limited Japanese content, but these keywords help
        {'q': 'japanese', 'genre': 'stories'},
        {'q': 'soseki', 'genre': 'literature'},
        {'q': 'akutagawa', 'genre': 'literature'},
        {'q': 'miazawa', 'genre': 'stories'}
    ]
}

def get_headers():
    return {
        'User-Agent': 'LinguaflowApp/1.0 (Language Learning Research)'
    }

def clean_html_summary(summary):
    if not summary: return ""
    clean = re.sub(r'<[^>]+>', '', summary).strip()
    return clean.replace('\n', ' ').replace('\r', '')

def parse_librivox_rss(rss_url, book_meta):
    """Parses RSS to get individual audio tracks."""
    try:
        response = requests.get(rss_url, headers=get_headers(), timeout=10)
        if response.status_code != 200:
            return []

        root = ET.fromstring(response.content)
        channel = root.find('channel')
        
        # Try to get cover image
        itunes_ns = {'itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd'}
        cover_img = None
        try:
            image_tag = channel.find('itunes:image', itunes_ns)
            if image_tag is not None:
                cover_img = image_tag.get('href')
        except:
            pass

        lessons = []
        items = channel.findall('item')
        
        # Get up to 50 tracks per book (covers most reasonable audiobooks)
        for i, item in enumerate(items[:50]): 
            title = item.find('title').text
            
            enclosure = item.find('enclosure')
            if enclosure is None: continue
            mp3_url = enclosure.get('url')
            
            # Duration calculation
            duration = 0
            try:
                dur_node = item.find('itunes:duration', itunes_ns)
                if dur_node is not None:
                    dur_str = dur_node.text
                    parts = dur_str.split(':')
                    if len(parts) == 3:
                        duration = int(parts[0])*3600 + int(parts[1])*60 + int(float(parts[2]))
                    elif len(parts) == 2:
                        duration = int(parts[0])*60 + int(float(parts[1]))
            except:
                pass

            # Create a unique ID for this specific chapter
            # ID format: lv_{book_id}_{chapter_index}
            lesson = {
                "id": f"lv_{book_meta['id']}_{i}",
                "userId": "system_librivox",
                "title": title,
                "language": book_meta['language'],
                "content": clean_html_summary(book_meta.get('description', 'Audiobook chapter.')),
                "sentences": [], # Audio doesn't have sentences text mapped by default here
                "transcript": [],
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": cover_img if cover_img else "https://librivox.org/images/librivox-logo.png", 
                "type": "audio", 
                "videoUrl": mp3_url, # Frontend uses videoUrl prop for media source often
                "audioUrl": mp3_url,
                "duration": duration,
                "difficulty": "intermediate", # Librivox is usually authentic native content
                "genre": book_meta['genre'],
                "sourceUrl": book_meta['url_text_source'], 
                "isFavorite": False,
                "progress": 0
            }
            lessons.append(lesson)
            
        return lessons

    except Exception as e:
        # print(f"    ⚠️ Error parsing RSS {rss_url}: {e}")
        return []

def search_librivox(query, genre, lang):
    # API search
    url = f"https://librivox.org/api/feed/audiobooks?format=json&title={query}&extended=1"
    
    try:
        res = requests.get(url, headers=get_headers(), timeout=15)
        # Check if response is valid JSON
        try:
            data = res.json()
        except:
            return []
        
        books = data.get('books', [])
        if not books: return []

        processed_lessons = []
        
        for book in books:
            # Language Filter
            # LibriVox uses full English names for languages (e.g. "French", "Spanish")
            lv_lang = book.get('language', '').lower()
            
            # Simple mapping check
            target_map = {
                'fr': 'french', 'es': 'spanish', 'de': 'german', 
                'it': 'italian', 'pt': 'portuguese', 'ja': 'japanese', 'en': 'english'
            }
            
            if target_map.get(lang) not in lv_lang:
                continue
            
            print(f"    🎧 Found Book: {book['title'][:50]}...")
            
            book_id = book['id']
            rss_url = f"https://librivox.org/rss/{book_id}"
            
            book_meta = {
                'id': book_id,
                'language': lang,
                'description': book.get('description'),
                'url_text_source': book.get('url_text_source'),
                'genre': genre
            }
            
            tracks = parse_librivox_rss(rss_url, book_meta)
            processed_lessons.extend(tracks)
            
            time.sleep(0.5) # Be gentle with their server

        return processed_lessons

    except Exception as e:
        print(f"    ❌ API Error for '{query}': {e}")
        return []

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, queries in SEARCH_CONFIG.items():
        print(f"\n==========================================")
        print(f" PROCESSING AUDIO: {lang.upper()}")
        print(f"==========================================")
        
        filepath = os.path.join(OUTPUT_DIR, f"audio_{lang}.json")
        
        # 1. LOAD EXISTING DATA (Handling Duplicates)
        existing_lessons = []
        existing_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    # Create a set of IDs for fast lookup
                    existing_ids = {l['id'] for l in existing_lessons}
                print(f"  📚 Loaded {len(existing_lessons)} existing tracks.")
            except:
                print("  🆕 No valid existing file found. Starting fresh.")
                existing_lessons = []

        # 2. SEARCH AND APPEND NEW CONTENT
        new_tracks_count = 0
        
        for item in queries:
            print(f"  🔍 Searching: '{item['q']}'")
            
            # Fetch candidates from API
            candidates = search_librivox(item['q'], item['genre'], lang)
            
            # Filter duplicates immediately
            added_for_query = 0
            for track in candidates:
                if track['id'] not in existing_ids:
                    existing_lessons.append(track)
                    existing_ids.add(track['id'])
                    new_tracks_count += 1
                    added_for_query += 1
            
            if added_for_query > 0:
                print(f"     ✅ Added {added_for_query} new tracks.")
            
            time.sleep(1)

        # 3. SAVE FILE (Overwrite with the combined list)
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
            print(f"  💾 SAVED: Added {new_tracks_count} new tracks. Total Library: {len(existing_lessons)}")
        except Exception as e:
            print(f"  ❌ ERROR SAVING FILE: {e}")

if __name__ == "__main__":
    main()