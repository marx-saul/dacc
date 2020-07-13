module dacc.dsl.grammar_info;

import std.algorithm;
import std.array;
import std.ascii;
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
    add,
    mul,
    lp,
    rp,
    id,
    ",
    // grammar
    r"
    Expr:
        Expr add Term `$$ = $1 + $3`,
        Term;
    Term:
        Term mul Fact `$$ = $1 * $3`,
        Fact;
    Fact:
        lp Expr rp `$$ = $2`,
        id,;
    ",
    // type infos
    r"
    %token : Token
    Expr Term Fact : int
    ",
    //
    );

    writeln(grammar_info.generate_code(null, "TokenKind"));
}

class GrammarInfo {
    Grammar grammar;
    string[] exec_code;
    LALRTableInfo table_info;

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
        auto token_list = token_def.split!(x => isWhite(x) || x == ',');    // list of tokens got from the definition file
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
            exec_code ~= production.code.length > 0 ? production.code[1..$] : "";
        }

        // set grammar
        grammar = new Grammar(
            productions,
            cast(Symbol) (names_of_non_terms.length-1 + names_of_tokens.length),
            cast(Symbol) names_of_non_terms.length-1,
            names_of_non_terms ~ names_of_tokens
        );


        /* ********** set table ********** */
        table_info = new LALRTableInfo(grammar);
    }

    string generate_code(string[string] nonterm_type, string token_kind) {
        string result;

        /* ********* get the literal of the table ********* */
        return table_info.generate_table_literal();
    }

    string internal_defs() {
        return q{
            enum dacc_Action : ubyte {
                error = 0, accept = 1, shift = 2, reduce = 3, goto_ = 4,
            }
            struct dacc_LREntry {
                align(1):
                int sym;
                dacc_Action action;
                int num;
            }
        };
    }

}
