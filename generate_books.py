import requests
import json
import re
import os
import time

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/text_lessons"
CHUNK_SIZE = 4500  # Characters per lesson (approx 10-15 min read)

# EXPANDED CATALOG OF PROJECT GUTENBERG IDS
BOOKS_CATALOG = {
    'fr': [
        24116, # Le Petit Chose (Daudet) - Simple narrative
        13526, # Contes de la Bécasse (Maupassant) - Short stories
        4650,  # Le Fantôme de l'Opéra (Leroux)
        17989, # La Belle et la Bête (Leprince de Beaumont)
        14163, # Candide (Voltaire)
        26557, # Le Tour du Monde en 80 Jours (Verne)
        20649, # Les Misérables (Hugo) - Advanced
        19202, # La Mare au Diable (Sand)
        1234,  # Madame Bovary (Flaubert)
        4666,  # Cyrano de Bergerac (Rostand)
        5711,  # Le Comte de Monte-Cristo (Dumas)
    ],
    'es': [
        2000,  # Don Quijote (Cervantes) - Advanced Classic
        15353, # Platero y yo (Jiménez) - Poetic/Beautiful
        34090, # Cuentos de amor (Pardo Bazán)
        26558, # Niebla (Unamuno)
        17029, # La Regenta (Alas)
        2938,  # La Celestina (Rojas)
        25330, # Cuentos de Hadas (Perrault)
        1619,  # La Vida es Sueño (Calderón)
    ],
    'en': [
        11,    # Alice's Adventures in Wonderland
        84,    # Frankenstein
        1342,  # Pride and Prejudice
        1952,  # The Yellow Wallpaper (Short/Inter)
        1524,  # Hamlet
        98,    # A Tale of Two Cities
        1661,  # Adventures of Sherlock Holmes
        1260,  # Jane Eyre
        2591,  # Grimm's Fairy Tales
        76,    # Adventures of Huckleberry Finn
    ],
    'de': [
        5220,  # Metamorphosis (Kafka)
        2591,  # Kinder- und Hausmärchen (Grimm)
        2197,  # Faust (Goethe)
        19323, # Siddhartha (Hesse)
        5323,  # Heidi (Spyri)
        2009,  # Also sprach Zarathustra (Nietzsche) - Very Advanced
        7849,  # Der Sandmann (Hoffmann)
    ],
    'it': [
        5000,  # Notebooks of Leonardo da Vinci
        8800,  # La Divina Commedia (Dante)
        208,   # Pinocchio (Collodi)
        10842, # Il piacere (D'Annunzio)
        22566, # Novelle rusticane (Verga)
        34218, # Cuore (De Amicis)
        24072, # First Italian Readings
    ],
    'pt': [
        55752, # Dom Casmurro (Machado de Assis)
        26233, # Os Maias (Eça de Queirós)
        23321, # Amor de Perdição (Castelo Branco)
        8284,  # Os Lusíadas (Camões)
        29040, # Contos e Lendas
        33056, # Memorias Posthumas de Braz Cubas
    ],
    'ja': [
        # Gutenberg is weak on Japanese.
        # This ID is "Tales of Old Japan" (English text with Japanese cultural context)
        # keeping for structure.
        48422
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
    
    # Read first 150 lines
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
    # Find Start
    start_match = re.search(r"\*\*\* ?START OF (THE|THIS) PROJECT GUTENBERG.*?\*\*\*", text, re.IGNORECASE)
    start_pos = start_match.end() if start_match else 0
    
    # Find End
    end_match = re.search(r"\*\*\* ?END OF (THE|THIS) PROJECT GUTENBERG.*?\*\*\*", text, re.IGNORECASE)
    end_pos = end_match.start() if end_match else len(text)
            
    clean = text[start_pos:end_pos].strip()
    
    # Remove license blurb that sometimes appears after start
    if "Produced by" in clean[:500] or "Distributed Proofreading" in clean[:500]:
        parts = clean.split("\n\n", 1)
        if len(parts) > 1:
            clean = parts[1]
        
    return clean

def calculate_difficulty(text, lang):
    """Heuristic to guess difficulty based on word length."""
    words = text.split()
    if not words: return "intermediate"
    
    avg_word_len = sum(len(w) for w in words) / len(words)
    
    if lang in ['de']: # German words are naturally longer
        if avg_word_len < 5.0: return "beginner"
        if avg_word_len > 6.5: return "advanced"
    else:
        if avg_word_len < 4.5: return "beginner"
        if avg_word_len > 5.8: return "advanced"
        
    return "intermediate"

def chunk_text(text, limit=CHUNK_SIZE):
    """Splits text into smaller chunks (lessons) preserving paragraphs."""
    # Split by double newline to preserve paragraph structure
    paragraphs = text.split('\n\n')
    chunks = []
    current_chunk = ""
    
    for para in paragraphs:
        # Clean inner newlines
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
        response = requests.get(url, headers=get_headers(), timeout=20)
        
        # Fallback for old file structure
        if response.status_code != 200:
            url = f"https://www.gutenberg.org/files/{book_id}/{book_id}-0.txt"
            response = requests.get(url, headers=get_headers(), timeout=20)
            
        if response.status_code != 200:
            print(f"    ❌ Failed to download ID {book_id}")
            return []
            
        response.encoding = response.apparent_encoding
        full_text = response.text
        
        title, author = extract_metadata(full_text)
        print(f"    📖 Processing: {title[:40]}... ({author})")
        
        clean_content = clean_gutenberg_text(full_text)
        difficulty = calculate_difficulty(clean_content[:5000], lang)
        
        # Split into Parts
        parts = chunk_text(clean_content)
        lessons = []
        
        for i, part in enumerate(parts):
            if len(part) < 500: continue # Skip tiny parts
            
            part_title = f"{title}"
            if len(parts) > 1:
                part_title += f" ({i+1}/{len(parts)})"
                
            # Create Sentence List for Frontend
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
        
        # 1. LOAD EXISTING DATA
        existing_lessons = []
        processed_book_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    
                # Extract Book IDs to avoid re-processing
                # ID Format: txt_fr_24116_1
                for l in existing_lessons:
                    parts = l['id'].split('_')
                    if len(parts) >= 3:
                        processed_book_ids.add(int(parts[2]))
                print(f"  📚 Loaded library. Skipping {len(processed_book_ids)} books.")
            except:
                print("  🆕 No existing library found.")

        new_chapters_count = 0

        # 2. PROCESS NEW BOOKS
        for book_id in ids:
            if book_id in processed_book_ids:
                continue
                
            book_lessons = process_book(book_id, lang)
            
            if book_lessons:
                existing_lessons.extend(book_lessons)
                processed_book_ids.add(book_id)
                new_chapters_count += len(book_lessons)
                
            time.sleep(1.5) # Be nice to Gutenberg

        # 3. SAVE
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
            
        print(f"  💾 SAVED: {new_chapters_count} new chapters added to {filepath}")

if __name__ == "__main__":
    main()