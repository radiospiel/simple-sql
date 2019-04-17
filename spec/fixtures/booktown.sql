DROP SCHEMA IF EXISTS booktown CASCADE;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.10
-- Dumped by pg_dump version 11.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: booktown; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA booktown;


--
-- Name: SCHEMA booktown; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA booktown IS 'standard public schema';


--
-- Name: add_shipment(integer, text); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.add_shipment(integer, text) RETURNS timestamp with time zone
    LANGUAGE plpgsql
    AS $_$
  DECLARE
    customer_id ALIAS FOR $1;
    isbn ALIAS FOR $2;
    shipment_id INTEGER;
    right_now timestamp;
  BEGIN
    right_now := 'now';
    SELECT INTO shipment_id id FROM shipments ORDER BY id DESC;
    shipment_id := shipment_id + 1;
    INSERT INTO shipments VALUES ( shipment_id, customer_id, isbn, right_now );
    RETURN right_now;
  END;
$_$;


--
-- Name: add_two_loop(integer, integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.add_two_loop(integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
  DECLARE
 
     -- Declare aliases for function arguments.
 
    low_number ALIAS FOR $1;
    high_number ALIAS FOR $2;
 
     -- Declare a variable to hold the result.
 
    result INTEGER = 0;
 
  BEGIN
 
    WHILE result != high_number LOOP
      result := result + 1;
    END LOOP;
 
    RETURN result;
  END;
$_$;


--
-- Name: audit_test(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.audit_test() RETURNS opaque
    LANGUAGE plpgsql
    AS $$
    BEGIN   
       
      IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN

         NEW.user_aud := current_user;
         NEW.mod_time := 'NOW';

        INSERT INTO inventory_audit SELECT * FROM inventory WHERE prod_id=NEW.prod_id;
              
      RETURN NEW; 

      ELSE if TG_OP = 'DELETE' THEN
        INSERT INTO inventory_audit SELECT *, current_user, 'NOW' FROM inventory WHERE prod_id=OLD.prod_id;

      RETURN OLD;
      END IF;
     END IF;
    END;
$$;


--
-- Name: books_by_subject(text); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.books_by_subject(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
  DECLARE
    sub_title ALIAS FOR $1;
    sub_id INTEGER;
    found_text TEXT :='';
  BEGIN
      SELECT INTO sub_id id FROM subjects WHERE subject = sub_title;
      RAISE NOTICE 'sub_id = %',sub_id;
      IF sub_title = 'all' THEN
        found_text := extract_all_titles();
        RETURN found_text;
      ELSE IF sub_id  >= 0 THEN
          found_text := extract_title(sub_id);
          RETURN  '
' || sub_title || ':
' || found_text;
        END IF;
    END IF;
    RETURN 'Subject not found.';
  END;
$_$;


--
-- Name: check_book_addition(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.check_book_addition() RETURNS opaque
    LANGUAGE plpgsql
    AS $$
  DECLARE 
    id_number INTEGER;
    book_isbn TEXT;
  BEGIN

    SELECT INTO id_number id FROM customers WHERE id = NEW.customer_id; 

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid customer ID number.';  
    END IF;

    SELECT INTO book_isbn isbn FROM editions WHERE isbn = NEW.isbn; 

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid ISBN.'; 
    END IF; 

    UPDATE stock SET stock = stock -1 WHERE isbn = NEW.isbn; 

    RETURN NEW; 
  END;
$$;


--
-- Name: check_shipment_addition(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.check_shipment_addition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
     -- Declare a variable to hold the customer ID.
    id_number INTEGER;
 
     -- Declare a variable to hold the ISBN.
    book_isbn TEXT;
  BEGIN
 
     -- If there is an ID number that matches the customer ID in
     -- the new table, retrieve it from the customers table.
    SELECT INTO id_number id FROM customers WHERE id = NEW.customer_id;
 
     -- If there was no matching ID number, raise an exception.
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid customer ID number.';
    END IF;
 
     -- If there is an ISBN that matches the ISBN specified in the
     -- new table, retrieve it from the editions table.
    SELECT INTO book_isbn isbn FROM editions WHERE isbn = NEW.isbn;
 
     -- If there is no matching ISBN, raise an exception.
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid ISBN.';
    END IF;
 
    -- If the previous checks succeeded, update the stock amount
    -- for INSERT commands.
    IF TG_OP = 'INSERT' THEN
       UPDATE stock SET stock = stock -1 WHERE isbn = NEW.isbn;
    END IF;
 
    RETURN NEW;
  END;
$$;


--
-- Name: compound_word(text, text); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.compound_word(text, text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
     DECLARE
       -- defines an alias name for the two input values
       word1 ALIAS FOR $1;
       word2 ALIAS FOR $2;
     BEGIN
       -- displays the resulting joined words
       RETURN word1 || word2;
     END;
  $_$;


--
-- Name: count_by_two(integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.count_by_two(integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
     DECLARE
          userNum ALIAS FOR $1;
          i integer;
     BEGIN
          i := 1;
          WHILE userNum[1] < 20 LOOP
                i = i+1; 
                return userNum;              
          END LOOP;
          
     END;
   $_$;


--
-- Name: double_price(double precision); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.double_price(double precision) RETURNS double precision
    LANGUAGE plpgsql
    AS $_$
  DECLARE
  BEGIN
    return $1 * 2;
  END;
$_$;


--
-- Name: extract_all_titles(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.extract_all_titles() RETURNS text
    LANGUAGE plpgsql
    AS $$
  DECLARE
    sub_id INTEGER;
    text_output TEXT = ' ';
    sub_title TEXT;
    row_data books%ROWTYPE;
  BEGIN
    FOR i IN 0..15 LOOP
      SELECT INTO sub_title subject FROM subjects WHERE id = i;
      text_output = text_output || '
' || sub_title || ':
';

      FOR row_data IN SELECT * FROM books
        WHERE subject_id = i  LOOP

        IF NOT FOUND THEN
          text_output := text_output || 'None.
';
        ELSE
          text_output := text_output || row_data.title || '
';
        END IF;

      END LOOP;
    END LOOP;
    RETURN text_output;
  END;
$$;


--
-- Name: extract_all_titles2(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.extract_all_titles2() RETURNS text
    LANGUAGE plpgsql
    AS $$
  DECLARE
    sub_id INTEGER;
    text_output TEXT = ' ';
    sub_title TEXT;
    row_data books%ROWTYPE;
  BEGIN
    FOR i IN 0..15 LOOP
      SELECT INTO sub_title subject FROM subjects WHERE id = i;
      text_output = text_output || '
' || sub_title || ':
';

      FOR row_data IN SELECT * FROM books
        WHERE subject_id = i  LOOP

        text_output := text_output || row_data.title || '
';

      END LOOP;
    END LOOP;
    RETURN text_output;
  END;
$$;


--
-- Name: extract_title(integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.extract_title(integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
  DECLARE
    sub_id ALIAS FOR $1;
    text_output TEXT :='
';
    row_data RECORD;
  BEGIN
    FOR row_data IN SELECT * FROM books
    WHERE subject_id = sub_id ORDER BY title  LOOP
      text_output := text_output || row_data.title || '
';
    END LOOP;
    RETURN text_output;
  END;
$_$;


--
-- Name: first(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.first() RETURNS integer
    LANGUAGE plpgsql
    AS $$ 
       DecLarE
        oNe IntEgER := 1;
       bEGiN
        ReTUrn oNE;       
       eNd;
$$;


--
-- Name: get_author(integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.get_author(integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
  DECLARE
 
    -- Declare an alias for the function argument,
    -- which should be the id of the author.
    author_id ALIAS FOR $1;
 
    -- Declare a variable that uses the structure of
    -- the authors table.
    found_author authors%ROWTYPE;
 
  BEGIN
 
    -- Retrieve a row of author information for
    -- the author whose id number matches
    -- the argument received by the function.
    SELECT INTO found_author * FROM authors WHERE id = author_id;
 
    -- Return the first
    RETURN found_author.first_name || ' ' || found_author.last_name;
 
  END;
$_$;


--
-- Name: get_author(text); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.get_author(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
  DECLARE
 
      -- Declare an alias for the function argument,
      -- which should be the first name of an author.
     f_name ALIAS FOR $1;
 
       -- Declare a variable with the same type as
       -- the last_name field of the authors table.
     l_name authors.last_name%TYPE;
 
  BEGIN
 
      -- Retrieve the last name of an author from the
      -- authors table whose first name matches the
      -- argument received by the function, and
      -- insert it into the l_name variable.
     SELECT INTO l_name last_name FROM authors WHERE first_name = f_name;
 
       -- Return the first name and last name, separated
       -- by a space.
     return f_name || ' ' || l_name;
 
  END;
$_$;


--
-- Name: get_customer_id(text, text); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.get_customer_id(text, text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
  DECLARE
 
    -- Declare aliases for user input.
    l_name ALIAS FOR $1;
    f_name ALIAS FOR $2;
 
    -- Declare a variable to hold the customer ID number.
    customer_id INTEGER;
 
  BEGIN
 
    -- Retrieve the customer ID number of the customer whose first and last
    --  name match the values supplied as function arguments.
    SELECT INTO customer_id id FROM customers
      WHERE last_name = l_name AND first_name = f_name;
 
    -- Return the ID number.
    RETURN customer_id;
  END;
$_$;


--
-- Name: get_customer_name(integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.get_customer_name(integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
  DECLARE
  
    -- Declare aliases for user input.
    customer_id ALIAS FOR $1;
    
    -- Declare variables to hold the customer name.
    customer_fname TEXT;
    customer_lname TEXT;
  
  BEGIN
  
    -- Retrieve the customer first and last name for the customer whose
    -- ID matches the value supplied as a function argument.
    SELECT INTO customer_fname, customer_lname 
                first_name, last_name FROM customers
      WHERE id = customer_id;
    
    -- Return the name.
    RETURN customer_fname || ' ' || customer_lname;
  END;
$_$;


--
-- Name: givename(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.givename() RETURNS opaque
    LANGUAGE plpgsql
    AS $$
 DECLARE
   tablename text;
 BEGIN
   
   tablename = TG_RELNAME; 
   INSERT INTO INVENTORY values (123, tablename);
   return old;
 END;
$$;


--
-- Name: html_linebreaks(text); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.html_linebreaks(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
  DECLARE
    formatted_string text := '';
  BEGIN
    FOR i IN 0 .. length($1) LOOP
      IF substr($1, i, 1) = '
' THEN
        formatted_string := formatted_string || '<br>';
      ELSE
        formatted_string := formatted_string || substr($1, i, 1);
      END IF;
    END LOOP;
    RETURN formatted_string;
  END;
$_$;


--
-- Name: in_stock(integer, integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.in_stock(integer, integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
  DECLARE
    b_id ALIAS FOR $1;
    b_edition ALIAS FOR $2;
    b_isbn TEXT;
    stock_amount INTEGER;
  BEGIN
     -- This SELECT INTO statement retrieves the ISBN
     -- number of the row in the editions table that had
     -- both the book ID number and edition number that
     -- were provided as function arguments.
    SELECT INTO b_isbn isbn FROM editions WHERE
      book_id = b_id AND edition = b_edition;
 
     -- Check to see if the ISBN number retrieved
     -- is NULL.  This will happen if there is not an
     -- existing book with both the ID number and edition
     -- number specified in the function arguments.
     -- If the ISBN is null, the function returns a
     -- FALSE value and ends.
    IF b_isbn IS NULL THEN
      RETURN FALSE;
    END IF;
 
     -- Retrieve the amount of books available from the
     -- stock table and record the number in the
     -- stock_amount variable.
    SELECT INTO stock_amount stock FROM stock WHERE isbn = b_isbn;
 
     -- Use an IF/THEN/ELSE check to see if the amount
     -- of books available is less than, or equal to 0.
     -- If so, return FALSE.  If not, return TRUE.
    IF stock_amount <= 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  END;
$_$;


--
-- Name: isbn_to_title(text); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.isbn_to_title(text) RETURNS text
    LANGUAGE sql
    AS $_$SELECT title FROM books
                                 JOIN editions AS e (isbn, id)
                                 USING (id)
                                 WHERE isbn = $1$_$;


--
-- Name: mixed(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.mixed() RETURNS integer
    LANGUAGE plpgsql
    AS $$
       DecLarE
          --assigns 1 to the oNe variable
          oNe IntEgER 
          := 1;

       bEGiN

          --displays the value of oNe
          ReTUrn oNe;       
       eNd;
       $$;


--
-- Name: raise_test(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.raise_test() RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
 
     -- Declare an integer variable for testing.
 
    an_integer INTEGER = 1;
 
  BEGIN
 
     -- Raise a debug level message.
 
    RAISE DEBUG 'The raise_test() function began.';
 
    an_integer = an_integer + 1;
 
     -- Raise a notice stating that the an_integer
     -- variable was changed, then raise another notice
     -- stating its new value.
 
    RAISE NOTICE 'Variable an_integer was changed.';
    RAISE NOTICE 'Variable an_integer value is now %.',an_integer;
 
     -- Raise an exception.
 
    RAISE EXCEPTION 'Variable % changed.  Aborting transaction.',an_integer;
 
  END;
$$;


--
-- Name: ship_item(text, text, text); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.ship_item(text, text, text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
  DECLARE
    l_name ALIAS FOR $1;
    f_name ALIAS FOR $2;
    book_isbn ALIAS FOR $3;
    book_id INTEGER;
    customer_id INTEGER;
 
  BEGIN
 
    SELECT INTO customer_id get_customer_id(l_name,f_name);
 
    IF customer_id = -1 THEN
      RETURN -1;
    END IF;
 
    SELECT INTO book_id book_id FROM editions WHERE isbn = book_isbn;
 
    IF NOT FOUND THEN
      RETURN -1;
    END IF;
 
    PERFORM add_shipment(customer_id,book_isbn);
 
    RETURN 1;
  END;
$_$;


--
-- Name: stock_amount(integer, integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.stock_amount(integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
  DECLARE
     -- Declare aliases for function arguments.
    b_id ALIAS FOR $1;
    b_edition ALIAS FOR $2;
     -- Declare variable to store the ISBN number.
    b_isbn TEXT;
     -- Declare variable to store the stock amount.
    stock_amount INTEGER;
  BEGIN
     -- This SELECT INTO statement retrieves the ISBN
     -- number of the row in the editions table that had
     -- both the book ID number and edition number that
     -- were provided as function arguments.
    SELECT INTO b_isbn isbn FROM editions WHERE
      book_id = b_id AND edition = b_edition;
 
     -- Check to see if the ISBN number retrieved
     -- is NULL.  This will happen if there is not an
     -- existing book with both the ID number and edition
     -- number specified in the function arguments.
     -- If the ISBN is null, the function returns a
     -- value of -1 and ends.
    IF b_isbn IS NULL THEN
      RETURN -1;
    END IF;
 
     -- Retrieve the amount of books available from the
     -- stock table and record the number in the
     -- stock_amount variable.
    SELECT INTO stock_amount stock FROM stock WHERE isbn = b_isbn;
 
     -- Return the amount of books available.
    RETURN stock_amount;
  END;
$_$;


--
-- Name: sync_authors_and_books(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.sync_authors_and_books() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    IF TG_OP = 'UPDATE' THEN
      UPDATE books SET author_id = new.id WHERE author_id = old.id; 
    END IF;
    RETURN new;
  END;
$$;


--
-- Name: test(integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.test(integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
  
 DECLARE 
   -- defines the variable as ALIAS
  variable ALIAS FOR $1;
 BEGIN
  -- displays the variable after multiplying it by two 
  return variable * 2.0;
 END; 
 $_$;


--
-- Name: test_check_a_id(); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.test_check_a_id() RETURNS opaque
    LANGUAGE plpgsql
    AS $$
    BEGIN
     -- checks to make sure the author id
     -- inserted is not left blank or less than 100

        IF NEW.a_id ISNULL THEN
           RAISE EXCEPTION
           'The author id cannot be left blank!';
        ELSE
           IF NEW.a_id < 100 THEN
              RAISE EXCEPTION
              'Please insert a valid author id.';
           ELSE
           RETURN NEW;
           END IF;
        END IF;
    END;
$$;


--
-- Name: title(integer); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.title(integer) RETURNS text
    LANGUAGE sql
    AS $_$SELECT title from books where id = $1$_$;


--
-- Name: triple_price(double precision); Type: FUNCTION; Schema: booktown; Owner: -
--

CREATE FUNCTION booktown.triple_price(double precision) RETURNS double precision
    LANGUAGE plpgsql
    AS $_$
  DECLARE
     -- Declare input_price as an alias for the
     -- argument variable normally referenced with
     -- the $1 identifier.
    input_price ALIAS FOR $1;
 
  BEGIN
     -- Return the input price multiplied by three.
    RETURN input_price * 3;
  END;
 $_$;


--
-- Name: sum(text); Type: AGGREGATE; Schema: booktown; Owner: -
--

CREATE AGGREGATE booktown.sum(text) (
    SFUNC = textcat,
    STYPE = text,
    INITCOND = ''
);


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: alternate_stock; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.alternate_stock (
    isbn text,
    cost numeric(5,2),
    retail numeric(5,2),
    stock integer
);


--
-- Name: author_ids; Type: SEQUENCE; Schema: booktown; Owner: -
--

CREATE SEQUENCE booktown.author_ids
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: authors; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.authors (
    id integer NOT NULL,
    last_name text,
    first_name text
);


--
-- Name: book_backup; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.book_backup (
    id integer,
    title text,
    author_id integer,
    subject_id integer
);


--
-- Name: book_ids; Type: SEQUENCE; Schema: booktown; Owner: -
--

CREATE SEQUENCE booktown.book_ids
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: book_queue; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.book_queue (
    title text NOT NULL,
    author_id integer,
    subject_id integer,
    approved boolean
);


--
-- Name: books; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.books (
    id integer NOT NULL,
    title text NOT NULL,
    author_id integer,
    subject_id integer
);


--
-- Name: customers; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.customers (
    id integer NOT NULL,
    last_name text,
    first_name text
);


--
-- Name: daily_inventory; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.daily_inventory (
    isbn text,
    is_stocked boolean
);


--
-- Name: distinguished_authors; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.distinguished_authors (
    award text
)
INHERITS (booktown.authors);


--
-- Name: editions; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.editions (
    isbn text NOT NULL,
    book_id integer,
    edition integer,
    publisher_id integer,
    publication date,
    type character(1),
    CONSTRAINT integrity CHECK (((book_id IS NOT NULL) AND (edition IS NOT NULL)))
);


--
-- Name: employees; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.employees (
    id integer NOT NULL,
    last_name text NOT NULL,
    first_name text,
    CONSTRAINT employees_id CHECK ((id > 100))
);


--
-- Name: favorite_authors; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.favorite_authors (
    employee_id integer,
    authors_and_titles text[]
);


--
-- Name: favorite_books; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.favorite_books (
    employee_id integer,
    books text[]
);


--
-- Name: money_example; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.money_example (
    money_cash money,
    numeric_cash numeric(6,2)
);


--
-- Name: my_list; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.my_list (
    todos text
);


--
-- Name: numeric_values; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.numeric_values (
    num numeric(30,6)
);


--
-- Name: publishers; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.publishers (
    id integer NOT NULL,
    name text,
    address text
);


--
-- Name: shipments; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.shipments (
    id integer DEFAULT nextval(('"shipments_ship_id_seq"'::text)::regclass) NOT NULL,
    customer_id integer,
    isbn text,
    ship_date timestamp with time zone
);


--
-- Name: recent_shipments; Type: VIEW; Schema: booktown; Owner: -
--

CREATE VIEW booktown.recent_shipments AS
 SELECT count(*) AS num_shipped,
    max(shipments.ship_date) AS max,
    b.title
   FROM ((booktown.shipments
     JOIN booktown.editions USING (isbn))
     JOIN booktown.books b(book_id, title, author_id, subject_id) USING (book_id))
  GROUP BY b.title
  ORDER BY (count(*)) DESC;


--
-- Name: schedules; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.schedules (
    employee_id integer NOT NULL,
    schedule text
);


--
-- Name: shipments_ship_id_seq; Type: SEQUENCE; Schema: booktown; Owner: -
--

CREATE SEQUENCE booktown.shipments_ship_id_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: states; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.states (
    id integer NOT NULL,
    name text,
    abbreviation character(2)
);


--
-- Name: stock; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.stock (
    isbn text NOT NULL,
    cost numeric(5,2),
    retail numeric(5,2),
    stock integer
);


--
-- Name: stock_backup; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.stock_backup (
    isbn text,
    cost numeric(5,2),
    retail numeric(5,2),
    stock integer
);


--
-- Name: stock_view; Type: VIEW; Schema: booktown; Owner: -
--

CREATE VIEW booktown.stock_view AS
 SELECT stock.isbn,
    stock.retail,
    stock.stock
   FROM booktown.stock;


--
-- Name: subject_ids; Type: SEQUENCE; Schema: booktown; Owner: -
--

CREATE SEQUENCE booktown.subject_ids
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: subjects; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.subjects (
    id integer NOT NULL,
    subject text,
    location text
);


--
-- Name: text_sorting; Type: TABLE; Schema: booktown; Owner: -
--

CREATE TABLE booktown.text_sorting (
    letter character(1)
);


--
-- Data for Name: alternate_stock; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.alternate_stock (isbn, cost, retail, stock) FROM stdin;
0385121679	29.00	36.95	65
039480001X	30.00	32.95	31
0394900014	23.00	23.95	0
044100590X	36.00	45.95	89
0441172717	17.00	21.95	77
0451160916	24.00	28.95	22
0451198492	36.00	46.95	0
0451457994	17.00	22.95	0
0590445065	23.00	23.95	10
0679803335	20.00	24.95	18
0694003611	25.00	28.95	50
0760720002	18.00	23.95	28
0823015505	26.00	28.95	16
0929605942	19.00	21.95	25
1885418035	23.00	24.95	77
0394800753	16.00	16.95	4
\.


--
-- Data for Name: authors; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.authors (id, last_name, first_name) FROM stdin;
1111	Denham	Ariel
1212	Worsley	John
15990	Bourgeois	Paulette
25041	Bianco	Margery Williams
16	Alcott	Louisa May
4156	King	Stephen
1866	Herbert	Frank
1644	Hogarth	Burne
2031	Brown	Margaret Wise
115	Poe	Edgar Allen
7805	Lutz	Mark
7806	Christiansen	Tom
1533	Brautigan	Richard
1717	Brite	Poppy Z.
2112	Gorey	Edward
2001	Clarke	Arthur C.
1213	Brookins	Andrew
\.


--
-- Data for Name: book_backup; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.book_backup (id, title, author_id, subject_id) FROM stdin;
7808	The Shining	4156	9
4513	Dune	1866	15
4267	2001: A Space Odyssey	2001	15
1608	The Cat in the Hat	1809	2
1590	Bartholomew and the Oobleck	1809	2
25908	Franklin in the Dark	15990	2
1501	Goodnight Moon	2031	2
190	Little Women	16	6
1234	The Velveteen Rabbit	25041	3
2038	Dynamic Anatomy	1644	0
156	The Tell-Tale Heart	115	9
41472	Practical PostgreSQL	1212	4
41473	Programming Python	7805	4
41477	Learning Python	7805	4
41478	Perl Cookbook	7806	4
7808	The Shining	4156	9
4513	Dune	1866	15
4267	2001: A Space Odyssey	2001	15
1608	The Cat in the Hat	1809	2
1590	Bartholomew and the Oobleck	1809	2
25908	Franklin in the Dark	15990	2
1501	Goodnight Moon	2031	2
190	Little Women	16	6
1234	The Velveteen Rabbit	25041	3
2038	Dynamic Anatomy	1644	0
156	The Tell-Tale Heart	115	9
41473	Programming Python	7805	4
41477	Learning Python	7805	4
41478	Perl Cookbook	7806	4
41472	Practical PostgreSQL	1212	4
\.


--
-- Data for Name: book_queue; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.book_queue (title, author_id, subject_id, approved) FROM stdin;
Learning Python	7805	4	t
Perl Cookbook	7806	4	t
\.


--
-- Data for Name: books; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.books (id, title, author_id, subject_id) FROM stdin;
7808	The Shining	4156	9
4513	Dune	1866	15
4267	2001: A Space Odyssey	2001	15
1608	The Cat in the Hat	1809	2
1590	Bartholomew and the Oobleck	1809	2
25908	Franklin in the Dark	15990	2
1501	Goodnight Moon	2031	2
190	Little Women	16	6
1234	The Velveteen Rabbit	25041	3
2038	Dynamic Anatomy	1644	0
156	The Tell-Tale Heart	115	9
41473	Programming Python	7805	4
41477	Learning Python	7805	4
41478	Perl Cookbook	7806	4
41472	Practical PostgreSQL	1212	4
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.customers (id, last_name, first_name) FROM stdin;
107	Jackson	Annie
112	Gould	Ed
142	Allen	Chad
146	Williams	James
172	Brown	Richard
185	Morrill	Eric
221	King	Jenny
270	Bollman	Julie
388	Morrill	Royce
409	Holloway	Christine
430	Black	Jean
476	Clark	James
480	Thomas	Rich
488	Young	Trevor
574	Bennett	Laura
652	Anderson	Jonathan
655	Olson	Dave
671	Brown	Chuck
723	Eisele	Don
724	Holloway	Adam
738	Gould	Shirley
830	Robertson	Royce
853	Black	Wendy
860	Owens	Tim
880	Robinson	Tammy
898	Gerdes	Kate
964	Gould	Ramon
1045	Owens	Jean
1125	Bollman	Owen
1149	Becker	Owen
1123	Corner	Kathy
\.


--
-- Data for Name: daily_inventory; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.daily_inventory (isbn, is_stocked) FROM stdin;
039480001X	t
044100590X	t
0451198492	f
0394900014	f
0441172717	t
0451160916	f
0385121679	\N
\.


--
-- Data for Name: distinguished_authors; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.distinguished_authors (id, last_name, first_name, award) FROM stdin;
25043	Simon	Neil	Pulitzer Prize
1809	Geisel	Theodor Seuss	Pulitzer Prize
\.


--
-- Data for Name: editions; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.editions (isbn, book_id, edition, publisher_id, publication, type) FROM stdin;
039480001X	1608	1	59	1957-03-01	h
0451160916	7808	1	75	1981-08-01	p
0394800753	1590	1	59	1949-03-01	p
0590445065	25908	1	150	1987-03-01	p
0694003611	1501	1	65	1947-03-04	p
0679803335	1234	1	102	1922-01-01	p
0760720002	190	1	91	1868-01-01	p
0394900014	1608	1	59	1957-01-01	p
0385121679	7808	2	75	1993-10-01	h
1885418035	156	1	163	1995-03-28	p
0929605942	156	2	171	1998-12-01	p
0441172717	4513	2	99	1998-09-01	p
044100590X	4513	3	99	1999-10-01	h
0451457994	4267	3	101	2000-09-12	p
0451198492	4267	3	101	1999-10-01	h
0823015505	2038	1	62	1958-01-01	p
0596000855	41473	2	113	2001-03-01	p
\.


--
-- Data for Name: employees; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.employees (id, last_name, first_name) FROM stdin;
101	Appel	Vincent
102	Holloway	Michael
105	Connoly	Sarah
104	Noble	Ben
103	Joble	David
106	Hall	Timothy
1008	Williams	\N
\.


--
-- Data for Name: favorite_authors; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.favorite_authors (employee_id, authors_and_titles) FROM stdin;
102	{{"J.R.R. Tolkien","The Silmarillion"},{"Charles Dickens","Great Expectations"},{"Ariel Denham","Attic Lives"}}
\.


--
-- Data for Name: favorite_books; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.favorite_books (employee_id, books) FROM stdin;
102	{"The Hitchhiker's Guide to the Galaxy","The Restauraunt at the End of the Universe"}
103	{"There and Back Again: A Hobbit's Holiday","Kittens Squared"}
\.


--
-- Data for Name: money_example; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.money_example (money_cash, numeric_cash) FROM stdin;
$12.24	12.24
\.


--
-- Data for Name: my_list; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.my_list (todos) FROM stdin;
Pick up laundry.
Send out bills.
Wrap up Grand Unifying Theory for publication.
\.


--
-- Data for Name: numeric_values; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.numeric_values (num) FROM stdin;
68719476736.000000
68719476737.000000
6871947673778.000000
999999999999999999999999.999900
999999999999999999999999.999999
-999999999999999999999999.999999
-100000000000000000000000.999999
1.999999
2.000000
2.000000
999999999999999999999999.999999
999999999999999999999999.000000
\.


--
-- Data for Name: publishers; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.publishers (id, name, address) FROM stdin;
150	Kids Can Press	Kids Can Press, 29 Birch Ave. Toronto, ON  M4V 1E2
91	Henry Holt & Company, Inc.	Henry Holt & Company, Inc. 115 West 18th Street New York, NY 10011
113	O'Reilly & Associates	O'Reilly & Associates, Inc. 101 Morris St, Sebastopol, CA 95472
62	Watson-Guptill Publications	1515 Boradway, New York, NY 10036
105	Noonday Press	Farrar Straus & Giroux Inc, 19 Union Square W, New York, NY 10003
99	Ace Books	The Berkley Publishing Group, Penguin Putnam Inc, 375 Hudson St, New York, NY 10014
101	Roc	Penguin Putnam Inc, 375 Hudson St, New York, NY 10014
163	Mojo Press	Mojo Press, PO Box 1215, Dripping Springs, TX 78720
171	Books of Wonder	Books of Wonder, 16 W. 18th St. New York, NY, 10011
102	Penguin	Penguin Putnam Inc, 375 Hudson St, New York, NY 10014
75	Doubleday	Random House, Inc, 1540 Broadway, New York, NY 10036
65	HarperCollins	HarperCollins Publishers, 10 E 53rd St, New York, NY 10022
59	Random House	Random House, Inc, 1540 Broadway, New York, NY 10036
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.schedules (employee_id, schedule) FROM stdin;
102	Mon - Fri, 9am - 5pm
\.


--
-- Data for Name: shipments; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.shipments (id, customer_id, isbn, ship_date) FROM stdin;
375	142	039480001X	2001-08-06 18:29:21+02
323	671	0451160916	2001-08-14 19:36:41+02
998	1045	0590445065	2001-08-12 21:09:47+02
749	172	0694003611	2001-08-11 19:52:34+02
662	655	0679803335	2001-08-09 16:30:07+02
806	1125	0760720002	2001-08-05 18:34:04+02
102	146	0394900014	2001-08-11 22:34:08+02
813	112	0385121679	2001-08-08 18:53:46+02
652	724	1885418035	2001-08-14 22:41:39+02
599	430	0929605942	2001-08-10 17:29:42+02
969	488	0441172717	2001-08-14 17:42:58+02
433	898	044100590X	2001-08-12 17:46:35+02
660	409	0451457994	2001-08-07 20:56:42+02
310	738	0451198492	2001-08-15 23:02:01+02
510	860	0823015505	2001-08-14 16:33:47+02
997	185	039480001X	2001-08-10 22:47:52+02
999	221	0451160916	2001-08-14 22:45:51+02
56	880	0590445065	2001-08-14 22:49:00+02
72	574	0694003611	2001-08-06 16:49:44+02
146	270	039480001X	2001-08-13 18:42:10+02
981	652	0451160916	2001-08-08 17:36:44+02
95	480	0590445065	2001-08-10 16:29:52+02
593	476	0694003611	2001-08-15 20:57:40+02
977	853	0679803335	2001-08-09 18:30:46+02
117	185	0760720002	2001-08-07 22:00:48+02
406	1123	0394900014	2001-08-13 18:47:04+02
340	1149	0385121679	2001-08-12 22:39:22+02
871	388	1885418035	2001-08-07 20:31:57+02
1000	221	039480001X	2001-09-15 01:46:32+02
1001	107	039480001X	2001-09-15 02:42:22+02
754	107	0394800753	2001-08-11 18:55:05+02
458	107	0394800753	2001-08-07 19:58:36+02
189	107	0394800753	2001-08-06 20:46:36+02
720	107	0394800753	2001-08-08 19:46:13+02
1002	107	0394800753	2001-09-22 20:23:28+02
2	107	0394800753	2001-09-23 05:58:56+02
\.


--
-- Data for Name: states; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.states (id, name, abbreviation) FROM stdin;
42	Washington	WA
51	Oregon	OR
\.


--
-- Data for Name: stock; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.stock (isbn, cost, retail, stock) FROM stdin;
0385121679	29.00	36.95	65
039480001X	30.00	32.95	31
0394900014	23.00	23.95	0
044100590X	36.00	45.95	89
0441172717	17.00	21.95	77
0451160916	24.00	28.95	22
0451198492	36.00	46.95	0
0451457994	17.00	22.95	0
0590445065	23.00	23.95	10
0679803335	20.00	24.95	18
0694003611	25.00	28.95	50
0760720002	18.00	23.95	28
0823015505	26.00	28.95	16
0929605942	19.00	21.95	25
1885418035	23.00	24.95	77
0394800753	16.00	16.95	4
\.


--
-- Data for Name: stock_backup; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.stock_backup (isbn, cost, retail, stock) FROM stdin;
0385121679	29.00	36.95	65
039480001X	30.00	32.95	31
0394800753	16.00	16.95	0
0394900014	23.00	23.95	0
044100590X	36.00	45.95	89
0441172717	17.00	21.95	77
0451160916	24.00	28.95	22
0451198492	36.00	46.95	0
0451457994	17.00	22.95	0
0590445065	23.00	23.95	10
0679803335	20.00	24.95	18
0694003611	25.00	28.95	50
0760720002	18.00	23.95	28
0823015505	26.00	28.95	16
0929605942	19.00	21.95	25
1885418035	23.00	24.95	77
\.


--
-- Data for Name: subjects; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.subjects (id, subject, location) FROM stdin;
0	Arts	Creativity St
1	Business	Productivity Ave
2	Children's Books	Kids Ct
3	Classics	Academic Rd
4	Computers	Productivity Ave
5	Cooking	Creativity St
6	Drama	Main St
7	Entertainment	Main St
8	History	Academic Rd
9	Horror	Black Raven Dr
10	Mystery	Black Raven Dr
11	Poetry	Sunset Dr
12	Religion	\N
13	Romance	Main St
14	Science	Productivity Ave
15	Science Fiction	Main St
\.


--
-- Data for Name: text_sorting; Type: TABLE DATA; Schema: booktown; Owner: -
--

COPY booktown.text_sorting (letter) FROM stdin;
0
1
2
3
A
B
C
D
a
b
c
d
\.


--
-- Name: author_ids; Type: SEQUENCE SET; Schema: booktown; Owner: -
--

SELECT pg_catalog.setval('booktown.author_ids', 25044, true);


--
-- Name: book_ids; Type: SEQUENCE SET; Schema: booktown; Owner: -
--

SELECT pg_catalog.setval('booktown.book_ids', 41478, true);


--
-- Name: shipments_ship_id_seq; Type: SEQUENCE SET; Schema: booktown; Owner: -
--

SELECT pg_catalog.setval('booktown.shipments_ship_id_seq', 1011, true);


--
-- Name: subject_ids; Type: SEQUENCE SET; Schema: booktown; Owner: -
--

SELECT pg_catalog.setval('booktown.subject_ids', 15, true);


--
-- Name: authors authors_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (id);


--
-- Name: books books_id_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.books
    ADD CONSTRAINT books_id_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: editions pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.editions
    ADD CONSTRAINT pkey PRIMARY KEY (isbn);


--
-- Name: publishers publishers_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.publishers
    ADD CONSTRAINT publishers_pkey PRIMARY KEY (id);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (employee_id);


--
-- Name: states state_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.states
    ADD CONSTRAINT state_pkey PRIMARY KEY (id);


--
-- Name: stock stock_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.stock
    ADD CONSTRAINT stock_pkey PRIMARY KEY (isbn);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: books_title_idx; Type: INDEX; Schema: booktown; Owner: -
--

CREATE INDEX books_title_idx ON booktown.books USING btree (title);


--
-- Name: shipments_ship_id_key; Type: INDEX; Schema: booktown; Owner: -
--

CREATE UNIQUE INDEX shipments_ship_id_key ON booktown.shipments USING btree (id);


--
-- Name: text_idx; Type: INDEX; Schema: booktown; Owner: -
--

CREATE INDEX text_idx ON booktown.text_sorting USING btree (letter);


--
-- Name: unique_publisher_idx; Type: INDEX; Schema: booktown; Owner: -
--

CREATE UNIQUE INDEX unique_publisher_idx ON booktown.publishers USING btree (name);


--
-- Name: editions sync_stock_with_editions; Type: RULE; Schema: booktown; Owner: -
--

CREATE RULE sync_stock_with_editions AS
    ON UPDATE TO booktown.editions DO  UPDATE booktown.stock SET isbn = new.isbn
  WHERE (stock.isbn = old.isbn);


--
-- Name: shipments check_shipment; Type: TRIGGER; Schema: booktown; Owner: -
--

CREATE TRIGGER check_shipment BEFORE INSERT OR UPDATE ON booktown.shipments FOR EACH ROW EXECUTE PROCEDURE booktown.check_shipment_addition();


--
-- Name: authors sync_authors_books; Type: TRIGGER; Schema: booktown; Owner: -
--

CREATE TRIGGER sync_authors_books BEFORE UPDATE ON booktown.authors FOR EACH ROW EXECUTE PROCEDURE booktown.sync_authors_and_books();


--
-- Name: schedules valid_employee; Type: FK CONSTRAINT; Schema: booktown; Owner: -
--

ALTER TABLE ONLY booktown.schedules
    ADD CONSTRAINT valid_employee FOREIGN KEY (employee_id) REFERENCES booktown.employees(id) MATCH FULL;


--
-- PostgreSQL database dump complete
--

