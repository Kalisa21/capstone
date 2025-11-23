# Legal Ease App

This Flutter application consumes a FastAPI backend that provides legal search
capabilities. The chatbot and the quick-search widget both rely on the
`POST /search` endpoint.

## Running the FastAPI backend locally

From the backend project root run:

```
uvicorn legal_search_api:app --host 127.0.0.1 --port 8000 --reload
```

The OpenAPI docs are available at `http://127.0.0.1:8000/docs`.

## Pointing the Flutter app to your API

Both the chatbot (`ChatbotScreen`) and the inline search widget (`HomeScreen`)
use an `API_BASE` compile-time environment variable. By default it points to
`http://127.0.0.1:8000`, which works for desktop, web, and iOS simulators.

If you need a different host (for example the Android emulator’s loopback),
override it when running Flutter:

```
flutter run --dart-define=API_BASE=http://10.0.2.2:8000
```

You can swap the value for any deployed API URL as needed.
