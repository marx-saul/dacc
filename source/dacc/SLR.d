module dacc.SLR;

import dacc.grammar, dacc.data, dacc.set, dacc.LR0ItemSet, dacc.LRTable;
import std.typecons, std.algorithm;

unittest {
	import std.stdio;
	writeln("## grammar.d unittest 1");
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
		], rPar, Factor, ["E'", "E", "T", "F", "id", "+", "*", "(", ")"]);

		auto slr_table_info = new SLRTableInfo(grammar1);
		sw1.stop();
		writeln("Exec time: ", sw1.peek.total!"usecs", " us");
		slr_table_info.state_set.each!(x => x.toString(grammar1).writeln());
		writeln(slr_table_info.display_table);
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
			Production(Term_, [mul, Factor, Term_]),
			Production(Term_, [empty_]),
			Production(Factor, [id]),
			Production(Factor, [lPar, Expr, rPar]),
		], rPar, Term_, ["S'", "Expr", "Term", "Fact", "Expr'", "Term'", "id", "add", "mul", "lPar", "rPar"]);

		auto slr_table_info = new SLRTableInfo(grammar1);
		sw1.stop();
		writeln("Exec time: ", sw1.peek.total!"usecs", " us");
		slr_table_info.state_set.each!(x => x.toString(grammar1).writeln());
		writeln(slr_table_info.display_table);
	}
}

private Tuple!(GLRTable, LR0ItemSet[]) getSLRtableAndStateSet(Grammar grammar) {
	GLRTable gtable; LREntrySet[Symbol] gtable0; gtable = [gtable0];

	LR0ItemSet[] state_set = [new LR0ItemSet(grammar)];

	void add_entry(State state, Symbol symbol, LREntry entry) {
		auto entry_set_ptr = symbol in gtable[state];
		if (!entry_set_ptr) {
			entry_set_ptr = &(gtable[state][symbol] = new LREntrySet);
		}
		entry_set_ptr.add(entry);
	}
	// generate canonical LR(0) collection
	size_t state = 0;
	while (true) {
		auto item_set = state_set[state];

		// for I = item_set, get goto(I, X) for all symbols
		foreach (sym; grammar.terminal_symbols) {
			import std.stdio;
			auto goto_set = item_set.goto_(grammar, sym);
			if (goto_set.empty) continue;	// error entry

			size_t shift_state = state_set.length;
			// check if it already appeared
			foreach (counter, i_s; state_set) { if (i_s == goto_set) { shift_state = counter; break; } }
			// new state
			if (shift_state == state_set.length) {
				state_set ~= goto_set;
				shift_state = state_set.length-1;
				LREntrySet[Symbol] entry_column;
				gtable ~= entry_column;
			}

			// shift entry
			add_entry(state, sym, LREntry(Action.shift, shift_state));
		}
		foreach (sym; grammar.nonterminal_symbols) {
			import std.stdio;
			auto goto_set = item_set.goto_(grammar, sym);
			if (goto_set.empty) continue;	// error entry

			size_t goto_state = state_set.length;
			// check if it already appeared
			foreach (counter, i_s; state_set) { if (i_s == goto_set) { goto_state = counter; break; } }
			// new state
			if (goto_state == state_set.length) {
				state_set ~= goto_set;
				goto_state = state_set.length-1;
				LREntrySet[Symbol] entry_column;
				gtable ~= entry_column;
			}

			// goto entry
			add_entry(state, sym, LREntry(Action.goto_, goto_state));
		}

		++state;
		if (state >= state_set.length) break;	// no more to be added
	}

	// reduce/accept
	foreach (st, item_set; state_set) {
		foreach (item; item_set.non_kernel) {
			auto production = grammar.productions[item.num];
			// A -> s. A -> .e
			if (item.index >= production.rhs.length || production.rhs.length == 1 && production.rhs[0] == empty_) {
				// if production is S' -> S.
				if (production.lhs == grammar.start_symbol) {
					add_entry(st, grammar.end_of_file, LREntry(Action.accept, 0));
					continue;
				}
				else
					// for each sym in Follow(A), add (reduce, item.num) if A is
					foreach (sym; grammar.follow(production.lhs))
						add_entry(st, sym, LREntry(Action.reduce, item.num));
			}
		}
		// A -> .e
		foreach (symbol; item_set.kernel) {
			auto ptr = symbol in grammar.empty_generate;
			if (!ptr) continue;
			foreach (sym; grammar.follow(symbol))
				add_entry(st, sym, LREntry(Action.reduce, *ptr));
		}
	}

	return tuple(gtable, state_set);
}

class SLRTableInfo {
	Grammar grammar;
	GLRTable gtable;
	LRTable table;
	LR0ItemSet[] state_set;
	this (Grammar grammar) {
		this.grammar = grammar;
		auto d = getSLRtableAndStateSet(grammar);
		gtable = d[0], state_set = d[1];
		table = gtable.toLRTable();
	}

	// get table
	string display_table() @property {
		Tuple!(State, Symbol)[] conflictions;
		import std.conv: to;
		string result = "\t ";
		foreach (sym; 1 .. grammar.max_symbol+2) {
			result ~= grammar.nameOf(sym) ~ "\t| ";
		}
		result ~= "\n";
		foreach (state; 0 .. state_set.length) {
			result ~= state.to!string ~ "\t ";
			foreach (sym; 1 .. grammar.max_symbol+2) {
				auto entry_set_ptr = sym in gtable[state];
				if (!entry_set_ptr) result ~= "---\t| ";
				else if (entry_set_ptr.cardinal > 1) {
					result ~= "con\t| ";
					conflictions ~= tuple(state, sym);
				}
				else {
					auto entry = entry_set_ptr.front;
					final switch (entry.action) {
						case Action.error:  assert(0);
						case Action.shift:  result ~= "s" ~ entry.num.to!string ~ "\t| "; break;
						case Action.goto_:  result ~= "g" ~ entry.num.to!string ~ "\t| "; break;
						case Action.reduce: result ~= "r" ~ entry.num.to!string ~ "\t| "; break;
						case Action.accept: result ~= "acc\t| "; break;
					}
				}
			}
			result ~= "\n";
		}
		foreach (conflict; conflictions) {
			auto state = conflict[0], symbol = conflict[1];
			result ~= state.to!string ~ " " ~ grammar.nameOf(symbol) ~ " : ";
			foreach (entry; gtable[state][symbol]) {
				final switch (entry.action) {
					case Action.error:  assert(0);
					case Action.shift:  result ~= "s" ~ entry.num.to!string ~ ", "; break;
					case Action.goto_:  result ~= "g" ~ entry.num.to!string ~ ", "; break;
					case Action.reduce: result ~= "r" ~ entry.num.to!string ~ ", "; break;
					case Action.accept: result ~= "acc, "; break;
				}
			}
			result = result[0 .. $-2] ~ "\n";
		}
		return result;
	}
}


