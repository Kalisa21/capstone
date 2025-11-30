import numpy as np
import faiss
import torch
import re
import pickle
from transformers import AutoTokenizer, AutoModel


class IntentHandler:
    def __init__(self):
        self.greeting_pattern = re.compile(
            r'\b(hello|hi|hey|good (morning|afternoon|evening|night)|greetings|howdy)\b',
            re.IGNORECASE
        )
        self.closing_pattern = re.compile(
            r'\b(bye|goodbye|see you|farewell|later|ciao|murabeho)\b',
            re.IGNORECASE
        )
        self.thanks_pattern = re.compile(
            r'\b(thanks?|thank\s*you|thx|merci|gracias|murakoze)\b',
            re.IGNORECASE
        )

    def classify_intent(self, text):
        if self.greeting_pattern.search(text):
            return "greeting"
        elif self.closing_pattern.search(text):
            return "closing"
        elif self.thanks_pattern.search(text):
            return "thanks"
        else:
            return "legal_query"


class EnhancedMultilingualLegalArticleChatbot:
    def __init__(self, model_path, index_path, article_info_path):
        print("🔄 Loading multilingual model and FAISS index...")
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

        self.tokenizer = AutoTokenizer.from_pretrained(model_path)
        self.model = AutoModel.from_pretrained(model_path).to(self.device)

        self.index = faiss.read_index(index_path)

        with open(article_info_path, "rb") as f:
            self.article_info = pickle.load(f)

        self.intent_handler = IntentHandler()
        self.legal_similarity_threshold = 0.35

        print(" Chatbot loaded successfully!")

    def embed_text(self, text):
        tokens = self.tokenizer(text, return_tensors="pt", truncation=True, padding=True).to(self.device)
        with torch.no_grad():
            outputs = self.model(**tokens)
        embeddings = outputs.last_hidden_state.mean(dim=1).cpu().numpy()
        return embeddings

    def search_articles(self, query):
        query_vec = self.embed_text(query)
        scores, indices = self.index.search(query_vec, k=3)
        return scores[0], indices[0]

    def enhanced_generate_response(self, query):
        intent = self.intent_handler.classify_intent(query)

        if intent == "greeting":
            return "Hello!  I'm your Rwanda Law Assistant. How can I help you today?"
        elif intent == "closing":
            return "Goodbye!  Have a great day!"
        elif intent == "thanks":
            return "You're welcome!  Always happy to help."
        else:
            scores, indices = self.search_articles(query)
            if scores[0] < self.legal_similarity_threshold:
                return "I’m sorry, I can only assist with questions related to Rwandan laws and regulations."
            response = "\n\n".join([self.article_info[i] for i in indices])
            return response
