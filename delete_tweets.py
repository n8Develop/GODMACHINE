"""Delete all tweets from @GODMACHINE_ON. Run and re-run until empty."""

import os, sys, time
sys.path.insert(0, ".")
from dotenv import load_dotenv
load_dotenv()

import tweepy

client = tweepy.Client(
    consumer_key=os.environ["TWITTER_API_KEY"],
    consumer_secret=os.environ["TWITTER_API_SECRET"],
    access_token=os.environ["TWITTER_ACCESS_TOKEN"],
    access_token_secret=os.environ["TWITTER_ACCESS_SECRET"],
)

me = client.get_me()
user_id = me.data.id
print(f"Deleting all tweets from @{me.data.username}...")
sys.stdout.flush()

total_deleted = 0
while True:
    tweets = client.get_users_tweets(user_id, max_results=100, user_auth=True)
    if not tweets.data:
        print("No more tweets found.")
        break

    print(f"Found {len(tweets.data)} tweets, deleting...")
    sys.stdout.flush()

    for tweet in tweets.data:
        try:
            client.delete_tweet(tweet.id)
            total_deleted += 1
            if total_deleted % 5 == 0:
                print(f"  Deleted {total_deleted}...")
                sys.stdout.flush()
            time.sleep(1.5)
        except tweepy.errors.TooManyRequests:
            print(f"  Rate limited at {total_deleted}. Waiting 15 min...")
            sys.stdout.flush()
            time.sleep(910)
        except Exception as e:
            print(f"  Error on {tweet.id}: {e}")
            sys.stdout.flush()
            time.sleep(2)

print(f"Done. Deleted {total_deleted} tweets total.")
