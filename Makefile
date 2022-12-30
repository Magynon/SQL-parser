#Magirescu Stefan 335C
CC=gcc
FLEX=lex

build: sql_parser.l
	@echo "Building sql_parser..."
	$(FLEX) sql_parser.l
	$(CC) lex.yy.c

clean:
	@echo "Cleaning up..."
	rm -f a.out lex.yy.c sql_parser.cpp sql_parser

run: sql_parser
	@echo "Running sql_parser..."
	./sql_parser input_copy.txt

all: sql_parser run

.PHONY: clean run all
