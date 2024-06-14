# What is this?

This is a [finite state machine](https://en.wikipedia.org/wiki/Finite-state_machine) implemented in SQL (specifically, SQLite). It uses a recursive CTE and a JSON object to 
implement a [lexical analyzer](https://en.wikipedia.org/wiki/Lexical_analysis), aka a tokenizer. Usually used as the first stage of a compiler or interpreter, the lexer converts
an input string into a stream of tokens.

# Why?

There is a lot of discussion concerning whether SQL is a [Turing-complete](https://en.wikipedia.org/wiki/Turing_completeness) language. Up until recursive CTEs were added, the answer to that
question was 'no', since there wasn't any way to implement a deterministic looping structure. This is a proof-of-concept exercise to show that a non-trivial solution can be coded using
a mixture of recursive CTEs and JSON objects.

# Practical applications

There are probably none. While this exercise shows that something like a state machine can be implemented in SQL, it will always be easier to use an imperative language to do so.
