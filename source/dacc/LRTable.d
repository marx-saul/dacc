module dacc.LRTable;

import dacc.set, dacc.grammar, dacc.data;
import std.typecons;

enum Action : string { error = "error ", accept = "accept", shift = "shift ", reduce = "reduce", goto_ = "goto_ " }
alias State = size_t;
alias LREntry = Tuple!(Action, "action", size_t, "num");	// num is the index of the production in grammar.
alias LRTable = LREntry[Symbol][];  // table[state][symbol].action = accept, shift, reduce, goto_. If symbol !in table[state], then that entry is error

// shift < reduce,
// if reduce-reduce confliction occurs, the preceding production is prefered.
private pure bool less(LREntry a, LREntry b) {
	return ( a.action < b.action ) || ( a.action == b.action && a.num < b.num );
}

// confliction saved table
alias LREntrySet = Set!(LREntry, less);
alias GLRTable = LREntrySet[Symbol][];

// get the least LREntry for each LREntrySet of the GLRTable.
LRTable toLRTable(GLRTable gtable) {
	LRTable table = new LREntry[Symbol][gtable.length];
	foreach (state; 0 .. gtable.length) {
		LREntry[Symbol] column;
		foreach (sym; gtable[state].byKey) {
			column[sym] = gtable[state][sym].front;
		}
		table[state] = column;
	}
	return table;
}
