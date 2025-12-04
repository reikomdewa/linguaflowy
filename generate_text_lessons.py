import requests
import json
import re
import os
import time

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/text_lessons"
CHUNK_SIZE = 4000  # Characters per lesson (approx 600-800 words)

# Curated list of Project Gutenberg IDs (Public Domain)
# You can find more IDs at https://www.gutenberg.org/
BOOKS_CATALOG = {
    'fr': [
        24116, # Le Petit Chose (Daudet) - Beginner/Inter
        13526, # Contes de la Bécasse (Maupassant) - Inter
        4650,  # Le Fantôme de l'Opéra - Advanced
        17989, # La Belle et la Bête - Beginner
        20649, # Les Misérables (Tome 1) - Advanced
        14163, # Candide (Voltaire) - Inter
        26557, # Le Tour du Monde en 80 Jours (Verne) - Inter
    ],
    'es': [
        2000,  # Don Quijote (Cervantes) - Advanced
        15353, # Platero y yo - Beginner/Inter
        34090, # Cuentos de amor (Pardo Bazán) - Inter
        26558, # Niebla (Unamuno) - Advanced
        17029, # La Regenta - Advanced
    ],
    'en': [
        11,    # Alice in Wonderland - Inter
        84,    # Frankenstein - Advanced
        1342,  # Pride and Prejudice - Advanced
        1952,  # The Yellow Wallpaper - Inter
        1524,  # Hamlet - Advanced
        98,    # A Tale of Two Cities - Advanced
    ],
    'de': [
        5220,  # Metamorphosis (Kafka) - Inter/Adv
        2591,  # Grimm's Fairy Tales - Beginner
        2197,  # Faust - Advanced
        19323, # Siddhartha - Inter
    ],
    'it': [
        5000,  # The Notebooks of Leonardo da Vinci - Advanced
        8500,  # La Divina Commedia (Dante) - Advanced
        208,   # Le avventure di Pinocchio - Beginner
        10842, # Il piacere (D'Annunzio) - Adv
    ],
    'pt': [
        55752, # Dom Casmurro (Machado de Assis) - Adv
        26233, # Os Maias (Eça de Queirós) - Adv
        23321, # Amor de Perdição - Inter
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
    
    # Read first 50 lines only
    header_lines = full_text[:2000].splitlines()
    
    for line in header_lines:
        if line.startswith("Title:") and title == "Unknown Title":
            title = line.replace("Title:", "").strip()
        if line.startswith("Author:") and author == "Unknown Author":
            author = line.replace("Author:", "").strip()
            
    return title, author

def clean_gutenberg_text(text):
    """Robustly removes Gutenberg headers and footers."""
    # Common regex patterns for start and end
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
    # Remove license blurb that sometimes appears after start
    if clean.startswith("Produced by"):
        clean = clean.split("\n\n", 1)[-1]
        
    return clean

def calculate_difficulty(text, lang):
    """Heuristic to guess difficulty based on word/sentence length."""
    words = text.split()
    if not words: return "intermediate"
    
    avg_word_len = sum(len(w) for w in words) / len(words)
    
    # Language specific adjustments could go here
    if lang in ['de']: # German words are naturally longer
        if avg_word_len < 5.0: return "beginner"
        if avg_word_len > 6.5: return "advanced"
    else:
        if avg_word_len < 4.5: return "beginner"
        if avg_word_len > 5.8: return "advanced"
        
    return "intermediate"

def chunk_text(text, limit=CHUNK_SIZE):
    """Splits text into smaller chunks (lessons) without breaking sentences."""
    sentences = re.split(r'(?<=[.!?])\s+', text)
    chunks = []
    current_chunk = ""
    
    for sentence in sentences:
        if len(current_chunk) + len(sentence) < limit:
            current_chunk += sentence + " "
        else:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = sentence + " "
            
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
        
        # Determine Difficulty globally for the book
        difficulty = calculate_difficulty(clean_content[:5000], lang)
        
        # Split into Parts (Lessons)
        parts = chunk_text(clean_content)
        lessons = []
        
        for i, part in enumerate(parts):
            # Don't create lessons for empty/tiny chunks
            if len(part) < 500: continue
            
            part_title = f"{title}"
            if len(parts) > 1:
                part_title += f" (Part {i+1})"
                
            # Create Sentences List for Flutter
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
                "createdAt": "2024-01-01T00:00:00.000Z",
                "imageUrl": None, 
                "type": "text",
                "difficulty": difficulty,
                "videoUrl": None,
                "isFavorite": False,
                "progress": 0,
                "author": author # Extra metadata if needed
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

    for lang, ids in BOOKS_CATALOG.items():
        print(f"\n==========================================")
        print(f" PROCESSING LANGUAGE: {lang.upper()}")
        print(f"==========================================")
        
        all_lang_lessons = []
        
        for book_id in ids:
            lessons = process_book(book_id, lang)
            all_lang_lessons.extend(lessons)
            time.sleep(1) # Rate limiting
            
        # Save to books_fr.json, books_es.json, etc.
        filepath = os.path.join(OUTPUT_DIR, f"books_{lang}.json")
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(all_lang_lessons, f, ensure_ascii=False, indent=None)
            
        print(f"  💾 Saved {len(all_lang_lessons)} total lessons to {filepath}")

if __name__ == "__main__":
    main()