"""
Legal Semantic Search FastAPI Application
Provides REST API endpoints for multilingual legal document search
"""

from fastapi import FastAPI, HTTPException, Query, Path
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import uvicorn
import os
import logging
from contextlib import asynccontextmanager

from legal_semantic_search import LegalSemanticSearch

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global model instance
search_model = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup, cleanup on shutdown"""
    global search_model
    
    # Startup
    logger.info("Loading legal semantic search model...")
    try:
        search_model = LegalSemanticSearch()
        
        # Try to load saved model first (index will be rebuilt if needed)
        if os.path.exists('legal_search_model.pkl'):
            logger.info("Loading saved model...")
            search_model.load_model()
        else:
            logger.info("No saved model found. Loading from scratch...")
            search_model.load_data('penal.csv')
            search_model.create_embeddings()
            search_model.build_index()
            search_model.save_model()
        
        logger.info("Model loaded successfully!")
        
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise e
    
    yield
    
    # Shutdown
    logger.info("Shutting down...")

# Initialize FastAPI app
app = FastAPI(
    title="Legal Semantic Search API",
    description="Multilingual semantic search for Rwanda Penal Code articles",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for request/response
class SearchRequest(BaseModel):
    query: str = Field(..., description="Search query text", example="murder voluntary killing")
    top_k: int = Field(1, ge=1, le=20, description="Number of results to return")
    language_filter: Optional[str] = Field(None, pattern="^(rw|en|fr)$", description="Filter by language")
    min_score: float = Field(0.0, ge=0.0, le=1.0, description="Minimum similarity score")

class CrossLingualRequest(BaseModel):
    query: str = Field(..., description="Search query in any language", example="murder killing")
    target_language: str = Field("en", pattern="^(rw|en|fr)$", description="Target language for results")
    min_score: float = Field(0.0, ge=0.0, le=1.0, description="Minimum similarity score")

class ArticleResponse(BaseModel):
    id: int
    article_label: str
    article_text: str
    language: str

class SearchResponse(BaseModel):
    query: str
    results: List[ArticleResponse]
    total_results: int
    processing_time_ms: float
    intent: Optional[str] = Field(None, description="Detected intent: greeting, closing, search")
    message: Optional[str] = Field(None, description="Human-friendly response message for greeting/closing intents")

class TranslationResponse(BaseModel):
    article_id: int
    translations: List[ArticleResponse]

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    total_articles: int
    languages: Dict[str, int]

# -------------------- Intent Classification --------------------
def classify_intent(query: str) -> Dict[str, str]:
    """Classify the user query into greeting, closing, or search.

    Returns a dict with keys:
    - intent: greeting | closing | search
    - message: Optional friendly response (for greeting/closing)
    """
    text = query.strip().lower()
    greetings = {
        "hi", "hello", "hey", "good morning", "good afternoon", "good evening",
        "greetings", "bonjour", "muraho", "mwiriwe", "salut"
    }
    closings = {
        "bye", "goodbye", "thanks", "thank you", "cheers", "see you",
        "murabeho", "merci", "thanks!", "thanks.", "thank you!"
    }
    for g in greetings:
        if text == g or text.startswith(g + " "):
            return {
                "intent": "greeting",
                "message": "Hello! I can help you search Rwanda Penal Code articles. Ask about crimes, penalties, or an article number."
            }
    for c in closings:
        if text == c or text.startswith(c + " "):
            return {
                "intent": "closing",
                "message": "Thank you for using the Legal Semantic Search API. Feel free to return anytime for legal article queries."
            }
    return {"intent": "search", "message": ""}

# Health check endpoint
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    global search_model
    
    if search_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        language_counts = search_model.df['language'].value_counts().to_dict()
        return HealthResponse(
            status="healthy",
            model_loaded=True,
            total_articles=len(search_model.df),
            languages=language_counts
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service unhealthy")

# Main search endpoint
@app.post("/search", response_model=SearchResponse)
async def search_articles(request: SearchRequest):
    """
    Search for legal articles using semantic similarity
    
    - **query**: Text to search for (any language)
    - **top_k**: Number of results (1-20)
    - **language_filter**: Filter by language (rw/en/fr) or null for all
    - **min_score**: Minimum similarity score (0.0-1.0)
    """
    global search_model
    
    if search_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Intent classification (short-circuit non-search intents)
        intent_info = classify_intent(request.query)
        if intent_info["intent"] != "search":
            return SearchResponse(
                query=request.query,
                results=[],
                total_results=0,
                processing_time_ms=0.0,
                intent=intent_info["intent"],
                message=intent_info["message"]
            )

        import time
        start_time = time.time()
        
        # Perform search
        results = search_model.search(
            query=request.query,
            top_k=request.top_k,
            language_filter=request.language_filter,
            min_score=request.min_score
        )
        
        processing_time = (time.time() - start_time) * 1000  # Convert to ms
        
        # Convert to response format
        article_responses = [
            ArticleResponse(
                id=result['id'],
                article_label=result['article_label'],
                article_text=result['article_text'],
                language=result['language']
            )
            for result in results
        ]
        
        return SearchResponse(
            query=request.query,
            results=article_responses,
            total_results=len(article_responses),
            processing_time_ms=round(processing_time, 2),
            intent="search",
            message=None
        )
        
    except Exception as e:
        logger.error(f"Search failed: {e}")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

# Cross-lingual search endpoint
@app.post("/search/cross-lingual", response_model=SearchResponse)
async def cross_lingual_search(request: CrossLingualRequest):
    """
    Cross-lingual search: query in any language, results in target language
    
    - **query**: Search query in any language
    - **target_language**: Language for results (rw/en/fr)
    - **min_score**: Minimum similarity score (0.0-1.0)
    """
    global search_model
    
    if search_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Intent classification (same behavior as /search)
        intent_info = classify_intent(request.query)
        if intent_info["intent"] != "search":
            return SearchResponse(
                query=request.query,
                results=[],
                total_results=0,
                processing_time_ms=0.0,
                intent=intent_info["intent"],
                message=intent_info["message"]
            )

        import time
        start_time = time.time()
        
        # Perform cross-lingual search
        results = search_model.search_cross_lingual(
            query=request.query,
            target_language=request.target_language,
            min_score=request.min_score
        )
        
        processing_time = (time.time() - start_time) * 1000
        
        # Convert to response format
        article_responses = [
            ArticleResponse(
                id=result['id'],
                article_label=result['article_label'],
                article_text=result['article_text'],
                language=result['language']
            )
            for result in results
        ]
        
        return SearchResponse(
            query=request.query,
            results=article_responses,
            total_results=len(article_responses),
            processing_time_ms=round(processing_time, 2),
            intent="search",
            message=None
        )
        
    except Exception as e:
        logger.error(f"Cross-lingual search failed: {e}")
        raise HTTPException(status_code=500, detail=f"Cross-lingual search failed: {str(e)}")

# Find translations endpoint
@app.get("/article/{article_id}/translations", response_model=TranslationResponse)
async def get_article_translations(
    article_id: int = Path(..., description="Article ID to find translations for")
):
    """
    Find all language versions (translations) of a specific article
    
    - **article_id**: ID of the article to find translations for
    """
    global search_model
    
    if search_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Find translations
        translations = search_model.find_translation(article_id)
        
        if not translations:
            raise HTTPException(status_code=404, detail=f"Article {article_id} not found")
        
        # Convert to response format
        translation_responses = [
            ArticleResponse(
                id=trans['id'],
                article_label=trans['article_label'],
                article_text=trans['article_text'],
                language=trans['language']
            )
            for trans in translations
        ]
        
        return TranslationResponse(
            article_id=article_id,
            translations=translation_responses
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Translation lookup failed: {e}")
        raise HTTPException(status_code=500, detail=f"Translation lookup failed: {str(e)}")

# Get specific article endpoint
@app.get("/article/{article_id}", response_model=ArticleResponse)
async def get_article(
    article_id: int = Path(..., description="Article ID"),
    language: str = Query("en", pattern="^(rw|en|fr)$", description="Language version")
):
    """
    Get a specific article by ID and language
    
    - **article_id**: ID of the article
    - **language**: Language version (rw/en/fr)
    """
    global search_model
    
    if search_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Find the specific article
        article_row = search_model.df[
            (search_model.df['id'] == article_id) & 
            (search_model.df['language'] == language)
        ]
        
        if len(article_row) == 0:
            raise HTTPException(
                status_code=404, 
                detail=f"Article {article_id} not found in language '{language}'"
            )
        
        row = article_row.iloc[0]
        
        return ArticleResponse(
            id=int(row['id']),
            article_label=row['article_label'],
            article_text=row['article_text'],
            language=row['language']
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Article lookup failed: {e}")
        raise HTTPException(status_code=500, detail=f"Article lookup failed: {str(e)}")

# Quick search endpoint (GET request)
@app.get("/search", response_model=SearchResponse)
async def quick_search(
    q: str = Query(..., description="Search query"),
    top_k: int = Query(5, ge=1, le=20, description="Number of results"),
    lang: Optional[str] = Query(None, pattern="^(rw|en|fr)$", description="Language filter"),
    min_score: float = Query(0.0, ge=0.0, le=1.0, description="Minimum score")
):
    """
    Quick search endpoint using GET request (for testing/simple usage)
    """
    request = SearchRequest(
        query=q,
        top_k=top_k,
        language_filter=lang,
        min_score=min_score
    )
    return await search_articles(request)

# Stats endpoint
@app.get("/stats")
async def get_stats():
    """Get statistics about the legal corpus"""
    global search_model
    
    if search_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        df = search_model.df
        
        stats = {
            "total_articles": len(df),
            "unique_articles": len(df) // 3,  # Each article has 3 language versions
            "languages": df['language'].value_counts().to_dict(),
            "model_info": {
                "embedding_dimension": search_model.embeddings.shape[1] if search_model.embeddings is not None else None,
                "total_embeddings": search_model.embeddings.shape[0] if search_model.embeddings is not None else None,
                "model_name": "paraphrase-multilingual-mpnet-base-v2"
            }
        }
        
        return stats
        
    except Exception as e:
        logger.error(f"Stats failed: {e}")
        raise HTTPException(status_code=500, detail=f"Stats failed: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(
        "legal_search_api:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
