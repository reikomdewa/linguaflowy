import json
import os
import yt_dlp
from youtube_transcript_api import YouTubeTranscriptApi

# We removed "subtitles" from the query to get more results. 
# We will filter for captions later.
LANGUAGES = {
    'es': 'Spanish comprehensible input',
    'fr': 'French comprehensible input',
    'de': 'German comprehensible input',
    'it': 'Italian comprehensible input',
    'pt': 'Portuguese comprehensible input',
    'ja': 'Japanese comprehensible input',
    'en': 'English stories'
}

def get_best_transcript(video_id, target_lang):
    try:
        # Fetch all available transcripts
        transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)
        
        # 1. Try fetching the target language directly (Manual or Auto)
        try:
            transcript = transcript_list.find_transcript([target_lang])
        except:
            # 2. If target missing, fetch English and Auto-Translate
            try:
                transcript = transcript_list.find_transcript(['en', 'en-US']).translate(target_lang)
            except:
                # 3. Last resort: Take ANY available transcript and translate
                transcript = transcript_list[0].translate(target_lang)

        # Fetch data
        data = transcript.fetch()
        full_text = " ".join([i['text'] for i in data]).replace('\n', ' ')
        return full_text
        
    except Exception as e:
        print(f"    ! Transcript Error: {e}")
        return None

def analyze_difficulty(text):
    words = text.split()
    if not words: return 'intermediate'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.5: return 'beginner'
    if avg_len > 6.0: return 'advanced'
    return 'intermediate'

def search_and_scrape(lang_code, query):
    print(f"\n--- Searching: {query} ({lang_code}) ---")
    
    # Configure yt-dlp for fast searching (metadata only, no download)
    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        'dump_single_json': True,
    }

    lessons = []
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        # Search for 15 videos
        try:
            search_query = f"ytsearch15:{query}"
            result = ydl.extract_info(search_query, download=False)
            
            if 'entries' not in result:
                print("    ! No entries found.")
                return []

            for video in result['entries']:
                video_id = video.get('id')
                title = video.get('title')
                
                # yt-dlp doesn't always give thumbnails in flat mode, construct it manually
                thumbnail = f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"

                print(f"  > Checking: {title} ({video_id})")
                
                # Try to get text
                content = get_best_transcript(video_id, lang_code)
                
                if content and len(content) > 100:
                    print(f"    + SUCCESS: Got {len(content)} chars")
                    lessons.append({
                        "id": f"yt_{video_id}",
                        "userId": "system",
                        "title": title,
                        "language": lang_code,
                        "content": content,
                        "sentences": [], 
                        "createdAt": "2024-01-01T00:00:00.000Z",
                        "imageUrl": thumbnail,
                        "type": "video",
                        "difficulty": analyze_difficulty(content),
                        "videoUrl": f"https://youtube.com/watch?v={video_id}",
                        "isFavorite": False
                    })
                else:
                    print("    - Skipped: No readable text.")

                if len(lessons) >= 6: # Stop after 6 good videos
                    break
                    
        except Exception as e:
            print(f"Search failed: {e}")

    return lessons

def main():
    if not os.path.exists('data'):
        os.makedirs('data')

    for lang_code, query in LANGUAGES.items():
        lessons = search_and_scrape(lang_code, query)
        
        # Always create the file, even if empty (prevents 404 errors)
        filename = f"data/lessons_{lang_code}.json"
        
        # If we have previous data, we could merge it here, 
        # but for now let's just save what we found to ensure it works.
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(lessons, f, ensure_ascii=False, indent=2)
            
        print(f"Saved {len(lessons)} videos to {filename}")

if __name__ == "__main__":
    main()