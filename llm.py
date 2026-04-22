from langchain_google_genai import ChatGoogleGenerativeAI
import os

def get_llm(model: str):
    api_key = os.getenv("GOOGLE_API_KEY")

    if not api_key:
        raise ValueError("GOOGLE_API_KEY not found")

    return ChatGoogleGenerativeAI(
        model="gemini-2.5-flash",   # ✅ FINAL WORKING MODEL
        temperature=0,
        google_api_key=api_key
    )