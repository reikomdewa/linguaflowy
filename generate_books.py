import requests
import json
import re
import os
import time

# --- CONFIGURATION ---
# Using the standard path from your previous scripts
OUTPUT_DIR = "assets/text_lessons" 

# 15,000 chars is roughly a 10-15 minute read. 
# This results in a file size of approx 15KB-30KB, well under the 1000KB (1MB) limit.
CHUNK_SIZE = 15000  

# EXPANDED CATALOG OF PROJECT GUTENBERG IDS
BOOKS_CATALOG = {
       'en': [
        14640, # McGuffey's Primer
        14668, # McGuffey's First Reader
        14642, # McGuffey's Second Reader
        14766, # McGuffey's Third Reader
        14880, # McGuffey's Fourth Reader
        25639, # Graded Memory Selections
    ],
    'es': [
        15353, # Cuentos de Hadas (Fairy tales are naturally simple)
        26558, # Niebla (Intermediate)
    ],
    
}

def get_headers():
    return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                      'LinguaflowApp/1.0 (Language Learning Research)'
    }

def get_object_size(obj):
    """Calculates byte size of a JSON object."""
    return len(json.dumps(obj).encode('utf-8'))

def extract_metadata(full_text):
    """Attempts to find Title and Author in the header."""
    title = "Unknown Title"
    author = "Unknown Author"
    
    header_lines = full_text[:3000].splitlines()
    for line in header_lines:
        line = line.strip()
        if line.startswith("Title:") and title == "Unknown Title":
            title = line.replace("Title:", "").strip()
        if line.startswith("Author:") and author == "Unknown Author":
            author = line.replace("Author:", "").strip()
            
    return title, author

def clean_gutenberg_text(text):
    """Robustly removes Gutenberg headers and footers."""
    start_match = re.search(r"\*\*\* ?START OF (THE|THIS) PROJECT GUTENBERG.*?\*\*\*", text, re.IGNORECASE)
    start_pos = start_match.end() if start_match else 0
    
    end_match = re.search(r"\*\*\* ?END OF (THE|THIS) PROJECT GUTENBERG.*?\*\*\*", text, re.IGNORECASE)
    end_pos = end_match.start() if end_match else len(text)
            
    clean = text[start_pos:end_pos].strip()
    
    if "Produced by" in clean[:500] or "Distributed Proofreading" in clean[:500]:
        parts = clean.split("\n\n", 1)
        if len(parts) > 1:
            clean = parts[1]
        
    return clean

def calculate_difficulty(text, lang):
    words = text.split()
    if not words: return "intermediate"
    avg_word_len = sum(len(w) for w in words) / len(words)
    
    if lang in ['de']: 
        if avg_word_len < 5.0: return "beginner"
        if avg_word_len > 6.5: return "advanced"
    else:
        if avg_word_len < 4.5: return "beginner"
        if avg_word_len > 5.8: return "advanced"
    return "intermediate"

def chunk_text(text, limit=CHUNK_SIZE):
    """Splits text into chunks strictly adhering to size limit."""
    paragraphs = text.split('\n\n')
    chunks = []
    current_chunk = ""
    
    for para in paragraphs:
        para = para.replace('\n', ' ').strip()
        if not para: continue

        # If a single paragraph is HUGE (rare), force split it
        if len(para) > limit:
            # If current chunk has content, save it first
            if current_chunk:
                chunks.append(current_chunk.strip())
                current_chunk = ""
            # Add the huge paragraph as its own chunk (or multiple)
            # This is a safety edge case
            chunks.append(para[:limit]) 
            continue

        if len(current_chunk) + len(para) < limit:
            current_chunk += para + "\n\n"
        else:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = para + "\n\n"
            
    if current_chunk:
        chunks.append(current_chunk.strip())
        
    return chunks

def process_book(book_id, lang):
    url = f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt"
    
    try:
        response = requests.get(url, headers=get_headers(), timeout=30)
        
        if response.status_code != 200:
            url = f"https://www.gutenberg.org/files/{book_id}/{book_id}-0.txt"
            response = requests.get(url, headers=get_headers(), timeout=30)
            
        if response.status_code != 200:
            print(f"    ❌ Failed to download ID {book_id}")
            return []
            
        response.encoding = response.apparent_encoding
        full_text = response.text
        
        # 1. Clean Text
        clean_content = clean_gutenberg_text(full_text)
        
        # 2. Extract Metadata
        title, author = extract_metadata(full_text)
        print(f"    📖 Processing: {title[:40]}... ({author})")
        
        difficulty = calculate_difficulty(clean_content[:5000], lang)
        
        # 3. Chunking (The key to avoiding large files)
        parts = chunk_text(clean_content)
        lessons = []
        
        for i, part in enumerate(parts):
            if len(part) < 500: continue # Skip very short snippets
            
            part_title = f"{title}"
            if len(parts) > 1:
                part_title += f" ({i+1}/{len(parts)})"
            
            # Sentence splitting for UI
            sentences_list = re.split(r'(?<=[.!?])\s+', part)
            sentences_list = [s.strip() for s in sentences_list if s.strip()]

            lesson = {
                "id": f"txt_{lang}_{book_id}_{i+1}",
                "userId": "system_gutenberg",
                "title": part_title,
                "language": lang,
                "content": part,
                "sentences": sentences_list,
                "transcript": [],
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": "assets/images/book_cover_placeholder.png", 
                "type": "text",
                "difficulty": difficulty,
                "videoUrl": None,
                "isFavorite": False,
                "progress": 0,
                "author": author,
                "genre": "classic"
            }

            # --- SAFETY CHECK ---
            # Ensure this specific lesson is not > 900KB
            size_bytes = get_object_size(lesson)
            if size_bytes > 900000:
                print(f"       ⚠️ SKIP Part {i+1}: Too large ({size_bytes} bytes).")
                continue

            lessons.append(lesson)
            
        print(f"       ✅ Generated {len(lessons)} chapters.")
        return lessons

    except Exception as e:
        print(f"    ⚠️ Exception processing {book_id}: {e}")
        return []

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, ids in BOOKS_CATALOG.items():
        print(f"\n==========================================")
        print(f" PROCESSING CLASSIC BOOKS: {lang.upper()}")
        print(f"==========================================")
        
        filepath = os.path.join(OUTPUT_DIR, f"books_{lang}.json")
        
        existing_lessons = []
        processed_book_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                for l in existing_lessons:
                    parts = l['id'].split('_')
                    if len(parts) >= 3:
                        processed_book_ids.add(int(parts[2]))
                print(f"  📚 Loaded library. Skipping {len(processed_book_ids)} books.")
            except:
                print("  🆕 No existing library found.")

        new_chapters_count = 0

        for book_id in ids:
            if book_id in processed_book_ids:
                continue
                
            book_lessons = process_book(book_id, lang)
            
            if book_lessons:
                existing_lessons.extend(book_lessons)
                processed_book_ids.add(book_id)
                new_chapters_count += len(book_lessons)
                
            time.sleep(1) 

        # Write to file
        with open(filepath, 'w', encoding='utf-8') as f:
            # separators=(',', ':') removes whitespace to save space
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None, separators=(',', ':'))
            
        print(f"  💾 SAVED: {new_chapters_count} new chapters added to {filepath}")

if __name__ == "__main__":
    main()