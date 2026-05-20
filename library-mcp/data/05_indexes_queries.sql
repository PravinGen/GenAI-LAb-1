-- =============================================================
--  COLLEGE LIBRARY DATABASE
--  File 05: Indexes & Sample Analytics Queries
-- =============================================================

USE college_library;

-- =============================================================
--  ADDITIONAL INDEXES (beyond FK indexes in schema)
-- =============================================================

-- Fast ISBN lookup
CREATE INDEX idx_book_isbn    ON books (isbn);
CREATE INDEX idx_book_title   ON books (title(50));
CREATE INDEX idx_book_year    ON books (publication_year);

-- Copy barcode scan
CREATE INDEX idx_copy_barcode ON book_copies (barcode);
CREATE INDEX idx_copy_status  ON book_copies (current_status);

-- User lookups
CREATE INDEX idx_user_type    ON users (user_type, is_active);
CREATE INDEX idx_student_roll ON students (roll_number);

-- Transaction date ranges
CREATE INDEX idx_txn_issue    ON book_transactions (issue_date);
CREATE INDEX idx_txn_due      ON book_transactions (due_date);
CREATE INDEX idx_txn_return   ON book_transactions (return_date);

-- Fine date ranges
CREATE INDEX idx_fine_raised  ON fines (raised_on);
CREATE INDEX idx_fine_paid    ON fines (paid_on);

-- =============================================================
--  SAMPLE ANALYTICS QUERIES
-- =============================================================


-- ── 1. Top 10 Performing Books ───────────────────────────────
SELECT
    borrow_rank,
    title,
    authors,
    borrows_last_year,
    unique_borrowers,
    available_copies,
    total_copies,
    turnover_ratio
FROM vw_book_performance_all
WHERE performance_band = 'TOP'
LIMIT 10;


-- ── 2. Low Performing Books with no borrows ever ─────────────
SELECT
    b.isbn,
    b.title,
    GROUP_CONCAT(ba.author ORDER BY ba.seq SEPARATOR ', ') AS authors,
    COUNT(bc.copy_id)   AS copies_owned,
    b.purchase_price,
    b.added_on
FROM books b
JOIN book_copies bc ON bc.book_id = b.book_id
JOIN book_authors ba ON ba.book_id = b.book_id
LEFT JOIN book_transactions bt ON bt.book_id = b.book_id
WHERE bt.txn_id IS NULL
  AND b.is_active = 1
GROUP BY b.book_id, b.isbn, b.title, b.purchase_price, b.added_on
ORDER BY b.added_on;


-- ── 3. Monthly Fine Collection — current year ────────────────
SELECT
    year_month,
    fines_paid_count,
    unique_payers,
    total_collected,
    overdue_collected,
    damage_collected,
    loss_collected,
    total_raised_in_month,
    total_waived_in_month
FROM vw_monthly_fine_summary
WHERE yr = YEAR(CURRENT_DATE)
ORDER BY mo;


-- ── 4. Monthly Book Ledger — current year ────────────────────
SELECT
    year_month,
    total_issued,
    total_returned,
    currently_overdue,
    reported_lost,
    returned_damaged,
    unique_borrowers,
    unique_books_borrowed,
    avg_borrow_days,
    avg_days_overdue
FROM vw_monthly_book_ledger
WHERE yr = YEAR(CURRENT_DATE)
ORDER BY mo;


-- ── 5. All overdue books right now (with user contact) ───────
SELECT
    bt.txn_id,
    u.full_name,
    u.email,
    u.phone,
    COALESCE(s.roll_number, lib.employee_id) AS id_number,
    b.title,
    bc.barcode,
    bt.issue_date,
    bt.due_date,
    DATEDIFF(CURRENT_DATE, bt.due_date)      AS days_overdue,
    DATEDIFF(CURRENT_DATE, bt.due_date) * fp.per_day_fine AS estimated_fine
FROM book_transactions bt
JOIN users       u   ON u.user_id  = bt.user_id
JOIN books       b   ON b.book_id  = bt.book_id
JOIN book_copies bc  ON bc.copy_id = bt.copy_id
LEFT JOIN students  s   ON s.user_id  = u.user_id
LEFT JOIN librarians lib ON lib.user_id = u.user_id
JOIN fine_policy fp ON fp.user_type = u.user_type
                    AND fp.effective_from <= CURRENT_DATE
                    AND (fp.effective_to IS NULL OR fp.effective_to >= CURRENT_DATE)
WHERE bt.status IN ('issued','overdue')
  AND bt.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;


-- ── 6. User account ledger (single user) ─────────────────────
--  Replace 3 with any user_id
SELECT *
FROM vw_user_account_dashboard
WHERE user_id = 3;


-- ── 7. Department-wise performance ───────────────────────────
SELECT
    department,
    code,
    total_borrows,
    active_borrowers,
    unique_books,
    problem_txns,
    ROUND(total_fines_accrued, 2) AS fines_accrued
FROM vw_dept_borrowing_summary;


-- ── 8. Consolidated library monthly account ──────────────────
SELECT *
FROM vw_library_account_monthly
LIMIT 24;   -- last 2 years


-- ── 9. Books with highest turnover ratio (copies scarce) ─────
SELECT
    title, authors,
    total_copies,
    borrows_last_year,
    turnover_ratio,
    available_copies
FROM vw_book_performance_all
WHERE total_copies <= 2
ORDER BY turnover_ratio DESC
LIMIT 10;


-- ── 10. Fine defaulters (outstanding > ₹0) ──────────────────
SELECT
    u.user_id,
    u.full_name,
    u.email,
    u.user_type,
    ua.outstanding_balance,
    ua.total_fines_accrued,
    ua.total_fines_paid,
    COUNT(f.fine_id) AS unpaid_fines
FROM user_accounts ua
JOIN users u ON u.user_id = ua.user_id
JOIN fines f ON f.user_id = ua.user_id AND f.status IN ('pending','partial')
WHERE ua.outstanding_balance > 0
GROUP BY u.user_id, u.full_name, u.email, u.user_type,
         ua.outstanding_balance, ua.total_fines_accrued, ua.total_fines_paid
ORDER BY ua.outstanding_balance DESC;