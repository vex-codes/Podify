Walkthrough - Apple Music Personal Downloader
This walkthrough details the architecture, code modules, and verification of the Apple Music Personal Downloader.

Changes Made
We have implemented a clean, production-grade local downloading pipeline consisting of the following core components in /Volumes/vex/VSCode/MP3s:

setup_env.sh
: Automates environment check. Verifies and installs system ffmpeg via Homebrew, creates the Python virtual environment (.venv), and installs requirements (customtkinter, yt-dlp, mutagen, requests, beautifulsoup4).
downloader.py
: The main execution engine:
Module A (Scraper): Requests Apple Music playlist page, parses metadata, extracts track info (title, artist, album) from #serialized-server-data (JSON) and fallback application/ld+json blocks. Resolves high-resolution square cover art.
Module B & C (Search & Download):
Search Candidate Rotation: Looks up the top 3 search candidates on YouTube to find the best match for the audio track.
Player Client Rotation: Rotates through standard yt-dlp client agents (default, ios, android, web) to bypass HTTP 403 Forbidden errors when downloading raw audio streams.
Module D (Audio Post-Processor): Transcodes raw formats to MP3 with EBU R128 volume leveling filter (-filter:a "loudnorm=... ") using FFmpeg.
Module E (Metadata Tagger): Downloads cover art, applies ID3 tags (TIT2, TPE1, TALB, APIC:Cover) via Mutagen.
Sync Mode: Checks if the target MP3 track already exists in the local directory (file size > 10KB). If so, it instantly skips the search, download, and processing steps, allowing rapid syncing of new songs added to large playlists.
Smart Destination Detection: Automatically detects if the chosen directory matches the playlist name. If it does (e.g. /Vibes), files are downloaded directly into that folder instead of nesting a new subfolder (e.g. /Vibes/vibes/), preventing duplicate directory layers during sync.
app.py
: Desktop GUI application written in CustomTkinter:
Y2K Retro Aesthetics: Overhauled to look like a premium cyber-deck or custom Winamp frame. Uses an Obsidian Jet Black background (#060709), Electric Cyan outline borders (#00FFFF), and a Matrix Radioactive Green LED LCD panel (#020304 / #39FF14). Font pairing relies on monospace Monaco typography.
Interactive HUD: Displays real-time settings configurations (e.g. [ MODE: SYNC-ONLY | VOL NORMALIZATION: ON | BITRATE: 320k ]) that react dynamically to slider/combobox user choices.
Threading & Callbacks: Pipeline operations run asynchronously inside background threads to prevent GUI freezing. Updates progress bar and streams stdout messages directly into the retro console logs.
Technical Flow Diagram
{}-UI
Mutagen Tagger
FFmpeg Process
yt-dlp API (Client Rotation)
Scraper (Requests + BS4)
Downloader Thread
CTk Y2K Cyber Deck
{}-UI
Mutagen Tagger
FFmpeg Process
yt-dlp API (Client Rotation)
Scraper (Requests + BS4)
Downloader Thread
CTk Y2K Cyber Deck
Exit Client Loop
Try next Client Agent
alt
[Successful download]
[HTTP 403 Forbidden]
loop
[Client Agent List (default, ios, android, web)]
alt
[Track exists locally & Sync Mode is ON]
[Track is missing / Sync Mode is OFF]
loop
[For each track]
User Toggles SYNC or Options -> Update HUD Info
Start Download (URL, Sync Mode, Quality, Leveling)
Fetch & Parse HTML
Track List JSON
Progress Skip Callback (Synced track skipped)
Update Progress / Status Label (Processing track)
Search (top 3) & Download Audio Stream
Raw Audio Stream File
Transcode + EBU R128 filter
Normalized MP3 Output
Fetch Artwork & Tag ID3v2
Fully Tagged MP3
Log: Saved 'Artist - Title.mp3'
Finished Processing / Reset Controls
Validation & Verification
1. Environment & Setup Verification
Running ./setup_env.sh successfully configured the dependencies:

Installed ffmpeg system binary via Brew.
Configured Python 3.13 .venv.
Installed python dependencies successfully.
2. Live Pipeline Integration Test
We ran test_pipeline_single.py which fetched the live Apple Music playlist R&B Now (103 tracks), extracted track metadata, matched it to YouTube, downloaded, transcoded to 320 kbps with volume leveling, and tagged with cover art:

bash
> Fetching playlist page...
Found serialized server data script block. Parsing...
Playlist Title: R&B Now
Found 103 tracks.
--- Testing Single Track: Body So Tea by Coco Jones ---
Searching YouTube: 'Coco Jones - Body So Tea (Official Audio)'
Match #1: Coco Jones – Body So Tea (Audio) ft. Chris Brown (ID: 92b23iSh9Z4)
  Attempting download with client: ['default', '-android_sdkless']
[download]   0.0% of    2.16MiB at  Unknown B/s ETA Unknown
[download] 100.0% of    2.16MiB at    4.68MiB/s ETA 00:00
Successfully downloaded stream using client ['default', '-android_sdkless']!
Raw audio stream downloaded: /var/folders/7c/qyq6rjhx3k10snvm4wpcn0p00000gn/T/92b23iSh9Z4.webm
Transcoding to MP3 at 320k (Volume Leveling: Enabled)...
Transcoded to MP3: ./Downloads/Test_Playlist/Coco Jones - Body So Tea.mp3
Writing ID3 metadata tags...
Successfully tagged MP3.
Verified output file path: ./Downloads/Test_Playlist/Coco Jones - Body So Tea.mp3
Output file size: 5179442 bytes
Cleaned up final output file.
Cleaned up raw stream file.
3. Sync Mode Verification Test
We ran test_sync.py which created a dummy Coco Jones - Body So Tea.mp3 in the output folder and executed the download in Sync Mode. The script logged:

bash
--- Starting Sync Test (Should skip first track and trigger cancel) ---
Starting pipeline for URL: https://music.apple.com/us/playlist/r-b-now/pl.b7ae3e0a28e84c5c96c4284b6a6c70af (Sync Mode: True)
Fetching playlist page...
Found serialized server data script block. Parsing...
Playlist Name: 'R&B Now'
Tracks Found: 103
Destination: '/var/folders/7c/qyq6rjhx3k10snvm4wpcn0p00000gn/T/tmp0aiaax3w/R&B Now'
--- Track 1 of 103 (Synced) ---
  'Coco Jones - Body So Tea.mp3' already exists locally. Skipping search and download.
Progress: 1/103 - Body So Tea
Download process cancelled by user.
Progress: 104/103 - None
=== Complete! Successfully processed 1 of 103 tracks ===
PASS: The track was skipped successfully in Sync Mode, and the test safely aborted.