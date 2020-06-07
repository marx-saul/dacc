module dacc.grammar;

import dacc.data, dacc.set, dacc.aatree;
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
	writeln("## tool.d unittest 1");
	
	enum:Symbol { Expr = 1, Term, Factor, id, add, mul, lPar, rPar,  }
	static const grammar = new Grammar([
		Production(Expr, [Expr, add, Term]),
		Production(Expr, [Term]),
		Production(Term, [Term, mul, Factor]),
		Production(Term, [Factor]),
		Production(Factor, [id]),
		Production(Factor, [lPar, Expr, rPar]),
	], rPar, Factor, ["S'", "Expr", "Term", "Factor", "id", "add", "mul", "lPar", "rPar"]);
	
	
	/*enum:Symbol { V1 = 1, V2, V3, V4, V5, V6, V7, V8, V9, V10, a }
	auto grammar = new Grammar([
		Production(V1, [a]),
		Production(V2, [V1]),	// V1 in edge[V2]
		Production(V2, [a]),
		Production(V3, [V2]),
		Production(V3, [a]),
		Production(V4, [V3]),
		Production(V6, [V3]),
		Production(V7, [V3]),
		Production(V4, [a]),
		Production(V5, [V4]),
		Production(V8, [V4]),
		Production(V5, [a]),
		Production(V2, [V5]),
		Production(V6, [a]),
		Production(V9, [V6]),
		Production(V7, [a]),
		Production(V8, [V7]),
		Production(V8, [a]),
		Production(V9, [V8]),
		Production(V9, [a]),
		Production(V7, [V9]),
		Production(V10,[V9]),
		Production(V10,[a]),
	], a, V10);*/
}

// nonterminal symbols: start_symbol = 0 (augmented start symbol), 1 (original start symbol), 2, ..., max_nonterminal_symbol
//    terminal symbols: max_nonterminal_symbol+1, ..., _max_symbol
package class Grammar {
	public Production[] productions;
    
    // return the identifier of the symbol
	private string[] symbol_name_dictionary;
	public  string nameOf(inout const Symbol sym) inout {
		if      (sym == virtual_)      return "#";
		else if (sym == end_of_file) return "$";
		else if (sym == empty_)       return "ε";
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
	
	// start symbol
	public pure Symbol start_symbol() @safe @nogc @property inout { return 0; }
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
	
	bool is_terminal(Symbol s) {
		return max_nonterminal_symbol < s;
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
		
		// calculate if X =>* ε for each X
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
					if (is_terminal(sym) || empty_ !in first_table[sym]) continue each_prod;
				}
				// ε has not been added to first_table[X]
				end_flag = false;
				first_table[production.lhs].add(empty_);
				empty_applied.add(m);
			}
		}
		
		// calculate first
		// for all non terminal symbols X, Y
		// Y in edges[X] iff there is a path X ---> Y iff FIRST(X) is contained in FIRST(Y) and X =/= Y.
		// Y in reverse_edges[X] iff there is a path Y ---> X.
		SymbolSet[] edges, reverse_edges;
		
		edges.length = max_nonterminal_symbol + 1;
		reverse_edges.length = max_nonterminal_symbol + 1;
		foreach (s; nonterminal_symbols) {
			edges[s] = new SymbolSet;
			reverse_edges[s] = new SymbolSet;
		}
		// construct the directed graph
		// if there is a production X::=A1 ... An with A1, ..., A(i-1) =>* ε, Ai =/= X and Ai is nonterminal, then Ai ---> X.
		foreach (production; productions) {
			foreach (sym; production.rhs) {
				// if sym = Ai is a terminal symbol
				if (is_terminal(sym)) {
					first_table[production.lhs].add(sym);	// initialize
					break;
				}
				// add an edge
				else if (sym != production.lhs) {
					edges[sym].add(production.lhs);
					reverse_edges[production.lhs].add(sym);
				}
				// no more ε-generating
				if (empty_ !in first_table[production.lhs]) break;
			}
		}
		// calculate strong components
		topological_sort(edges, strong_components(edges, reverse_edges), first_table);
		foreach (s; nonterminal_symbols) {
			writeln(s, " : ", first_table[s].array);
		}
	}
	
	// return the array of the representative of strong components.
	// s_c[i] = j means that the minimal vertex of the strong component containing i is j
	SymbolSet[] strong_components(SymbolSet[] edges, SymbolSet[] reverse_edges) {
		SymbolSet[] strong_components;													// strong components
		
		bool[] visited_vertices; visited_vertices.length = max_nonterminal_symbol+1; 	// record all the visited vertices
		foreach (sym; nonterminal_symbols) {
			if (visited_vertices[sym]) continue;
			//writeln(sym, ": ", edges[sym].array);
			
			Symbol[] post_order_vertices;		// post order
			// DFS
			auto vert_stack = [sym];
			while (vert_stack.length > 0) {
				// already visited
				if (visited_vertices[vert_stack[$-1]]) {
					post_order_vertices ~= vert_stack[$-1];
					vert_stack.length -= 1;
					continue;
				}
				visited_vertices[vert_stack[$-1]] = true;
				// push all vertices directed by vert_stack[$-1] that have not been visited
				foreach (direct_to; edges[vert_stack[$-1]]) if (!visited_vertices[direct_to]) {
					vert_stack ~= direct_to;
				}
			}
			// one of the (weak) components of the graph
			auto post_order_vertices_set = new SymbolSet(post_order_vertices);
			
			// DFS on the reversed directed graph
			bool[] visited_vertices_2; visited_vertices_2.length = max_nonterminal_symbol+1;
			foreach_reverse (sym_2; post_order_vertices) {
				if (visited_vertices_2[sym_2]) continue;
				
				auto strong_component = new SymbolSet();
				auto vert_stack_2 = [sym_2];
				//write("\t");
				while (vert_stack_2.length > 0) {
					// already visited
					if (visited_vertices_2[vert_stack_2[$-1]]) {
						strong_component.add(vert_stack_2[$-1]);
						//write(vert_stack_2[$-1], ", ");
						vert_stack_2.length -= 1;
						continue;
					}
					visited_vertices_2[vert_stack_2[$-1]] = true;
					// push all vertices directed by vert_stack_2[$-1] that have not been visited and is in the (weak) component
					foreach (direct_from; reverse_edges[vert_stack_2[$-1]])
						if (!visited_vertices_2[direct_from] && direct_from in post_order_vertices_set) {
							vert_stack_2 ~= direct_from;
						}
				}
				//writeln();
				strong_components ~= strong_component;
			}
		}
		
		strong_components.each!(x => x.array.writeln);
		writeln();
		
		return strong_components;
	}
	
	// topological sort the strong components and propagate the symbols
	private void topological_sort(SymbolSet[] original_edges, SymbolSet[] str_comps, ref SymbolSet[] table) {
		// representatives[i] = j means that the representative of the strong-component containing j is i.
		Symbol[] representatives; representatives.length = max_nonterminal_symbol + 1;
		
		// Vertices consists of the representatives of each strong components; they are identified as the same.
		Symbol[] vertices; size_t[] indegree;
		SymbolSet[] edges;	// j in edges[i] iff vertices[i] ---> vertices[j]
		vertices.length = indegree.length = edges.length = str_comps.length;
		
		// set representatives
		size_t i;
		foreach (strong_component; str_comps) {
			auto rep = strong_component.front;
			foreach (sym; strong_component) {
				representatives[sym] = rep;
			}
			edges[i] = new SymbolSet;
			++i;
		}
		// set vertices, and collect all elements to table[rep].
		i = 0;
		foreach (sym; 0 .. max_nonterminal_symbol+1) {
			if (representatives[sym] == sym) {
				vertices[i] = sym;
				++i;
			}
			else {
				table[sym] += table[representatives[sym]];
			}
		}
		
		// set edges and indegree
		auto vertices_r = assumeSorted(vertices);
		i = 0;
		foreach (strong_component; str_comps) {
			auto rep_sym = vertices[i]; // = strong_component.front;
			foreach (original_vertex; strong_component) foreach (direct_to; original_edges[original_vertex]) {
				auto rep_to = representatives[direct_to];
				auto j = cast(Symbol) vertices_r.lowerBound(rep_to).length;	// vertices[j] = rep_to
				
				if (i == j) continue;
				auto prev_card = edges[i].cardinal;
				edges[i].add(j);
				if (prev_card < edges[i].cardinal) { ++indegree[j]; writeln(i, "--->", j); }
			}
			++i;
		}
		
		writeln(vertices);
		writeln(indegree);
		edges.each!(x => x.array.writeln);
		
		// topological sort
		size_t[] vertex_stack;
		// first collect all the vertices with indegree = 0
		foreach (vert, indeg; indegree) {
			if (indeg == 0) vertex_stack ~= vert;
		}
		while (vertex_stack.length > 0) {
			auto top_vert = vertex_stack[0];
			// delete the edge top_vert ---> direct_to
			// top_vert has indegree = 0
			foreach (direct_to; edges[top_vert]) {
				// FIRST(vertices[top_vert]) is contained in FIRST(vertices[direct_to])
				table[vertices[direct_to]] += table[vertices[top_vert]];
				--indegree[direct_to];
				if (indegree[direct_to] == 0) vertex_stack ~= direct_to;
			}
			vertex_stack = vertex_stack[1 .. $];
		}
		
		// representatives are correctly calculated
		foreach (sym; 0 .. max_nonterminal_symbol+1) {
			if (representatives[sym] != sym) table[sym] = table[representatives[sym]];
		}
	}
}
