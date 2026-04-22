# Agentic AI - Research Notes

## 📌 Objective

Build a minimal Agentic AI system using LangGraph and Gemini LLM.

---

## 🤖 What is Agentic AI?

Agentic AI refers to systems that can:

* Understand user input
* Make decisions
* Take actions
* Maintain state

Unlike simple chatbots, agentic systems can perform workflows.

---

## 🔗 LangGraph Overview

LangGraph is used to build stateful workflows using nodes.

### Key Concepts:

* Node → A function (e.g., ask_llm)
* State → Stores messages (MessagesState)
* Graph → Defines execution flow

---

## 🔄 Workflow Implemented

Input → LLM → Response

Steps:

1. User provides input
2. Message is passed to LLM
3. LLM generates response
4. Response is returned

---

## 🧠 LLM Used

* Model: Gemini (Google)
* Integration: langchain-google-genai
* API Key via environment variable

---

## ⚙️ Learnings

* Importance of environment variables (.env)
* Handling module imports in Python
* Working with LangGraph state
* Debugging model and API errors

---

## 🚀 Future Improvements

* Add tools (calculator, weather API)
* Implement multi-step reasoning
* Add memory for conversations
* Convert into production-ready agent

---

## 📌 Conclusion

Successfully built a minimal Agentic AI system using:

* Python
* LangGraph
* Gemini LLM

This forms the foundation for advanced AI agents.
