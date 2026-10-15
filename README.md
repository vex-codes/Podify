# Podify (Podia)

Retro iPod Classic simulator & Apple Music downloader engine built for iOS (SwiftUI) and Python.

## Overview

- **Podia iOS App**: Retro iPod chassis interface with interactive Click Wheel, custom firmware themes, hardware haptics, and security checks.
- **Apple Music Downloader / Scraper**: Python & CustomTkinter Y2K cyber-deck desktop engine for scraping Apple Music playlists, YouTube audio stream matching (yt-dlp), EBU R128 volume normalization (FFmpeg), and ID3 metadata tagging (Mutagen).

## Features

- **iPod UI**: Authentic retro Click Wheel navigation, LCD display, and customizable themes.
- **Playlist Sync**: Download and update local audio files from Apple Music playlists skip-syncing duplicates.
- **Audio Processing**: High-bitrate MP3 transcoding, cover art tagging, and loudness leveling.

## Architecture

- **`Podia/`**: SwiftUI iOS App (Click Wheel, Firmware UI, Audio Player).
- **`SCRAPER.MD`**: Technical walkthrough & pipeline docs for Python downloader.
- **`add_bg_script.rb` / `sync_xcode.rb`**: Ruby build & asset automation helpers.
