from firebase_functions import https_fn
from youtube_transcript_api import YouTubeTranscriptApi, TranscriptsDisabled, NoTranscriptFound

@https_fn.on_call()
def get_transcript(req: https_fn.CallableRequest) -> any:
    """
    Fetches the transcript for a given YouTube Video ID.
    Expects 'videoId' and 'lang' in the data.
    """
    video_id = req.data.get("videoId")
    lang = req.data.get("lang", "en")

    if not video_id:
        return {"success": False, "error": "Missing videoId"}

    try:
        # 1. Fetch available transcripts
        transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)

        # 2. Try to find the requested language
        # First try manually created, then auto-generated
        try:
            transcript = transcript_list.find_manually_created_transcript([lang])
        except:
            try:
                transcript = transcript_list.find_generated_transcript([lang])
            except:
                # 3. Fallback: Get English and auto-translate (Powerful feature!)
                # This ensures we almost ALWAYS return content.
                en_transcript = transcript_list.find_transcript(['en'])
                transcript = en_transcript.translate(lang)

        # 4. Fetch the actual text data
        data = transcript.fetch()

        # 5. Join into a single string
        full_text = " ".join([item['text'] for item in data])
        
        # Basic cleaning
        full_text = full_text.replace('\n', ' ')

        return {
            "success": True,
            "content": full_text
        }

    except (TranscriptsDisabled, NoTranscriptFound):
        return {
            "success": False, 
            "error": "No subtitles available for this video."
        }
    except Exception as e:
        return {
            "success": False, 
            "error": str(e)
        }