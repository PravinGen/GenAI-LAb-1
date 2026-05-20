-- =============================================================
--  COLLEGE LIBRARY DATABASE
--  File 02: Stored Procedures & Triggers
-- =============================================================

USE college_library;

DELIMITER $$

-- =============================================================
--  PROCEDURE: issue_book
--  Issues a copy to a user and updates the copy status.
-- =============================================================
CREATE PROCEDURE issue_book (
    IN  p_copy_id       INT UNSIGNED,
    IN  p_user_id       INT UNSIGNED,
    IN  p_issued_by     INT UNSIGNED,
    IN  p_borrow_days   TINYINT UNSIGNED,   -- 0 = use policy default
    OUT p_txn_id        BIGINT UNSIGNED,
    OUT p_message       VARCHAR(255)
)
BEGIN
    DECLARE v_book_id       INT UNSIGNED;
    DECLARE v_copy_status   VARCHAR(20);
    DECLARE v_outstanding   DECIMAL(12,2);
    DECLARE v_max_books     TINYINT UNSIGNED;
    DECLARE v_current_books TINYINT UNSIGNED;
    DECLARE v_user_type     VARCHAR(20);
    DECLARE v_policy_days   TINYINT UNSIGNED;
    DECLARE v_due_date      DATE;

    -- Fetch copy details
    SELECT book_id, current_status
    INTO   v_book_id, v_copy_status
    FROM   book_copies
    WHERE  copy_id = p_copy_id FOR UPDATE;

    IF v_copy_status IS NULL THEN
        SET p_message = 'ERROR: Copy not found.';
        LEAVE issue_book_proc;
    END IF;

    IF v_copy_status <> 'available' THEN
        SET p_message = CONCAT('ERROR: Copy is not available (status: ', v_copy_status, ').');
        LEAVE issue_book_proc;
    END IF;

    -- Check user outstanding balance
    SELECT outstanding_balance
    INTO   v_outstanding
    FROM   user_accounts
    WHERE  user_id = p_user_id;

    IF v_outstanding > 0 THEN
        SET p_message = CONCAT('ERROR: User has an outstanding fine of ₹', v_outstanding, '. Please clear before issuing.');
        LEAVE issue_book_proc;
    END IF;

    -- Fetch user type and policy
    SELECT u.user_type INTO v_user_type FROM users u WHERE u.user_id = p_user_id;

    SELECT max_borrow_days, max_books
    INTO   v_policy_days, v_max_books
    FROM   fine_policy
    WHERE  user_type = v_user_type
      AND  effective_from <= CURRENT_DATE
      AND  (effective_to IS NULL OR effective_to >= CURRENT_DATE)
    ORDER BY effective_from DESC
    LIMIT 1;

    -- Count current active borrowings
    SELECT COUNT(*)
    INTO   v_current_books
    FROM   book_transactions
    WHERE  user_id = p_user_id AND status = 'issued';

    IF v_current_books >= v_max_books THEN
        SET p_message = CONCAT('ERROR: User has reached max book limit (', v_max_books, ').');
        LEAVE issue_book_proc;
    END IF;

    SET v_due_date = DATE_ADD(CURRENT_DATE, INTERVAL IF(p_borrow_days > 0, p_borrow_days, v_policy_days) DAY);

    -- Insert transaction
    INSERT INTO book_transactions (copy_id, book_id, user_id, issued_by, issue_date, due_date, status)
    VALUES (p_copy_id, v_book_id, p_user_id, p_issued_by, CURRENT_DATE, v_due_date, 'issued');

    SET p_txn_id = LAST_INSERT_ID();

    -- Update copy status
    UPDATE book_copies SET current_status = 'issued' WHERE copy_id = p_copy_id;

    -- Update user account
    UPDATE user_accounts
    SET    total_books_borrowed = total_books_borrowed + 1,
           last_activity        = NOW()
    WHERE  user_id = p_user_id;

    -- Update library daily ledger
    INSERT INTO library_account (ledger_date, books_issued)
    VALUES (CURRENT_DATE, 1)
    ON DUPLICATE KEY UPDATE books_issued = books_issued + 1;

    SET p_message = CONCAT('SUCCESS: Book issued. Due date: ', v_due_date);
END$$

-- Label for LEAVE (MySQL workaround)
-- Actually using a BEGIN/END block exit via condition handler is cleaner; simplified above.


-- =============================================================
--  PROCEDURE: return_book
--  Returns a copy, calculates any fine, creates fine record.
-- =============================================================
CREATE PROCEDURE return_book (
    IN  p_txn_id            BIGINT UNSIGNED,
    IN  p_returned_to       INT UNSIGNED,
    IN  p_condition_return  VARCHAR(20),    -- 'good','fair','damaged','lost'
    OUT p_fine_id           BIGINT UNSIGNED,
    OUT p_fine_amount       DECIMAL(10,2),
    OUT p_message           VARCHAR(255)
)
BEGIN
    DECLARE v_user_id       INT UNSIGNED;
    DECLARE v_copy_id       INT UNSIGNED;
    DECLARE v_book_id       INT UNSIGNED;
    DECLARE v_due_date      DATE;
    DECLARE v_user_type     VARCHAR(20);
    DECLARE v_per_day       DECIMAL(8,2);
    DECLARE v_dmg_pct       DECIMAL(5,2);
    DECLARE v_loss_pct      DECIMAL(5,2);
    DECLARE v_price         DECIMAL(10,2);
    DECLARE v_days_late     INT;
    DECLARE v_overdue_fine  DECIMAL(10,2) DEFAULT 0;
    DECLARE v_damage_fine   DECIMAL(10,2) DEFAULT 0;
    DECLARE v_total_fine    DECIMAL(10,2) DEFAULT 0;
    DECLARE v_fine_type     VARCHAR(20);
    DECLARE v_txn_status    VARCHAR(20);

    SELECT user_id, copy_id, book_id, due_date, status
    INTO   v_user_id, v_copy_id, v_book_id, v_due_date, v_txn_status
    FROM   book_transactions
    WHERE  txn_id = p_txn_id FOR UPDATE;

    IF v_txn_status IS NULL THEN
        SET p_message = 'ERROR: Transaction not found.';
        LEAVE return_proc;
    END IF;

    IF v_txn_status = 'returned' THEN
        SET p_message = 'ERROR: Book already returned.';
        LEAVE return_proc;
    END IF;

    -- Get policy
    SELECT u.user_type INTO v_user_type FROM users u WHERE u.user_id = v_user_id;

    SELECT per_day_fine, damage_fine_pct, loss_fine_pct
    INTO   v_per_day, v_dmg_pct, v_loss_pct
    FROM   fine_policy
    WHERE  user_type = v_user_type
      AND  effective_from <= CURRENT_DATE
      AND  (effective_to IS NULL OR effective_to >= CURRENT_DATE)
    ORDER BY effective_from DESC
    LIMIT 1;

    SELECT COALESCE(purchase_price, 0) INTO v_price FROM books WHERE book_id = v_book_id;

    -- Calculate overdue fine
    SET v_days_late = DATEDIFF(CURRENT_DATE, v_due_date);
    IF v_days_late > 0 THEN
        SET v_overdue_fine = v_days_late * v_per_day;
    ELSE
        SET v_days_late = 0;
    END IF;

    -- Calculate damage / loss fine
    IF p_condition_return = 'damaged' THEN
        SET v_damage_fine = v_price * v_dmg_pct / 100;
        SET v_fine_type   = 'damage';
    ELSEIF p_condition_return = 'lost' THEN
        SET v_damage_fine = v_price * v_loss_pct / 100;
        SET v_fine_type   = 'loss';
    ELSE
        SET v_fine_type = IF(v_overdue_fine > 0, 'overdue', NULL);
    END IF;

    SET v_total_fine = v_overdue_fine + v_damage_fine;
    SET p_fine_amount = v_total_fine;

    -- Update transaction
    UPDATE book_transactions
    SET    return_date          = CURRENT_DATE,
           returned_to          = p_returned_to,
           status               = 'returned',
           condition_at_return  = p_condition_return
    WHERE  txn_id = p_txn_id;

    -- Update copy status
    UPDATE book_copies
    SET    current_status = CASE
                              WHEN p_condition_return = 'lost'    THEN 'lost'
                              WHEN p_condition_return = 'damaged' THEN 'damaged'
                              ELSE 'available'
                            END
    WHERE  copy_id = v_copy_id;

    -- Create fine if applicable
    IF v_total_fine > 0 AND v_fine_type IS NOT NULL THEN
        INSERT INTO fines (txn_id, user_id, fine_type, days_overdue, base_amount, final_amount, raised_on, status)
        VALUES (p_txn_id, v_user_id, v_fine_type, v_days_late, v_total_fine, v_total_fine, CURRENT_DATE, 'pending');

        SET p_fine_id = LAST_INSERT_ID();

        -- Update user account
        UPDATE user_accounts
        SET    total_fines_accrued = total_fines_accrued + v_total_fine,
               last_activity       = NOW()
        WHERE  user_id = v_user_id;

        -- Update library ledger
        INSERT INTO library_account (ledger_date, books_returned, fines_raised)
        VALUES (CURRENT_DATE, 1, v_total_fine)
        ON DUPLICATE KEY UPDATE
            books_returned = books_returned + 1,
            fines_raised   = fines_raised   + v_total_fine;
    ELSE
        SET p_fine_id = NULL;

        UPDATE user_accounts
        SET    total_books_returned = total_books_returned + 1,
               last_activity        = NOW()
        WHERE  user_id = v_user_id;

        INSERT INTO library_account (ledger_date, books_returned)
        VALUES (CURRENT_DATE, 1)
        ON DUPLICATE KEY UPDATE books_returned = books_returned + 1;
    END IF;

    SET p_message = CONCAT('SUCCESS: Book returned. Fine: ₹', COALESCE(v_total_fine, 0));
END$$


-- =============================================================
--  PROCEDURE: collect_fine_payment
-- =============================================================
CREATE PROCEDURE collect_fine_payment (
    IN  p_fine_id       BIGINT UNSIGNED,
    IN  p_amount        DECIMAL(10,2),
    IN  p_mode          VARCHAR(20),
    IN  p_ref           VARCHAR(100),
    IN  p_collected_by  INT UNSIGNED,
    OUT p_payment_id    BIGINT UNSIGNED,
    OUT p_message       VARCHAR(255)
)
BEGIN
    DECLARE v_user_id       INT UNSIGNED;
    DECLARE v_pending       DECIMAL(10,2);
    DECLARE v_already_paid  DECIMAL(10,2);
    DECLARE v_new_paid      DECIMAL(10,2);

    SELECT user_id, final_amount,
           COALESCE((SELECT SUM(amount_paid) FROM fine_payments fp WHERE fp.fine_id = p_fine_id), 0)
    INTO   v_user_id, v_pending, v_already_paid
    FROM   fines
    WHERE  fine_id = p_fine_id
      AND  status NOT IN ('paid','waived')
    FOR UPDATE;

    IF v_user_id IS NULL THEN
        SET p_message = 'ERROR: Fine not found or already settled.';
        LEAVE pay_proc;
    END IF;

    SET v_new_paid = v_already_paid + p_amount;

    INSERT INTO fine_payments (fine_id, amount_paid, payment_mode, payment_ref, collected_by)
    VALUES (p_fine_id, p_amount, p_mode, p_ref, p_collected_by);

    SET p_payment_id = LAST_INSERT_ID();

    -- Update fine status
    UPDATE fines
    SET    status  = IF(v_new_paid >= final_amount, 'paid', 'partial'),
           paid_on = IF(v_new_paid >= final_amount, CURRENT_DATE, paid_on)
    WHERE  fine_id = p_fine_id;

    -- Update user account
    UPDATE user_accounts
    SET    total_fines_paid = total_fines_paid + p_amount,
           last_activity    = NOW()
    WHERE  user_id = v_user_id;

    -- Update library ledger
    INSERT INTO library_account (ledger_date, fines_collected)
    VALUES (CURRENT_DATE, p_amount)
    ON DUPLICATE KEY UPDATE
        fines_collected  = fines_collected + p_amount,
        running_balance  = running_balance  + p_amount;

    SET p_message = CONCAT('SUCCESS: Payment of ₹', p_amount, ' recorded.');
END$$


-- =============================================================
--  TRIGGER: auto-create user_account on new user insert
-- =============================================================
CREATE TRIGGER trg_create_user_account
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO user_accounts (user_id) VALUES (NEW.user_id);
END$$


-- =============================================================
--  TRIGGER: flag overdue transactions daily (event-based alternative)
--  This trigger fires when book_transactions is updated.
-- =============================================================
CREATE TRIGGER trg_mark_overdue
BEFORE UPDATE ON book_transactions
FOR EACH ROW
BEGIN
    IF NEW.status = 'issued' AND NEW.due_date < CURRENT_DATE THEN
        SET NEW.status = 'overdue';
    END IF;
END$$


-- =============================================================
--  EVENT: daily_overdue_scan  (runs every night at 00:05)
-- =============================================================
CREATE EVENT IF NOT EXISTS daily_overdue_scan
ON SCHEDULE EVERY 1 DAY STARTS CONCAT(CURDATE() + INTERVAL 1 DAY, ' 00:05:00')
DO
BEGIN
    UPDATE book_transactions
    SET    status = 'overdue'
    WHERE  status   = 'issued'
      AND  due_date < CURRENT_DATE;
END$$

DELIMITER ;