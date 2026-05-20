-- =============================================================
--  COLLEGE LIBRARY DATABASE
--  File 03: Analytics Views
-- =============================================================

USE college_library;

-- =============================================================
--  BOOK PERFORMANCE CLASSIFICATION
--  Top = borrowed ≥ 10x/year  |  Under = 3–9x  |  Low = 0–2x
-- =============================================================

-- ── Helper: per-book borrow counts in the last 365 days ──────
CREATE OR REPLACE VIEW vw_book_borrow_stats AS
SELECT
    b.book_id,
    b.isbn,
    b.title,
    GROUP_CONCAT(DISTINCT ba.author ORDER BY ba.seq SEPARATOR ', ') AS authors,
    b.publication_year,
    p.name           AS publisher,
    COUNT(bt.txn_id) AS borrows_last_year,
    COUNT(DISTINCT bt.user_id) AS unique_borrowers,
    SUM(CASE WHEN bt.return_date IS NULL AND bt.status = 'issued' THEN 1 ELSE 0 END) AS currently_issued,
    (SELECT COUNT(*) FROM book_copies bc WHERE bc.book_id = b.book_id AND bc.current_status = 'available') AS available_copies,
    (SELECT COUNT(*) FROM book_copies bc WHERE bc.book_id = b.book_id AND bc.current_status != 'retired') AS total_copies
FROM books b
LEFT JOIN book_authors ba  ON ba.book_id  = b.book_id
LEFT JOIN publishers   p   ON p.publisher_id = b.publisher_id
LEFT JOIN book_transactions bt
       ON bt.book_id    = b.book_id
      AND bt.issue_date >= DATE_SUB(CURRENT_DATE, INTERVAL 365 DAY)
WHERE b.is_active = 1
GROUP BY b.book_id, b.isbn, b.title, b.publication_year, p.name;


-- ── TOP PERFORMING BOOKS (≥ 10 borrows / year) ───────────────
CREATE OR REPLACE VIEW vw_top_performing_books AS
SELECT
    book_id,
    isbn,
    title,
    authors,
    publication_year,
    publisher,
    borrows_last_year,
    unique_borrowers,
    currently_issued,
    available_copies,
    total_copies,
    ROUND(borrows_last_year / NULLIF(total_copies, 0), 2) AS turnover_ratio,
    'TOP' AS performance_band
FROM vw_book_borrow_stats
WHERE borrows_last_year >= 10
ORDER BY borrows_last_year DESC;


-- ── UNDER PERFORMING BOOKS (3 – 9 borrows / year) ────────────
CREATE OR REPLACE VIEW vw_under_performing_books AS
SELECT
    book_id,
    isbn,
    title,
    authors,
    publication_year,
    publisher,
    borrows_last_year,
    unique_borrowers,
    currently_issued,
    available_copies,
    total_copies,
    ROUND(borrows_last_year / NULLIF(total_copies, 0), 2) AS turnover_ratio,
    'UNDER' AS performance_band
FROM vw_book_borrow_stats
WHERE borrows_last_year BETWEEN 3 AND 9
ORDER BY borrows_last_year DESC;


-- ── LOW PERFORMING BOOKS (0 – 2 borrows / year) ──────────────
CREATE OR REPLACE VIEW vw_low_performing_books AS
SELECT
    book_id,
    isbn,
    title,
    authors,
    publication_year,
    publisher,
    borrows_last_year,
    unique_borrowers,
    currently_issued,
    available_copies,
    total_copies,
    ROUND(borrows_last_year / NULLIF(total_copies, 0), 2) AS turnover_ratio,
    'LOW' AS performance_band
FROM vw_book_borrow_stats
WHERE borrows_last_year <= 2
ORDER BY borrows_last_year ASC;


-- ── CONSOLIDATED PERFORMANCE RANKING (all books) ─────────────
CREATE OR REPLACE VIEW vw_book_performance_all AS
SELECT
    book_id, isbn, title, authors, publication_year, publisher,
    borrows_last_year, unique_borrowers,
    currently_issued, available_copies, total_copies,
    ROUND(borrows_last_year / NULLIF(total_copies, 0), 2) AS turnover_ratio,
    CASE
        WHEN borrows_last_year >= 10 THEN 'TOP'
        WHEN borrows_last_year >= 3  THEN 'UNDER'
        ELSE                              'LOW'
    END AS performance_band,
    RANK() OVER (ORDER BY borrows_last_year DESC) AS borrow_rank
FROM vw_book_borrow_stats
ORDER BY borrows_last_year DESC;


-- =============================================================
--  MONTHLY FINE COLLECTION SUMMARY
-- =============================================================

CREATE OR REPLACE VIEW vw_monthly_fine_summary AS
SELECT
    YEAR(fp.paid_at)                                    AS yr,
    MONTH(fp.paid_at)                                   AS mo,
    DATE_FORMAT(fp.paid_at, '%Y-%m')                    AS year_month,
    COUNT(DISTINCT fp.fine_id)                          AS fines_paid_count,
    COUNT(DISTINCT f.user_id)                           AS unique_payers,
    SUM(fp.amount_paid)                                 AS total_collected,
    SUM(CASE WHEN f.fine_type = 'overdue'  THEN fp.amount_paid ELSE 0 END) AS overdue_collected,
    SUM(CASE WHEN f.fine_type = 'damage'   THEN fp.amount_paid ELSE 0 END) AS damage_collected,
    SUM(CASE WHEN f.fine_type = 'loss'     THEN fp.amount_paid ELSE 0 END) AS loss_collected,
    SUM(CASE WHEN f.fine_type = 'other'    THEN fp.amount_paid ELSE 0 END) AS other_collected,
    -- Raised this month (not necessarily paid)
    (SELECT COALESCE(SUM(f2.final_amount), 0)
     FROM   fines f2
     WHERE  YEAR(f2.raised_on)  = YEAR(fp.paid_at)
       AND  MONTH(f2.raised_on) = MONTH(fp.paid_at))   AS total_raised_in_month,
    -- Waived this month
    (SELECT COALESCE(SUM(f2.waiver_amount), 0)
     FROM   fines f2
     WHERE  YEAR(f2.raised_on)  = YEAR(fp.paid_at)
       AND  MONTH(f2.raised_on) = MONTH(fp.paid_at))   AS total_waived_in_month,
    -- Still pending (across all time, as of now)
    (SELECT COALESCE(SUM(f2.final_amount - COALESCE(
        (SELECT SUM(fp2.amount_paid) FROM fine_payments fp2 WHERE fp2.fine_id = f2.fine_id), 0)), 0)
     FROM   fines f2
     WHERE  f2.status IN ('pending','partial'))         AS total_pending_all_time
FROM fine_payments fp
JOIN fines f ON f.fine_id = fp.fine_id
GROUP BY yr, mo, year_month
ORDER BY yr DESC, mo DESC;


-- =============================================================
--  MONTHLY BOOK LEDGER SUMMARY
-- =============================================================

CREATE OR REPLACE VIEW vw_monthly_book_ledger AS
SELECT
    YEAR(issue_date)                        AS yr,
    MONTH(issue_date)                       AS mo,
    DATE_FORMAT(issue_date, '%Y-%m')        AS year_month,
    COUNT(txn_id)                           AS total_issued,
    SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) AS total_returned,
    SUM(CASE WHEN status = 'overdue'  THEN 1 ELSE 0 END) AS currently_overdue,
    SUM(CASE WHEN status = 'lost'     THEN 1 ELSE 0 END) AS reported_lost,
    SUM(CASE WHEN condition_at_return = 'damaged' THEN 1 ELSE 0 END) AS returned_damaged,
    COUNT(DISTINCT user_id)                 AS unique_borrowers,
    COUNT(DISTINCT book_id)                 AS unique_books_borrowed,
    -- Average borrow duration for returned books
    ROUND(AVG(CASE WHEN return_date IS NOT NULL
                   THEN DATEDIFF(return_date, issue_date) END), 1) AS avg_borrow_days,
    -- Average days overdue (for overdue returns)
    ROUND(AVG(CASE WHEN return_date > due_date
                   THEN DATEDIFF(return_date, due_date) END), 1) AS avg_days_overdue
FROM book_transactions
GROUP BY yr, mo, year_month
ORDER BY yr DESC, mo DESC;


-- =============================================================
--  DEPARTMENT-WISE BORROWING (bonus analytics)
-- =============================================================

CREATE OR REPLACE VIEW vw_dept_borrowing_summary AS
SELECT
    d.department_id,
    d.name           AS department,
    d.code,
    COUNT(bt.txn_id) AS total_borrows,
    COUNT(DISTINCT bt.user_id)  AS active_borrowers,
    COUNT(DISTINCT bt.book_id)  AS unique_books,
    SUM(CASE WHEN bt.status IN ('overdue','lost') THEN 1 ELSE 0 END) AS problem_txns,
    COALESCE(SUM(f.final_amount), 0) AS total_fines_accrued
FROM departments d
LEFT JOIN students    s  ON s.department_id = d.department_id
LEFT JOIN users       u  ON u.user_id = s.user_id AND u.is_active = 1
LEFT JOIN book_transactions bt ON bt.user_id   = u.user_id
LEFT JOIN fines        f  ON f.user_id = u.user_id
GROUP BY d.department_id, d.name, d.code
ORDER BY total_borrows DESC;


-- =============================================================
--  USER ACCOUNT DASHBOARD VIEW
-- =============================================================

CREATE OR REPLACE VIEW vw_user_account_dashboard AS
SELECT
    u.user_id,
    u.username,
    u.full_name,
    u.email,
    u.user_type,
    ua.total_books_borrowed,
    ua.total_books_returned,
    (ua.total_books_borrowed - ua.total_books_returned) AS currently_borrowed,
    ua.total_fines_accrued,
    ua.total_fines_paid,
    ua.total_fines_waived,
    ua.outstanding_balance,
    (SELECT COUNT(*) FROM book_transactions bt
     WHERE  bt.user_id = u.user_id AND bt.status = 'overdue') AS overdue_books,
    ua.last_activity,
    -- Student-specific
    s.roll_number,
    dep.name AS department,
    s.year_of_study,
    s.program
FROM users u
JOIN user_accounts ua ON ua.user_id = u.user_id
LEFT JOIN students  s   ON s.user_id  = u.user_id
LEFT JOIN departments dep ON dep.department_id = s.department_id
WHERE u.is_active = 1;


-- =============================================================
--  CONSOLIDATED LIBRARY ACCOUNT MONTHLY ROLLUP
-- =============================================================

CREATE OR REPLACE VIEW vw_library_account_monthly AS
SELECT
    DATE_FORMAT(ledger_date, '%Y-%m')      AS year_month,
    SUM(books_issued)                       AS total_issued,
    SUM(books_returned)                     AS total_returned,
    SUM(new_books_added)                    AS new_acquisitions,
    SUM(books_retired)                      AS retirements,
    SUM(fines_raised)                       AS fines_raised,
    SUM(fines_collected)                    AS fines_collected,
    SUM(fines_waived)                       AS fines_waived,
    MAX(active_members)                     AS peak_active_members,
    MAX(running_balance)                    AS month_end_balance
FROM library_account
GROUP BY year_month
ORDER BY year_month DESC;