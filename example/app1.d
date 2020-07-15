import std.stdio;
import lexer1, parser1;

void main() {
	writeln("Write expressions.");
	while (true) {
		auto code = readln();
		if (code.length <= 1) { break; }
		auto lex = new Lexer(code);
		auto result = parse(lex);
		if (!result) { writeln("parse error"); }
		else { writeln(*result); }
	}
}
