# Indexing 

StudentID :

StudentName: 

```sql
-- account table
CREATE TABLE account(
    account_id serial PRIMARY KEY,
    name text NOT NULL,
    dob date
);
```

```sql
-- thread table
CREATE TABLE thread(
    thread_id serial PRIMARY KEY,
    account_id integer NOT NULL REFERENCES account(account_id),
    title text NOT NULL
);
```

```sql
-- post table
CREATE TABLE post(
    post_id serial PRIMARY KEY,
    thread_id integer NOT NULL REFERENCES thread(thread_id),
    account_id integer NOT NULL REFERENCES account(account_id),
    created timestamp with time zone NOT NULL DEFAULT now(),
    visible boolean NOT NULL DEFAULT TRUE,
    comment text NOT NULL
);
```


```sql
-- word table create with word in linux file
CREATE TABLE words (word TEXT) ;
\copy words (word) FROM '/data/words';
```

```sql
-- create account data
INSERT INTO account (name, dob)
SELECT
    substring('AEIOU', (random()*4)::int + 1, 1) ||
    substring('ctdrdwftmkndnfnjnknsntnyprpsrdrgrkrmrnzslstwl', (random()*22*2 + 1)::int, 2) ||
    substring('aeiou', (random()*4 + 1)::int, 1) || 
    substring('ctdrdwftmkndnfnjnknsntnyprpsrdrgrkrmrnzslstwl', (random()*22*2 + 1)::int, 2) ||
    substring('aeiou', (random()*4 + 1):: int, 1),
    Now() + ('1 days':: interval * random() * 365)
FROM generate_series (1, 100)
;
```

```sql
-- create thread data 
INSERT INTO thread (account_id, title)
WITH random_titles AS (
    -- 1. สร้างชื่อ Title สุ่มเตรียมไว้ 1,000 ชุด (หรือเท่ากับจำนวนที่ต้องการ insert)
    -- วิธีนี้จะทำการสุ่มคำเพียงครั้งเดียวต่อหนึ่ง title
    SELECT 
        row_number() OVER () as id,
        initcap(sentence) as title
    FROM (
        SELECT (SELECT string_agg(word, ' ') FROM (SELECT word FROM words ORDER BY random() LIMIT 5) AS w) as sentence
        FROM generate_series(1, 1000)
    ) s
)
SELECT
    (RANDOM() * 99 + 1)::int,
    rt.title
FROM generate_series(1, 1000) AS s(n)
JOIN random_titles rt ON rt.id = s.n
;
```

```sql
-- create post data
INSERT INTO post (thread_id, account_id, created, visible, comment)
WITH random_comments AS (
    SELECT row_number() OVER () as id, sentence
    FROM (
        SELECT (SELECT string_agg(word, ' ') FROM (SELECT word FROM words ORDER BY random() LIMIT 20) AS w) as sentence
        FROM generate_series(1, 1000)
    ) s
),
source_data AS (
    -- สร้างโครงข้อมูล 100,000 แถว พร้อมสุ่ม ID สำหรับเลือก comment
    SELECT 
        (RANDOM() * 999 + 1)::int AS t_id,
        (RANDOM() * 99 + 1)::int AS a_id,
        NOW() - ('1 days'::interval * random() * 1000) AS c_date,
        (RANDOM() > 0.1) AS vis,
        floor(random() * 1000 + 1)::int AS comment_id
    FROM generate_series(1, 100000)
)
SELECT 
    sd.t_id, 
    sd.a_id, 
    sd.c_date, 
    sd.vis, 
    rc.sentence
FROM source_data sd
JOIN random_comments rc ON sd.comment_id = rc.id -- ใช้ JOIN เพื่อการันตีว่าข้อมูลต้องมีค่า
;
```


# WITHOUT INDEXING

```sql
-- table and index data
SELECT
    t.table_name,
    pg_size_pretty(pg_total_relation_size('public.' || t.table_name)) AS total_size,
    pg_size_pretty(pg_indexes_size('public.' || t.table_name)) AS index_size,
    pg_size_pretty(pg_relation_size('public.' || t.table_name)) AS table_size,
    COALESCE(pg_class.reltuples::bigint, 0) AS num_rows
FROM
    information_schema.tables t
LEFT JOIN
    pg_class ON pg_class.relname = t.table_name
LEFT JOIN
    pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE
    t.table_schema = 'public'
    AND pg_namespace.nspname = 'public'
ORDER BY
    t.table_name ASC
;
-- Output
------------+------------+------------+------------+----------
 table_name | total_size | index_size | table_size | num_rows 
------------+------------+------------+------------+----------
 account    | 32 kB      | 16 kB      | 8192 bytes |      100 
 post       | 27 MB      | 2208 kB    | 25 MB      |   100000 
 thread     | 168 kB     | 40 kB      | 96 kB      |     1000 
 words      | 10024 kB   | 0 bytes    | 9984 kB    |   235976 
(4 rows)

```


### Exercise 2 See all my posts
```sql
-- Query 1: See all my posts
EXPLAIN ANALYZE
SELECT * FROM post
WHERE account_id = 1
;

-- Output
                                               QUERY PLAN                          

--------------------------------------------------------------------------------------------------------
 Seq Scan on post  (cost=0.00..4476.00 rows=530 width=222) (actual time=0.142..32.420 rows=543 loops=1)
   Filter: (account_id = 1)
   Rows Removed by Filter: 99457
 Planning Time: 0.461 ms
 Execution Time: 32.493 ms
(5 rows)

```

### Exercise 3 How many post have i made?
```sql
-- Query 2: How many post have i made?
EXPLAIN ANALYZE
SELECT COUNT(*) FROM post
WHERE account_id = 1;

-- Output
                                                 QUERY PLAN                        

------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=4477.32..4477.34 rows=1 width=8) (actual time=30.265..30.266 rows=1 loops=1)
   ->  Seq Scan on post  (cost=0.00..4476.00 rows=530 width=0) (actual time=0.156..30.159 rows=543 loops=1)
         Filter: (account_id = 1)
         Rows Removed by Filter: 99457
 Planning Time: 0.191 ms
 Execution Time: 30.308 ms
(6 rows)

```

### Exercise 4 See all current posts for a Thread

```sql
-- Query 3: See all current posts for a Thread
EXPLAIN ANALYZE
SELECT * FROM post
WHERE thread_id = 1
AND visible = TRUE;

-- Output
                                              QUERY PLAN                           

------------------------------------------------------------------------------------------------------
 Seq Scan on post  (cost=0.00..4476.00 rows=89 width=222) (actual time=0.918..35.108 rows=36 loops=1)
   Filter: (visible AND (thread_id = 1))
   Rows Removed by Filter: 99964
 Planning Time: 0.133 ms
 Execution Time: 35.147 ms
(5 rows)

```

### Exercise 5 How many posts have i made to a Thread?

```sql
-- Query 4: How many posts have i made to a Thread?
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM post
WHERE thread_id = 1 AND visible = TRUE AND account_id = 1;

-- Output
                                               QUERY PLAN                          

---------------------------------------------------------------------------------------------------------
 Aggregate  (cost=4726.00..4726.01 rows=1 width=8) (actual time=20.171..20.173 rows=1 loops=1)
   ->  Seq Scan on post  (cost=0.00..4726.00 rows=1 width=0) (actual time=20.166..20.167 rows=0 loops=1)
         Filter: (visible AND (thread_id = 1) AND (account_id = 1))
         Rows Removed by Filter: 100000
 Planning Time: 0.200 ms
 Execution Time: 20.217 ms
(6 rows)



```

### Exercise 6 See all current posts for a Thread for this month, in order

```sql
-- Query 5: See all current posts for a Thread for this month, in order
EXPLAIN ANALYZE
SELECT *
FROM post
WHERE thread_id = 1 AND visible = TRUE AND created > NOW() - '1 month'::interval
ORDER BY created;

-- Output
                                                        QUERY PLAN                 

--------------------------------------------------------------------------------------------------------------------------
 Gather Merge  (cost=5059.37..5059.60 rows=2 width=222) (actual time=22.677..26.359 rows=0 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Sort  (cost=4059.34..4059.35 rows=1 width=222) (actual time=13.978..13.979 rows=0 loops=3)
         Sort Key: created
         Sort Method: quicksort  Memory: 25kB
         Worker 0:  Sort Method: quicksort  Memory: 25kB
         Worker 1:  Sort Method: quicksort  Memory: 25kB
         ->  Parallel Seq Scan on post  (cost=0.00..4059.33 rows=1 width=222) (actual time=13.809..13.810 rows=0 loops=3)
               Filter: (visible AND (thread_id = 1) AND (created > (now() - '1 mon'::interval)))
               Rows Removed by Filter: 33333
 Planning Time: 0.338 ms
 Execution Time: 26.416 ms
(13 rows)

```


## CREATE INDEXES

### Case A Baseline

```sql
EXPLAIN ANALYZE
SELECT * FROM post WHERE account_id = 1; 

-- Output

                                               QUERY PLAN                                        

--------------------------------------------------------------------------------------------------------
 Seq Scan on post  (cost=0.00..4476.00 rows=530 width=222) (actual time=0.298..30.446 rows=543 loops=1)
   Filter: (account_id = 1)
   Rows Removed by Filter: 99457
 Planning Time: 0.147 ms
 Execution Time: 30.531 ms
```

### Case B Single Index

```sql
CREATE INDEX post_account_id_idx ON post(account_id);

EXPLAIN ANALYZE
SELECT * FROM post WHERE account_id = 1; 

-- Output 
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on post  (cost=8.55..1440.45 rows=550 width=222) (actual time=0.335..1.460 rows=543 loops=1)
   Recheck Cond: (account_id = 1)
   Heap Blocks: exact=500
   ->  Bitmap Index Scan on post_account_id_idx  (cost=0.00..8.42 rows=550 width=0) (actual time=0.159..0.159 rows=543 loops=1)
         Index Cond: (account_id = 1)
 Planning Time: 0.207 ms
 Execution Time: 1.567 ms
(7 rows)
```

### Case C Composite Index

```sql
DROP INDEX post_account_id_idx;

CREATE INDEX post_thread_id_account_id_idx ON post(thread_id, account_id);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND account_id = 1;

-- Output
                                                             QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using post_thread_id_account_id_idx on post  (cost=0.29..8.31 rows=1 width=222) (actual time=0.070..0.071 rows=0 loops=1)
   Index Cond: ((thread_id = 1) AND (account_id = 1))
 Planning Time: 0.374 ms
 Execution Time: 0.124 ms
(4 rows)
```

### Case D Full Composite Index

```sql
DROP INDEX post_thread_id_account_id_idx;

CREATE INDEX post_thread_id_account_id_visible_idx ON post(thread_id, account_id, visible);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND account_id = 1 AND visible = TRUE;

--Output
                                                                  QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using post_thread_id_account_id_visible_idx on post  (cost=0.42..8.44 rows=1 width=222) (actual time=0.041..0.042 rows=0 loops=1)
   Index Cond: ((thread_id = 1) AND (account_id = 1) AND (visible = true))
 Planning Time: 0.549 ms
 Execution Time: 0.094 ms
(4 rows)
```

### Case E Partial Index

```sql
DROP INDEX post_thread_id_account_id_visible_idx;

CREATE INDEX post_thread_id_visible_idx ON post(thread_id) WHERE visible = TRUE;

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND visible = TRUE;

-- Output
                                                             QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on post  (cost=4.98..314.49 rows=89 width=222) (actual time=0.056..0.152 rows=36 loops=1)
   Recheck Cond: ((thread_id = 1) AND visible)
   Heap Blocks: exact=36
   ->  Bitmap Index Scan on post_thread_id_visible_idx  (cost=0.00..4.96 rows=89 width=0) (actual time=0.035..0.035 rows=36 loops=1)
         Index Cond: (thread_id = 1)
 Planning Time: 0.564 ms
 Execution Time: 0.208 ms
(7 rows)
```

### Case F Sorting

```sql
DROP INDEX post_thread_id_visible_idx;

CREATE INDEX post_thread_id_create_idx ON post(thread_id, created DESC);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 ORDER BY created DESC LIMIT 10;

-- Output
                                                                 QUERY PLAN

--------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.42..40.59 rows=10 width=222) (actual time=0.050..0.077 rows=10 loops=1)
   ->  Index Scan using post_thread_id_create_idx on post  (cost=0.42..398.12 rows=99 width=222) (actual time=0.047..0.071 rows=10 loops=1)
         Index Cond: (thread_id = 1)
 Planning Time: 0.468 ms
 Execution Time: 0.107 ms
(5 rows)
```
