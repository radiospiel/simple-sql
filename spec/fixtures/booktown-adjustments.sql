--
-- This file contains some adjustments to the booktown database
--
 
ALTER TABLE ONLY booktown.books ADD CONSTRAINT books_subject_id FOREIGN KEY (subject_id) REFERENCES booktown.subjects(id);

ALTER TABLE ONLY booktown.editions ADD CONSTRAINT editions_book_id FOREIGN KEY (book_id) REFERENCES booktown.books(id);
ALTER TABLE ONLY booktown.editions ADD CONSTRAINT editions_publisher_id FOREIGN KEY (publisher_id) REFERENCES booktown.publishers(id);

ALTER TABLE ONLY booktown.favorite_authors ADD CONSTRAINT favorite_authors_employee_id FOREIGN KEY (employee_id) REFERENCES booktown.employees(id);
ALTER TABLE ONLY booktown.favorite_books ADD CONSTRAINT favorite_authors_employee_id FOREIGN KEY (employee_id) REFERENCES booktown.employees(id);



ALTER TABLE ONLY booktown.shipments ADD CONSTRAINT shipments_isbn FOREIGN KEY (isbn) REFERENCES booktown.editions(isbn);

ALTER TABLE ONLY booktown.schedules ADD CONSTRAINT schedules_employee_id FOREIGN KEY (employee_id) REFERENCES booktown.employees(id);


DROP INDEX IF EXISTS booktown.shipments_ship_id_key;
ALTER TABLE ONLY booktown.shipments ADD PRIMARY KEY (id);
