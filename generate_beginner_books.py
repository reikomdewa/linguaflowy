import requests
import json
import re
import os
import time

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/beginner_books"
CHUNK_SIZE = 2500  # Characters per lesson (approx 1 page of text)

# EXPANDED CATALOG OF LEARNER-FRIENDLY PUBLIC DOMAIN BOOKS
# Selected for simpler vocabulary, direct narratives, or cultural importance.
BEGINNER_CATALOG = {
    'fr': [
        30117, # ABC: Petits Contes (Jules Lemaître) - Very Easy
        17989, # La Belle et la Bête (Leprince de Beaumont) - Classic
        14163, # Candide (Voltaire) - Short sentences, clear satire
        24116, # Le Petit Chose (Alphonse Daudet)
        4650,  # Poil de Carotte (Jules Renard) - Childhood stories
        13953, # Contes Français (Hills) - Specifically for learners
        5097,  # Trois Contes (Flaubert)
        2650,  # Contes de la Bécasse (Maupassant)
        19202, # La Mare au Diable (George Sand) - Rustic/Simple
        1567,  # Fables de La Fontaine (Poetry/Classic)
    ],
    'es': [
        36805, # Spanish Tales for Beginners (E.C. Hills)
        33406, # Spanish Short Stories (Hills & Reinhardt)
        25330, # Cuentos de Hadas (Perrault translations)
        2828,  # Doña Perfecta (Galdós) - Standard easy novel
        17013, # Cuentos de amor de locura y de muerte (Quiroga) - The "Poe" of Latin America
        47287, # Platero y yo (Juan Ramón Jiménez) - Beautiful simple prose
        15353, # Fortunata y Jacinta (Galdós) - Advanced but classic
        4300,  # Ulysses (Joyce) - JUST KIDDING. Removed.
        11529, # Marianela (Galdós)
        1619,  # La Vida es Sueño (Calderón) - Play format
    ],
    'en': [
        21,    # Aesop's Fables - Very Short
        2591,  # Grimm's Fairy Tales
        11,    # Alice's Adventures in Wonderland
        16,    # Peter Pan
        1661,  # Adventures of Sherlock Holmes
        74,    # The Adventures of Tom Sawyer
        2701,  # Moby Dick (Just kidding, too hard) -> Replaced with:
        35,    # The Time Machine (Wells)
        236,   # The Jungle Book (Kipling)
        120,   # Treasure Island
    ],
    'de': [
        35794, # Märchen und Erzählungen für Anfänger (Guerber)
        2591,  # Kinder- und Hausmärchen (Grimm)
        5323,  # Heidi (Johanna Spyri) - Perfect for beginners
        22367, # Die Verwandlung (Kafka) - Metamorphosis (Simple grammar, weird story)
        2001,  # Faust (Goethe) - Hard but essential
        19022, # Siddhartha (Hesse) - Clear, spiritual language
        7849,  # Der Sandmann (Hoffmann)
    ],
    'it': [
        24072, # First Italian Readings
        208,   # Le avventure di Pinocchio (Collodi) - The original
        1012,  # La Divina Commedia (Dante) - Advanced poetry
        22566, # Novelle rusticane (Verga)
        34218, # Cuore (De Amicis) - Children's diary, very famous
        46337, # Il piacere (D'Annunzio)
    ],
    'pt': [
        29040, # Contos e Lendas
        31602, # As Viagens de Gulliver
        8284,  # Os Lusíadas (Camões) - Advanced Poetry
        54829, # O Ateneu (Raul Pompeia)
        17454, # Amor de Perdição (Castelo Branco)
        33056, # Memorias Posthumas de Braz Cubas (Machado de Assis)
    ],
    'ja': [
        # Gutenberg has very few Japanese texts (Aozora Bunko is better, but harder to scrape).
        # We will use the few available or skip.
        48422, # Tales of Old Japan (English with Japanese context) - keeping for reference
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
    header_lines = full_text[:4000].splitlines()
    
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

def chunk_text(text, limit=CHUNK_SIZE):
    """Splits text into smaller chunks (lessons) preserving paragraphs."""
    # Split by double newline to preserve paragraphs
    paragraphs = text.split('\n\n')
    chunks = []
    current_chunk = ""
    
    for para in paragraphs:
        # Clean up inner newlines within a paragraph
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
    # Gutenberg cache URL is usually reliable
    url = f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt"
    
    try:
        response = requests.get(url, headers=get_headers(), timeout=20)
        
        # Handle redirects or errors
        if response.status_code != 200:
            # Fallback for some IDs that use different naming conventions
            url_fallback = f"https://www.gutenberg.org/files/{book_id}/{book_id}-0.txt"
            response = requests.get(url_fallback, headers=get_headers(), timeout=20)
            
        if response.status_code != 200:
            print(f"    ❌ Failed to download ID {book_id}")
            return []
            
        # Ensure correct encoding (Gutenberg usually UTF-8, but sometimes ISO-8859-1)
        response.encoding = response.apparent_encoding
        full_text = response.text
        
        title, author = extract_metadata(full_text)
        print(f"    📖 Processing: {title[:40]}... ({author})")
        
        clean_content = clean_gutenberg_text(full_text)
        
        # Split into Parts
        parts = chunk_text(clean_content)
        lessons = []
        
        for i, part in enumerate(parts):
            if len(part) < 200: continue # Skip tiny garbage chunks
            
            part_title = f"{title}"
            if len(parts) > 1:
                part_title += f" ({i+1}/{len(parts)})"

            # Create simple sentence split for Frontend
            sentences_list = re.split(r'(?<=[.!?])\s+', part)
            sentences_list = [s.strip() for s in sentences_list if s.strip()]

            lesson = {
                "id": f"beg_{lang}_{book_id}_{i+1}", # Unique ID
                "userId": "system_gutenberg",
                "title": part_title,
                "language": lang,
                "content": part,
                "sentences": sentences_list,
                "transcript": [],
                "createdAt": time.strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                "imageUrl": "assets/images/book_cover_placeholder.png", # Placeholder
                "type": "text",
                "difficulty": "beginner",
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

    for lang, ids in BEGINNER_CATALOG.items():
        print(f"\n==========================================")
        print(f" PROCESSING BEGINNER BOOKS: {lang.upper()}")
        print(f"==========================================")
        
        filepath = os.path.join(OUTPUT_DIR, f"beginner_{lang}.json")
        
        # 1. LOAD EXISTING DATA
        existing_lessons = []
        processed_book_ids = set()
        
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_lessons = json.load(f)
                    
                # Extract Book IDs from lesson IDs to avoid re-downloading
                # ID Format: beg_fr_30117_1 -> We want '30117'
                for l in existing_lessons:
                    parts = l['id'].split('_')
                    if len(parts) >= 3:
                        processed_book_ids.add(int(parts[2]))
                        
                print(f"  📚 Loaded library. Skipping {len(processed_book_ids)} already processed books.")
            except:
                print("  🆕 No existing library found.")

        # 2. DOWNLOAD NEW BOOKS
        new_lessons_count = 0
        
        for book_id in ids:
            # CHECK FOR DUPLICATE BOOK
            if book_id in processed_book_ids:
                continue
                
            book_lessons = process_book(book_id, lang)
            
            if book_lessons:
                existing_lessons.extend(book_lessons)
                processed_book_ids.add(book_id)
                new_lessons_count += len(book_lessons)
            
            time.sleep(1.5) # Be nice to Gutenberg

        # 3. SAVE
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(existing_lessons, f, ensure_ascii=False, indent=None)
            
        print(f"  💾 SAVED: {new_lessons_count} new chapters added to {filepath}")

if __name__ == "__main__":
    main()