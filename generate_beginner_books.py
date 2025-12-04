import requests
import json
import re
import os
import time

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/beginner_books"
CHUNK_SIZE = 3000  # Smaller chunks for beginners (approx 400-500 words)

# Curated list of Beginner-Friendly Project Gutenberg IDs
# Focus: Fairy Tales, Fables, and "First Readers"
BEGINNER_CATALOG = {
    'fr': [
        30117, # ABC: Petits Contes (Jules Lemaître) - Very Easy
        17989, # La Belle et la Bête (Jeanne-Marie Leprince de Beaumont) - Classic
        14163, # Candide (Voltaire) - Short sentences, clear satire (A2/B1)
        24116, # Le Petit Chose (Alphonse Daudet) - Simple narrative
    ],
    'es': [
        36805, # Spanish Tales for Beginners (E.C. Hills) - Specifically for learners!
        33406, # Spanish Short Stories (Hills & Reinhardt) - Collection
        25330, # Cuentos de Hadas (Charles Perrault translations) - Fairy Tales
    ],
    'en': [
        21,    # Aesop's Fables - Perfect A1 (Very short stories)
        2591,  # Grimm's Fairy Tales - Classic simple stories
        17326, # Andersen's Fairy Tales
    ],
    'de': [
        35794, # Märchen und Erzählungen für Anfänger (H.A. Guerber) - "Stories for Beginners"
        2591,  # Kinder- und Hausmärchen (Grimm) - German originals
    ],
    'it': [
        24072, # First Italian Readings (Various) - Specifically for learners
        208,   # Le avventure di Pinocchio (Collodi) - The original simple classic
    ],
    'pt': [
        29040, # Contos e Lendas (Luís de Camões) - Short legends
        31602, # As Viagens de Gulliver (Translation) - Simple adventure
    ]
}

def get_headers():
    return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                      'LinguaflowApp/1.0 (Language Learning Research)'
    }

def extract_metadata(full_text):
    """Attempts to find Title and Author in the header."""
    title = "Unknown Title"
    author = "Unknown Author"
    
    # Read first 100 lines only to find metadata
    header_lines = full_text[:3000].splitlines()
    
    for line in header_lines:
        if line.startswith("Title:") and title == "Unknown Title":
            title = line.replace("Title:", "").strip()
        if line.startswith("Author:") and author == "Unknown Author":
            author = line.replace("Author:", "").strip()
            
    return title, author

def clean_gutenberg_text(text):
    """Robustly removes Gutenberg headers and footers."""
    start_patterns = [
        r"\*\*\* ?START OF (THE|THIS) PROJECT GUTENBERG EBOOK .* \*\*\*",
        r"\*\*\* ?START OF (THE|THIS) PROJECT GUTENBERG ETEXT .* \*\*\*",
        r"START OF THE PROJECT GUTENBERG EBOOK",
    ]
    end_patterns = [
        r"\*\*\* ?END OF (THE|THIS) PROJECT GUTENBERG EBOOK",
        r"\*\*\* ?END OF (THE|THIS) PROJECT GUTENBERG ETEXT",
        r"END OF THE PROJECT GUTENBERG EBOOK",
    ]

    start_pos = 0
    end_pos = len(text)

    # Find Start
    for pattern in start_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            start_pos = match.end()
            break
            
    # Find End
    for pattern in end_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            end_pos = match.start()
            break
            
    clean = text[start_pos:end_pos].strip()
    
    # Remove standard license blurb that sometimes appears after start
    if "Produced by" in clean[:500]:
        parts = clean.split("\n\n", 1)
        if len(parts) > 1:
            clean = parts[1]
        
    return clean

def chunk_text(text, limit=CHUNK_SIZE):
    """Splits text into smaller chunks (lessons)."""
    # Split by double newline to preserve paragraphs
    paragraphs = text.split('\n\n')
    chunks = []
    current_chunk = ""
    
    for para in paragraphs:
        # Clean up the paragraph (remove single newlines inside it)
        para = para.replace('\n', ' ').strip()
        if not para: continue

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
        response = requests.get(url, headers=get_headers(), timeout=15)
        if response.status_code != 200:
            print(f"    ❌ Error {response.status_code} downloading ID {book_id}")
            return []
            
        full_text = response.text
        title, author = extract_metadata(full_text)
        
        print(f"    📖 Processing: {title} ({author})")
        
        clean_content = clean_gutenberg_text(full_text)
        
        # Split into Parts (Lessons)
        parts = chunk_text(clean_content)
        lessons = []
        
        for i, part in enumerate(parts):
            if len(part) < 300: continue # Skip tiny chunks
            
            part_title = f"{title}"
            # Add part number if it's a long book split up
            if len(parts) > 1:
                part_title += f" (Part {i+1})"
                
            # Create Sentences List for Flutter
            # Regex splits by . ! ? but keeps the punctuation attached if possible
            sentences_list = re.split(r'(?<=[.!?])\s+', part)
            sentences_list = [s.strip() for s in sentences_list if s.strip()]

            lesson = {
                "id": f"beg_{lang}_{book_id}_{i+1}", # Unique ID for beginners
                "userId": "system_gutenberg_beginner",
                "title": part_title,
                "language": lang,
                "content": part,
                "sentences": sentences_list,
                "transcript": [],
                "createdAt": "2024-01-01T00:00:00.000Z",
                "imageUrl": None, 
                "type": "text",
                "difficulty": "beginner", # Hardcoded as beginner for this folder
                "videoUrl": None,
                "isFavorite": False,
                "progress": 0,
                "author": author
            }
            lessons.append(lesson)
            
        print(f"    ✅ Generated {len(lessons)} lessons.")
        return lessons

    except Exception as e:
        print(f"    ⚠️ Exception processing {book_id}: {e}")
        return []

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    for lang, ids in BEGINNER_CATALOG.items():
        print(f"\n==========================================")
        print(f" PROCESSING BEGINNER {lang.upper()}")
        print(f"==========================================")
        
        all_lang_lessons = []
        
        for book_id in ids:
            lessons = process_book(book_id, lang)
            all_lang_lessons.extend(lessons)
            time.sleep(1) # Be nice to Gutenberg servers
            
        # Save to beginner_fr.json, beginner_es.json, etc.
        filepath = os.path.join(OUTPUT_DIR, f"beginner_{lang}.json")
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(all_lang_lessons, f, ensure_ascii=False, indent=None)
            
        print(f"  💾 Saved {len(all_lang_lessons)} beginner stories to {filepath}")

if __name__ == "__main__":
    main()