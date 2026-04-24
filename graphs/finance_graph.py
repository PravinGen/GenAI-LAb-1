from langgraph.graph import StateGraph
from typing import TypedDict

class CustomerConcern(TypedDict):
    concern: str
    comments: str
    response: str


def analyze_facts(state: CustomerConcern):
    return {"comments": state["comments"] + "\nCustomer is genuine"}


def fin_response(state: CustomerConcern):
    return {"response": "Your money is safe with us"}


def build_graph():
    builder = StateGraph(CustomerConcern)

    builder.add_node("facts", analyze_facts)
    builder.add_node("response", fin_response)

    builder.set_entry_point("facts")
    builder.add_edge("facts", "response")
    builder.set_finish_point("response")

    return builder.compile()