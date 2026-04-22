from dotenv import load_dotenv
from langgraph.graph import StateGraph
from langgraph.graph.message import MessagesState
from langchain_core.messages import HumanMessage

from llm import get_llm

load_dotenv()

# Initialize LLM
llm = get_llm()

# Node function
def chatbot(state: MessagesState):
    response = llm.invoke(state["messages"])
    return {"messages": response}

# Build graph
graph = StateGraph(MessagesState)

graph.add_node("chatbot", chatbot)
graph.set_entry_point("chatbot")
graph.set_finish_point("chatbot")

app = graph.compile()

# Run
if __name__ == "__main__":
    user_input = input("You: ")
    
    result = app.invoke({
        "messages": [HumanMessage(content=user_input)]
    })

    print("AI:", result["messages"].content)