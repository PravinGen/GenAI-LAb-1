-- =============================================================
--  COLLEGE LIBRARY DATABASE SCHEMA
--  File 01: Table Definitions
--  Database: MySQL 8.0+
-- =============================================================

CREATE DATABASE IF NOT EXISTS college_library
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE college_library;

-- =============================================================
--  SECTION 1: REFERENCE / LOOKUP TABLES
-- =============================================================

CREATE TABLE genres (
    genre_id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(60)  NOT NULL UNIQUE,
    description   VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE publishers (
    publisher_id  SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    city          VARCHAR(80),
    country       VARCHAR(80),
    website       VARCHAR(200)
) ENGINE=InnoDB;

CREATE TABLE departments (
    department_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE,
    code          VARCHAR(10)  NOT NULL UNIQUE    -- e.g. 'CSE', 'ECE'
) ENGINE=InnoDB;

CREATE TABLE fine_policy (
    policy_id         TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_type         ENUM('student','librarian') NOT NULL,
    per_day_fine      DECIMAL(8,2) NOT NULL DEFAULT 2.00,   -- ₹ per day
    damage_fine_pct   DECIMAL(5,2) NOT NULL DEFAULT 50.00,  -- % of book price
    loss_fine_pct     DECIMAL(5,2) NOT NULL DEFAULT 150.00, -- % of book price
    max_borrow_days   TINYINT UNSIGNED NOT NULL DEFAULT 14,
    max_books         TINYINT UNSIGNED NOT NULL DEFAULT 5,
    effective_from    DATE NOT NULL,
    effective_to      DATE,
    UNIQUE KEY uq_policy_user_period (user_type, effective_from)
) ENGINE=InnoDB;

-- =============================================================
--  SECTION 2: BOOKS
-- =============================================================

CREATE TABLE books (
    book_id         INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
    isbn            VARCHAR(20)     NOT NULL UNIQUE,
    title           VARCHAR(300)    NOT NULL,
    subtitle        VARCHAR(300),
    publisher_id    SMALLINT UNSIGNED,
    edition         VARCHAR(30),
    publication_year YEAR,
    language        VARCHAR(40)     DEFAULT 'English',
    total_pages     SMALLINT UNSIGNED,
    cover_image_url VARCHAR(500),
    purchase_price  DECIMAL(10,2),
    added_on        DATE            NOT NULL DEFAULT (CURRENT_DATE),
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    CONSTRAINT fk_book_publisher FOREIGN KEY (publisher_id)
        REFERENCES publishers (publisher_id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE book_authors (
    book_id   INT UNSIGNED    NOT NULL,
    author    VARCHAR(150)    NOT NULL,
    seq       TINYINT UNSIGNED NOT NULL DEFAULT 1,   -- 1 = primary author
    PRIMARY KEY (book_id, seq),
    CONSTRAINT fk_ba_book FOREIGN KEY (book_id)
        REFERENCES books (book_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE book_genres (
    book_id   INT UNSIGNED    NOT NULL,
    genre_id  TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (book_id, genre_id),
    CONSTRAINT fk_bg_book  FOREIGN KEY (book_id)  REFERENCES books  (book_id)  ON DELETE CASCADE,
    CONSTRAINT fk_bg_genre FOREIGN KEY (genre_id) REFERENCES genres (genre_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Physical copies of a book
CREATE TABLE book_copies (
    copy_id         INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
    book_id         INT UNSIGNED    NOT NULL,
    barcode         VARCHAR(50)     NOT NULL UNIQUE,
    rack_location   VARCHAR(30),               -- shelf/rack code
    condition_on_add ENUM('new','good','fair','poor') NOT NULL DEFAULT 'new',
    current_status  ENUM('available','issued','reserved','damaged','lost','retired')
                    NOT NULL DEFAULT 'available',
    acquired_on     DATE,
    retired_on      DATE,
    CONSTRAINT fk_copy_book FOREIGN KEY (book_id)
        REFERENCES books (book_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =============================================================
--  SECTION 3: USERS
-- =============================================================

CREATE TABLE users (
    user_id         INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
    username        VARCHAR(50)     NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    full_name       VARCHAR(150)    NOT NULL,
    email           VARCHAR(150)    NOT NULL UNIQUE,
    phone           VARCHAR(20),
    address         TEXT,
    date_of_birth   DATE,
    gender          ENUM('M','F','Other'),
    photo_url       VARCHAR(500),
    user_type       ENUM('student','librarian') NOT NULL,
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE students (
    user_id         INT UNSIGNED    PRIMARY KEY,
    roll_number     VARCHAR(30)     NOT NULL UNIQUE,
    department_id   SMALLINT UNSIGNED NOT NULL,
    year_of_study   TINYINT UNSIGNED,           -- 1-5
    program         ENUM('UG','PG','PhD') NOT NULL DEFAULT 'UG',
    batch_year      YEAR            NOT NULL,
    enrollment_date DATE            NOT NULL DEFAULT (CURRENT_DATE),
    graduation_date DATE,
    CONSTRAINT fk_student_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_student_dept FOREIGN KEY (department_id)
        REFERENCES departments (department_id) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE librarians (
    user_id         INT UNSIGNED    PRIMARY KEY,
    employee_id     VARCHAR(30)     NOT NULL UNIQUE,
    designation     VARCHAR(80),
    joining_date    DATE            NOT NULL DEFAULT (CURRENT_DATE),
    can_approve_fines  TINYINT(1)   NOT NULL DEFAULT 0,
    is_admin        TINYINT(1)      NOT NULL DEFAULT 0,
    CONSTRAINT fk_lib_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================================
--  SECTION 4: TRANSACTIONS — ISSUE & RETURN
-- =============================================================

CREATE TABLE book_transactions (
    txn_id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    copy_id         INT UNSIGNED    NOT NULL,
    book_id         INT UNSIGNED    NOT NULL,       -- denorm for faster analytics
    user_id         INT UNSIGNED    NOT NULL,
    issued_by       INT UNSIGNED    NOT NULL,       -- librarian user_id
    returned_to     INT UNSIGNED,                   -- librarian user_id
    issue_date      DATE            NOT NULL DEFAULT (CURRENT_DATE),
    due_date        DATE            NOT NULL,
    return_date     DATE,
    status          ENUM('issued','returned','overdue','lost') NOT NULL DEFAULT 'issued',
    condition_at_return ENUM('good','fair','damaged','lost'),
    remarks         TEXT,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_txn_copy    FOREIGN KEY (copy_id)     REFERENCES book_copies (copy_id),
    CONSTRAINT fk_txn_book    FOREIGN KEY (book_id)     REFERENCES books       (book_id),
    CONSTRAINT fk_txn_user    FOREIGN KEY (user_id)     REFERENCES users       (user_id),
    CONSTRAINT fk_txn_issued  FOREIGN KEY (issued_by)   REFERENCES users       (user_id),
    CONSTRAINT fk_txn_return  FOREIGN KEY (returned_to) REFERENCES users       (user_id),
    INDEX idx_txn_user    (user_id),
    INDEX idx_txn_book    (book_id),
    INDEX idx_txn_dates   (issue_date, due_date, return_date),
    INDEX idx_txn_status  (status)
) ENGINE=InnoDB;

-- =============================================================
--  SECTION 5: FINES & DAMAGES
-- =============================================================

CREATE TABLE fines (
    fine_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    txn_id          BIGINT UNSIGNED NOT NULL UNIQUE,  -- 1-to-1 with transaction
    user_id         INT UNSIGNED    NOT NULL,          -- denorm
    fine_type       ENUM('overdue','damage','loss','other') NOT NULL,
    days_overdue    SMALLINT UNSIGNED DEFAULT 0,
    base_amount     DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    waiver_amount   DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    final_amount    DECIMAL(10,2)   NOT NULL DEFAULT 0.00,  -- base - waiver
    waiver_reason   VARCHAR(255),
    waived_by       INT UNSIGNED,                   -- librarian who waived
    status          ENUM('pending','paid','waived','partial') NOT NULL DEFAULT 'pending',
    raised_on       DATE            NOT NULL DEFAULT (CURRENT_DATE),
    paid_on         DATE,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_fine_txn     FOREIGN KEY (txn_id)    REFERENCES book_transactions (txn_id),
    CONSTRAINT fk_fine_user    FOREIGN KEY (user_id)   REFERENCES users (user_id),
    CONSTRAINT fk_fine_waiver  FOREIGN KEY (waived_by) REFERENCES users (user_id),
    INDEX idx_fine_user   (user_id),
    INDEX idx_fine_status (status),
    INDEX idx_fine_month  (raised_on)
) ENGINE=InnoDB;

CREATE TABLE fine_payments (
    payment_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fine_id         BIGINT UNSIGNED NOT NULL,
    amount_paid     DECIMAL(10,2)   NOT NULL,
    payment_mode    ENUM('cash','upi','card','online','adjustment') NOT NULL DEFAULT 'cash',
    payment_ref     VARCHAR(100),
    collected_by    INT UNSIGNED    NOT NULL,       -- librarian
    paid_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes           VARCHAR(255),
    CONSTRAINT fk_fp_fine FOREIGN KEY (fine_id)      REFERENCES fines (fine_id),
    CONSTRAINT fk_fp_lib  FOREIGN KEY (collected_by) REFERENCES users (user_id),
    INDEX idx_fp_fine  (fine_id),
    INDEX idx_fp_month (paid_at)
) ENGINE=InnoDB;

-- =============================================================
--  SECTION 6: ACCOUNTS
-- =============================================================

-- Per-user ledger (wallet/balance view)
CREATE TABLE user_accounts (
    account_id      INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNSIGNED    NOT NULL UNIQUE,
    total_fines_accrued  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_fines_paid     DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_fines_waived   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    outstanding_balance  DECIMAL(12,2) GENERATED ALWAYS AS
                         (total_fines_accrued - total_fines_paid - total_fines_waived) STORED,
    total_books_borrowed MEDIUMINT UNSIGNED NOT NULL DEFAULT 0,
    total_books_returned MEDIUMINT UNSIGNED NOT NULL DEFAULT 0,
    last_activity    DATETIME,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_ua_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Library-wide consolidated ledger (one row per day)
CREATE TABLE library_account (
    ledger_id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ledger_date          DATE           NOT NULL UNIQUE,
    books_issued         SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    books_returned       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    fines_raised         DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
    fines_collected      DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
    fines_waived         DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
    new_books_added      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    books_retired        SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    active_members       MEDIUMINT UNSIGNED NOT NULL DEFAULT 0,
    running_balance      DECIMAL(14,2)  NOT NULL DEFAULT 0.00,  -- cumulative fines collected
    created_at           DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_la_month (ledger_date)
) ENGINE=InnoDB;

-- =============================================================
--  SECTION 7: RESERVATIONS (supporting table)
-- =============================================================

CREATE TABLE reservations (
    reservation_id  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    book_id         INT UNSIGNED    NOT NULL,
    user_id         INT UNSIGNED    NOT NULL,
    reserved_on     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_on      DATE            NOT NULL,
    status          ENUM('active','fulfilled','expired','cancelled') NOT NULL DEFAULT 'active',
    fulfilled_txn   BIGINT UNSIGNED,
    CONSTRAINT fk_res_book FOREIGN KEY (book_id) REFERENCES books (book_id),
    CONSTRAINT fk_res_user FOREIGN KEY (user_id) REFERENCES users (user_id),
    CONSTRAINT fk_res_txn  FOREIGN KEY (fulfilled_txn) REFERENCES book_transactions (txn_id),
    INDEX idx_res_book (book_id),
    INDEX idx_res_user (user_id)
) ENGINE=InnoDB;