from mcp.server.fastmcp import FastMCP
from datastore import BOOKS, STUDENTS, LOANS      # ✅ add LOANS
from datetime import date

mcp = FastMCP("library-mcp", host="0.0.0.0", port=19000)   # ✅ int not string


@mcp.tool(name="search_books",
          description="Search active books by title, author or keyword. Optional genre filter.")
def search_books(query: str, genre: str = "") -> list[dict]:
    q = query.lower()
    results = []
    for book in BOOKS.values():
        if not book["active"]:
            continue
        hit = q in book["title"].lower() or q in book["author"].lower()
        genre_ok = (genre == "") or (genre.lower() in book["genre"].lower())
        if hit and genre_ok:
            results.append(book)
    return results or [{"message": "No books found"}]


@mcp.tool(name="get_loans_due",
          description="Get all loans that are due today or overdue.")
def get_loans_due() -> list[dict]:
    today = date.today()
    results = []
    for loan_id, loan in LOANS.items():
        due = date.fromisoformat(loan["due_date"])
        if due <= today:
            results.append({
                **loan,
                "loan_id": loan_id,
                "days_overdue": (today - due).days,
                "status": "due_today" if due == today else "overdue"
            })
    return results or [{"message": "No loans due today"}]


@mcp.tool(name="get_loans_due_this_week",
          description="Get all loans due within the next 7 days.")
def get_loans_due_this_week() -> list[dict]:
    today = date.today()
    results = []
    for loan_id, loan in LOANS.items():
        due = date.fromisoformat(loan["due_date"])
        days_until = (due - today).days
        if 0 < days_until <= 7:
            results.append({
                **loan,
                "loan_id": loan_id,
                "days_until_due": days_until
            })
    return results or [{"message": "No loans due this week"}]


@mcp.resource("library://catalog")
def get_catalog() -> str:
    lines = ["──── College Library Catalog ────"]
    for book in BOOKS.values():
        status = "RETIRED" if not book["active"] else "AVAILABLE"
        lines.append(
            f"{book['id']}: {book['title']} by {book['author']} [{book['genre']}] - {status}"
        )
    return "\n".join(lines)


@mcp.resource("library://students/{student_id}")
def get_student_profile(student_id: str) -> str:
    student = STUDENTS.get(student_id)
    if not student:
        return f"Student with id {student_id} not found"
    return "\n".join([
        "──── Student Profile ────",
        f"Name  : {student['name']}",
        f"Email : {student['email']}",
    ])


@mcp.prompt(name="return_due_today",
            description="Librarian prompt for books due today, overdue, and due this week.")
def return_due_today() -> str:
    return (
        f"Today is {date.today()}.\n\n"
        "Use the following tools to build a full due-date report:\n"
        "  1. Call `get_loans_due` → shows overdue + due today (includes days_overdue)\n"
        "  2. Call `get_loans_due_this_week` → shows upcoming loans in next 7 days\n\n"
        "Format the output as a clear table for the librarian with columns:\n"
        "  Loan ID | Student | Book | Due Date | Status | Days Overdue"
    )


if __name__ == "__main__":
    mcp.run(transport="streamable-http")