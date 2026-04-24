from langgraph_api import add_graph
from graphs.marketing_graph import build_graph as marketing_graph
from graphs.finance_graph import build_graph as finance_graph

# Register graphs
add_graph("marketing_graph", marketing_graph())
add_graph("finance_graph", finance_graph())