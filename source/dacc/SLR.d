module dacc.SLR;

import dacc.grammar, dacc.data, dacc.set, dacc.LR0ItemSet, dacc.LRTable;
import std.typecons;

GLRTable getSLRtable(Grammar grammar) {
	GLRTable gtable;

	LR0ItemSet[] state_set = [new LR0ItemSet(grammar)];
	// generate canonical LR(0) collection


	return gtable;
}
