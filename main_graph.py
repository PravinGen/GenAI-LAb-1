from langgraph.graph import StateGraph
from typing import TypedDict
from langgraph_sdk import get_client

client = get_client(url="http://localhost:2024")

class CustomerConcern(TypedDict):
    concern: str
    comments: str
    response: str


# 🔥 SDK call to marketing graph
def call_marketing(state: CustomerConcern):
    res = client.runs.create(
        assistant_id="marketing_graph",
        input=state
    )
    return res["output"]


# 🔥 SDK call to finance graph
def call_finance(state: CustomerConcern):
    res = client.runs.create(
        assistant_id="finance_graph",
        input=state
    )
    return res["output"]


# 🔥 Router (dynamic decision)
def router(state: CustomerConcern):
    if "money" in state["concern"]:
        return "finance"
    return "marketing"


# Build main graph
builder = StateGraph(CustomerConcern)

builder.add_node("router", router)
builder.add_node("marketing", call_marketing)
builder.add_node("finance", call_finance)

builder.set_entry_point("router")

builder.add_conditional_edges(
    "router",
    router,
    {
        "marketing": "marketing",
        "finance": "finance"
    }
)

builder.set_finish_point("marketing")  # or finance dynamically

main_graph = builder.compile()