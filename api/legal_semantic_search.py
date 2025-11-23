"""
Legal Corpus Semantic Search ML Model
Uses sentence-transformers for multilingual legal text search
"""

import pandas as pd
import numpy as np
from sentence_transformers import SentenceTransformer
try:
    import faiss  # type: ignore
    USE_FAISS = True
except Exception:
    faiss = None  # type: ignore
    USE_FAISS = False
import pickle
import os
from typing import List, Tuple
import warnings
warnings.filterwarnings('ignore')

class LegalSemanticSearch:
    """
    Semantic search model for legal corpus with multilingual support.
    
    Best for:
    - Finding similar legal articles across languages
    - Cross-lingual retrieval
    - Semantic similarity search
    - Article recommendation
    """
    
    def __init__(self, model_name='paraphrase-multilingual-mpnet-base-v2'):
        """
        Initialize the semantic search model.
        
        Args:
            model_name: SentenceTransformer model for multilingual embeddings
                - 'paraphrase-multilingual-mpnet-base-v2': Best cross-lingual
                - 'all-MiniLM-L6-v2': Fast, single language
                - 'distiluse-base-multilingual-cased': Good for legal text
        """
        print(f"Loading model: {model_name}")
        self.model = SentenceTransformer(model_name)
        self.df = None
        self.embeddings = None
        self.index = None
        
    def load_data(self, csv_path='penal.csv'):
        """Load legal corpus data"""
        print(f"Loading data from {csv_path}...")
        self.df = pd.read_csv(csv_path)
        print(f"Loaded {len(self.df)} articles")
        print(f"Languages: {self.df['language'].value_counts().to_dict()}")
        return self.df
    
    def create_embeddings(self):
        """Create embeddings for all articles"""
        if self.df is None:
            raise ValueError("Load data first using load_data()")
        
        print("Creating embeddings...")
        # Use label and text for better context
        texts = (self.df['article_label'] + '. ' + self.df['article_text']).tolist()
        
        # Generate embeddings
        self.embeddings = self.model.encode(
            texts, 
            show_progress_bar=True,
            normalize_embeddings=True  # For better cosine similarity
        )
        
        print(f"Created embeddings of shape: {self.embeddings.shape}")
        return self.embeddings
    
    def build_index(self):
        """Build similarity index (FAISS if available, else sklearn)."""
        if self.embeddings is None:
            self.create_embeddings()
        
        if USE_FAISS:
            print("Building FAISS index...")
            dimension = self.embeddings.shape[1]
            self.index = faiss.IndexFlatIP(dimension)
            self.index.add(self.embeddings.astype('float32'))
            print(f"Index built with {self.index.ntotal} vectors")
            return self.index
        else:
            print("FAISS not available. Falling back to sklearn NearestNeighbors (cosine)...")
            from sklearn.neighbors import NearestNeighbors
            # On normalized vectors, cosine distance = 1 - cosine similarity
            nn = NearestNeighbors(metric='cosine', algorithm='brute')
            nn.fit(self.embeddings.astype('float32'))
            self.index = nn
            print("Sklearn index built")
            return self.index
    
    def search(self, query: str, top_k: int = 5, language_filter: str = None, min_score: float = 0.0) -> List[dict]:
        """
        Search for similar articles
        
        Args:
            query: Search query text
            top_k: Number of results to return
            language_filter: Filter by language ('rw', 'en', 'fr') or None for all
            min_score: Minimum similarity score (0.0-1.0). Default 0.0 (all results)
            
        Returns:
            List of similar articles with scores
        """
        if self.index is None:
            raise ValueError("Build index first using build_index()")
        
        # Encode query
        query_embedding = self.model.encode(query, normalize_embeddings=True)
        query_embedding = query_embedding.reshape(1, -1)
        
        # Search
        if USE_FAISS:
            scores, indices = self.index.search(query_embedding.astype('float32'), k=top_k * 3)
        else:
            # sklearn returns distances; convert to cosine similarity
            distances, indices = self.index.kneighbors(query_embedding.astype('float32'), n_neighbors=top_k * 3)
            scores = 1.0 - distances
        
        results = []
        for score, idx in zip(scores[0], indices[0]):
            # Skip results below minimum score
            if score < min_score:
                continue
                
            if idx < len(self.df):
                row = self.df.iloc[idx]
                
                # Apply language filter
                if language_filter and row['language'] != language_filter:
                    continue
                
                results.append({
                    'id': int(row['id']),
                    'article_label': row['article_label'],
                    'article_text': row['article_text'],  # Keep full text for API
                    'language': row['language'],
                    'similarity_score': float(score)
                })
                
                if len(results) >= top_k:
                    break
        
        return results
    
    def find_translation(self, article_id: int) -> List[dict]:
        """
        Find translations of an article across languages
        
        Args:
            article_id: ID of the article
            
        Returns:
            List of translations (same article in different languages)
        """
        if self.df is None:
            raise ValueError("Load data first")
        
        # Get the article
        article = self.df[self.df['id'] == article_id]
        if len(article) == 0:
            return []
        
        # Find all articles with same id (they are translations)
        translations = self.df[self.df['id'] == article_id]
        
        results = []
        for idx, row in translations.iterrows():
            results.append({
                'id': int(row['id']),
                'article_label': row['article_label'],
                'article_text': row['article_text'],
                'language': row['language']
            })
        
        return results
    
    def search_cross_lingual(self, query: str, target_language: str = 'en', min_score: float = 0.0) -> List[dict]:
        """
        Search in any language, return results in target language
        
        Args:
            query: Search query in any language
            target_language: Language for results ('rw', 'en', 'fr')
            min_score: Minimum similarity score for filtering
            
        Returns:
            List of similar articles in target language
        """
        # Search across all languages
        all_results = self.search(query, top_k=20, language_filter=None, min_score=min_score)
        
        # Group by article ID and find translations
        found_ids = set()
        target_results = []
        
        for result in all_results:
            article_id = result['id']
            if article_id not in found_ids:
                # Find translation in target language
                translations = self.find_translation(article_id)
                
                for trans in translations:
                    if trans['language'] == target_language:
                        trans['similarity_score'] = result['similarity_score']
                        target_results.append(trans)
                        found_ids.add(article_id)
                        break
        
        return target_results[:5]
    
    def save_model(self, filepath='legal_search_model.pkl'):
        """Save the model and data"""
        print(f"Saving model to {filepath}...")
        
        data_to_save = {
            'df': self.df,
            'embeddings': self.embeddings,
            'model_name': self.model.get_sentence_embedding_dimension()
        }
        
        with open(filepath, 'wb') as f:
            pickle.dump(data_to_save, f)
        
        # Save index if FAISS is used; sklearn index can be rebuilt on load
        if USE_FAISS and self.index is not None:
            faiss.write_index(self.index, 'legal_search_index.faiss')
        print("Model saved successfully")
    
    def load_model(self, filepath='legal_search_model.pkl'):
        """Load saved model"""
        print(f"Loading model from {filepath}...")
        
        with open(filepath, 'rb') as f:
            data = pickle.load(f)
        
        self.df = data['df']
        self.embeddings = data['embeddings']
        
        # Load index
        if USE_FAISS and os.path.exists('legal_search_index.faiss'):
            self.index = faiss.read_index('legal_search_index.faiss')
        else:
            # Rebuild a sklearn index on the fly
            self.build_index()
        print("Model loaded successfully")


def demonstrate_usage():
    """Demonstrate the usage of the legal search model"""
    
    print("=" * 80)
    print("Legal Corpus Semantic Search ML Model")
    print("=" * 80)
    
    # Initialize model
    search_model = LegalSemanticSearch(
        model_name='paraphrase-multilingual-mpnet-base-v2'
    )
    
    # Load and prepare data
    search_model.load_data('penal.csv')
    search_model.create_embeddings()
    search_model.build_index()
    
    print("\n" + "=" * 80)
    print("Example 1: Search for articles about murder (improved with min_score filter)")
    print("=" * 80)
    
    results = search_model.search("murder voluntary killing", top_k=3, min_score=0.65)
    print(f"\nFound {len(results)} highly relevant results (score >= 0.65)")
    for i, result in enumerate(results, 1):
        print(f"\n{i}. Article {result['id']} ({result['language']})")
        print(f"   Label: {result['article_label']}")
        print(f"   Text: {result['article_text'][:200]}...")
        print(f"   Similarity: {result['similarity_score']:.4f}")
    
    print("\n" + "=" * 80)
    print("Example 2: Cross-lingual search with quality filter")
    print("Search: 'murder killing' (English) → Results: French articles")
    print("Filtering out low-quality matches (score < 0.50)")
    print("=" * 80)
    
    results = search_model.search_cross_lingual("murder killing", target_language='fr', min_score=0.50)
    print(f"\nFound {len(results)} high-quality results (score >= 0.50)")
    for i, result in enumerate(results, 1):
        print(f"\n{i}. Article {result['id']} ({result['language']})")
        print(f"   Label: {result['article_label']}")
        print(f"   Text: {result['article_text'][:200]}...")
        print(f"   Similarity: {result['similarity_score']:.4f}")
    
    print("\n" + "=" * 80)
    print("Example 3: Search in Kinyarwanda")
    print("=" * 80)
    
    results = search_model.search("jenocide", top_k=3, language_filter='rw')
    for i, result in enumerate(results, 1):
        print(f"\n{i}. Article {result['id']} ({result['language']})")
        print(f"   Label: {result['article_label']}")
        print(f"   Text: {result['article_text'][:200]}...")
        print(f"   Similarity: {result['similarity_score']:.4f}")
    
    # Save model for future use
    search_model.save_model()
    
    print("\n" + "=" * 80)
    print("Model saved! You can now load it faster next time.")
    print("=" * 80)


if __name__ == "__main__":
    demonstrate_usage()