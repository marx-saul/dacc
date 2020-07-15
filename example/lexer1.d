module lexer1;
import std.ascii;
import std.stdio;
import std.variant;

enum TokenKind : int {
	add, sub, div, mul, lp, rp, digit,
	end_of_file,
}

struct Token {
	TokenKind t_k;
	string str;
}

class Lexer {
	private Token[] tokens;
	private size_t tokens_ptr;
	
	this (string code) {
		size_t index = 0;
		while (index < code.length) {
			// ignore spaces
			while (index < code.length && code[index].isWhite) {
				++index;
			}
			Token result;
			if (index >= code.length) break;
			else if (code[index].isDigit) {
				result.t_k = TokenKind.digit;
				while (index < code.length && code[index].isDigit) {
					result.str ~= code[index];
					++index;
				}
			}
			else if (code[index] == '+') {
				result.t_k = TokenKind.add;
				result.str = "+";
				++index;
			}
			else if (code[index] == '-') {
				result.t_k = TokenKind.sub;
				result.str = "-";
				++index;
			}
			else if (code[index] == '*') {
				result.t_k = TokenKind.mul;
				result.str = "*";
				++index;
			}
			else if (code[index] == '/') {
				result.t_k = TokenKind.div;
				result.str = "/";
				++index;
			}
			else if (code[index] == '(') {
				result.t_k = TokenKind.lp;
				result.str = "(";
				++index;
			}
			else if (code[index] == ')') {
				result.t_k = TokenKind.rp;
				result.str = ")";
				++index;
			}
			else {
				writeln("Invalid character ", code[index]);
				++index;
			}
			tokens ~= result;
		}
		tokens ~= Token(TokenKind.end_of_file, "EOF");
	}
	
	Variant token() {
		Variant v = tokens[tokens_ptr];
		return v;
	}
	TokenKind token_kind() {
		return tokens[tokens_ptr].t_k;
	}
	void nextToken() {
		++tokens_ptr;
	}
}
