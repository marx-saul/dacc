module dacc.LALR;

import dacc.grammar, dacc.graph, dacc.data, dacc.set, dacc.LR0ItemSet, dacc.LRTable, dacc.SLR;
import std.typecons, std.algorithm;

unittest {
    import std.stdio;
    writeln("## LALR.d unittest 1");
    import std.datetime.stopwatch: benchmark, StopWatch;
    {
        StopWatch sw1;
        sw1.start();
        enum:Symbol { S = 1, L, R, id, eq, mul }
        auto grammar1 = new Grammar([
            Production(S, [L, eq, R]),
            Production(S, [R]),
            Production(L, [mul, R]),
            Production(L, [id]),
            Production(R, [L]),
        ], mul, R, ["S'", "S", "L", "R", "id", "=", "*"]);

        auto slr_table_info = new LALRTableInfo(grammar1);
        sw1.stop();
        writeln("Exec time: ", sw1.peek.total!"usecs", " us");
        slr_table_info.state_set.each!(x => x.toString(grammar1).writeln());
        writeln(slr_table_info.display_table);
    }
}

class LALRTableInfo : SLRTableInfo {
    this (Grammar grammar) {
        super(grammar);     // generate SLR table
        // check if there is any confliction
        foreach (state; 0 .. state_set.length) foreach (sym; 1 .. grammar.max_symbol+2) {
            auto ptr = sym in gtable[state];
            // there is a confliction
            if (ptr !is null && ptr.cardinal > 1) { lalr(); break; }
        }
    }

    void lalr() {
        // lookaheads.
        auto lookaheads = new Set!Symbol[state_set.length];
        foreach (i; 0 .. lookaheads.length) { lookaheads[i] = new Set!Symbol; }
        lookaheads[0].add(grammar.end_of_file);

        // edges of the graph of propagations
        Tuple!(size_t, size_t)[] edges;

        void set_propagation_inner_generate(State state, LR1ItemGroup lr1_item_group) {
            // the item group is [item / symbol...]
            foreach (item; lr1_item_group.byKey) {
                auto symbol_set = lr1_item_group[item];
                if (symbol_set.empty) continue;

                // lookaheads
                auto lookahead_symbol_array = symbol_set.array;

                // propagation
                if (lookahead_symbol_array[0] == virtual_) {
                    // get rid of #
                    lookahead_symbol_array = lookahead_symbol_array[1 .. $];

                    auto prod = grammar.productions[item.num];
                    // for the item, the . is not at the last and the item is not of the form A -> .
                    if (!(item.index >= prod.rhs.length || prod.rhs.length == 1 && prod.rhs[0] == empty_)) {
                        auto sym = grammar.productions[item.num].rhs[item.index];
                        //assert (table[state][sym].action == Action.shift);
                        edges ~= tuple(state, table[state][sym].num);
                    }
                }

                // inner-generate
                foreach (symbol; lookahead_symbol_array) {
                    auto prod = grammar.productions[item.num];
                    // for the item, the . is not at the last and the item is not of the form A -> .
                    if (!(item.index >= prod.rhs.length || prod.rhs.length == 1 && prod.rhs[0] == empty_)) {
                        auto sym = grammar.productions[item.num].rhs[item.index];
                        //assert (table[state][sym].action == Action.shift);
                        lookaheads[table[state][sym].num].add(symbol);
                    }
                }
            }
        }

        // get propagation and inner-generate.
        // S' -> .S
        LR1ItemGroup item_group0 = [LR0Item(grammar.productions.length-1, 0) : new Set!Symbol(virtual_)];
        closure(grammar, item_group0);
        set_propagation_inner_generate(0, item_group0);

        foreach (state; 1 .. state_set.length) {
            auto item_set = state_set[state];
            foreach (item; item_set.non_kernel) {
                LR1ItemGroup item_group = [item : new Set!Symbol(virtual_)];
                closure(grammar, item_group);
                set_propagation_inner_generate(state, item_group);
            }
        }

        auto graph = new DirectedGraph(state_set.length, edges);
        auto vertices = graph.topological_sort();
        //assert(vertices !is null);
        // execute propagation
        foreach (state; vertices) {
            foreach (propagate_state; graph.paths_array[state]) {
                lookaheads[propagate_state] += lookaheads[state];
            }
        }

        foreach (state; 0 .. state_set.length) foreach (sym; 1 .. grammar.max_symbol+2) {
            auto ptr = sym in gtable[state];
            // no confliction on this entry
            if (ptr is null || ptr.cardinal < 1) continue;
            // according to LALR(1), if reduce is not proper for state and sym
            if (sym !in lookaheads[state]) {
                // LALR(1) can only solve shift/reduce confliction
                if (ptr.front.action == Action.shift) gtable[state][sym] = new LREntrySet(ptr.front);
            }
        }
    }
}

alias LR1ItemGroup = Set!Symbol[LR0Item];

package void closure(Grammar grammar, LR1ItemGroup item_group) {
    auto production = grammar.productions;
    auto item_group_array = item_group.keys;    // this equation always hold.

    // for all [A -> s.Bt, a] in item set and rule B -> u,
    // add [B -> .u, b] where a terminal symbol b is in FIRST(ta)
    size_t i = 0;
    while (i < item_group_array.length) {
        auto item = item_group_array[i];

        // . is at the last
        if (item.index >= production[item.num].rhs.length) { ++i; continue; }

        auto b_sym = grammar.productions[item.num].rhs[item.index];
        if (!grammar.is_nonterminal(b_sym)) { ++i; continue; }

        // first_set = FIRST(t)
        auto first_set = grammar.first( grammar.productions[item.num].rhs[item.index+1 .. $] );

        // for each productions B -> u
        foreach (n_r; grammar.prod_by_nonterms[b_sym]) {
            auto num = n_r.num;
            auto entry = LR0Item(num, 0);
            // new item
            if (entry !in item_group) {
                item_group[entry] = new Set!Symbol();
                item_group_array ~= entry;
            }
            // add all symbol in FIRST(t) to item_group[B-> .u]
            auto added_set = item_group[entry];
            foreach (symbol; first_set) { added_set.add(symbol); }
            // a in FIRST(ta)
            if (empty_ in first_set) {
                item_group[entry].remove(empty_);
                item_group[entry] += item_group[item];
            }
        }
        ++i;
    }
}
