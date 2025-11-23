# Legal Semantic Search API

FastAPI service for multilingual semantic search over the Rwanda Penal Code, backed by Sentence-Transformers. Uses FAISS for fast similarity search when available, and automatically falls back to scikit-learn on Windows.

## Quickstart (Windows, cmd)

```
python -m venv venv
venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel build
venv\Scripts\python.exe -m pip install -r requirements.txt
venv\Scripts\python.exe legal_search_api.py
```

Then run the test client in another terminal:

```
venv\Scripts\python.exe test_api.py
```

Notes:
- On Windows, `faiss-cpu` is skipped automatically; the app uses scikit-learn’s cosine nearest neighbors instead.
- On Linux/macOS, `faiss-cpu` is installed and used by default.

## Troubleshooting

- If you see `BackendUnavailable: Cannot import 'setuptools.build_meta'`, upgrade build tooling:
```
venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel build
```
- If installation is slow or fails mid-way, install packages incrementally to identify the culprit:
```
venv\Scripts\python.exe -m pip install torch==2.0.1 transformers==4.24.0 sentence-transformers==2.2.2
```

## Intent Classification

The `/search` and `/search/cross-lingual` endpoints now automatically classify simple conversational inputs and return an `intent` and `message` without performing a semantic search when appropriate.

Supported intents:
- `greeting` – e.g. `"hello"`, `"muraho"`
- `closing` – e.g. `"thanks"`, `"goodbye"`
- `search` – Standard legal queries; semantic search is executed

Response additions (for `SearchResponse`):
```json
{
	"query": "hello",
	"results": [],
	"total_results": 0,
	"processing_time_ms": 0.0,
	"intent": "greeting",
	"message": "Hello! I can help you search Rwanda Penal Code articles. Ask about crimes, penalties, or an article number."
}
```

### Examples (cmd / PowerShell syntax similar)

Greeting:
```
curl -X POST http://localhost:8000/search -H "Content-Type: application/json" -d "{\"query\": \"hello\", \"top_k\": 3, \"language_filter\": null, \"min_score\": 0}"
```

Standard search (unchanged behavior):
```
curl -X POST http://localhost:8000/search -H "Content-Type: application/json" -d "{\"query\": \"article 107 murder\", \"top_k\": 3, \"language_filter\": null, \"min_score\": 0.6}"
```

Clients that ignore the new `intent`/`message` fields will continue to function normally.