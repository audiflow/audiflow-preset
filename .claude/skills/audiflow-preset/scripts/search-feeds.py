#!/usr/bin/env python3
"""Search for podcast feeds by title using the iTunes Search API.

Usage:
    python search-feeds.py "podcast name" [--limit N] [--country CC]

Output (JSON):
    Array of results with feedUrl, trackId, title, author, artworkUrl, genre,
    episodeCount, and country.
    Results are sorted by relevance. feedUrl is the RSS feed URL needed for
    pattern creation.
"""

import argparse
import json
import sys
import urllib.request
import urllib.parse


def search_feeds(query: str, limit: int = 10, country: str = "jp") -> list[dict]:
    """Search iTunes for podcasts matching a query string."""
    params = urllib.parse.urlencode({
        "term": query,
        "media": "podcast",
        "entity": "podcast",
        "limit": limit,
        "country": country,
    })
    url = f"https://itunes.apple.com/search?{params}"

    req = urllib.request.Request(url, headers={"User-Agent": "audiflow-preset-skill/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    results = []
    for item in data.get("results", []):
        feed_url = item.get("feedUrl", "")
        if not feed_url:
            continue
        results.append({
            "title": item.get("collectionName", ""),
            "author": item.get("artistName", ""),
            "feedUrl": feed_url,
            "trackId": item.get("trackId"),
            "artworkUrl": item.get("artworkUrl600", item.get("artworkUrl100", "")),
            "genre": item.get("primaryGenreName", ""),
            "episodeCount": item.get("trackCount", 0),
            "country": item.get("country", ""),
        })
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description="Search for podcast feeds by title")
    parser.add_argument("query", help="Podcast name or keyword to search for")
    parser.add_argument("--limit", type=int, default=10, help="Max results (default: 10)")
    parser.add_argument("--country", default="jp", help="Country code (default: jp)")
    parser.add_argument("--compact", action="store_true", help="Compact JSON output")
    args = parser.parse_args()

    try:
        results = search_feeds(args.query, limit=args.limit, country=args.country)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)

    indent = None if args.compact else 2
    print(json.dumps(results, indent=indent, ensure_ascii=False))


if __name__ == "__main__":
    main()
