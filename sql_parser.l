%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <regex.h>

struct Column {
  char *name;
  char *data_type;
  char *constraint;
  struct Column *next;
};

struct Table {
  char *name;
  char *primary_key;
  char *constraint_name;
  int num_columns;
  int num_records;
  struct Column *columns;
};

struct TableNode {
  struct Table table;
  struct TableNode *next;
};

struct TableNode *tables = NULL;
char *current_table;
bool primary_key_found;
int insert_columns, insert_values, insert_mode_columns;
%}

%option noyywrap

%x COMMENT
%x TABLE_NAME
%x COLUMN_NAME
%x DATA_TYPE
%x CONSTRAINT_NAME
%x TABLE_PRIMARY_KEY
%x DESCRIBE_TABLE_NAME
%x DROP_TABLE_NAME
%x PRIMARY_CONSTRAINT_NAME
%x INSERT_TABLE_NAME
%x INSERT_VALUES
%x INSERT_COLUMNS
%x INSERT

%%

  /* ------------------------- */
  /*  CREATE TABLE STATE MACHINE */
  /* ------------------------- */

"CREATE"[ ]+"TABLE"[ ]+ { BEGIN(TABLE_NAME); }

<TABLE_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  // check if the table already exists
  struct TableNode *current = tables;
  while (current != NULL) {
    if (strcmp(current->table.name, yytext) == 0) {
      printf("Invalid command\n");
      BEGIN(INITIAL);
    }
    current = current->next;
  }

  // Create a new table
  struct TableNode *new_table = malloc(sizeof(struct TableNode));
  new_table->table.name = malloc(strlen(yytext) + 1);
  strcpy(new_table->table.name, yytext);
  new_table->table.primary_key = NULL;
  new_table->table.num_columns = 0;
  new_table->table.num_records = 0;
  new_table->table.columns = NULL;
  new_table->next = NULL;

  // Add the new table to the list of tables
  if (tables == NULL) {
    tables = new_table;
  } else {
    struct TableNode *current = tables;
    while (current->next != NULL) {
      current = current->next;
    }
    current->next = new_table;
  }

  current_table = malloc(strlen(yytext) + 1);
  strcpy(current_table, yytext);

  BEGIN(COLUMN_NAME);
}

<COLUMN_NAME>"CONSTRAINT"[ ]+ {
  BEGIN(PRIMARY_CONSTRAINT_NAME);
}

<COLUMN_NAME>"PRIMARY"[ ]+"KEY"[ ]+"\(" { BEGIN(TABLE_PRIMARY_KEY); }

<PRIMARY_CONSTRAINT_NAME>[a-zA-Z][a-zA-Z0-9_]*[ ]+ {
  // Add the constraint name to the current table
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }
  current->table.constraint_name = malloc(strlen(yytext) + 1);

  yytext[strlen(yytext) - 1] = '\0'; // remove the trailing space
  strcpy(current->table.constraint_name, yytext);

  BEGIN(COLUMN_NAME);
}

<TABLE_PRIMARY_KEY>[a-zA-Z][a-zA-Z0-9_]* {
  // Add the primary key to the current table
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }
  current->table.primary_key = malloc(strlen(yytext) + 1);
  strcpy(current->table.primary_key, yytext);

  BEGIN(CONSTRAINT_NAME);
}

<COLUMN_NAME>[a-zA-Z][a-zA-Z0-9_]*[ ]+ { 
  // check if the column already exists
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }
  struct Column *current_column = current->table.columns;
  while (current_column != NULL) {
    if (strcmp(current_column->name, yytext) == 0) {
      printf("Invalid command\n");
      BEGIN(INITIAL);
    }
    current_column = current_column->next;
  }

  // allocate memory for the new column
  struct Column *new_column = malloc(sizeof(struct Column));
  new_column->name = malloc(strlen(yytext) + 1);
  strcpy(new_column->name, yytext);
  new_column->data_type = NULL;
  new_column->constraint = NULL;

  // Add the new column to the list of columns
  if (current->table.columns == NULL) {
    current->table.columns = new_column;
  } else {
    struct Column *current_column = current->table.columns;
    while (current_column->next != NULL) {
      current_column = current_column->next;
    }
    current_column->next = new_column;
  }
  current->table.num_columns++;

  BEGIN(DATA_TYPE); 
}

<DATA_TYPE>[a-zA-Z][a-zA-Z0-9_\(\)]* {
  // Add the data type to the current column
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }
  struct Column *current_column = current->table.columns;
  while (current_column->next != NULL) {
    current_column = current_column->next;
  }

  current_column->data_type = malloc(strlen(yytext) + 1);
  strcpy(current_column->data_type, yytext);

  BEGIN(CONSTRAINT_NAME);
}

<CONSTRAINT_NAME>"NOT"[ ]+"NULL" {
  // Add the constraint to the current column
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }
  struct Column *current_column = current->table.columns;
  while (current_column->next != NULL) {
    current_column = current_column->next;
  }

  // concat the constraint to the existing constraint
  if (current_column->constraint == NULL) {
    current_column->constraint = malloc(strlen(yytext) + 1);
    strcpy(current_column->constraint, yytext);
  } else {
    char *new_constraint = malloc(strlen(current_column->constraint) + strlen(yytext) + 2);
    strcpy(new_constraint, current_column->constraint);
    strcat(new_constraint, " ");
    strcat(new_constraint, yytext);
    free(current_column->constraint);
    current_column->constraint = new_constraint;
  }

  BEGIN(CONSTRAINT_NAME);
}

<CONSTRAINT_NAME>"PRIMARY"[ ]+"KEY" {
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }

  struct Column *current_column = current->table.columns;
  while (current_column->next != NULL) {
    current_column = current_column->next;
  }

  // set the table's primary key
  current->table.primary_key = malloc(strlen(current_column->name) + 1);
  strcpy(current->table.primary_key, current_column->name);
  
  BEGIN(CONSTRAINT_NAME);
}

<COLUMN_NAME>[ \t\n]*[,\(][ \t\n]* { BEGIN(COLUMN_NAME); }
<DATA_TYPE>","[ ]* { BEGIN(COLUMN_NAME); }
<CONSTRAINT_NAME>[ \t\n]*","[ \t\n]* { BEGIN(COLUMN_NAME); }

<COLUMN_NAME>")"[ ]* { BEGIN(INITIAL); }
<DATA_TYPE>")"[ ]* { BEGIN(INITIAL); }
<CONSTRAINT_NAME>[\)]*[ \t\n]*");"[ \t\n]* { BEGIN(INITIAL); }


  /* ------------------------- */
  /*  DESCRIBE TABLE STATE MACHINE */
  /* ------------------------- */


"DESCRIBE"[ \t\n]+ {
  BEGIN(DESCRIBE_TABLE_NAME);
}
<DESCRIBE_TABLE_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  if (tables == NULL){
    printf("Invalid command\n");

  } else {
    struct TableNode *current = tables;
    while (current != NULL) {
      if (strcmp(current->table.name, yytext) == 0) {
        // print the table name
        printf("Table name: %s\n", yytext);

        // print the primary key
        if(current->table.constraint_name == NULL){
          printf("Primary key: %s\n", current->table.primary_key);
        } else {
          printf("Primary key: %s(%s)\n", current->table.constraint_name, current->table.primary_key);
        }
        break;
      }
      current = current->next;
    }

    // print the number of columns
    int num_columns = 0;
    struct Column *current_column = current->table.columns;
    while (current_column != NULL) {
      num_columns++;
      current_column = current_column->next;
    }
    printf("Number of columns: %d\n", num_columns);

    // print the number of records
    printf("Number of records: %d\n", current->table.num_records);
  }
  BEGIN(DESCRIBE_TABLE_NAME);
}

<DESCRIBE_TABLE_NAME>[ \t\n]*; {
  BEGIN(INITIAL);
}


  /* ------------------------- */
  /*  INSERT TABLE STATE MACHINE */
  /* ------------------------- */


"INSERT"[ ]+"INTO"[ ]+ {
  insert_mode_columns = 0;
  BEGIN(INSERT_TABLE_NAME);
}

<INSERT_TABLE_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  if (tables == NULL){
    printf("Invalid command\n");
  } else {
    struct TableNode *current = tables;
    while (current != NULL) {
      if (strcmp(current->table.name, yytext) == 0) {
        strcpy(current_table, yytext);
        break;
      }
      current = current->next;
    }
  }
  BEGIN(INSERT);
}

<INSERT>[ \t\n]*[\(\),]* {
  insert_columns = 0;
  insert_mode_columns = 1;
  BEGIN(INSERT_COLUMNS);
}

  /* read values */
<INSERT>[ \t\n]*"VALUES"[ \t\n]*[a-zA-Z0-9\", \(\)]+ {
  BEGIN(INSERT_VALUES);
}

<INSERT_COLUMNS>[a-zA-Z0-9]+ {
  // increment the number of columns
  insert_columns++;

  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }

  if (insert_columns > current->table.num_columns) {
    printf("Invalid command\n");
    BEGIN(INITIAL);
  } else {
    BEGIN(INSERT_COLUMNS);
  }
}

<INSERT_COLUMNS>[ \t\n]*","[ \t\n]* {
  BEGIN(INSERT_COLUMNS);
}

<INSERT_COLUMNS>[ \t\n]*")" {
  BEGIN(INSERT_VALUES);
}

<INSERT_VALUES>[ \t\n]*"VALUES" {
  insert_values = 0;
  BEGIN(INSERT_VALUES);
}

<INSERT_VALUES>[ \t\n]*[\(,] {
  BEGIN(INSERT_VALUES);
}

<INSERT_VALUES>[a-zA-Z0-9]+ {
  printf("Value: %s\n", yytext);

  // increment the number of values
  insert_values++;

  BEGIN(INSERT_VALUES);
}

<INSERT_VALUES>")"[ \t\n]*";" {
  if (insert_mode_columns == 1 && insert_columns != insert_values) {
    printf("Invalid command\n");
  } 
  else {
    // increment the number of records
    struct TableNode *current = tables;
    while (strcmp(current->table.name, current_table) != 0) {
      current = current->next;
    }
    current->table.num_records++;
  }
  
  BEGIN(INITIAL);
}

  /* ------------------------- */
  /*  ALTER TABLE STATE MACHINE */
  /* ------------------------- */


"ALTER"[ ]+"TABLE"[ ]+[a-zA-Z][a-zA-Z0-9_]*[ \t\n]+"ADD"[ ]+[a-zA-Z][a-zA-Z0-9_]*[ ]+[a-zA-Z][a-zA-Z0-9_]*; {
	printf("%s\n", yytext);
}
"ALTER"[ ]+"TABLE"[ ]+[a-zA-Z][a-zA-Z0-9_]*[ \t\n]+"DROP"[ ]+"COLUMN"[ ]+[a-zA-Z][a-zA-Z0-9_]*[ ]*; {
	printf("%s\n", yytext);
}


  /* ------------------------- */
  /*  DROP TABLE STATE MACHINE */
  /* ------------------------- */

"DROP"[ ]+"TABLE"[ \t\n]+ {
  BEGIN(DROP_TABLE_NAME);
}

<DROP_TABLE_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  if (tables == NULL) {
    printf("Invalid command\n");

  } else {
    int tableFound = 0;
    struct TableNode *current = tables;
    struct Table temp;

    // if only one table exists or if table is the last one
    if (current->next == NULL && strcmp(current->table.name, yytext) == 0) {
      printf("one table exists\n");
      tableFound = 1;
      temp = current->table;
      tables = NULL;
    }

    // if table is the first one
    if (tableFound == 0 && strcmp(current->table.name, yytext) == 0) {
      printf("table is the first one\n");
      tableFound = 1;
      temp = current->table;
      tables = current->next;
    }

    // if more than one table exists
    while (tableFound == 0 && current->next != NULL) {
      printf("current->next->table.name: %s\n", current->next->table.name);
      if (strcmp(current->next->table.name, yytext) == 0) {
        tableFound = 1;
        temp = current->next->table;
        current->next = current->next->next;
        break;
      }
      current = current->next;
    }

    // free the table
    if (tableFound) {
      free(temp.name);

      if (temp.constraint_name != NULL) {
        free(temp.constraint_name);
      }
      if (temp.primary_key != NULL) {
        free(temp.primary_key);
      }

      struct Column *current_column = temp.columns;
      while (current_column != NULL) {
        struct Column *tempCol = current_column;
        current_column = current_column->next;
        free(tempCol->name);
        free(tempCol->data_type);
        free(tempCol->constraint);
        free(tempCol);
      }
      printf("Table %s dropped\n", yytext);

      // print all tables names
      printf("Tables: ");
      current = tables;
      while (current != NULL) {
        printf("%s ", current->table.name);
        current = current->next;
      }
      printf(".\n");
    } else {
      printf("Invalid command\n");
    }
  }

  BEGIN(DROP_TABLE_NAME);
}

<DROP_TABLE_NAME>[ \t\n]*; {
  BEGIN(INITIAL);
}

"--".*\n { BEGIN(COMMENT); }
<COMMENT>.+\n { BEGIN(INITIAL); }

[ \t\n]+ { /* ignore whitespace */ }
. { printf("Invalid command\n"); }

%%

int main(void) {
  yylex();
  return 0;
}

void yyerror(const char *s) {
  printf("Error: %s\n", s);
}