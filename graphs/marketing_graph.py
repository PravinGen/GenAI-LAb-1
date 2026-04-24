from langgraph.graph import StateGraph
from typing import TypedDict

class CustomerConcern(TypedDict):
    concern: str
    comments: str
    response: str


def analyze_sentiment(state: CustomerConcern):
    return {"comments": state["comments"] + "\nCustomer is furious"}


def marketing_response(state: CustomerConcern):
    return {"response": "We are extremely sorry. Our executive will reach out."}


def build_graph():
    builder = StateGraph(CustomerConcern)

    builder.add_node("sentiment", analyze_sentiment)
    builder.add_node("response", marketing_response)

    builder.set_entry_point("sentiment")
    builder.add_edge("sentiment", "response")
    builder.set_finish_point("response")

    return builder.compile()