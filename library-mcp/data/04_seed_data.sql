-- =============================================================
--  COLLEGE LIBRARY DATABASE
--  File 04: Seed / Sample Data
-- =============================================================

USE college_library;

-- Fine policy
INSERT INTO fine_policy (user_type, per_day_fine, damage_fine_pct, loss_fine_pct, max_borrow_days, max_books, effective_from)
VALUES
  ('student',   2.00, 50.00, 150.00, 14, 5, '2024-01-01'),
  ('librarian', 0.00, 25.00, 100.00, 30, 10, '2024-01-01');

-- Genres
INSERT INTO genres (name) VALUES
  ('Computer Science'), ('Mathematics'), ('Physics'), ('Chemistry'),
  ('Literature'), ('History'), ('Economics'), ('Engineering'),
  ('Management'), ('Reference');

-- Publishers
INSERT INTO publishers (name, city, country) VALUES
  ('McGraw-Hill', 'New York', 'USA'),
  ('Pearson', 'London', 'UK'),
  ('Wiley', 'Hoboken', 'USA'),
  ('Oxford University Press', 'Oxford', 'UK'),
  ('Tata McGraw-Hill', 'New Delhi', 'India'),
  ('Arihant Publications', 'Meerut', 'India');

-- Departments
INSERT INTO departments (name, code) VALUES
  ('Computer Science & Engineering', 'CSE'),
  ('Electronics & Communication', 'ECE'),
  ('Mechanical Engineering', 'ME'),
  ('Civil Engineering', 'CE'),
  ('Information Technology', 'IT'),
  ('Physics', 'PHY'),
  ('Mathematics', 'MATH'),
  ('Chemistry', 'CHEM');

-- Books
INSERT INTO books (isbn, title, publisher_id, edition, publication_year, purchase_price) VALUES
  ('978-0-13-468599-1', 'The C Programming Language',          3, '2nd', 1988, 450.00),
  ('978-0-13-110362-7', 'Introduction to Algorithms',          1, '4th', 2022, 850.00),
  ('978-0-07-338487-1', 'Database System Concepts',            1, '7th', 2019, 750.00),
  ('978-0-13-468468-0', 'Operating System Concepts',           2, '10th',2018, 800.00),
  ('978-0-471-43338-1', 'Engineering Mathematics',             3, '3rd', 2016, 550.00),
  ('978-0-19-965426-0', 'Modern Physics',                      4, '2nd', 2020, 620.00),
  ('978-81-203-4874-4', 'Principles of Management',            5, '5th', 2017, 380.00),
  ('978-0-07-070949-2', 'Electric Circuits',                   1, '11th',2021, 920.00),
  ('978-93-80874-32-1', 'Strength of Materials',               6, '1st', 2018, 420.00),
  ('978-0-13-235088-4', 'Computer Networks',                   2, '6th', 2021, 780.00);

-- Authors
INSERT INTO book_authors (book_id, author, seq) VALUES
  (1, 'Brian W. Kernighan', 1), (1, 'Dennis M. Ritchie', 2),
  (2, 'Thomas H. Cormen', 1),   (2, 'Charles E. Leiserson', 2),
  (3, 'Abraham Silberschatz', 1),(3, 'Henry F. Korth', 2),
  (4, 'Abraham Silberschatz', 1),(4, 'Greg Gagne', 2),
  (5, 'Erwin Kreyszig', 1),
  (6, 'Paul A. Tipler', 1),
  (7, 'Harold Koontz', 1),      (7, 'Heinz Weihrich', 2),
  (8, 'James W. Nilsson', 1),
  (9, 'R. K. Bansal', 1),
  (10,'Andrew S. Tanenbaum', 1),(10,'David J. Wetherall', 2);

-- Book genre mapping
INSERT INTO book_genres (book_id, genre_id) VALUES
  (1,1),(2,1),(3,1),(4,1),(10,1),
  (5,2),(6,3),(7,9),(8,8),(9,8);

-- Book copies (2-3 per book)
INSERT INTO book_copies (book_id, barcode, rack_location, condition_on_add, acquired_on) VALUES
  (1,'LIB-C-00101','A1-S2','good','2023-06-01'),
  (1,'LIB-C-00102','A1-S2','good','2023-06-01'),
  (2,'LIB-C-00201','A1-S3','new', '2023-07-15'),
  (2,'LIB-C-00202','A1-S3','new', '2023-07-15'),
  (2,'LIB-C-00203','A1-S3','good','2023-07-15'),
  (3,'LIB-C-00301','A2-S1','good','2022-01-10'),
  (3,'LIB-C-00302','A2-S1','fair','2020-06-01'),
  (4,'LIB-C-00401','A2-S2','new', '2023-09-01'),
  (5,'LIB-C-00501','B1-S1','good','2022-03-20'),
  (5,'LIB-C-00502','B1-S1','good','2022-03-20'),
  (6,'LIB-C-00601','B1-S2','new', '2023-11-01'),
  (7,'LIB-C-00701','B2-S1','fair','2021-08-15'),
  (8,'LIB-C-00801','C1-S1','new', '2024-01-05'),
  (8,'LIB-C-00802','C1-S1','new', '2024-01-05'),
  (9,'LIB-C-00901','C1-S2','good','2022-05-12'),
  (10,'LIB-C-01001','C2-S1','new','2023-10-20'),
  (10,'LIB-C-01002','C2-S1','good','2023-10-20');

-- Users: 2 librarians + 8 students
INSERT INTO users (username, password_hash, full_name, email, phone, user_type) VALUES
  ('lib_admin',    '$2b$12$hashedpassword1', 'Ramesh Kumar',     'ramesh.kumar@library.edu',   '9876543210', 'librarian'),
  ('lib_staff',    '$2b$12$hashedpassword2', 'Sunita Sharma',    'sunita.sharma@library.edu',  '9876543211', 'librarian'),
  ('stu_2201',     '$2b$12$hashedpassword3', 'Arjun Verma',      'arjun.verma@college.edu',    '9871000001', 'student'),
  ('stu_2202',     '$2b$12$hashedpassword4', 'Priya Patel',      'priya.patel@college.edu',    '9871000002', 'student'),
  ('stu_2203',     '$2b$12$hashedpassword5', 'Ravi Singh',       'ravi.singh@college.edu',     '9871000003', 'student'),
  ('stu_2204',     '$2b$12$hashedpassword6', 'Anjali Gupta',     'anjali.gupta@college.edu',   '9871000004', 'student'),
  ('stu_2205',     '$2b$12$hashedpassword7', 'Vikram Yadav',     'vikram.yadav@college.edu',   '9871000005', 'student'),
  ('stu_2206',     '$2b$12$hashedpassword8', 'Deepa Nair',       'deepa.nair@college.edu',     '9871000006', 'student'),
  ('stu_2207',     '$2b$12$hashedpassword9', 'Suresh Mishra',    'suresh.mishra@college.edu',  '9871000007', 'student'),
  ('stu_2208',     '$2b$12$hashedpassword0', 'Kavya Reddy',      'kavya.reddy@college.edu',    '9871000008', 'student');

-- Librarian profiles
INSERT INTO librarians (user_id, employee_id, designation, joining_date, can_approve_fines, is_admin) VALUES
  (1, 'EMP-001', 'Chief Librarian', '2015-06-01', 1, 1),
  (2, 'EMP-002', 'Library Assistant','2020-08-01', 0, 0);

-- Student profiles
INSERT INTO students (user_id, roll_number, department_id, year_of_study, program, batch_year, enrollment_date) VALUES
  (3, '22CSE001', 1, 3, 'UG', 2022, '2022-08-01'),
  (4, '22CSE002', 1, 3, 'UG', 2022, '2022-08-01'),
  (5, '22ECE001', 2, 3, 'UG', 2022, '2022-08-01'),
  (6, '22ECE002', 2, 3, 'UG', 2022, '2022-08-01'),
  (7, '23ME001',  3, 2, 'UG', 2023, '2023-08-01'),
  (8, '23IT001',  5, 2, 'UG', 2023, '2023-08-01'),
  (9, '22PG001',  6, 1, 'PG', 2022, '2022-08-01'),
  (10,'21PHD001', 1, 1, 'PhD',2021, '2021-08-01');