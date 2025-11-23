"""
Convert Python model files to Dart-readable formats for APK
Extracts data from .pkl and .faiss files and converts to JSON/SQLite
"""

import pickle
import json
import sqlite3
import numpy as np
import pandas as pd
import os
from pathlib import Path

def convert_pkl_to_dart():
    """Extract data from .pkl file and convert to Dart-readable formats"""
    
    print("=" * 60)
    print("Converting Python model to Dart-readable format")
    print("=" * 60)
    
    # Load the pickle file
    print("\n1. Loading legal_search_model.pkl...")
    with open('legal_search_model.pkl', 'rb') as f:
        data = pickle.load(f)
    
    df = data['df']
    embeddings = data['embeddings']
    embedding_dim = data.get('model_name', embeddings.shape[1] if embeddings is not None else 768)
    
    print(f"   ✅ Loaded {len(df)} articles")
    print(f"   ✅ Embeddings shape: {embeddings.shape}")
    print(f"   ✅ Embedding dimension: {embedding_dim}")
    
    # Create output directory
    output_dir = Path('../lib/assets/legal_data')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. Convert DataFrame to JSON
    print("\n2. Converting articles to JSON...")
    articles_json = []
    for idx, row in df.iterrows():
        article = {
            'id': int(row['id']),
            'article_label': str(row['article_label']),
            'article_text': str(row['article_text']),
            'language': str(row['language']),
            'index': int(idx)  # Store original index for embedding lookup
        }
        articles_json.append(article)
    
    json_path = output_dir / 'articles.json'
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(articles_json, f, ensure_ascii=False, indent=2)
    print(f"   ✅ Saved {len(articles_json)} articles to {json_path}")
    
    # 2. Save embeddings as binary numpy file (Dart can read this)
    print("\n3. Saving embeddings...")
    embeddings_path = output_dir / 'embeddings.npy'
    np.save(embeddings_path, embeddings.astype('float32'))
    print(f"   ✅ Saved embeddings to {embeddings_path}")
    print(f"   ✅ Embeddings size: {embeddings.nbytes / (1024*1024):.2f} MB")
    
    # 3. Save embeddings metadata
    embeddings_meta = {
        'shape': list(embeddings.shape),
        'dtype': str(embeddings.dtype),
        'dimension': int(embedding_dim),
        'total_articles': int(len(df))
    }
    meta_path = output_dir / 'embeddings_meta.json'
    with open(meta_path, 'w') as f:
        json.dump(embeddings_meta, f, indent=2)
    print(f"   ✅ Saved embeddings metadata to {meta_path}")
    
    # 4. Create SQLite database (alternative format, more efficient)
    print("\n4. Creating SQLite database...")
    db_path = output_dir / 'legal_data.db'
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Create articles table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS articles (
            id INTEGER PRIMARY KEY,
            article_label TEXT,
            article_text TEXT,
            language TEXT,
            row_index INTEGER
        )
    ''')
    
    # Create embeddings table (store as BLOB)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS embeddings (
            row_index INTEGER PRIMARY KEY,
            embedding BLOB
        )
    ''')
    
    # Insert articles
    print("   Inserting articles...")
    for idx, row in df.iterrows():
        cursor.execute('''
            INSERT OR REPLACE INTO articles (id, article_label, article_text, language, row_index)
            VALUES (?, ?, ?, ?, ?)
        ''', (
            int(row['id']),
            str(row['article_label']),
            str(row['article_text']),
            str(row['language']),
            int(idx)
        ))
    
    # Insert embeddings
    print("   Inserting embeddings...")
    for idx in range(len(embeddings)):
        embedding_bytes = embeddings[idx].astype('float32').tobytes()
        cursor.execute('''
            INSERT OR REPLACE INTO embeddings (row_index, embedding)
            VALUES (?, ?)
        ''', (int(idx), embedding_bytes))
    
    conn.commit()
    conn.close()
    print(f"   ✅ Created SQLite database at {db_path}")
    print(f"   ✅ Database size: {db_path.stat().st_size / (1024*1024):.2f} MB")
    
    # 5. Convert FAISS index if available
    print("\n5. Processing FAISS index...")
    faiss_index_path = 'legal_search_index.faiss'
    if os.path.exists(faiss_index_path):
        try:
            import faiss
            index = faiss.read_index(faiss_index_path)
            
            # Extract index data
            # FAISS IndexFlatIP stores vectors directly, we can reconstruct from embeddings
            # For now, we'll use the embeddings directly in Dart
            print(f"   ✅ FAISS index found (type: {type(index).__name__})")
            print(f"   ✅ Index contains {index.ntotal} vectors")
            print(f"   ✅ Note: Will use embeddings directly for similarity search in Dart")
            
            # Save index metadata
            index_meta = {
                'type': type(index).__name__,
                'ntotal': int(index.ntotal),
                'dimension': int(index.d) if hasattr(index, 'd') else embedding_dim,
                'use_embeddings_directly': True
            }
            index_meta_path = output_dir / 'index_meta.json'
            with open(index_meta_path, 'w') as f:
                json.dump(index_meta, f, indent=2)
            print(f"   ✅ Saved index metadata to {index_meta_path}")
            
        except ImportError:
            print("   ⚠️ FAISS not available, skipping index conversion")
        except Exception as e:
            print(f"   ⚠️ Error processing FAISS index: {e}")
    else:
        print("   ⚠️ FAISS index file not found")
    
    # 6. Create summary
    print("\n" + "=" * 60)
    print("Conversion Complete!")
    print("=" * 60)
    print(f"\nOutput files in: {output_dir}")
    print(f"  ✅ articles.json - Article data ({len(articles_json)} articles)")
    print(f"  ✅ embeddings.npy - Pre-computed embeddings ({embeddings.shape})")
    print(f"  ✅ embeddings_meta.json - Embeddings metadata")
    print(f"  ✅ legal_data.db - SQLite database (articles + embeddings)")
    print(f"\nNext steps:")
    print(f"  1. Add these files to Flutter assets in pubspec.yaml")
    print(f"  2. Update Dart service to load and use this data")
    print(f"  3. Implement cosine similarity search in Dart")
    print("=" * 60)

if __name__ == '__main__':
    try:
        convert_pkl_to_dart()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

