from langchain_core.messages import SystemMessage, HumanMessage
from langchain_google_genai import ChatGoogleGenerativeAI
from dotenv import load_dotenv
import os
import asyncio
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain.agents import create_agent


load_dotenv()
project = os.getenv('GOOGLE_CLOUD_PROJECT')



# def main():
#     result = llm.invoke("What is captial of france")
#     result.pretty_print()
async def main():
    # model
    llm = ChatGoogleGenerativeAI(
        model = "gemini-2.5-flash-lite",
        vertexai = True,
        project = project
    )
    client = MultiServerMCPClient({
        "library-mcp": {
            "transport": "streamable_http",
            "url": "http://localhost:19000/mcp"
        }
    })
    tools = await client.get_tools()
    agent = create_agent(llm, tools)

    result = await llm.ainvoke("""Get most popular book details on electrical engineering books
    i need title isbn in 13 digit format, published year, author""")
    print(result.content)
    books_to_be_added = result.content
    result = await agent.ainvoke({
         "messages": [HumanMessage(content=f"Add 3 copies of the each book mentioned in here {books_to_be_added} using library mcp")]
    })

    print(result)


    

if __name__ == "__main__":
    asyncio.run(main())
