// parse DSL
module dacc.dsl.parse;

import dacc.set;
import std.stdio, std.ascii;
import std.array, std.range, std.algorithm, std.algorithm.comparison;
import std.meta;
import std.conv: to;

alias DSLGrammar = DSLRule[];

struct DSLRule {
    string lhs;     // lhs
    string[] rhs;   // rhs
    string code;  // execution code
}

static immutable special_tokens = ",|>:;";

unittest {
    writeln("## dsl.parse unittest 1");
    auto productions = parse(r"
    Expr:
        Expr add Term `$$ = $1 + $3`,
        Term;
    Term:
        Term mul Fact `$$ = $1 * $3`,
        Fact;
    Fact:
        lparen Expr rparen `$$ = $2`,
        digit,;
    ");
    writeln(productions);
}

/////////////////////////////
/////////////////////////////
pure bool isIdentifier(string token) {
    return token.length > 0 && (isAlpha(token[0]) || token[0] == '_');
}

DSLGrammar parse(string text) {
    DSLGrammar result;
    size_t index, line_num;
    auto token = nextToken(text, index, line_num);

    while (token.length != 0) {
        auto rules = parseRuleList(token, text, index, line_num);
        if (!rules) token = nextToken(text, index, line_num);
        else result ~= rules;
    }

    return result;
}

// "A : rule, rule, rule,;"
DSLRule[] parseRuleList(ref string token, string text, ref size_t index, ref size_t line_num)  {
    if (!isIdentifier(token)) {
        writeln("Identifier expected. Line Number = " ~ to!string(line_num) );
        return null;
    }
    if (token == "empty") {
        writeln("'empty' cannot be an identifier for a non-terminal symbol.");
        return null;
    }
    auto lhs = token;

    token = nextToken(text, index, line_num);
    if (token != ":" && token != ">") {
        writeln("':' or '>' is expected. Line Number = " ~ to!string(line_num) );
    }
    token = nextToken(text, index, line_num);

    DSLRule[] result;

    while (true) {
        auto rule = parseRhs(token, lhs, text, index, line_num);
        result ~= rule;
        if (token == "," || token == "|") { token = nextToken(text, index, line_num); }
        if (token == ";") { token = nextToken(text, index, line_num); break; }
        if (!token.isIdentifier()) {
            writeln("',', '|', ';' or an identifier expected, not ", token, " . Did you forget ';' at the last of some rule? Line Number=" ~ to!string(line_num) );
            break;
        }
    }

    return result;
}

// parse "identifier... `code`,"
DSLRule parseRhs(ref string token, string lhs, string text, ref size_t index, ref size_t line_num) {
    DSLRule result;
    result.lhs = lhs;
    if(token.length == 0) {
        writeln("Parsing error. EOF is not expected.");
        return result;
    }
    while (isIdentifier(token)) {
        result.rhs ~= token;
        auto previous_line_num = line_num;
        token = nextToken(text, index, line_num);
        if (previous_line_num < line_num && isIdentifier(token)) {
            writeln(0, "Line breaks in a single sequence before" ~ token ~ ". Did you forget ',' or '|' at the end? Line Number=" ~ to!string(line_num) );
        }
    }
    if (token.length > 0 && token[0] == '`') {
        result.code = token[1..$];  // get rid of `
        token = nextToken(text, index, line_num);
    }
    return result;
}

string nextToken(string text, ref size_t index, ref size_t line_num) {
    string result;
    start:
    // skip spaces
    while (index < text.length && isWhite(text[index])) {
        if (text[index] == '\n') line_num++;
        index++;
    }
    if (index >= text.length) return result;

    // identifier
    if (index < text.length && (isAlpha(text[index]) || text[index] == '_') ) {
        while (index < text.length && (isAlphaNum(text[index]) || text[index] == '_') ) {
            result ~= text[index];
            index++;
        }
    }
    // other symbols
    else if (text[index].among!(aliasSeqOf!special_tokens)) {
        result ~= text[index];
        index++;
    }
    // exec code
    else if (text[index] == '`') {
        auto index_num = index;
        ++index;
        while (index < text.length && text[index] != '`') {
            result ~= text[index];
            if (text[index] == '\n') ++line_num;
            ++index;
        }
        // error
        if (index >= text.length || text[index] != '`') {
            writeln("Reached EOF when expecting `");
        }
        ++index;    // get rid of enclosing `
        result = '`' ~ result;
    }
    // invalid
    else { writeln("Invalid character: " ~ text[index]); ++index; goto start; }

    return result;
}
