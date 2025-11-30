from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from intent_handler import EnhancedMultilingualLegalArticleChatbot


app = FastAPI(
    title="legalEase",
    description="An API for querying Rwandan laws using multilingual embeddings, FAISS search, and intent handling.",
    version="1.0.1",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    chatbot = EnhancedMultilingualLegalArticleChatbot(
        model_path="fine-tuned-multilingual-legal-model",
        index_path="multilingual_legal_articles.index",
        article_info_path="multilingual_article_info.pkl"
    )
except Exception as e:
    chatbot = None
    print(f" Failed to initialize chatbot: {e}")

class QueryRequest(BaseModel):
    query: str

class QueryResponse(BaseModel):
    intent: str
    response: str


@app.get("/", tags=["Root"])
def home():
    return {"message": "Welcome to the Rwanda Law Chatbot API! Visit /docs for Swagger UI."}

@app.get("/health", tags=["System"])
def health_check():
    """Simple health check to confirm model and FAISS are loaded."""
    if chatbot is None:
        return {"status": "error", "message": "Chatbot not loaded"}
    return {"status": "ok", "message": "Chatbot and FAISS index loaded successfully"}

@app.post("/query", response_model=QueryResponse, tags=["Chatbot"])
def query_model(request: QueryRequest):
    """Main endpoint to interact with the chatbot."""
    if chatbot is None:
        raise HTTPException(status_code=500, detail="Chatbot not initialized")
    try:
        intent = chatbot.intent_handler.classify_intent(request.query)
        response = chatbot.enhanced_generate_response(request.query)
        return {"intent": intent, "response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
