CC=gcc
FLEX=lex

build: sql_parser.l
	$(FLEX) sql_parser.l
	$(CC) lex.yy.c

clean:
	rm -f a.out lex.yy.c sql_parser.cpp

run: sql_parser
	./sql_parser < input.sql

all: sql_parser run

.PHONY: clean run all
