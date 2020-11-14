# Chapter 01. Why Redis?

- Redis, best known for its speed, is not only fast in its execution but also fast in the sense that solutions built with Redis have fast iterations because of the ease in configuring, setting up, running, and using Redis
- Redis is short for **REmote DIctionary Server**

## Is Redis right for me?
- Redis does not need to replace the existing databases but is an excellent addition to an enterprise for new functionalities or to solve sometimes intractable problems
- Being a single-threaded application with a small memory footprint, Redis achieves durability and scalability through running multiple instances on the current multicore processors available in data centers and cloud providers. With Redis-rich master-slave replication and now with Redis clusters are released in production, creating multiple Redis instances are relatively cheap operation in terms of memory and CPU requirements, allowing you to both scale and increase the durability of your larger applications.
- Redis allows you to conceptualize and approach challenging data analysis and data manipulation problems in a very different manner as compared to a typical relational data model
  - No need of normalizing the data into columns, rows, and tables with connecting joins through foreign-key relationships required by SQL-based relational DB
- While NoSQL as MongoDB or Elasticsearch requires the intermediate marshaling data as JSON document data structures, Redis just providing sets of commands for specific data structures such as strings, lists, hashes, sets, and sorted sets
- Redis may not be the best technology to use when you have a large amount of infrequently used data that does not require immediate access

## Experimenting with Redis

### MARC
- **MAachine-Readable Cataloging** is abbreviated as MARC
- Latest version is MARC21, initially encoded information about the books on the library's shelves and has been extended to support
  - e-books available for checkout
  - video, music, and audio formats
  - physical formats such as CDs, Blu-ray discs, and online streaming formats
  - academic libraries
- Storage in Redis
  - HOW
    - Each MARC record was a hash key modeled as `marc:{counter}` with the `counter` being a global incremental counter
    - Each MARC field is a hash with the key modeled as `marc:{counter}:{field}`
    - As some MARC fields are repeatable with different information, the hash key would include a global counter such as `marc:{counter}:{field}:{fieldcounter}`
  - Commands (command cheat sheet sees [redis commands])

      ```bash
      127.0.0.1:6379> INCR marc
      (integer) 1
      127.0.0.1:6379> INCR marc:1:100
      (integer) 1
      127.0.0.1:6379> HSET marc:1:100:1 a "Wallace, David Foster"
      (integer) 1
      127.0.0.1:6379> INCR marc:1:245
      (integer) 1
      127.0.0.1:6379> HMSET marc:1:245:1 a "Infinite jest :" b "a novel" c "David Foster Wallace"
      OK
      127.0.0.1:6379> HGETALL marc:1:245:1
      1) "a"
      2) "Infinite jest :"
      3) "b"
      4) "a novel"
      5) "c"
      6) "David Foster Wallace"
      ```

### FRBR
- The **Functionality Requirements for Bibliographic Record**, or FRBR, was a document that put forward an alternative to MARC and was based on **entity-relationship (ER)** models
- The FRBR ER model contained groups of properties that were categorized according to abstraction
  - The `Work` class represents the most general properties to uniquely identify a creative artifact with such information as titles, authors, and subjects
  - The `Expression` class is made of properties such as edition and translations with a defined relationship to the parent `Work`
  - `Manifestations` and `Items` are the final two FRBR classes, capturing more specific data
    - `Item` is a physical object that is a specific instance of a more general `Manifestation`
- Using existing mappings of MARC data to FRBR's `Work`, `Expression`, `Manifestation`, and `Item`, the MARC 100 and 245 fields from the above would be mapped to an FRBR Work in Redis as shown by these examples

  ```bash
  127.0.0.1:6379> HMSET frbr:work:1 title "Infinite Jest" "created by" "David Foster Wallace"
  OK
  127.0.0.1:6379> HMSET frbr:expression:1 date 1996 "realization of" frbr:work:1
  OK
  127.0.0.1:6379> HMSET frbr:manifestation:1 publisher "Little, Brown and Company" "physical embodiment of" frbr:expression:1
  OK
  127.0.0.1:6379> HMSET frbr:item:1 'exemplar of' frbr:manifestation:1 identifier 33027005910579
  OK
  ```

### Multi-value properties
- **WHEN**: more than one value for a specific property, such as when representing multiple authors of a work
- **HOW** to tackle: creating a counter for each multi-value property

  ```bash
  127.0.0.1:6379> INCR global:marc:1:856
  (integer) 1
  127.0.0.1:6379> HMSET marc:1:856:1 ind1 4 ind2 1 u https://books.google.com/books?id=Nhe2yvx6hP8C
  OK
  127.0.0.1:6379> HMSET marc:1:856:2 ind1 4 ind2 2 u http://infinitejest.wallacewiki.com/
  OK
  ```

### Fields with multiple, repeating subfields
- Solution 1: store a string with some delimiter between each subfield as the value for a particular filed in the MARC
  - This would require additional parsing on the client side to extract all the different subfields
- Solution 2: further expand the Redis key syntax and use a list or some other data structure as value for each subfield key

  ```bash
  127.0.0.1:6379> LPUSH marc:1:856:1:u https://books.google.com/books?id=Nhe2yvx6hP8C http://www.amazon.com/Infinite-Jest-David-Foster-Wallace/
  (integer) 2
  127.0.0.1:6379> HSET marc:1:856:1 u marc:1:856:1:u
  (integer) 0
  ```

### List vs Set vs Sorted-Set
- List
  - Layout

    ```
    [
      https://google.books.com/1
      https://amazon.com/book/1,
      https://google.books.com/1
    ]
    ```
  - Pros
    - Fast
    - Maintains ordering
  - Cons
    - Allow duplicates
- Set
  - Layout
    ```
    (
      https://google.books.com/1
      https://amazon.com/book/1,
    )
    ```
  - Pros
    - All values unique
    - Set algebra available
  - Cons
    - No ordering of values
- Sorted-Set
  - Layout
    ```
    (
      (1, https://google.books.com/1),
      (2, https://amazon.com/book/1),
    )
    ```
  - Pros
    - All values unique
    - Maintains ordering through weights
  - Cons
    - Slowest of the three
  - Example

    ```bash
    127.0.0.1:6379> DEL marc:1:856:1:u
    (integer) 1
    127.0.0.1:6379> ZADD marc:1:856:1:u 1 https://books.google.com/books?id=Nhe2yvx6hP8C 2 http://www.amazon.com/Infinite-Jest-David-Foster-Wallace/
    (integer) 2
    127.0.0.1:6379> ZRANGE marc:1:856:1:u 0 -1 WITHSCORES
    1) "https://books.google.com/books?id=Nhe2yvx6hP8C"
    2) "1"
    3) "http://www.amazon.com/Infinite-Jest-David-Foster-Wallace/"
    4) "2"
    ```

## Popular usage patterns
### An in-memory cache for web apps

@TODO: workflow

- By utilizing Redis's ability to set an expiration time on a key, one of Redis' popular caching strategies called Less Recently Used (LRU) is robust enough to handle even the largest web properties, with the most popular content remaining in cache but stale and little-used data being evicted from the data store

### Metric storage
- Example: quantitative data such as web page usage and user behavior on gamer leaderboards

### Pub/Sub model
- One post messages to one or more channels that can be acted upon by other systems that have subscribed to or are listening to that channel for incoming messages

## Redis isn't right because ... try again soon!
- Redis follows a common semantic versioning pattern of `major.minor.patchlevel` 
  - an even/odd `minor` even number denoting a **stable**/**unstable** version

[redis commands]: https://redis.io/commands
