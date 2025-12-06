import requests
import json
import os
import xml.etree.ElementTree as ET
import time
import re

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/audio_library"

# Optimized search queries for French content
SEARCH_CONFIG = {
    'fr': [
        {'q': 'fables', 'genre': 'fables'},      # La Fontaine (Classic)
        {'q': 'contes', 'genre': 'stories'},     # Fairy tales
        {'q': 'maupassant', 'genre': 'literature'}, # Short stories
        {'q': 'verne', 'genre': 'adventure'},    # Jules Verne
        {'q': 'leblanc', 'genre': 'mystery'}     # Arsène Lupin
    ],
    # You can keep or comment out other languages
    'es': [{'q': 'cuentos', 'genre': 'stories'}],
    'en': [{'q': 'aesop', 'genre': 'fables'}],
    'de': [{'q': 'märchen', 'genre': 'stories'}],
    'it': [{'q': 'fiabe', 'genre': 'stories'}],
    'pt': [{'q': 'contos', 'genre': 'stories'}],
    'ja': [{'q': 'japanese', 'genre': 'stories'}]
}

def get_headers():
    return {
        'User-Agent': 'LinguaflowApp/1.0 (Language Learning Research)'
    }

def clean_html_summary(summary):
    if not summary: return ""
    return re.sub(r'<[^>]+>', '', summary).strip()

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
        
        # Limit tracks per book to avoid flooding (e.g., first 15 chapters)
        for i, item in enumerate(items[:15]): 
            title = item.find('title').text
            
            enclosure = item.find('enclosure')
            if enclosure is None: continue
            mp3_url = enclosure.get('url')
            
            # Duration calculation
            duration = 0
            try:
                dur_str = item.find('itunes:duration', itunes_ns).text
                parts = dur_str.split(':')
                if len(parts) == 3:
                    duration = int(parts[0])*3600 + int(parts[1])*60 + int(parts[2])
                elif len(parts) == 2:
                    duration = int(parts[0])*60 + int(parts[1])
            except:
                pass

            lesson = {
                "id": f"lv_{book_meta['id']}_{i}",
                "userId": "system_librivox",
                "title": title,
                "language": book_meta['language'],
                "content": clean_html_summary(book_meta.get('description', '')),
                "sentences": [],
                "transcript": [],
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": cover_img, 
                "type": "audio", 
                "videoUrl": mp3_url, # Storing MP3 link here for consistency with your model
                "audioUrl": mp3_url, # Redundant but safe
                "duration": duration,
                "difficulty": "intermediate", 
                "genre": book_meta['genre'],
                "sourceUrl": book_meta['url_text_source'], 
                "isFavorite": False,
                "progress": 0
            }
            lessons.append(lesson)
            
        return lessons

    except Exception as e:
        print(f"    ⚠️ Error parsing RSS {rss_url}: {e}")
        return []

def search_librivox(query, genre, lang):
    # API search
    url = f"https://librivox.org/api/feed/audiobooks?format=json&title={query}&extended=1"
    
    try:
        res = requests.get(url, headers=get_headers(), timeout=15)
        data = res.json()
        
        books = data.get('books', [])
        if not books: return []

        processed_lessons = []
        
        for book in books:
            # Language Filter
            # LibriVox uses full English names for languages
            lv_lang = book.get('language', '').lower()
            
            if lang == 'fr' and 'french' not in lv_lang: continue
            if lang == 'es' and 'spanish' not in lv_lang: continue
            if lang == 'de' and 'german' not in lv_lang: continue
            
            print(f"    🎧 Found Audiobook: {book['title']}")
            
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
            
            if len(processed_lessons) >= 30: break # Stop after ~30 tracks per query to vary content
            
            time.sleep(1) 

        return processed_lessons

    except Exception as e:
        print(f"    ❌ API Error: {e}")
        return []

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, queries in SEARCH_CONFIG.items():
        print(f"\n==========================================")
        print(f" PROCESSING AUDIO: {lang.upper()}")
        print(f"==========================================")
        
        filepath = os.path.join(OUTPUT_DIR, f"audio_{lang}.json")
        all_audio_lessons = []
        
        for item in queries:
            print(f"  🔍 Searching: '{item['q']}'")
            lessons = search_librivox(item['q'], item['genre'], lang)
            all_audio_lessons.extend(lessons)
            time.sleep(1)
            
        # Deduplicate
        unique_lessons = {l['id']: l for l in all_audio_lessons}.values()
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(list(unique_lessons), f, ensure_ascii=False, indent=None)
            
        print(f"  💾 SAVED: {len(unique_lessons)} tracks to {filepath}")

if __name__ == "__main__":
    main()