import json
import os
from youtubesearchpython import VideosSearch
from youtube_transcript_api import YouTubeTranscriptApi

# Define what to search for
LANGUAGES = {
    'es': 'Spanish comprehensible input subtitles',
    'fr': 'French comprehensible input subtitles',
    'de': 'German comprehensible input subtitles',
    'it': 'Italian comprehensible input subtitles',
    'pt': 'Portuguese comprehensible input subtitles',
    'ja': 'Japanese comprehensible input subtitles',
    'en': 'English learning stories'
}

MAX_FEED_SIZE = 50  # Keep the last 50 videos per language

def get_transcript_text(video_id, lang_code):
    try:
        transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)
        try:
            transcript = transcript_list.find_manually_created_transcript([lang_code])
        except:
            try:
                transcript = transcript_list.find_generated_transcript([lang_code])
            except:
                transcript = transcript_list.find_transcript(['en']).translate(lang_code)

        data = transcript.fetch()
        full_text = " ".join([i['text'] for i in data]).replace('\n', ' ')
        return full_text
    except Exception:
        return None

def analyze_difficulty(text):
    words = text.split()
    if not words: return 'intermediate'
    avg_len = sum(len(w) for w in words) / len(words)
    if avg_len < 4.5: return 'beginner'
    if avg_len > 6.0: return 'advanced'
    return 'intermediate'

def load_existing_feed(filename):
    if os.path.exists(filename):
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return []
    return []

def scrape_language(lang_code, query):
    print(f"--- Processing {lang_code} ---")
    
    # 1. Load existing feed (History)
    filename = f"data/lessons_{lang_code}.json"
    current_feed = load_existing_feed(filename)
    existing_ids = set(item['id'] for item in current_feed)
    
    # 2. Search for NEW videos
    # We fetch 15 candidates
    videos_search = VideosSearch(query, limit=15)
    results = videos_search.result()['result']
    
    new_videos = []
    
    for video in results:
        video_id = video['id']
        lesson_id = f"yt_{video_id}"
        
        # Skip if we already have this video
        if lesson_id in existing_ids:
            continue
            
        try:
            title = video['title']
            thumbnail = video['thumbnails'][0]['url'].split('?')[0]
            
            # Get Transcript
            content = get_transcript_text(video_id, lang_code)
            
            if content and len(content) > 50:
                print(f"  + New Video Found: {title}")
                new_videos.append({
                    "id": lesson_id,
                    "userId": "system",
                    "title": title,
                    "language": lang_code,
                    "content": content,
                    "sentences": [], # Flutter handles splitting
                    "createdAt": "2024-01-01T00:00:00.000Z", 
                    "imageUrl": thumbnail,
                    "type": "video",
                    "difficulty": analyze_difficulty(content),
                    "videoUrl": f"https://youtube.com/watch?v={video_id}",
                    "isFavorite": False
                })
        except Exception as e:
            print(f"  - Error processing {video_id}: {e}")
            continue

    # 3. Merge: New videos go to the TOP of the list
    updated_feed = new_videos + current_feed
    
    # 4. Limit Feed Size (Keep freshness)
    updated_feed = updated_feed[:MAX_FEED_SIZE]
    
    # 5. Save
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(updated_feed, f, ensure_ascii=False, indent=2)
    
    print(f"Saved {len(updated_feed)} videos (Added {len(new_videos)} new)")

def main():
    if not os.path.exists('data'):
        os.makedirs('data')

    for lang_code, query in LANGUAGES.items():
        scrape_language(lang_code, query)

if __name__ == "__main__":
    main()