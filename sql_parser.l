  /* Magirescu Stefan 335C */
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

FILE *fp;
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
%x ALTER_TABLE_NAME
%x ALTER_TABLE
%x ALTER_TABLE_ADD
%x ALTER_TABLE_DROP
%x ALTER_TABLE_ADD_TYPE

%%

  /* ------------------------- */
  /*  CREATE TABLE STATE MACHINE */
  /* ------------------------- */

  /* parses the CREATE TABLE command */
"CREATE"[ ]+"TABLE"[ ]+ { BEGIN(TABLE_NAME); }

  /* parses the table name */
<TABLE_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  int found = 0;

  // check if the table already exists
  struct TableNode *current = tables;
  while (current != NULL) {
    if (strcmp(current->table.name, yytext) == 0) {
      printf("Invalid command\n");
      found = 1;
      break;
    }
    current = current->next;
  }

  if (found == 1) {
    BEGIN(INITIAL);
  } else {
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
}

  /* parses the constraint command */
<COLUMN_NAME>"CONSTRAINT"[ ]+ {
  BEGIN(PRIMARY_CONSTRAINT_NAME);
}

  /* parses the primary key command */
<COLUMN_NAME>"PRIMARY"[ ]+"KEY"[ ]+"\(" { BEGIN(TABLE_PRIMARY_KEY); }

  /* parses the column name */
<PRIMARY_CONSTRAINT_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  // Add the constraint name to the current table
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }

  current->table.constraint_name = malloc(strlen(yytext) + 1);
  strcpy(current->table.constraint_name, yytext);

  BEGIN(COLUMN_NAME);
}

  /* parses the table primary key name */
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

  /* parses the column name */
<COLUMN_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }
  struct Column *current_column = current->table.columns;

  // check if the column already exists
  while (current_column != NULL) {
    if (strcmp(current_column->name, yytext) == 0) {
      printf("Invalid command\n");
      BEGIN(INITIAL);
    }
    current_column = current_column->next;
  }

  // allocate memory for the new column
  struct Column *new_column = malloc(sizeof(struct Column));
  new_column->next = NULL;
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

  /* parses the data type */
<DATA_TYPE>[a-zA-Z][a-zA-Z0-9_\(\)]* {
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }

  struct Column *current_column = current->table.columns;
  while (current_column->next != NULL) {
    current_column = current_column->next;   
  }

  // Add the data type to the current column
  current_column->data_type = malloc(strlen(yytext) + 1);
  strcpy(current_column->data_type, yytext);

  BEGIN(CONSTRAINT_NAME);
}

  /* parses the constraint command */
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

  /* parses the primary key command */
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
<DATA_TYPE>","[ \t\n]* { BEGIN(COLUMN_NAME); }
<CONSTRAINT_NAME>[ \t\n]*","[ \t\n]* { BEGIN(COLUMN_NAME); }

<COLUMN_NAME>")"[ \t\n]* { BEGIN(INITIAL); }
<DATA_TYPE>")"[ \t\n]* { BEGIN(INITIAL); }
<CONSTRAINT_NAME>[\)]*[ \t\n]*");"[ \t\n]* { BEGIN(INITIAL); }


  /* ------------------------- */
  /*  DESCRIBE TABLE STATE MACHINE */
  /* ------------------------- */

  /* parses the describe command */
"DESCRIBE"[ \t\n]+ {
  BEGIN(DESCRIBE_TABLE_NAME);
}

  /* parses the table name */
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

  /* parses the semicolon */
<DESCRIBE_TABLE_NAME>";" {
  BEGIN(INITIAL);
}


  /* ------------------------- */
  /*  INSERT TABLE STATE MACHINE */
  /* ------------------------- */

  /* parses the insert command */
"INSERT"[ ]+"INTO"[ ]+ {
  insert_mode_columns = 0;
  BEGIN(INSERT_TABLE_NAME);
}

  /* parses the table name */
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

  /* parses the open parantheses */
<INSERT>[ \t\n]*"(" {
  insert_columns = 0;
  insert_mode_columns = 1;
  BEGIN(INSERT_COLUMNS);
}

  /* read values */
<INSERT>[ \t\n]*"VALUES"[ \t\n]*"(" {
  BEGIN(INSERT_VALUES);
}

  /* parses the columns names */
<INSERT_COLUMNS>[a-zA-Z0-9_]+ {
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

  /* parses the commas */
<INSERT_COLUMNS>[ \t\n]*","[ \t\n]* {
  BEGIN(INSERT_COLUMNS);
}

  /* parses the close parantheses */
<INSERT_COLUMNS>[ \t\n]*")" {
  BEGIN(INSERT_VALUES);
}

  /* parses the values */
<INSERT_VALUES>[ \t\n]*"VALUES"[ \t\n]* {
  insert_values = 0;
  BEGIN(INSERT_VALUES);
}

  /* parses the values */
<INSERT_VALUES>[ \t\n]*[\(,][ \t\n]* {
  BEGIN(INSERT_VALUES);
}

  /* parses the values */
<INSERT_VALUES>[\"]*[a-zA-Z0-9 ]+[\"]* {
  // increment the number of values
  insert_values++;
  BEGIN(INSERT_VALUES);
}

  /* parses the close parantheses */
<INSERT_VALUES>");" {
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

  /* parses the alter command */
"ALTER"[ ]+"TABLE"[ ]+ {
  BEGIN(ALTER_TABLE_NAME);
}

  /* parses the table name */
<ALTER_TABLE_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  int found = 0;
  if (tables == NULL){
    printf("Invalid command\n");
  } else {
    struct TableNode *current = tables;
    while (current != NULL) {
      if (strcmp(current->table.name, yytext) == 0) {
        strcpy(current_table, yytext);
        found = 1;
        break;
      }
      current = current->next;
    }
  }
  if (found == 0) {
    printf("Invalid command\n");
    BEGIN(INITIAL);
  } else {
    BEGIN(ALTER_TABLE);
  }
}

  /* parses the add command */
<ALTER_TABLE>"ADD" {
  BEGIN(ALTER_TABLE_ADD);
}

  /* parses the drop command */
<ALTER_TABLE>"DROP"[ \t\n]*"COLUMN" {
  BEGIN(ALTER_TABLE_DROP);
}

  /* parses the column name */
<ALTER_TABLE_ADD>[a-zA-Z][a-zA-Z0-9_]* {
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }
  current->table.num_columns++;

  // add the column to the table
  struct Column *newColumn = (struct Column *) malloc(sizeof(struct Column));
  newColumn->name = (char *) malloc(strlen(yytext) + 1);
  strcpy(newColumn->name, yytext);
  newColumn->next = NULL;

  if (current->table.columns == NULL) {
    current->table.columns = newColumn;
  } else {
    struct Column *currentColumn = current->table.columns;
    while (currentColumn->next != NULL) {
      currentColumn = currentColumn->next;
    }
    currentColumn->next = newColumn;
  }

  BEGIN(ALTER_TABLE_ADD_TYPE);
}

  /* parses the column type */
<ALTER_TABLE_ADD_TYPE>[a-zA-Z][a-zA-Z0-9_\(\)]* {
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }

  // add the type to the table
  struct Column *currentColumn = current->table.columns;
  while (currentColumn->next != NULL) {
    currentColumn = currentColumn->next;
  }
  currentColumn->data_type = (char *) malloc(strlen(yytext) + 1);
  strcpy(currentColumn->data_type, yytext);

  BEGIN(ALTER_TABLE);
}

  /* parses the column name */
<ALTER_TABLE_DROP>[a-zA-Z][a-zA-Z0-9_]* {
  struct TableNode *current = tables;
  while (strcmp(current->table.name, current_table) != 0) {
    current = current->next;
  }
  current->table.num_columns--;

  // remove the column from the table
  struct Column *currentColumn = current->table.columns;
  struct Column *previousColumn = NULL;
  while (currentColumn != NULL) {
    if (strcmp(currentColumn->name, yytext) == 0) {
      if (previousColumn == NULL) {
        current->table.columns = currentColumn->next;
      } else {
        previousColumn->next = currentColumn->next;
      }
      free(currentColumn);
      break;
    }
    previousColumn = currentColumn;
    currentColumn = currentColumn->next;
  }

  BEGIN(ALTER_TABLE);
}

  /* parses the end of the alter command */
<ALTER_TABLE>";" {
  BEGIN(INITIAL);
}

  /* ------------------------- */
  /*  DROP TABLE STATE MACHINE */
  /* ------------------------- */

  /* parses the drop command */
"DROP"[ ]+"TABLE"[ \t\n]+ {
  BEGIN(DROP_TABLE_NAME);
}

  /* parses the table name */
<DROP_TABLE_NAME>[a-zA-Z][a-zA-Z0-9_]* {
  if (tables == NULL) {
    printf("Invalid command\n");

  } else {
    int tableFound = 0;
    struct TableNode *current = tables;
    struct Table temp;

    // if only one table exists or if table is the last one
    if (current->next == NULL && strcmp(current->table.name, yytext) == 0) {
      tableFound = 1;
      temp = current->table;
      tables = NULL;
    }

    // if table is the first one
    if (tableFound == 0 && strcmp(current->table.name, yytext) == 0) {
      tableFound = 1;
      temp = current->table;
      tables = current->next;
    }

    // if more than one table exists
    while (tableFound == 0 && current->next != NULL) {
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

      current = tables;
    } else {
      printf("Invalid command\n");
    }
  }

  BEGIN(DROP_TABLE_NAME);
}

  /* parses the end of the drop command */
<DROP_TABLE_NAME>[ \t\n]*; {
  BEGIN(INITIAL);
}

"--".*\n { BEGIN(COMMENT); }
<COMMENT>.+\n { BEGIN(INITIAL); }
[ \t\n] {  }

. { }

%%

int main(int argc, char **argv) {
  fp = fopen(argv[1], "r");
  yyin = fp;
  yylex();
  fclose(fp);
  return 0;
}

void yyerror(const char *s) {
  printf("Error: %s\n", s);
}