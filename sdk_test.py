import asyncio
from langgraph_sdk import get_client


async def main():
    client = get_client(url="http://localhost:2024")

    # Step 1: create thread
    thread = await client.threads.create()

    # Step 2: start run
    run = await client.runs.create(
        thread_id=thread["thread_id"],
        assistant_id="marketing_graph",
        input={
            "concern": "money issue",
            "comments": "",
            "response": ""
        }
    )

    run_id = run["run_id"]

    # Step 3: poll using run_id
    while True:
        status = await client.runs.get(
            thread["thread_id"],   # positional
            run_id                 # positional
        )

        if status["status"] == "completed":
            print("\nFINAL OUTPUT:\n", status["state"]["values"])
            break

        await asyncio.sleep(1)


asyncio.run(main())