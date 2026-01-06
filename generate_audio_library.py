# import requests
# import json
# import os
# import xml.etree.ElementTree as ET
# import time
# import re

# # --- CONFIGURATION ---
# OUTPUT_DIR = "assets/audio_library"

# # EXPANDED SEARCH CONFIGURATION
# # Designed to find a wide variety of content (Fiction, Non-fiction, Short Stories, Classics)
# SEARCH_CONFIG = {
#     'fr': [
#         {'q': 'fables', 'genre': 'fables'},           # La Fontaine
#         {'q': 'maupassant', 'genre': 'literature'},   # Short stories (Great for learners)
#         {'q': 'verne', 'genre': 'adventure'},         # Jules Verne
#         {'q': 'leblanc', 'genre': 'mystery'},         # Arsène Lupin
#         {'q': 'comtesse de segur', 'genre': 'kids'},  # Children's books (Easier vocab)
#         {'q': 'perrault', 'genre': 'stories'},        # Fairy Tales
#         {'q': 'hugo', 'genre': 'literature'},         # Victor Hugo
#         {'q': 'dumas', 'genre': 'adventure'},         # Three Musketeers
#         {'q': 'zola', 'genre': 'drama'},              # Emile Zola
#         {'q': 'voltaire', 'genre': 'philosophy'}      # Candide etc.
#     ],
#     'es': [
#         {'q': 'cuentos', 'genre': 'stories'},         # General short stories
#         {'q': 'quiroga', 'genre': 'literature'},      # Horacio Quiroga (Jungle tales)
#         {'q': 'poesia', 'genre': 'poetry'},           # Poetry
#         {'q': 'cervantes', 'genre': 'classics'},      # Don Quixote
#         {'q': 'benavente', 'genre': 'drama'},
#         {'q': 'ruben dario', 'genre': 'poetry'},
#         {'q': 'ibanez', 'genre': 'novel'},
#         {'q': 'bazan', 'genre': 'literature'}
#     ],
#     'de': [
#         {'q': 'grimm', 'genre': 'stories'},           # Brothers Grimm (Essential)
#         {'q': 'kafka', 'genre': 'literature'},        # Franz Kafka
#         {'q': 'goethe', 'genre': 'classics'},
#         {'q': 'heine', 'genre': 'poetry'},
#         {'q': 'rilke', 'genre': 'poetry'},
#         {'q': 'zweig', 'genre': 'novel'},
#         {'q': 'spyri', 'genre': 'kids'},              # Heidi
#         {'q': 'märchen', 'genre': 'stories'}          # General Fairy Tales
#     ],
#     'it': [
#         {'q': 'collodi', 'genre': 'kids'},            # Pinocchio
#         {'q': 'fiabe', 'genre': 'stories'},           # Fables
#         {'q': 'pirandello', 'genre': 'literature'},
#         {'q': 'salgari', 'genre': 'adventure'},       # Italian adventure novels
#         {'q': 'deledda', 'genre': 'novel'},
#         {'q': 'dante', 'genre': 'classics'},
#         {'q': 'verga', 'genre': 'drama'}
#     ],
#     'pt': [
#         {'q': 'machado de assis', 'genre': 'literature'},
#         {'q': 'contos', 'genre': 'stories'},
#         {'q': 'pessoa', 'genre': 'poetry'},
#         {'q': 'eca de queiros', 'genre': 'novel'},
#         {'q': 'lobato', 'genre': 'kids'},             # Sítio do Picapau Amarelo
#         {'q': 'bilac', 'genre': 'poetry'}
#     ],
#     'en': [
#         {'q': 'aesop', 'genre': 'fables'},
#         {'q': 'twain', 'genre': 'adventure'},
#         {'q': 'doyle', 'genre': 'mystery'},           # Sherlock Holmes
#         {'q': 'austen', 'genre': 'romance'},
#         {'q': 'london', 'genre': 'adventure'},        # Call of the Wild
#         {'q': 'wells', 'genre': 'scifi'},
#         {'q': 'poe', 'genre': 'horror'}
#     ],
#     'ja': [
#         # Note: LibriVox has limited Japanese content, but these keywords help
#         {'q': 'japanese', 'genre': 'stories'},
#         {'q': 'soseki', 'genre': 'literature'},
#         {'q': 'akutagawa', 'genre': 'literature'},
#         {'q': 'miazawa', 'genre': 'stories'}
#     ]
# }

# def get_headers():
#     return {
#         'User-Agent': 'LinguaflowApp/1.0 (Language Learning Research)'
#     }

# def clean_html_summary(summary):
#     if not summary: return ""
#     clean = re.sub(r'<[^>]+>', '', summary).strip()
#     return clean.replace('\n', ' ').replace('\r', '')

# def parse_librivox_rss(rss_url, book_meta):
#     """Parses RSS to get individual audio tracks."""
#     try:
#         response = requests.get(rss_url, headers=get_headers(), timeout=10)
#         if response.status_code != 200:
#             return []

#         root = ET.fromstring(response.content)
#         channel = root.find('channel')
        
#         # Try to get cover image
#         itunes_ns = {'itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd'}
#         cover_img = None
#         try:
#             image_tag = channel.find('itunes:image', itunes_ns)
#             if image_tag is not None:
#                 cover_img = image_tag.get('href')
#         except:
#             pass

#         lessons = []
#         items = channel.findall('item')
        
#         # Get up to 50 tracks per book (covers most reasonable audiobooks)
#         for i, item in enumerate(items[:50]): 
#             title = item.find('title').text
            
#             enclosure = item.find('enclosure')
#             if enclosure is None: continue
#             mp3_url = enclosure.get('url')
            
#             # Duration calculation
#             duration = 0
#             try:
#                 dur_node = item.find('itunes:duration', itunes_ns)
#                 if dur_node is not None:
#                     dur_str = dur_node.text
#                     parts = dur_str.split(':')
#                     if len(parts) == 3:
#                         duration = int(parts[0])*3600 + int(parts[1])*60 + int(float(parts[2]))
#                     elif len(parts) == 2:
#                         duration = int(parts[0])*60 + int(float(parts[1]))
#             except:
#                 pass

#             # Create a unique ID for this specific chapter
#             # ID format: lv_{book_id}_{chapter_index}
#             lesson = {
#                 "id": f"lv_{book_meta['id']}_{i}",
#                 "userId": "system_librivox",
#                 "title": title,
#                 "language": book_meta['language'],
#                 "content": clean_html_summary(book_meta.get('description', 'Audiobook chapter.')),
#                 "sentences": [], # Audio doesn't have sentences text mapped by default here
#                 "transcript": [],
#                 "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
#                 "imageUrl": cover_img if cover_img else "https://librivox.org/images/librivox-logo.png", 
#                 "type": "audio", 
#                 "videoUrl": mp3_url, # Frontend uses videoUrl prop for media source often
#                 "audioUrl": mp3_url,
#                 "duration": duration,
#                 "difficulty": "intermediate", # Librivox is usually authentic native content
#                 "genre": book_meta['genre'],
#                 "sourceUrl": book_meta['url_text_source'], 
#                 "isFavorite": False,
#                 "progress": 0
#             }
#             lessons.append(lesson)
            
#         return lessons

#     except Exception as e:
#         # print(f"    ⚠️ Error parsing RSS {rss_url}: {e}")
#         return []

# def search_librivox(query, genre, lang):
#     # API search
#     url = f"https://librivox.org/api/feed/audiobooks?format=json&title={query}&extended=1"
    
#     try:
#         res = requests.get(url, headers=get_headers(), timeout=15)
#         # Check if response is valid JSON
#         try:
#             data = res.json()
#         except:
#             return []
        
#         books = data.get('books', [])
#         if not books: return []

#         processed_lessons = []
        
#         for book in books:
#             # Language Filter
#             # LibriVox uses full English names for languages (e.g. "French", "Spanish")
#             lv_lang = book.get('language', '').lower()
            
#             # Simple mapping check
#             target_map = {
#                 'fr': 'french', 'es': 'spanish', 'de': 'german', 
#                 'it': 'italian', 'pt': 'portuguese', 'ja': 'japanese', 'en': 'english'
#             }
            
#             if target_map.get(lang) not in lv_lang:
#                 continue
            
#             print(f"    🎧 Found Book: {book['title'][:50]}...")
            
#             book_id = book['id']
#             rss_url = f"https://librivox.org/rss/{book_id}"
            
#             book_meta = {
#                 'id': book_id,
#                 'language': lang,
#                 'description': book.get('description'),
#                 'url_text_source': book.get('url_text_source'),
#                 'genre': genre
#             }
            
#             tracks = parse_librivox_rss(rss_url, book_meta)
#             processed_lessons.extend(tracks)
            
#             time.sleep(0.5) # Be gentle with their server

#         return processed_lessons

#     except Exception as e:
#         print(f"    ❌ API Error for '{query}': {e}")
#         return []

# def main():
#     if not os.path.exists(OUTPUT_DIR):
#         os.makedirs(OUTPUT_DIR)

#     for lang, queries in SEARCH_CONFIG.items():
#         print(f"\n==========================================")
#         print(f" PROCESSING AUDIO: {lang.upper()}")
#         print(f"==========================================")
        
#         filepath = os.path.join(OUTPUT_DIR, f"audio_{lang}.json")
        
#         # 1. LOAD EXISTING DATA (Handling Duplicates)
#         existing_lessons = []
#         existing_ids = set()
        
#         if os.path.exists(filepath):
#             try:
#                 with open(filepath, 'r', encoding='utf-8') as f:
#                     existing_lessons = json.load(f)
#                     # Create a set of IDs for fast lookup
#                     existing_ids = {l['id'] for l in existing_lessons}
#                 print(f"  📚 Loaded {len(existing_lessons)} existing tracks.")
#             except:
#                 print("  🆕 No valid existing file found. Starting fresh.")
#                 existing_lessons = []

#         # 2. SEARCH AND APPEND NEW CONTENT
#         new_tracks_count = 0
        
#         for item in queries:
#             print(f"  🔍 Searching: '{item['q']}'")
            
#             # Fetch candidates from API
#             candidates = search_librivox(item['q'], item['genre'], lang)
            
#             # Filter duplicates immediately
#             added_for_query = 0
#             for track in candidates:
#                 if track['id'] not in existing_ids:
#                     existing_lessons.append(track)
#                     existing_ids.add(track['id'])
#                     new_tracks_count += 1
#                     added_for_query += 1
            
#             if added_for_query > 0:
#                 print(f"     ✅ Added {added_for_query} new tracks.")
            
#             time.sleep(1)

#         # 3. SAVE FILE (Overwrite with the combined list)
#         try:
#             with open(filepath, 'w', encoding='utf-8') as f:
#                 json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
#             print(f"  💾 SAVED: Added {new_tracks_count} new tracks. Total Library: {len(existing_lessons)}")
#         except Exception as e:
#             print(f"  ❌ ERROR SAVING FILE: {e}")

# if __name__ == "__main__":
#     main()



import requests
import json
import os
import xml.etree.ElementTree as ET
import time
import re
import datetime
from urllib.parse import quote

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/audio_library"

# 1. FULL LANGUAGE LIST (Code -> Name)
LANGUAGES = {
    'fr': 'French', 'es': 'Spanish', 'pt': 'Portuguese', 'en': 'English',
    'it': 'Italian', 'de': 'German', 'ru': 'Russian', 'zh': 'Chinese',
    'ja': 'Japanese', 'ar': 'Arabic', 'tr': 'Turkish', 'sw': 'Swahili',
    'pl': 'Polish', 'nl': 'Dutch', 'sv': 'Swedish', 'hi': 'Hindi',
    # African Languages
    'ha': 'Hausa', 'yo': 'Yoruba', 'ig': 'Igbo', 'zu': 'Zulu', 
    'xh': 'Xhosa', 'st': 'Southern Sotho', 'lg': 'Luganda',
    'rw': 'Kinyarwanda', 'am': 'Amharic', 'so': 'Somali'
}

# 2. ISO MAP (For Tatoeba: 2-letter -> 3-letter)
ISO_MAP = {
    'fr': 'fra', 'es': 'spa', 'pt': 'por', 'en': 'eng', 'it': 'ita',
    'de': 'deu', 'ru': 'rus', 'zh': 'cmn', 'ja': 'jpn', 'ar': 'ara',
    'tr': 'tur', 'sw': 'swa', 'pl': 'pol', 'nl': 'nld', 'sv': 'swe',
    'hi': 'hin', 'ha': 'hau', 'yo': 'yor', 'ig': 'ibo', 'zu': 'zul',
    'xh': 'xho', 'st': 'sot', 'lg': 'lug', 'rw': 'kin', 'am': 'amh'
}

# 3. LIBRIVOX CONFIG
LIBRIVOX_QUERIES = {
    'fr': [{'q': 'Maupassant', 'g': 'stories'}, {'q': 'Verne', 'g': 'adventure'}],
    'es': [{'q': 'Quiroga', 'g': 'stories'}, {'q': 'Cervantes', 'g': 'classics'}],
    'pt': [{'q': 'Machado de Assis', 'g': 'literature'}, {'q': 'Pessoa', 'g': 'poetry'}],
    'de': [{'q': 'Grimm', 'g': 'fairy_tales'}, {'q': 'Kafka', 'g': 'literature'}],
    'it': [{'q': 'Collodi', 'g': 'fairy_tales'}, {'q': 'Pirandello', 'g': 'stories'}],
    'ru': [{'q': 'Chekhov', 'g': 'stories'}, {'q': 'Tolstoy', 'g': 'literature'}],
    'en': [{'q': 'Aesop', 'g': 'fables'}, {'q': 'Twain', 'g': 'adventure'}],
}

def get_headers():
    return {'User-Agent': 'LinguaflowApp/1.0 (Language Learning Research)'}

def get_current_time():
    return datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S.000Z')

# --- SOURCE 1: TATOEBA (Sentences) ---
def fetch_tatoeba(lang_code, limit=5):
    iso = ISO_MAP.get(lang_code, lang_code)
    url = f"https://tatoeba.org/en/api_v0/search?from=eng&to={iso}&has_audio=yes&sort=relevance&trans_filter=limit&trans_to=eng"
    
    try:
        res = requests.get(url, headers=get_headers(), timeout=10)
        if res.status_code != 200: return []
        
        results = res.json().get('results', [])
        items = []
        
        for item in results[:limit]:
            if not item.get('audios'): continue
            
            sent_id = item['id']
            text = item['text']
            # Get English translation
            trans = ""
            if item.get('translations'):
                trans = item['translations'][0][0]['text']
            
            # Construct Audio URL
            mp3 = f"https://tatoeba.org/audio/sentences/{iso}/{sent_id}.mp3"
            
            items.append({
                "id": f"tat_{lang_code}_{sent_id}",
                "userId": "system_tatoeba",
                "title": f"Sentence: {text[:20]}...",
                "language": lang_code,
                "content": f"{text}\n\n({trans})",
                "sentences": [text],
                "transcript": [],
                "createdAt": get_current_time(),
                "imageUrl": "assets/images/audio_placeholder.png", # Generic icon path
                "type": "audio",
                "videoUrl": mp3,
                "audioUrl": mp3,
                "duration": 5,
                "difficulty": "beginner",
                "genre": "sentences",
                "sourceUrl": f"https://tatoeba.org/en/sentences/show/{sent_id}",
                "isFavorite": False,
                "progress": 0
            })
        return items
    except: return []

# --- SOURCE 2: INTERNET ARCHIVE (Courses) ---
def fetch_archive_courses(lang_code, lang_name):
    query = f"title:({lang_name}) AND mediatype:audio AND (subject:course OR subject:language)"
    url = f"https://archive.org/advancedsearch.php?q={quote(query)}&fl[]=identifier,title&rows=2&output=json"
    
    items = []
    try:
        res = requests.get(url, timeout=10)
        docs = res.json().get('response', {}).get('docs', [])
        
        for doc in docs:
            pid = doc['identifier']
            title = doc.get('title', 'Audio Course')
            
            # Get file list
            meta_res = requests.get(f"https://archive.org/metadata/{pid}", timeout=10)
            files = meta_res.json().get('files', [])
            mp3s = [f for f in files if f['name'].endswith('.mp3')]
            
            # Take first 2 tracks
            for i, f in enumerate(mp3s[:2]):
                mp3_url = f"https://archive.org/download/{pid}/{f['name']}"
                track_name = f['name'].replace('.mp3', '').replace('_', ' ')
                
                items.append({
                    "id": f"ia_{lang_code}_{pid}_{i}",
                    "userId": "system_archive",
                    "title": f"{title} - {track_name}",
                    "language": lang_code,
                    "content": f"Audio course from Internet Archive: {title}",
                    "sentences": [],
                    "transcript": [],
                    "createdAt": get_current_time(),
                    "imageUrl": "assets/images/audio_placeholder.png",
                    "type": "audio",
                    "videoUrl": mp3_url,
                    "audioUrl": mp3_url,
                    "duration": 300,
                    "difficulty": "advanced",
                    "genre": "course",
                    "sourceUrl": f"https://archive.org/details/{pid}",
                    "isFavorite": False,
                    "progress": 0
                })
        return items
    except: return []

# --- SOURCE 3: LIBRIVOX (Literature) ---
def clean_html(raw_html):
    clean = re.sub(r'<[^>]+>', '', raw_html)
    return clean.strip()

def fetch_librivox(lang_code, lang_name):
    # Determine what to search for
    queries = LIBRIVOX_QUERIES.get(lang_code, [{'q': lang_name, 'g': 'stories'}])
    
    items = []
    for q_obj in queries:
        url = f"https://librivox.org/api/feed/audiobooks?format=json&title={q_obj['q']}&extended=1"
        try:
            res = requests.get(url, headers=get_headers(), timeout=15)
            books = res.json().get('books', [])
            
            for book in books:
                # Filter by language match
                if lang_name.lower() not in book.get('language', '').lower():
                    continue
                
                # Parse RSS for tracks
                rss_url = f"https://librivox.org/rss/{book['id']}"
                rss_res = requests.get(rss_url, headers=get_headers(), timeout=10)
                root = ET.fromstring(rss_res.content)
                
                # Get Cover
                cover = "assets/images/audio_placeholder.png" # Default
                # Try to find real cover in RSS if user wants later
                
                channel = root.find('channel')
                tracks = channel.findall('item')
                
                # Limit to 5 tracks per book to keep size down
                for i, track in enumerate(tracks[:5]):
                    enc = track.find('enclosure')
                    if enc is None: continue
                    
                    mp3_url = enc.get('url')
                    track_title = track.find('title').text
                    
                    items.append({
                        "id": f"lv_{book['id']}_{i}",
                        "userId": "system_librivox",
                        "title": track_title,
                        "language": lang_code,
                        "content": clean_html(book.get('description', '')),
                        "sentences": [],
                        "transcript": [],
                        "createdAt": get_current_time(),
                        "imageUrl": cover,
                        "type": "audio",
                        "videoUrl": mp3_url,
                        "audioUrl": mp3_url,
                        "duration": int(book.get('total_time_secs', 0) / len(tracks)),
                        "difficulty": "intermediate",
                        "genre": q_obj['g'],
                        "sourceUrl": book.get('url_librivox'),
                        "isFavorite": False,
                        "progress": 0
                    })
                
                if len(items) > 10: break # Stop after finding enough for this query
        except: pass
        
    return items

# --- MAIN EXECUTION ---
def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # Process specific languages or all
    for code, name in LANGUAGES.items():
        print(f"\n🎧 Processing: {name} ({code})")
        filepath = os.path.join(OUTPUT_DIR, f"audio_{code}.json")
        
        # 1. LOAD EXISTING DATA (Append Mode)
        existing_data = []
        existing_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_data = json.load(f)
                    existing_ids = {x['id'] for x in existing_data}
                print(f"    📂 Loaded {len(existing_data)} existing items.")
            except:
                print("    ⚠️ JSON error, starting fresh.")

        new_items = []

        # 2. RUN SCRAPERS
        # A. Tatoeba (Quick sentences)
        print("    🔍 Scanning Tatoeba...")
        new_items.extend(fetch_tatoeba(code, limit=5))
        
        # B. Archive.org (Courses)
        # print("    🔍 Scanning Archive.org...")
        # new_items.extend(fetch_archive_courses(code, name))
        
        # C. LibriVox (Books)
        print("    🔍 Scanning LibriVox...")
        new_items.extend(fetch_librivox(code, name))

        # 3. DEDUPLICATE & MERGE
        unique_new = []
        for item in new_items:
            if item['id'] not in existing_ids:
                unique_new.append(item)
                existing_ids.add(item['id'])
        
        if unique_new:
            final_list = existing_data + unique_new
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(final_list, f, ensure_ascii=False, indent=None)
            print(f"    💾 Appended {len(unique_new)} new tracks. Total: {len(final_list)}")
        else:
            print("    💤 No new unique content found.")

if __name__ == "__main__":
    main()