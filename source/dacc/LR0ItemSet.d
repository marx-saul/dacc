module dacc.LR0ItemSet;

import dacc.grammar, dacc.data, dacc.aatree, dacc.set;
import std.typecons, std.conv: to;

unittest {
	import std.stdio;
	writeln("## LR0ItemSet unittest1");
	{
		enum:Symbol { Expr = 1, Term, Factor, id, add, mul, lPar, rPar,  }
		auto grammar1 = new Grammar([
			Production(Expr, [Expr, add, Term]),
			Production(Expr, [Term]),
			Production(Term, [Term, mul, Factor]),
			Production(Term, [Factor]),
			Production(Factor, [id]),
			Production(Factor, [lPar, Expr, rPar]),
		], rPar, Factor, ["S'", "Expr", "Term", "Factor", "id", "add", "mul", "lPar", "rPar"]);

		auto lr0itemset1 = new LR0ItemSet(grammar1);
		writeln(lr0itemset1.toString(grammar1));

		auto lr0itemset2 = lr0itemset1.goto_(grammar1, Expr);
		writeln(lr0itemset2.toString(grammar1));

		auto lr0itemset3 = lr0itemset2.goto_(grammar1, add);
		writeln(lr0itemset3.toString(grammar1));

		auto lr0itemset4 = lr0itemset3.goto_(grammar1, Term);
		writeln(lr0itemset4.toString(grammar1));

		auto lr0itemset5 = lr0itemset4.goto_(grammar1, mul);
		writeln(lr0itemset5.toString(grammar1));
	}
}

// LR0Item set
// if there is an item [A -> s.xt], where the production is the n-th and the index of . is m, then
// this item is LR0Item(n, m)
// if there are items [A -> .s], then A in kernel
alias LR0Item = Tuple!(size_t, "num", size_t, "index");
package pure @nogc @safe bool itemLess(LR0Item a, LR0Item b) {
	return ( a.num < b.num ) || ( a.num == b.num && a.index < b.index );
}
alias LR0Items = Set!(LR0Item, itemLess);

class LR0ItemSet {
	LR0Items non_kernel;
	Set!Symbol kernel;
	
	this(const Grammar grammar, LR0Items item_set) {
		non_kernel = item_set;
		kernel = new Set!Symbol;
		// initialize kernel.
		foreach (item; item_set) {
			auto prod = grammar.productions[item.num];
			// A -> s.Bt
			if (item.index < prod.rhs.length && grammar.is_nonterminal(prod.rhs[item.index])) {
				kernel.add(prod.rhs[item.index]);
			}
		}
		// get all kernels.
		Set!Symbol visited = new Set!Symbol;
		Symbol[] stack = kernel.array;
		while (stack.length > 0) {
			auto top_symbol = stack[$-1];
			// already visited
			if (top_symbol in visited) {
				stack.length -= 1;
				continue;
			}
			// first_visit
			visited.add(top_symbol);
			kernel.add(top_symbol);
			// there is a production of the form
			// top_symbol -> rhs0 rhs1 ...,
			// and the item top_symbol -> . rhs0 rhs1 ... is in the kernel.
			foreach (p_info; grammar.prod_by_nonterms[top_symbol]) if (grammar.is_nonterminal(p_info.rhs0)) {
				stack ~= p_info.rhs0;
			}
		}
	}
	// starting state
	this(const Grammar grammar) {
		non_kernel = new LR0Items;
		kernel = new Set!Symbol;
		// add S' -> .S
		kernel.add(grammar.start_symbol);
		// get all kernels.
		Set!Symbol visited = new Set!Symbol;
		Symbol[] stack = kernel.array;
		while (stack.length > 0) {
			auto top_symbol = stack[$-1];
			// already visited
			if (top_symbol in visited) {
				stack.length -= 1;
				continue;
			}
			// first_visit
			visited.add(top_symbol);
			kernel.add(top_symbol);
			// there is a production of the form
			// top_symbol -> rhs0 rhs1 ...,
			// and the item top_symbol -> . rhs0 rhs1 ... is in the kernel.
			foreach (p_info; grammar.prod_by_nonterms[top_symbol]) if (grammar.is_nonterminal(p_info.rhs0)) {
				stack ~= p_info.rhs0;
			}
		}
	}
	
	// "==" overload
	override public bool opEquals(Object o) const {
		auto a = cast(LR0ItemSet) o;
		return this.non_kernel == a.non_kernel;		// closed LR0ItemSet are the same iff their non_kernels are the same
	}

	// goto function
	LR0ItemSet goto_(const Grammar grammar, Symbol symbol) {
		auto goto_item_set = new LR0Items;
		// for each A -> s.Xt with X = symbol, add A -> sX.t
		foreach (item; non_kernel) {
			auto production = grammar.productions[item.num];
			// A -> s.Xt and X = symbol
			if (item.index < production.rhs.length && production.rhs[item.index] == symbol) {
				goto_item_set.add(LR0Item(item.num, item.index+1));	// add s -> sX.t
			}
		}
		// for each A -> .Xs with X = symbol, add A -> X.s
		foreach (sym; kernel) {
			// the (p_info.num)-th production is of the form
			// sym -> p_info.rhs0 s
			foreach (p_info; grammar.prod_by_nonterms[sym]) {
				if (p_info.rhs0 == symbol) {
					goto_item_set.add(LR0Item(p_info.num, 1));
				}
			}
		}

		return new LR0ItemSet(grammar, goto_item_set);
	}

	bool empty() @property inout {
		return non_kernel.cardinal == 0 && kernel.cardinal == 0;
	}

	// to string
	string toString(const Grammar grammar) {
		string result = "{ ";
		foreach (item; non_kernel) {
			auto production = grammar.productions[item.num];
			result ~= grammar.nameOf(production.lhs) ~ " => ";
			foreach (sym; production.rhs[0 .. item.index]) {
				result ~= grammar.nameOf(sym) ~ " ";
			}
			result = result[0 .. $-1];
			result ~= ".";
			foreach (sym; production.rhs[item.index .. $]) {
				result ~= grammar.nameOf(sym) ~ " ";
			}
			result ~= ", ";
		}
		result ~= "// ";
		foreach (sym; kernel) result ~= grammar.nameOf(sym) ~ " ";
		return result ~ "}";
	}

}

/+
unittest {
	enum : Symbol {
		Expr, Term, Factor,
		digit, add, mul, lPar, rPar
	}
	static const grammar_info = new GrammarInfo([
		rule(Expr, Expr, add, Term),
		rule(Expr, Term),
		rule(Term, Term, mul, Factor),
		rule(Term, Factor),
		rule(Factor, digit),
		rule(Factor, lPar, Expr, rPar)
	]);
	/*
	static const item_set1 = new LR0ItemSet(LR0Item(0, 0), LR0Item(8, 5), LR0Item(8, 1), LR0Item(3, 17));
	static assert (LR0Item(3, 16) !in item_set1);
	static assert (LR0Item(8, 1)   in item_set1);
	static const item_set2 = new LR0ItemSet(LR0Item(0, 1), LR0Item(1, 9), LR0Item(2, 0), LR0Item(8, 5));
	static const item_set3 = item_set1 + item_set2;
	static assert (LR0Item(2, 0) in item_set3);
	
	static const item_set_set1 = new LR0ItemSetSet(cast(LR0ItemSet) item_set1, cast(LR0ItemSet) item_set2, cast(LR0ItemSet) item_set3);
	static assert (new LR0ItemSet(LR0Item(0, 0), LR0Item(8, 5), LR0Item(8, 1), LR0Item(3, 17)) in item_set_set1);
	static assert (new LR0ItemSet(LR0Item(9, 0), LR0Item(9, 5), LR0Item(9, 1), LR0Item(9, 17)) !in item_set_set1);
	
	static const item_set_set2 = new LR0ItemSetSet(cast(LR0ItemSet) item_set1, cast(LR0ItemSet) item_set3);
	static assert (item_set_set2 in item_set_set1);
	*/
	
	auto item_set1 = new LR0ItemSet(LR0Item(0, 0), LR0Item(8, 5), LR0Item(8, 1), LR0Item(3, 17));
	assert (LR0Item(3, 16) !in item_set1);
	assert (LR0Item(8, 1)   in item_set1);
	auto item_set2 = new LR0ItemSet(LR0Item(0, 1), LR0Item(1, 9), LR0Item(2, 0), LR0Item(8, 5));
	auto item_set3 = item_set1 + item_set2;
	auto (LR0Item(2, 0) in item_set3);
	
	auto item_set_set1 = new LR0ItemSetSet(cast(LR0ItemSet) item_set1, cast(LR0ItemSet) item_set2, cast(LR0ItemSet) item_set3);
	assert (new LR0ItemSet(LR0Item(0, 0), LR0Item(8, 5), LR0Item(8, 1), LR0Item(3, 17)) in item_set_set1);
	assert (new LR0ItemSet(LR0Item(9, 0), LR0Item(9, 5), LR0Item(9, 1), LR0Item(9, 17)) !in item_set_set1);
	
	auto item_set_set2 = new LR0ItemSetSet(cast(LR0ItemSet) item_set1, cast(LR0ItemSet) item_set3);
	assert (item_set_set2 in item_set_set1);
	
	writeln("## LR0ItemSet.d unittest 1");
}
+/
