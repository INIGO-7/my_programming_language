%{
#include "common_lib.h"

int yylex(void);
void yyerror(const char *s);

astnode_t *root_ast;
%}

%debug

%union {
    astnode_t *ast;
    int number;
    float decimal; 
    char* string;
    bool boolean;
    bool bool_op_type;
}

%token <number> NUMBER
%token <decimal> DECIMAL
%token <string> IDENTIFIER STRING
%token WHILE FOR FUNC FUNCSTART FUNCEND
%token TRUE FALSE
%token AND OR NOT
%token EQ NEQ LT GT LE GE
%token PRINT ASSIGN SEMICOLON COLON
%token PLUS MINUS MUL DIV EXP
%token OPENPAR CLOSEPAR

/* Declare types for our new non-terminals */
%type <ast> stmt stmts expr term factor 
%type <ast> bool_expr compar_expr for_init for_update

/* Operator precedence and associativity */
%left PLUS MINUS
%left MUL DIV EXP
%left OR
%left AND
%right NOT
%left EQ NEQ
%left LT LE GT GE

%%

program     : stmts { init_symbol_table(); root_ast = $1; };

stmts       : stmt SEMICOLON {
              $$ = astnode_new(NODE_STMTS);
              astnode_add_child($$, $1, 0);
            }
            | stmts stmt SEMICOLON {
              $$ = astnode_new(NODE_STMTS);
              astnode_add_child($$, $1, 0);
              astnode_add_child($$, $2, 1);
            }
            ;

stmt        : IDENTIFIER ASSIGN expr {
                $$ = astnode_new(NODE_ASSIGN);
                $$->val.id = $1;
                astnode_add_child($$, $3, 0);
            }
            | IDENTIFIER ASSIGN bool_expr {
                $$ = astnode_new(NODE_ASSIGN);
                $$->val.id = $1;
                astnode_add_child($$, $3, 0);
            }
            | PRINT expr {
                $$ = astnode_new(NODE_PRINT);
                astnode_add_child($$, $2, 0);
            }
            | PRINT bool_expr {
                $$ = astnode_new(NODE_PRINT);
                astnode_add_child($$, $2, 0);
            }
            | WHILE bool_expr FUNCSTART stmts FUNCEND {
                $$ = astnode_new(NODE_WHILE);
                astnode_add_child($$, $2, 0);
                astnode_add_child($$, $4, 1);
            }
            | FOR for_init COLON bool_expr COLON for_update FUNCSTART stmts FUNCEND {
                $$ = astnode_new(NODE_FOR);
                astnode_add_child($$, $2, 0);   // for init
                astnode_add_child($$, $4, 1);   // for condition
                astnode_add_child($$, $6, 2);   // for update
                astnode_add_child($$, $8, 3);   // for body
            }
            ;

for_init    : IDENTIFIER ASSIGN expr {
                $$ = astnode_new(NODE_ASSIGN);
                $$->val.id = $1;
                astnode_add_child($$, $3, 0);
            }

for_update  : IDENTIFIER ASSIGN expr {
                $$ = astnode_new(NODE_ASSIGN);
                $$->val.id = $1;
                astnode_add_child($$, $3, 0);
            }

expr        : expr PLUS term    { 
                $$ = astnode_new(NODE_ADD);
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | expr MINUS term   { 
                $$ = astnode_new(NODE_SUB);
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | term              { $$ = $1; }
            ;

term        : term MUL factor   { 
                $$ = astnode_new(NODE_MUL);
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | term DIV factor   { 
                if ($3 == 0) {
                    fprintf(stderr, "Error: Division by zero\n");
                    exit(EXIT_FAILURE);
                }
                $$ = astnode_new(NODE_DIV);
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | term EXP factor   { 
                $$ = astnode_new(NODE_EXP);
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | factor            { $$ = $1; }
            ;

factor      : NUMBER            { 
                $$ = astnode_new(NODE_NUM);
                $$->val.num = $1;
            }
            | DECIMAL           { 
                $$ = astnode_new(NODE_DEC);
                $$->val.decimal = $1;
            }
            | STRING            {
                $$ = astnode_new(NODE_STRING);
                $$->val.str = strdup($1);
            }
            | IDENTIFIER        {
                $$ = astnode_new(NODE_ID);
                $$->val.id = $1;
            }
            | OPENPAR expr CLOSEPAR   { $$ = $2; }
            | MINUS factor            { 
                $$ = astnode_new(NODE_NUM);

                if ($2->type == NODE_NUM) {
                    if ($2->val.num) {
                       $$->val.num = -($2->val.num);
                    } else {
                        $$->val.decimal = -($2->val.decimal);
                    }
                }
            }  /* Handle unary minus */
            ;

bool_expr   : TRUE                            { 
                $$ = astnode_new(NODE_BOOL);
                $$->val.boolean = true;
            }
            | FALSE                           { 
                $$ = astnode_new(NODE_BOOL);
                $$->val.boolean = false;
            }
            | bool_expr AND bool_expr         { 
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("and");
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | bool_expr OR bool_expr          { 
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("or");
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | NOT bool_expr                   { 
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("not");
                astnode_add_child($$, $2, 0);
                printf("yes looks like its workin");
            }
            | compar_expr                     { $$ = $1; }
            | OPENPAR bool_expr CLOSEPAR      { $$ = $2; }            
            | IDENTIFIER                      { /*expr to handle bool id case*/
                $$ = astnode_new(NODE_ID);
                $$->val.id = $1;
            }
            ;

compar_expr : expr EQ expr    { 
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("eq");
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | expr NEQ expr   { 
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("neq");
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | expr LT expr    {
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("lt");
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | expr LE expr    {
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("le");
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | expr GT expr    {
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("gt");
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            | expr GE expr    {
                $$ = astnode_new(NODE_BOOL_OP);
                $$->val.bool_op_type = strdup("ge");
                astnode_add_child($$, $1, 0);
                astnode_add_child($$, $3, 1);
            }
            ;
%%
void yyerror(const char *s) {
    extern char *yytext;
    extern int yylineno;
    fprintf(stderr, "Error: %s at line %d, near token '%s'\n", s, yylineno, yytext);
}
