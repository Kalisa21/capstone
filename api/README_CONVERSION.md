# Python to Dart Conversion

## Quick Start

1. **Run the conversion:**
   ```bash
   cd api
   venv\Scripts\activate  # Windows
   python convert_to_dart.py
   ```

2. **Output files will be created in:**
   ```
   lib/assets/legal_data/
   ```

3. **Files created:**
   - `articles.json` - All article data
   - `embeddings.npy` - Pre-computed embeddings
   - `embeddings_meta.json` - Embedding metadata
   - `legal_data.db` - SQLite database
   - `index_meta.json` - FAISS index metadata

4. **Add to Flutter:**
   - Files are automatically added to `pubspec.yaml`
   - Run `flutter pub get`
   - Rebuild APK

## What This Does

- Extracts all articles from `.pkl` file
- Extracts pre-computed embeddings
- Converts to Dart-readable formats (JSON, SQLite)
- Preserves all data for semantic search

## Requirements

- Python 3.x
- pandas, numpy (already in requirements.txt)
- The `.pkl` and `.faiss` files must exist

## Notes

- The conversion preserves 100% of the data
- Embeddings are saved in efficient formats
- SQLite database provides fast access
- Query encoding still needs improvement (see CONVERSION_GUIDE.md)

