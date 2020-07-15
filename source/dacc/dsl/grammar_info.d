module dacc.dsl.grammar_info;

import std.algorithm;
import std.array;
import std.ascii;
import std.conv;
import std.stdio;
import dacc.data;
import dacc.grammar;
import dacc.LALR;
import dacc.dsl.parse;

unittest {
    writeln("## dacc.dsl.grammar_info unittest 1");
    auto grammar_info = new GrammarInfo(
    // configs
    r"",
    // tokens
    r"
add +
sub -
div /
mul *
lp (
rp )
digit
",
    // grammar
    r"
Expr:
    Expr add Term `$$ = $1 + $3;`,
    Expr sub Term `$$ = $1 - $3; `,
    Term `$$ = $1;`;
Term:
    Term mul UExp `$$ = $1 * $3; `,
    Term div UExp `$$ = $1 / $3;`,
    UExp `$$ = $1; `;
UExp:
    add UExp `$$ = $2;`,
    sub UExp ` $$ = -$2; `,
    Fact `$$ = $1;`;
Fact:
    lp Expr rp ` $$ = $2; `,
    digit ` $$ = $1.str.to!long;`,;
",
    // type infos
    r"
%token : Token
Expr Term UExp Fact : long
",
    //
    );

    writeln(grammar_info.generate_code());
}

class GrammarInfo {
    Grammar grammar;
    string[] exec_code;
    LALRTableInfo table_info;
    string[string] type_of_symbols;
    string[] symbol_ids;

    // corresponding type (in the sense of D) of non-terminal symbols
    string[string] cor_type;

    this (string configns, string token_def, string grammar_def, string types_info) {
        /*auto sections = def.split("%%");
        if (sections.length != 4) {
            writeln("Error: Invalid definition file. <configurations> %% <token definitions> %% <grammar definition> %% <type of symbols>");
            return;
        }
        // separate
        auto   configs = sections[0],
             token_def = sections[1],
           grammar_def = sections[2],
          types info = sections[3];
        */
        /* ********** get configurations *********** */
        bool style_check = true;

        /* ********** set all tokens *********** */
        auto token_list = token_def.split('\n');    // list of tokens got from the definition file
        string[] names_of_tokens;   // array of the names that will be passed to Grammar
        Symbol[string] token_dict;  // collect all tokens
        Symbol token_counter = 0;
        // process
        foreach (one_line; token_list) if (one_line.length > 0) {
            // id name
            // e.g. add +
            auto id_and_name = one_line.split;
            if (id_and_name.length == 0) continue;

            // set token's identifier
            string token_id;
            if (id_and_name.length > 0) token_id = id_and_name[0];

            // set token's name
            string token_name;
            if (id_and_name.length > 1) token_name = id_and_name[1];
            else token_name = id_and_name[0]; // if the name was not designated, it is the same as token_id

            // unnecessary information was there
            if (id_and_name.length > 2) {
                writeln("Error: '", one_line, "' third and latter string(s) are ignored.");
            }

            // tokens must start with lower letter
            if (style_check && !token_id[0].isLower()) {
                writeln("Error: '", token_id, "' is declared as a token, are you sure?");
            }

            // already appeared
            if (token_id in token_dict) {
                writeln("Error: '", token_id, "' has already appeared.");
            }
            else {
                token_dict[token_id] = token_counter++;
                names_of_tokens ~= token_name;
                symbol_ids ~= token_id;
            }
        }

        /* ************ set grammar ************ */
        auto dsl_grammar = parse(grammar_def);

        /* **** set symbol **** */
        Symbol[string] non_term_dict = ["empty": -1, "S'" : 0];
        string[] names_of_non_terms = ["S'"];
        Symbol symbol_num = 1;
        // get non terminal symbols
        foreach (production; dsl_grammar) {
            if (production.lhs in token_dict) {
                writeln("Error: '", production.lhs, "'is declared as a token.");
            }
            // new symbol
            if (production.lhs !in non_term_dict) {
                // set
                non_term_dict[production.lhs] = symbol_num;
                names_of_non_terms ~= production.lhs;
                symbol_ids = [production.lhs] ~ symbol_ids;

                ++symbol_num;

                // style checking
                // non-terminals must start with a capital alphabet
                if (style_check && !production.lhs[0].isUpper())
                    writeln("Warning: '", production.lhs, "' is used as a non-terminal symbol, are you sure?");
            }
        }

        // set productions and exec_code
        Production[] productions;
        foreach (production; dsl_grammar) {
            // set rhs
            Symbol[] rhs;
            foreach (id; production.rhs) {
                // terminal symbol
                auto ptr1 = id in token_dict;
                if (ptr1) {
                    rhs ~= *ptr1 + cast (Symbol)names_of_non_terms.length;
                    continue;
                }
                // non terminal symbol
                auto ptr2 = id in non_term_dict;
                if (ptr2) {
                    rhs ~= *ptr2;
                    continue;
                }
                writeln("Error: '", id, "' is not declared as a token or as a non-terminal symbol.");
            }

            productions ~= Production(non_term_dict[production.lhs], rhs);
            exec_code ~= production.code;
        }
        symbol_ids = ["S'"] ~ symbol_ids;

        // grammar class initialization
        grammar = new Grammar(
            productions,
            cast(Symbol) (names_of_non_terms.length-1 + names_of_tokens.length),
            cast(Symbol) names_of_non_terms.length-1,
            names_of_non_terms ~ names_of_tokens
        );

        /* ********** set table ********** */
        table_info = new LALRTableInfo(grammar);

        /* ********** set types ********** */
        auto type_info_list = types_info.split('\n');
        foreach (type_info_line; type_info_list) {
            auto sym_ids_and_type = type_info_line.split;
            if (sym_ids_and_type.length == 0) { continue; }
            // error
            if (sym_ids_and_type.length < 3) {
                writeln("Invalid type declaration '", type_info_line, "'");
                continue;
            }
            if (sym_ids_and_type[$-2] != ":") {
                writeln("' : ' (SPACE IS NEEDED!) is missing for the type declaration '", type_info_line, "'");
                continue;
            }
            // every symbols in 'sym_ids' have type 'type_code'
            auto type_code = sym_ids_and_type[$-1];
            auto sym_ids = sym_ids_and_type[0 .. $-2];
            if (sym_ids[0] == "%token")
                foreach (token; token_dict.byKey) {
                    // already appeared
                    if (token in type_of_symbols) {
                        writeln("Multiple declaration of the type of " ~ token ~ " by %token");
                    }
                    else type_of_symbols[token] = type_code;
                }
            else
                foreach (sym_id; sym_ids) {
                    // already appeared
                    if (sym_id in type_of_symbols) {
                        writeln("Multiple declaration of the type of " ~ sym_id);
                    }
                    else type_of_symbols[sym_id] = type_code;
                }
        }
        //writeln(type_of_symbols);
        // check if type is defined for every symbol.
        if (type_of_symbols.length < grammar.max_symbol) {
            foreach (id; symbol_ids[1..$]) {
                if (id !in type_of_symbols) {
                    writeln("Type of ", id, " is not defined.");
                }
            }
        }
    }

    // generate the whole parser module
    string generate_code() {
        return generate_code("TokenKind");
    }

    private string generate_code(string token_kind) {
        string result;
        // definition for dacc
        result ~= internal_defs(token_kind) ~ "\n\n";
        // LR table information
        result ~= "dacc_Sorted_Column[" ~ table_info.state_set.length.to!string ~ "] dacc_table = "
                ~ table_info.generate_table_literal() ~ "\n\n";
        // reduce funtions
        result ~= reduce_func(type_of_symbols, true) ~ "\n\n";
        // parser functinos
        result ~= parser_func(type_of_symbols[grammar.nameOf(1)], "parse") ~ "\n";
        return result;
    }

    private string internal_defs(string token_kind) {
        return
`import std.variant;
// lexer
interface dacc_Lexer {
    Variant token();
    ` ~ token_kind ~ ` token_kind();
    void nextToken();
}
import std.traits: ReturnType;
enum dacc_isLexer(T) = (
    is(ReturnType!((T t) => t.token()) == Variant) &&
    is(ReturnType!((T t) => t.token_kind()) == ` ~ token_kind ~ `) &&
    is(typeof({T t; t.nextToken();}))
);
// LR Actions
enum dacc_Action : ubyte {
    error = 0, accept = 1, shift = 2, reduce = 3, goto_ = 4,
}
struct dacc_LREntry {
    align(1):
    int sym;
    dacc_Action action;
    uint num;
}
private pure dacc_LREntry_cmp(dacc_LREntry a, dacc_LREntry b) {
    return a.sym < b.sym;
}
alias dacc_Sorted_Column = std.range.SortedRange!(dacc_LREntry[], dacc_LREntry_cmp);
alias dacc_Sorted_column = std.range.assumeSorted!(dacc_LREntry_cmp, dacc_LREntry[]);`;
    }

    private string reduce_func(string[string] type_info, bool insert_assertion = false) {
        // $$ -> dacc_s_result
        // $7 -> dacc_s7
        string process_reduce_code(string code) {
            import std.regex;
            auto reg1 = regex(`(\$\$)|(\$[0-9]+)`);
            auto reg2 = regex(`\n[^\t]`);
            return ("\n" ~ code).replaceAll!(
                match =>
                  match.hit == "$$" ?
                    "dacc_s_result" :
                    "(*dacc_s" ~ match.hit[1..$] ~ ")"
            )(reg1).replaceAll!(
                match => "\n\t\t" ~ match.hit[1..$]
            )(reg2);
        }

        string process_one_production(size_t num) {
            auto prod = grammar.productions[num];
            // comment
            string result = "\t//" ~ grammar.production_string(num);
            // case block
            result ~= "\n\tcase " ~ num.to!string ~ "u:\n";
            result ~= "\t\t" ~ type_info[symbol_ids[prod.lhs]] ~ " " ~ "dacc_s_result;\n";

            auto r = prod.rhs.length;
            foreach (i, sym; prod.rhs) {
                //writeln(type_info, grammar.nameOf(sym));
                result ~= "\t\tauto " ~ "dacc_s" ~ (i+1).to!string
                        ~ " = dacc_ast_stack[$-" ~ (r-i).to!string ~ "].peek!(" ~ type_info[symbol_ids[sym]] ~ ");\n";
                result ~= "\t\tassert(dacc_s" ~ (i+1).to!string ~ ");\n";
            }
            result ~= process_reduce_code(exec_code[num]) ~ "\n\n";
            if (prod.rhs[0] == empty_) {
                result ~= "\t\tdacc_ast_stack ~= dacc_s_result;\n"
                        ~ "\t\treturn " ~ prod.lhs.to!string ~ ";\n";
            }
            else {
                result ~= "\t\tdacc_ast_stack.length -= " ~ (r-1).to!string ~ "; dacc_ast_stack[$-1] = dacc_s_result;\n"
                        ~ "\t\tdacc_state_stack.length -= " ~ r.to!string ~ ";\n"
                        ~ "\t\treturn " ~ prod.lhs.to!string ~ ";\n";
                /* This does not work for some reason:
                result ~= "\t\tdacc_ast_stack.length -= " ~ (prod.rhs.length-1).to!string ~ "; dacc_ast_stack[$-1] = dacc_s_result;\n"
                        ~ "\t\tdacc_state_stack.length -= " ~ (prod.rhs.length).to!string ~ ";\n"
                        ~ "\t\treturn " ~ prod.lhs.to!string ~ ";\n";
                */
            }
            return result;
        }

        string result =
`int dacc_reduce(uint dacc_num, ref Variant[] dacc_ast_stack, ref uint[] dacc_state_stack) {
    switch (dacc_num) {
`;
        // except S' => S
        foreach (num; 0 .. grammar.productions.length-1) {
            result ~= process_one_production(num);
        }
        return result ~ "\tdefault: assert(0);\n\t}\n}";
    }

    private string parser_func(string ret_type, string parser_func_name) {
        return
ret_type ~ "* " ~ parser_func_name ~ `(L)(L lexer)
    if (dacc_isLexer!L)
{
    Variant[] dacc_ast_stack;
    uint[] state_stack = [0u];

    dacc_LREntry getEntry(uint state, int symbol) {
        auto ent = dacc_table[state].equalRange(dacc_LREntry(symbol, dacc_Action.init, uint.init));
        if (ent.empty) return dacc_LREntry(symbol, dacc_Action.error, 0u);
        else return ent.front;
    }
    parsing_routine:
    while (true) {
        auto current_state = state_stack[$-1];
        auto entry = getEntry(current_state, lexer.token_kind +` ~ (grammar.max_nonterminal_symbol+1).to!string ~ `); // terminal symbols start from ` ~ (grammar.max_nonterminal_symbol+1).to!string ~ ` in the internal processing
        final switch (entry.action) {
        case dacc_Action.shift:
            state_stack ~= entry.num; // push
            dacc_ast_stack ~= lexer.token(); //push
            lexer.nextToken();
            break;
        case dacc_Action.reduce:
            auto symbol = dacc_reduce(entry.num, dacc_ast_stack, state_stack);
            auto goto_entry = getEntry(state_stack[$-1], symbol);
            //assert(goto_entry.action == dacc_Action.goto_);
            state_stack ~= goto_entry.num;
            break;
        case dacc_Action.accept:
            break parsing_routine;
        case dacc_Action.error:
            //error();
            return null;    // error
        case dacc_Action.goto_:
            assert(0);
        }
    }
    return dacc_ast_stack[0].peek!(` ~ ret_type ~ `);
}`;
    }
}
