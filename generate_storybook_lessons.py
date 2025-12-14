import os
import json
import re
import datetime

# --- CONFIGURATION ---

# 1. CHANGE THIS to the path where you downloaded the repo
# Example: If you ran 'git clone ...' it might be "asp-source" or "storybooks-core"
REPO_ROOT_PATH = "asp-source" 

# 2. Output folder for your Flutter assets
OUTPUT_DIR = "assets/storybooks_lessons"

# 3. Map your App's language codes to the Repo's folder names
# Check the repo folders. Sometimes they use 'fr' (2 letter) or 'fra' (3 letter).
# Format: 'your_app_code': 'repo_folder_name'
LANG_MAP = {
    'fr': 'fr',
    'es': 'es',
    'en': 'en',
    'de': 'de',
    'it': 'it',
    'pt': 'pt',
    # Add others if needed
}

# 4. Map Storybook Levels to your App's Difficulty
# Global Storybooks uses Levels 1 (easiest) to 5 (hardest)
LEVEL_MAP = {
    '1': 'beginner',
    '2': 'beginner',
    '3': 'intermediate',
    '4': 'intermediate',
    '5': 'advanced'
}

def parse_markdown(file_path):
    """
    Parses a Global Storybooks markdown file.
    They usually have a 'frontmatter' (header) with metadata.
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    metadata = {
        'title': 'Unknown',
        'level': '3', # Default
        'author': 'Global Storybooks'
    }
    
    content_lines = []
    is_frontmatter = False
    
    for line in lines:
        stripped = line.strip()
        
        # Detect Metadata Block (YAML style usually between ---)
        if stripped == '---':
            is_frontmatter = not is_frontmatter
            continue
            
        if is_frontmatter:
            # Extract metadata
            if stripped.startswith('title:'):
                metadata['title'] = stripped.replace('title:', '').strip()
            elif stripped.startswith('level:'):
                metadata['level'] = stripped.replace('level:', '').strip()
            elif stripped.startswith('author:'):
                metadata['author'] = stripped.replace('author:', '').strip()
        else:
            # This is actual story content
            # Skip empty lines or image links (![alt](url))
            if stripped and not stripped.startswith('!['):
                # Clean up bold/italic markdown
                clean_line = stripped.replace('*', '').replace('_', '').replace('#', '')
                content_lines.append(clean_line)

    full_content = "\n\n".join(content_lines)
    return metadata, full_content

def process_languages():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    total_books = 0

    for app_lang, repo_folder in LANG_MAP.items():
        # Construct path to the language folder
        # Note: In some repos, the path is 'content/fr' or just 'fr'. Check your folder structure!
        # Try finding the folder:
        possible_paths = [
            os.path.join(REPO_ROOT_PATH, repo_folder),
            os.path.join(REPO_ROOT_PATH, "content", repo_folder)
        ]
        
        lang_path = None
        for p in possible_paths:
            if os.path.exists(p):
                lang_path = p
                break
        
        if not lang_path:
            print(f"⚠️  Skipping '{app_lang}': Folder not found in {REPO_ROOT_PATH}")
            continue

        print(f"📂 Processing {app_lang.upper()} from {lang_path}...")
        
        lessons = []
        files = [f for f in os.listdir(lang_path) if f.endswith('.md')]

        for filename in files:
            file_path = os.path.join(lang_path, filename)
            
            try:
                meta, content = parse_markdown(file_path)
                
                # Skip if no content (sometimes just metadata files)
                if len(content) < 50: 
                    continue

                # Map Difficulty
                raw_level = meta.get('level', '3').replace('Level', '').strip()
                difficulty = LEVEL_MAP.get(raw_level, 'intermediate')

                # Create Sentences for UI
                sentences = re.split(r'(?<=[.!?])\s+', content)
                sentences = [s.strip() for s in sentences if s.strip()]

                lesson = {
                    "id": f"story_{app_lang}_{filename.replace('.md', '')}",
                    "userId": "system_storybooks", # Matches your filters
                    "title": meta['title'],
                    "language": app_lang,
                    "content": content,
                    "sentences": sentences,
                    "transcript": [],
                    "createdAt": datetime.datetime.now().isoformat(),
                    "imageUrl": "assets/images/story_placeholder.png", 
                    "type": "text",
                    "difficulty": difficulty,
                    "videoUrl": None,
                    "isFavorite": False,
                    "progress": 0,
                    "author": meta['author'],
                    "genre": "short_story"
                }
                
                lessons.append(lesson)

            except Exception as e:
                print(f"   Error parsing {filename}: {e}")

        # Save to JSON
        output_file = os.path.join(OUTPUT_DIR, f"storybooks_{app_lang}.json")
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(lessons, f, ensure_ascii=False, separators=(',', ':')) # Minified

        print(f"   ✅ Saved {len(lessons)} stories to {output_file}")
        total_books += len(lessons)

    print(f"\n🎉 DONE! Processed {total_books} stories total.")

if __name__ == "__main__":
    process_languages()