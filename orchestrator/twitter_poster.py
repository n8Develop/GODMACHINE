"""Twitter posting for GODMACHINE — posts patch notes after successful cycles."""

import os


def _get_client():
    """Create a Twitter API v2 client from environment variables.

    Required env vars:
        TWITTER_API_KEY
        TWITTER_API_SECRET
        TWITTER_ACCESS_TOKEN
        TWITTER_ACCESS_SECRET
    """
    try:
        import tweepy
    except ImportError:
        print("[Twitter] tweepy not installed — skipping.")
        return None

    api_key = os.environ.get("TWITTER_API_KEY")
    api_secret = os.environ.get("TWITTER_API_SECRET")
    access_token = os.environ.get("TWITTER_ACCESS_TOKEN")
    access_secret = os.environ.get("TWITTER_ACCESS_SECRET")

    if not all([api_key, api_secret, access_token, access_secret]):
        return None

    return tweepy.Client(
        consumer_key=api_key,
        consumer_secret=api_secret,
        access_token=access_token,
        access_token_secret=access_secret,
    )


def _get_api_v1():
    """Create a Twitter API v1.1 client for media upload."""
    try:
        import tweepy
    except ImportError:
        return None

    api_key = os.environ.get("TWITTER_API_KEY")
    api_secret = os.environ.get("TWITTER_API_SECRET")
    access_token = os.environ.get("TWITTER_ACCESS_TOKEN")
    access_secret = os.environ.get("TWITTER_ACCESS_SECRET")

    if not all([api_key, api_secret, access_token, access_secret]):
        return None

    auth = tweepy.OAuth1UserHandler(api_key, api_secret, access_token, access_secret)
    return tweepy.API(auth)


def post_tweet(text: str, media_path: str | None = None) -> dict | None:
    """Post a tweet with optional media attachment.

    Args:
        text: Tweet text (max 280 chars, will be truncated).
        media_path: Optional path to an image or video file.

    Returns:
        Dict with tweet id and text on success, None on failure.
    """
    client = _get_client()
    if not client:
        print("[Twitter] Not configured — set TWITTER_API_KEY, TWITTER_API_SECRET, "
              "TWITTER_ACCESS_TOKEN, TWITTER_ACCESS_SECRET env vars")
        return None

    # Truncate to 280 chars
    if len(text) > 280:
        text = text[:277] + "..."

    media_ids = None
    if media_path:
        api_v1 = _get_api_v1()
        if api_v1:
            try:
                media = api_v1.media_upload(filename=media_path)
                media_ids = [media.media_id]
            except Exception as e:
                print(f"[Twitter] Media upload failed: {e}")

    try:
        response = client.create_tweet(text=text, media_ids=media_ids)
        tweet_id = response.data["id"]
        print(f"[Twitter] Posted: {text[:60]}{'...' if len(text) > 60 else ''} (id: {tweet_id})")
        return {"id": tweet_id, "text": text}
    except Exception as e:
        print(f"[Twitter] Post failed: {e}")
        return None


def is_configured() -> bool:
    """Check if Twitter credentials are available."""
    return all([
        os.environ.get("TWITTER_API_KEY"),
        os.environ.get("TWITTER_API_SECRET"),
        os.environ.get("TWITTER_ACCESS_TOKEN"),
        os.environ.get("TWITTER_ACCESS_SECRET"),
    ])
