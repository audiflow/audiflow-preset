#!/usr/bin/env python3
"""Analyze a podcast RSS feed and suggest grouping configurations.

Usage:
    python analyze-feed.py <feed_url> [--limit N] [--json]

Fetches the RSS feed, parses episode titles, and outputs:
  - Feed metadata (title, author, episode count, date range)
  - Title pattern analysis (brackets, numbering, recurring prefixes)
  - Suggested resolver type with reasoning
  - Suggested regex patterns for filters/extractors/groups

The suggestions are starting points -- always review against the actual
episode titles before writing playlist definitions.
"""

import argparse
import datetime
import hashlib
import json
import re
import sys
import urllib.request
from email.utils import parsedate_to_datetime
try:
    import defusedxml.ElementTree as ET
except ImportError as exc:
    raise SystemExit(
        "Missing required dependency 'defusedxml'. "
        "Install it with: python -m pip install defusedxml"
    ) from exc
from collections import Counter
from dataclasses import dataclass, field


@dataclass
class Episode:
    title: str
    description: str
    pub_date: str
    season: str
    episode_num: str
    guid: str


@dataclass
class FeedInfo:
    title: str
    author: str
    feed_url: str
    podcast_guid: str
    episode_count: int
    date_range: tuple[str, str]
    episodes: list[Episode] = field(default_factory=list)


@dataclass
class PatternMatch:
    pattern: str
    example_titles: list[str]
    count: int
    description: str


@dataclass
class Suggestion:
    resolver_type: str
    reasoning: str
    title_patterns: list[PatternMatch]
    has_season_numbers: bool
    has_bracket_format: bool
    suggested_filters: list[dict]
    suggested_groups: list[dict]
    group_stats: dict[str, int]


NS = {
    "itunes": "http://www.itunes.com/dtds/podcast-1.0.dtd",
    "podcast": "https://podcastindex.org/namespace/1.0",
    "atom": "http://www.w3.org/2005/Atom",
}


def fetch_feed(url: str) -> bytes:
    """Fetch RSS feed content from URL as raw bytes."""
    req = urllib.request.Request(url, headers={
        "User-Agent": "audiflow-playlist-skill/1.0",
        "Accept": "application/rss+xml, application/xml, text/xml",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def parse_feed(xml_content: bytes | str, feed_url: str) -> FeedInfo:
    """Parse RSS feed XML into structured feed info.

    Accepts bytes (preferred -- lets ElementTree honor the XML encoding
    declaration) or str.
    """
    root = ET.fromstring(xml_content)
    channel = root.find("channel")
    if channel is None:
        raise ValueError("No <channel> element found in RSS feed")

    title = (channel.findtext("title") or "").strip()
    author = (
        channel.findtext("itunes:author", namespaces=NS)
        or channel.findtext("managingEditor")
        or ""
    ).strip()

    # Extract podcast GUID from podcast:guid (Podcast Index namespace)
    podcast_guid = ""
    guid_elem = channel.find("podcast:guid", NS)
    if guid_elem is not None and guid_elem.text:
        podcast_guid = guid_elem.text.strip()

    episodes: list[Episode] = []
    for item in channel.findall("item"):
        ep_title = (item.findtext("title") or "").strip()
        ep_desc = (item.findtext("description") or "").strip()
        pub_date = (item.findtext("pubDate") or "").strip()
        season = (item.findtext("itunes:season", namespaces=NS) or "").strip()
        ep_num = (item.findtext("itunes:episode", namespaces=NS) or "").strip()
        guid = (item.findtext("guid") or "").strip()

        if ep_title:
            episodes.append(Episode(
                title=ep_title,
                description=ep_desc,
                pub_date=pub_date,
                season=season,
                episode_num=ep_num,
                guid=guid,
            ))

    # Parse dates and use min/max -- RSS feeds are not guaranteed ordered.
    # Normalize to UTC to avoid TypeError from mixing aware/naive datetimes.
    utc = datetime.timezone.utc
    parsed_dates: list[tuple[str, datetime.datetime]] = []
    for ep in episodes:
        if ep.pub_date:
            try:
                dt = parsedate_to_datetime(ep.pub_date)
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=utc)
                else:
                    dt = dt.astimezone(utc)
                parsed_dates.append((ep.pub_date, dt))
            except (ValueError, TypeError):
                pass
    if parsed_dates:
        oldest = min(parsed_dates, key=lambda pair: pair[1])[0]
        newest = max(parsed_dates, key=lambda pair: pair[1])[0]
        date_range = (oldest, newest)
    else:
        date_range = ("", "")

    return FeedInfo(
        title=title,
        author=author,
        feed_url=feed_url,
        podcast_guid=podcast_guid,
        episode_count=len(episodes),
        date_range=date_range,
        episodes=episodes,
    )


def detect_bracket_patterns(titles: list[str]) -> list[PatternMatch]:
    """Detect Japanese-style bracket patterns like title formats."""
    patterns_found: list[PatternMatch] = []

    # Full-width brackets
    bracket_re = re.compile(r"[\u3010\u3011\u300c\u300d\u300e\u300f\u3014\u3015\uff08\uff09\uff3b\uff3d]")
    bracket_titles = [t for t in titles if bracket_re.search(t)]
    if bracket_titles:
        # Detect specific bracket formats
        formats: dict[str, list[str]] = {}

        # Use the same bracket characters as the prefilter for classification
        open_brackets = r"\u3010\u300c\u300e\u3014\uff08\uff3b"
        close_brackets = r"\u3011\u300d\u300f\u3015\uff09\uff3d"

        for t in bracket_titles:
            # e.g. numbered brackets
            if re.search(rf"[{open_brackets}]\d+-\d+[{close_brackets}]", t):
                formats.setdefault("numbered_bracket", []).append(t)
            elif re.search(rf"[{open_brackets}]\d+\u6708\d+\u65e5[{close_brackets}]", t):
                formats.setdefault("date_bracket", []).append(t)
            elif re.search(rf"[{open_brackets}]", t):
                formats.setdefault("generic_bracket", []).append(t)

        for fmt, examples in formats.items():
            desc_map = {
                "numbered_bracket": "Numbered format like [season-episode]",
                "date_bracket": "Date format like [month/day]",
                "generic_bracket": "Bracketed title prefix/suffix",
            }
            patterns_found.append(PatternMatch(
                pattern=fmt,
                example_titles=examples[:3],
                count=len(examples),
                description=desc_map.get(fmt, fmt),
            ))

    return patterns_found


def detect_numbering(titles: list[str]) -> dict:
    """Detect season/episode numbering patterns in titles."""
    numbering_patterns = [
        (r"[Ss](\d+)\s*[Ee](\d+)", "SxxExx format"),
        (r"[Ss]eason\s+(\d+)", "Season N format"),
        (r"[Ee]p(?:isode)?\.?\s*(\d+)", "Episode N format"),
        (r"#(\d+)", "Hash numbering (#N)"),
        (r"\u7b2c(\d+)\u56de", "Japanese counter (N-kai)"),
        (r"\u7b2c(\d+)\u8a71", "Japanese counter (N-wa)"),
        (r"[\u3010\uff3b](\d+)-(\d+)[\u3011\uff3d]", "Bracket season-episode"),
        (r"[\u3010\uff3b](\d+)[\u3011\uff3d]", "Bracket number"),
        (r"Vol\.?\s*(\d+)", "Volume numbering"),
    ]

    results = {}
    for pattern, desc in numbering_patterns:
        matches = [(t, re.search(pattern, t, re.IGNORECASE)) for t in titles]
        matched = [(t, m) for t, m in matches if m]
        if matched:
            results[desc] = {
                "pattern": pattern,
                "count": len(matched),
                "percentage": round(100 * len(matched) / len(titles), 1),
                "examples": [t for t, _ in matched[:3]],
            }
    return results


def detect_recurring_prefixes(titles: list[str], min_count: int = 3) -> list[dict]:
    """Find recurring title prefixes that could become groups."""
    # Extract prefix before common delimiters
    prefix_counter: Counter[str] = Counter()
    prefix_examples: dict[str, list[str]] = {}

    delimiters = [" - ", " | ", ": ", " -- ", "\uff5c", "\u3011"]
    for t in titles:
        for delim in delimiters:
            idx = t.find(delim)
            if 0 < idx < 40:
                prefix = t[:idx].strip()
                # Remove bracket prefixes for cleaner grouping
                prefix = re.sub(r"^[\u3010\uff3b]", "", prefix).strip()
                if 2 < len(prefix):
                    prefix_counter[prefix] += 1
                    prefix_examples.setdefault(prefix, []).append(t)
                break

    results = []
    for prefix, count in prefix_counter.most_common(30):
        if min_count <= count:
            results.append({
                "prefix": prefix,
                "count": count,
                "percentage": round(100 * count / len(titles), 1),
                "examples": prefix_examples[prefix][:3],
            })
    return results


def detect_rss_seasons(episodes: list[Episode]) -> dict:
    """Check for RSS season/episode metadata coverage."""
    has_season = sum(1 for ep in episodes if ep.season)
    has_episode = sum(1 for ep in episodes if ep.episode_num)
    total = len(episodes)

    seasons_set = {ep.season for ep in episodes if ep.season}

    return {
        "season_coverage": round(100 * has_season / total, 1) if 0 < total else 0,
        "episode_coverage": round(100 * has_episode / total, 1) if 0 < total else 0,
        "distinct_seasons": sorted(
            seasons_set,
            key=lambda s: (0, int(s)) if s.isdigit() else (1, s),
        ),
        "season_count": len(seasons_set),
    }


def suggest_resolver(
    titles: list[str],
    numbering: dict,
    rss_seasons: dict,
    prefixes: list[dict],
) -> Suggestion:
    """Analyze patterns and suggest the best resolver type."""
    has_season_numbers = (
        40 < rss_seasons["season_coverage"]
        or "Bracket season-episode" in numbering
        or "SxxExx format" in numbering
    )

    bracket_patterns = detect_bracket_patterns(titles)
    has_bracket_format = 0 < len(bracket_patterns)

    # Decision logic
    reasoning_parts = []
    suggested_resolver = "titleClassifier"  # default fallback

    if has_season_numbers and 3 < rss_seasons["season_count"]:
        suggested_resolver = "seasonNumber"
        reasoning_parts.append(
            f"Feed has {rss_seasons['season_count']} distinct seasons "
            f"with {rss_seasons['season_coverage']}% RSS coverage"
        )
    elif has_season_numbers:
        for key in ("Bracket season-episode", "SxxExx format"):
            if key in numbering:
                suggested_resolver = "seasonNumber"
                info = numbering[key]
                reasoning_parts.append(
                    f"Title numbering pattern '{key}' found in {info['percentage']}% of episodes"
                )
                break

    if suggested_resolver != "seasonNumber":
        # Check for recurring prefixes that suggest titleClassifier
        if prefixes and 3 <= len(prefixes):
            coverage = sum(p["count"] for p in prefixes)
            pct = round(100 * coverage / len(titles), 1)
            if 50 < pct:
                suggested_resolver = "titleClassifier"
                reasoning_parts.append(
                    f"{len(prefixes)} recurring prefixes cover {pct}% of episodes"
                )
            else:
                suggested_resolver = "titleDiscovery"
                reasoning_parts.append(
                    f"Some recurring prefixes found ({pct}% coverage) but not dominant -- "
                    "titleDiscovery may auto-detect patterns"
                )
        elif 200 < len(titles):
            suggested_resolver = "year"
            reasoning_parts.append(
                "Long-running podcast with no clear title patterns -- year grouping fits"
            )

    if not reasoning_parts:
        reasoning_parts.append("No strong patterns detected; titleClassifier with manual groups recommended")

    # Build suggested groups for titleClassifier (schema-compatible GroupDef shape)
    suggested_groups: list[dict] = []
    group_stats: dict[str, int] = {}
    used_group_ids: set[str] = {"other"}  # reserve catch-all ID
    if prefixes:
        included_prefixes = prefixes[:10]
        for p in included_prefixes:
            escaped = re.escape(p["prefix"])
            raw_id = re.sub(r"[^a-z0-9_]", "_", p["prefix"].lower())[:30]
            # Strip leading/trailing underscores and collapse runs
            raw_id = re.sub(r"_+", "_", raw_id).strip("_")
            # Fallback for non-Latin prefixes that collapse to empty
            if not raw_id:
                raw_id = f"group_{hashlib.md5(p['prefix'].encode('utf-8')).hexdigest()[:6]}"
            # Deduplicate IDs
            candidate = raw_id
            seq = 2
            while candidate in used_group_ids:
                candidate = f"{raw_id}_{seq}"
                seq += 1
            used_group_ids.add(candidate)
            suggested_groups.append({
                "id": candidate,
                "displayName": p["prefix"],
                "pattern": f"^{escaped}",
            })
            group_stats[candidate] = p["count"]
        # Catch-all group omits "pattern" entirely (schema does not allow null).
        # Only subtract included prefixes (not all) to avoid undercounting.
        included_total = sum(p["count"] for p in included_prefixes)
        suggested_groups.append({
            "id": "other",
            "displayName": "Other",
        })
        group_stats["other"] = len(titles) - included_total

    # Build suggested filters using the playlist schema's episodeFilters shape
    suggested_filters: list[dict] = []
    if bracket_patterns:
        for bp in bracket_patterns:
            if bp.pattern == "numbered_bracket":
                suggested_filters.append({
                    "require": [
                        {"title": r"[\u3010\uff3b]\d+-\d+[\u3011\uff3d]"},
                    ],
                    "exclude": [],
                })

    return Suggestion(
        resolver_type=suggested_resolver,
        reasoning="; ".join(reasoning_parts),
        title_patterns=bracket_patterns,
        has_season_numbers=has_season_numbers,
        has_bracket_format=has_bracket_format,
        suggested_filters=suggested_filters,
        suggested_groups=suggested_groups,
        group_stats=group_stats,
    )


def compute_pattern_id(podcast_guid: str, feed_url: str) -> str:
    """Derive the 12-char hex pattern ID."""
    source = podcast_guid if podcast_guid else feed_url
    return hashlib.md5(source.encode("utf-8")).hexdigest()[:12]


def format_report(feed: FeedInfo, suggestion: Suggestion, pattern_id: str) -> dict:
    """Build the full analysis report as a dict."""
    titles = [ep.title for ep in feed.episodes]
    numbering = detect_numbering(titles)
    rss_seasons = detect_rss_seasons(feed.episodes)

    return {
        "feed": {
            "title": feed.title,
            "author": feed.author,
            "feedUrl": feed.feed_url,
            "podcastGuid": feed.podcast_guid,
            "episodeCount": feed.episode_count,
            "dateRange": {"oldest": feed.date_range[0], "newest": feed.date_range[1]},
        },
        "patternId": pattern_id,
        "analysis": {
            "rssSeasonsMetadata": rss_seasons,
            "titleNumbering": numbering,
            "bracketPatterns": [
                {
                    "type": bp.pattern,
                    "description": bp.description,
                    "count": bp.count,
                    "examples": bp.example_titles,
                }
                for bp in suggestion.title_patterns
            ],
            "recurringPrefixes": detect_recurring_prefixes(titles),
        },
        "suggestion": {
            "resolverType": suggestion.resolver_type,
            "reasoning": suggestion.reasoning,
            "suggestedGroups": suggestion.suggested_groups,
            "groupStats": suggestion.group_stats,
            "suggestedFilters": suggestion.suggested_filters,
        },
        "sampleTitles": titles[:50],
    }


def format_text_report(report: dict) -> str:
    """Format the report as human-readable text."""
    lines = []
    feed = report["feed"]
    lines.append(f"# Feed Analysis: {feed['title']}")
    lines.append(f"Author: {feed['author']}")
    lines.append(f"Feed URL: {feed['feedUrl']}")
    if feed["podcastGuid"]:
        lines.append(f"Podcast GUID: {feed['podcastGuid']}")
    lines.append(f"Episodes: {feed['episodeCount']}")
    lines.append(f"Date range: {feed['dateRange']['oldest']} to {feed['dateRange']['newest']}")
    lines.append(f"Pattern ID: {report['patternId']}")
    lines.append("")

    analysis = report["analysis"]
    lines.append("## RSS Season/Episode Metadata")
    rss = analysis["rssSeasonsMetadata"]
    lines.append(f"  Season tag coverage: {rss['season_coverage']}%")
    lines.append(f"  Episode tag coverage: {rss['episode_coverage']}%")
    if rss["distinct_seasons"]:
        lines.append(f"  Distinct seasons: {', '.join(rss['distinct_seasons'])}")
    lines.append("")

    if analysis["titleNumbering"]:
        lines.append("## Title Numbering Patterns")
        for desc, info in analysis["titleNumbering"].items():
            lines.append(f"  {desc}: {info['count']} episodes ({info['percentage']}%)")
            lines.append(f"    regex: {info['pattern']}")
            for ex in info["examples"]:
                lines.append(f"    e.g.: {ex}")
        lines.append("")

    if analysis["bracketPatterns"]:
        lines.append("## Bracket Patterns")
        for bp in analysis["bracketPatterns"]:
            lines.append(f"  {bp['description']}: {bp['count']} episodes")
            for ex in bp["examples"]:
                lines.append(f"    e.g.: {ex}")
        lines.append("")

    if analysis["recurringPrefixes"]:
        lines.append("## Recurring Title Prefixes")
        for p in analysis["recurringPrefixes"][:15]:
            lines.append(f"  \"{p['prefix']}\" -- {p['count']} episodes ({p['percentage']}%)")
            for ex in p["examples"][:2]:
                lines.append(f"    e.g.: {ex}")
        lines.append("")

    suggestion = report["suggestion"]
    lines.append("## Suggestion")
    lines.append(f"  Resolver type: {suggestion['resolverType']}")
    lines.append(f"  Reasoning: {suggestion['reasoning']}")
    if suggestion["suggestedGroups"]:
        lines.append("  Suggested groups:")
        stats = suggestion.get("groupStats", {})
        for g in suggestion["suggestedGroups"]:
            pattern_str = g.get("pattern") or "(catch-all)"
            count = stats.get(g["id"], 0)
            lines.append(f"    - {g['displayName']} [{pattern_str}] ({count} episodes)")
    lines.append("")

    lines.append("## Sample Titles (first 50)")
    for i, t in enumerate(report["sampleTitles"]):
        lines.append(f"  {i + 1}. {t}")

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Analyze a podcast RSS feed")
    parser.add_argument("feed_url", help="RSS feed URL to analyze")
    parser.add_argument("--limit", type=int, default=0, help="Limit episodes to analyze (0=all)")
    parser.add_argument("--json", action="store_true", help="Output as JSON instead of text")
    args = parser.parse_args()

    try:
        xml_content = fetch_feed(args.feed_url)
        feed = parse_feed(xml_content, args.feed_url)

        if 0 < args.limit:
            feed.episodes = feed.episodes[:args.limit]
            feed.episode_count = len(feed.episodes)

        titles = [ep.title for ep in feed.episodes]
        numbering = detect_numbering(titles)
        rss_seasons = detect_rss_seasons(feed.episodes)
        prefixes = detect_recurring_prefixes(titles)

        suggestion = suggest_resolver(titles, numbering, rss_seasons, prefixes)
        pattern_id = compute_pattern_id(feed.podcast_guid, feed.feed_url)
        report = format_report(feed, suggestion, pattern_id)

        if args.json:
            print(json.dumps(report, indent=2, ensure_ascii=False))
        else:
            print(format_text_report(report))

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
