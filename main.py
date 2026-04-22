from dotenv import load_dotenv
from langgraph.graph import StateGraph
from langgraph.graph.message import MessagesState
from langchain_core.messages import HumanMessage

from llm import get_llm

# Load env
load_dotenv()

# Init LLM
llm = get_llm("gemini-flash-lite")

# Node
def chatbot(state: MessagesState):
    messages = state["messages"]
    print("⚡ Calling Gemini...")
    response = llm.invoke(messages)
    return {"messages": messages + [response]}

# Graph
builder = StateGraph(MessagesState)
builder.add_node("chatbot", chatbot)
builder.set_entry_point("chatbot")
builder.set_finish_point("chatbot")

app = builder.compile()

# CLI loop
if __name__ == "__main__":
    while True:
        user_input = input("\nYou: ")

        if user_input.lower() in ["exit", "quit"]:
            break

        result = app.invoke({
            "messages": [HumanMessage(content=user_input)]
        })

        print("AI:", result["messages"][-1].content)what 