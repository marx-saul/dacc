module dacc.grammar;

import dacc.data, dacc.aatree, dacc.graph, dacc.set;
import std.typecons, std.array, std.container, std.algorithm, std.range;
import std.stdio: writeln, write;
import std.conv: to;

package alias Symbol = int;
package enum  Symbol empty_ = -1, virtual_ = -2;
package alias Production = Tuple!(Symbol, "lhs", Symbol[], "rhs");
package alias SymbolSet = Set!(Symbol);
private alias SymbolTable = AATree!(Symbol, (a,b)=>a<b, SymbolSet);

// a range of successive numbers
struct SuccessiveNumbers(N) {
	private N current;
	private N end;
	this (N from, N to) {
		current = from;
		end = to;
	}
	bool empty() @property {
		return current > end;
	}
	N front() @property {
		return current;
	}
	void popFront() {
		++current;
	}
}

unittest {
	writeln("## grammar.d unittest 1");
	//import std.datetime;	// measure the time needed to calculate first and follow table
	// first and follow
	import std.datetime.stopwatch: benchmark, StopWatch;
	{
		StopWatch sw1;
		sw1.start();
		enum:Symbol { Expr = 1, Term, Factor, id, add, mul, lPar, rPar,  }
		auto grammar1 = new Grammar([
			Production(Expr, [Expr, add, Term]),
			Production(Expr, [Term]),
			Production(Term, [Term, mul, Factor]),
			Production(Term, [Factor]),
			Production(Factor, [id]),
			Production(Factor, [lPar, Expr, rPar]),
		], rPar, Factor, ["S'", "Expr", "Term", "Factor", "id", "add", "mul", "lPar", "rPar"]);
		sw1.stop();
		writeln("Exec time: ", sw1.peek.total!"usecs", " us");

		writeln("First");
		foreach (s; grammar1.nonterminal_symbols) {
			writeln(grammar1.nameOf(s), " : ", grammar1.first_table[s].array.map!(a => grammar1.nameOf(a)));
		}
		writeln("Follow");
		foreach (s; grammar1.nonterminal_symbols) {
			writeln(grammar1.nameOf(s), " : ", grammar1.follow_table[s].array.map!(a => grammar1.nameOf(a)));
		}

		writeln();
	}

	{
		StopWatch sw1;
		sw1.start();
		enum:Symbol { Expr = 1, Term, Factor, Expr_, Term_, id, add, mul, lPar, rPar, }
		auto grammar1 = new Grammar([
			Production(Expr, [Term, Expr_]),
			Production(Expr_, [add, Term, Expr_]),
			Production(Expr_, [empty_]),
			Production(Term, [Factor, Term_]),
			Production(Term_, [mul, Term_]),
			Production(Term_, [empty_]),
			Production(Factor, [id]),
			Production(Factor, [lPar, Expr, rPar]),
		], rPar, Term_, ["S'", "Expr", "Term", "Factor", "Expr'", "Term'", "id", "add", "mul", "lPar", "rPar"]);
		sw1.stop();
		writeln("Exec time: ", sw1.peek.total!"usecs", " us");

		writeln("First");
		foreach (s; grammar1.nonterminal_symbols) {
			writeln(grammar1.nameOf(s), " : ", grammar1.first_table[s].array.map!(a => grammar1.nameOf(a)));
		}
		writeln("Follow");
		foreach (s; grammar1.nonterminal_symbols) {
			writeln(grammar1.nameOf(s), " : ", grammar1.follow_table[s].array.map!(a => grammar1.nameOf(a)));
		}

		writeln();
	}

	// calculation time test
	{
		StopWatch sw2;
		sw2.start();
		enum:Symbol { V1 = 1, V2, V3, V4, V5, V6, V7, V8, V9, V10, a, b, c, d, e, f }
		auto grammar2 = new Grammar([
			Production(V1, [a]),
			Production(V2, [V1]),	// V1 in edge[V2]
			Production(V2, [b]),
			Production(V3, [V2]),
			Production(V3, [a]),
			Production(V4, [V3]),
			Production(V6, [V3]),
			Production(V7, [V3]),
			Production(V4, [d]),
			Production(V4, [e]),
			Production(V5, [V4]),
			Production(V8, [V4]),
			Production(V5, [c]),
			Production(V2, [V5]),
			Production(V6, [f]),
			Production(V9, [V6]),
			Production(V7, [a]),
			Production(V8, [V7]),
			Production(V8, [a]),
			Production(V9, [V8]),
			Production(V9, [a]),
			Production(V7, [V9]),
			Production(V10,[V9]),
			Production(V10,[a]),
		], f, V10);
		sw2.stop();
		/*foreach (s; grammar2.nonterminal_symbols) {
			writeln(s, " : ", grammar2.first_table[s].array);
		}*/
		writeln("Exec time: ", sw2.peek.total!"usecs", " us");

		writeln();
	}
	{
		/*
		enum:Symbol {
			E1, ..., En,
			op1, ..., opn,
			atom1, ..., atomm
		}
		*/
		Production[] productions;
		uint n = 1000, m = 1000;
		foreach (i; 1 .. n) {
			productions ~= [Production(i, [i, i+100, i+1]), Production(i, [i+1])];
		}
		foreach (i; 1 .. m+1) {
			productions ~= [Production(n, [i+100])];
		}
		StopWatch sw3;
		sw3.start();
		auto grammar3 = new Grammar(productions, n+m, n);
		sw3.stop();
		writeln("n = ", n , ", m = ", m, " : ", sw3.peek.total!"usecs", " us");

		writeln();
	}
}

// nonterminal symbols: start_symbol = 0 (augmented start symbol), 1 (original start symbol), 2, ..., max_nonterminal_symbol
//	terminal symbols: max_nonterminal_symbol+1, ..., _max_symbol
package class Grammar {
	package Production[] productions;
	// if (s, i) in prod_by_nonterms[sym], then i-th production is of the form sym => rhs0 rhs1 ...
	package Tuple!(Symbol, "rhs0", size_t, "num")[][] prod_by_nonterms;
	package size_t[Symbol] empty_generate;	// empty_generate[sym] = i means that i-th production is sym -> e
	
	// return the identifier of the symbol
	private string[] symbol_name_dictionary;
	public  string nameOf(inout const Symbol sym) inout {
		if	  (sym == virtual_)	  return "#";
		else if (sym == end_of_file) return "EOF";
		else if (sym == empty_)	   return "ε";
		else if (0 <= sym && sym < symbol_name_dictionary.length) return symbol_name_dictionary[sym];
		else return to!string(sym);
	}
	
	// return the label of productions
	private string[] rule_label;
	public pure string labelOf(inout const size_t index) inout {
		if (index >= rule_label.length) return to!string(index);
		else if (rule_label[index].length > 0) return rule_label[index];
		else return to!string(index);
	}
	
	// start symbol of the augmented grammar
	public pure Symbol start_symbol() @safe @nogc @property inout { return 0; }
	// start symbol of the original grammar
	public pure Symbol original_start_symbol() @safe @nogc @property inout { return 1; }
	// max nonterminal symbol
	private Symbol _max_symbol;
	public pure Symbol max_symbol()  @safe @nogc @property inout { return _max_symbol; }
	// max nonterminal symbol
	private Symbol _max_nonterminal_symbol;
	public pure Symbol max_nonterminal_symbol()  @safe @nogc @property inout { return _max_nonterminal_symbol; }
	// symbols (for foreach-loop)
	SuccessiveNumbers!uint _symbols, _terminal_symbols, _nonterminal_symbols;
	public pure SuccessiveNumbers!uint symbols()  @safe @nogc @property inout { return _symbols; }
	public pure SuccessiveNumbers!uint terminal_symbols()  @safe @nogc @property inout { return _terminal_symbols; }
	public pure SuccessiveNumbers!uint nonterminal_symbols()  @safe @nogc @property inout { return _nonterminal_symbols; }
	// end of file
	private Symbol _end_of_file;
	public pure Symbol end_of_file() @safe @nogc @property inout { return _end_of_file; }

	// $ is a terminal, e is not a terminal
	bool is_terminal(Symbol s) inout {
		return max_nonterminal_symbol < s;
	}
	// e is not a terminal
	bool is_nonterminal(Symbol s) inout {
		return 0 <= s && s <= max_nonterminal_symbol;
	}
	
	// first and follow
	private SymbolSet[]  first_table;
	private SymbolSet[] follow_table;
		
	this (Production[] g, int max_symbol, int max_nonterminal_symbol, string[] snd = [], string[] rl = []) {
		assert(g.length > 0, "\033[1m\033[32mthe length of the grammar must be > 0.\033[0m");
		// initialize
		_end_of_file = max_symbol + 1;
		productions = g ~ [Production(start_symbol, [1])];	// augmentation
		_max_symbol = max_symbol;
		_max_nonterminal_symbol = max_nonterminal_symbol;
		symbol_name_dictionary = snd;
		rule_label = rl;
		_symbols = SuccessiveNumbers!uint(0, max_symbol);
		_nonterminal_symbols = SuccessiveNumbers!uint(0, _max_nonterminal_symbol);
		   _terminal_symbols = SuccessiveNumbers!uint(_max_nonterminal_symbol+1, max_symbol);
		
		// initialize first_table and follow_table
		 first_table.length = max_nonterminal_symbol + 1;
		follow_table.length = max_nonterminal_symbol + 1;
		foreach (s; nonterminal_symbols) {
			first_table[s] = new SymbolSet;
			follow_table[s] = new SymbolSet;
		}

		// set prod_by_nonterm
		prod_by_nonterms = new Tuple!(Symbol, "rhs0", size_t, "num")[][max_nonterminal_symbol + 1];
		foreach (i; 0 .. prod_by_nonterms.length) {
			prod_by_nonterms[i] = [];
		}
		foreach (i, prod; productions) {
			prod_by_nonterms[prod.lhs] ~= Tuple!(Symbol, "rhs0", size_t, "num")(prod.rhs[0], i);
			if (prod.rhs.length == 1 && prod.rhs[0] == empty_) {
				//assert(prod.lhs !in empty_generate)
				empty_generate[prod.lhs] = i;
			}
		}

		/* ************** FIRST ************** */
		{
			// calculate if X =>* ε for each XX
			// if the m-th production is X ::= A1, ..., An and all Ai =>* ε, add ε to first_table[X] and m to empty_applied
			auto empty_applied = new Set!(size_t);
			add_empty:
			while (true) {
				auto end_flag = true;
				scope(exit) { if (end_flag) break add_empty; }
			
				each_prod:
				// X = production.lhs
				foreach (m, production; productions) {
					// already applied, or already ε is in first_table[X]
					if (!first_table[production.lhs].empty || m in empty_applied) continue;
				
					// check if all Ai =>* ε
					foreach (sym; production.rhs) {
						if (sym == empty_) continue;
						if (is_terminal(sym)) { empty_applied.add(m); continue each_prod; }	// if there is a nonterminal
						if (empty_ !in first_table[sym]) continue each_prod;
					}
					// ε has not been added to first_table[X]
					end_flag = false;
					first_table[production.lhs].add(empty_);
					empty_applied.add(m);
				}
			}

			/* ************** calculate first ************** */
			// for all non terminal symbols X, Y
			// Define a path X ---> Y iff FIRST(X) is contained in FIRST(Y) and X =/= Y.
			Tuple!(uint, uint)[] edges;

			// if there is a production X::=A1 ... An with A1, ..., A(i-1) =>* ε, Ai =/= X  and Ai is nonterminal, then Ai ---> X.
			foreach (production; productions) {
				// X = production.lhs
				foreach (sym; production.rhs) {
					// if sym = Ai is a terminal symbol
					if (is_terminal(sym)) {
						first_table[production.lhs].add(sym);	// initialize, sym in FIRST(X)
						break;
					}
					// add an edge
					else if (sym != production.lhs && sym != empty_) {
						edges ~= tuple(cast(uint) sym, cast(uint) production.lhs);	// Ai ---> X
					}
					// no more ε-generating
					if (empty_ !in first_table[production.lhs]) break;
				}
			}

			auto graph = new DirectedGraph(cast(uint) max_nonterminal_symbol+1, edges);
			auto strong_components = graph.strong_decomposition();
			auto representatives = graph.get_representative(strong_components);
			auto shrunk_graph = graph.shrink(strong_components, representatives);
			auto tssc_index = shrunk_graph.topological_sort();	// indexes of topologically sorted strong components

			// propagate first
			// initialize
			auto first_set = new SymbolSet[strong_components.length];
			foreach (i, sc; strong_components) {
				first_set[i] = new SymbolSet;
				// for symbols in sc, their FIRST are the same
				foreach (sym; sc) {
					first_set[i] += first_table[sym];
				}
			}
			foreach (i; tssc_index) {
				// i ---> j
				foreach (j; shrunk_graph.paths[i]) {
					first_set[j] += first_set[i];
				}
			}
			foreach (i, sc; strong_components) foreach (sym; sc) {
				first_table[sym] = first_set[i];
			}
		}

		/* ************** FOLLOW ************** */
		{
			// $ in FOLLOW(S)
			follow_table[start_symbol].add(end_of_file);
			// If there is a production A -> sBt, add all nonterminals in FIRST(t) except e to FOLLOW(B)
			// If there is a production A -> sBt with e in FIRST(t) or t = e, then FOLLOW(A) is contained in FOLLOW(B)
			// A ---> B iff FOLLOW(A) is contained in FOLLOW(B)
			Tuple!(uint, uint)[] edges;
			foreach (production; productions) {
				// production.lhs = A, non_t = B, production.rhs[i+1 .. $] = t.
				foreach (i, non_t; production.rhs[0 .. $-1]) if (is_nonterminal(non_t)) {
					auto first_set = first(production.rhs[i+1 .. $]);
					follow_table[non_t] += first_set;
					if (empty_ in first_set) {
						follow_table[non_t].remove(empty_);
						edges ~= tuple(cast(uint) production.lhs, cast(uint) non_t);
					}
				}
				if (is_nonterminal(production.rhs[$-1])) edges ~= tuple(cast(uint) production.lhs, cast(uint) production.rhs[$-1]);
			}

			auto graph = new DirectedGraph(cast(uint) max_nonterminal_symbol+1, edges);
			auto strong_components = graph.strong_decomposition();
			auto representatives = graph.get_representative(strong_components);
			auto shrunk_graph = graph.shrink(strong_components, representatives);
			auto tssc_index = shrunk_graph.topological_sort();	// indexes of topologically sorted strong components

			// propagate follow
			// initialize
			auto follow_set = new SymbolSet[strong_components.length];
			foreach (i, sc; strong_components) {
				follow_set[i] = new SymbolSet;
				// for symbols in sc, their FIRST are the same
				foreach (sym; sc) {
					follow_set[i] += follow_table[sym];
				}
			}
			foreach (i; tssc_index) {
				// i ---> j
				foreach (j; shrunk_graph.paths[i]) {
					follow_set[j] += follow_set[i];
				}
			}
			foreach (i, sc; strong_components) foreach (sym; sc) {
				follow_table[sym] = follow_set[i];
			}
		}
	}

	package SymbolSet first(Symbol[] symbols...) {
		auto result = new SymbolSet;
		foreach (symbol; symbols) {
			if (is_terminal(symbol)) {
				result.add(symbol);
				result.remove(empty_);
				return result;
			}
			else {
				result += first_table[symbol];
				if (empty_ !in first_table[symbol]) {
					result.remove(empty_);
					return result;
				}
			}
		}
		return result;
	}

	package SymbolSet follow(Symbol symbol) {
		return follow_table[symbol];
	}
}
