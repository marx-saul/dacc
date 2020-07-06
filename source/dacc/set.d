module dacc.set;

import dacc.aatree;
import std.stdio : writeln;
import std.meta, std.typecons;
import std.algorithm, std.array;

// CTFE check
unittest {
	writeln("## Set unittest 1");

	static const set1 = new Set!int(3, 1, 4);
	static const set2 = new Set!int(5, 8, 8, 7);
	static assert (1 in set1);
	static assert (9 !in set2);
	static assert (set1 !in set2);
	static assert (set1 != set2);
	static const set3 = set1 + set2;
	static assert (set3 == new Set!int(3, 5, 1, 7, 8, 4, 7));
	static assert (set3 - set2 == set1);
	static assert ((set2 & set1).cardinal == 0);
	
	Set!int test() {
		auto result = new Set!int();
		foreach (i; 0 .. 10) {
			result += new Set!int(i);
		}
		return result;
	}
	static const set4 = test();
	static assert (10 !in set4 && 4 in set4);
	static assert ( equal(set4.array, [0,1,2,3,4,5,6,7,8,9]) );

}

/+
// run time check
unittest {
	auto set1 = new Set!int(3, 1, 4);
	set1.add(1, 99, 999);
	assert ( equal(set1.array, [1, 3, 4, 99, 999]) );
	assert (1 in set1);
	assert (10 !in set1);
	
	auto set2 = new Set!int(1, 99, 4);
	assert (set2 in set1);
	
	auto set3 = new Set!int(3, 999);
	assert ( (set2 + set3) == set1 );
	
	auto set4 = new Set!int(-8);
	set4 += set3;
	assert (set4 == new Set!int(-8, 3, 999));
	writeln("## Set unittest 2");
}
+/

// Set wrapper for AATree
class Set(T, alias less = (a,b)=>a<b)
	if ( is(typeof(less(T.init, T.init))) )
{
	private AATree!(T, less, bool) aat;
	// initialize
	pure this(T[] args...) {
		aat = new AATree!(T, less, bool)(args);
	}
	
	public pure @nogc @safe @property bool empty() inout const {
		return aat.empty;
	}
	public pure @nogc @property T front() inout const {
		return aat.front;
	}
	
	// foreach loop by key and value in the ascending order of the key
	public int opApply(int delegate(T) dg) {
		return aat.opApply((T a, bool b) => dg(a));
	}
	
	// array, cardinal
	public pure inout(T)[] array() @property inout const {
		return aat.keys;
	}
	public pure size_t cardinal() @property inout {
		return aat.cardinal;
	}
	
	public pure void add(T[] args...) {
		aat.insert(args);
	}
	public pure void remove(T[] args...) {
		aat.remove(args);
	}
	
	
	// "in" overload (element)
	public pure bool opBinaryRight(string op)(inout T elem) inout
		if (op == "in")
	{
		return aat.hasKey(elem);
	}
	
	// "in" overload (containment)
	public pure bool opBinary(string op)(inout Set!(T, less) rhs) inout
		if (op == "in")
	{
		foreach(elem; aat.keys) {
			if (elem !in rhs) return false;
		}
		return true;
	}
	
	// "==" overload
	override public pure bool opEquals(Object o) const {
		auto a = cast(Set!(T, less)) o;
		return this.cardinal == a.cardinal && this in a;
	}
	
	// operator "+" overload
	// cup
	public pure Set!(T, less) opBinary(string op)(inout Set!(T, less) set2) inout
		if (op == "+")
	{
		auto result = new Set!(T, less)();
		foreach (t; this.aat.keys) result.add(t);
		foreach (t; set2.aat.keys) result.add(t);
		return result;
	}
	
	// operator "&" overload
	// cap
	public pure Set!(T, less) opBinary(string op)(inout Set!(T, less) set2) inout
		if (op == "&")
	{
		auto result = new Set!(T, less)();
		foreach (t; this.aat.keys) if (t in set2) result.add(t);
		return result;
	}
	
	// operator "-" overload
	// subtract
	public pure Set!(T, less) opBinary(string op)(inout Set!(T, less) set2) inout
		if (op == "-")
	{
		auto result = new Set!(T, less)();
		foreach (t; this.aat.keys) result.add(t);
		foreach (t; set2.aat.keys) result.remove(t);
		return result;
	}
	
	public pure Set!(T, less) opOpAssign(string op)(inout Set!(T, less) set2) {
		// operator "+=" overload
		static if (op == "+") {
			foreach (t; set2.aat.keys) this.add(t);
			return this;
		}
		// operator "-=" overload
		else if (op == "-") {
			foreach (t; set2.aat.keys) this.remove(t);
			return this;
		}
		else assert(0, op ~ "= for Set is not implemented.");
	}
}
/+
unittest {
	HashSet!int set1;
	set1.add(12, 11, 18, 19);
	auto set2 = HashSet!int(2, 2, 9, 3);
	
	set1 += set2;
	
	auto set3 = HashSet!int();
	set3.add(18, 9, 120, 168);
	
	set1 -= set3;
	
	auto set4 = HashSet!int(19, 12, 11, 3, 2);
	
	assert(set1 in set4);
	assert(set4 in set1);
	assert(set1 == set4);
	assert(set1 != set3);   
}

// this Set is not used because associative array cannot be used in the compile time.
// Set!Symbol is below:
struct HashSet(T) {
	private bool[T] hash;
	// initialize
	this(inout(T)[] args...) {
		foreach (arg; args) { hash[arg] = true; }
	}

	public @nogc @safe @property bool empty() inout const {
		return hash.length == 0;
	}

	// foreach loop by key and value in the ascending order of the key
	public int opApply(int delegate(inout T) dg) inout const {
		foreach (key; hash.byKey) {
			if (dg(key)) return 1;  // do
		}
		return 1;   // stop
	}

	public void add(inout(T)[] args...) {
		foreach (arg; args) {
			hash[arg] = true;
		}
	}

	public void remove(inout(T)[] args...) {
		foreach (arg; args) {
			hash.remove(arg);
		}
	}

	// "in" overload (element)
	public pure bool opBinaryRight(string op)(inout T elem) inout const
		if (op == "in")
	{
		return (elem in hash) !is null;
	}

	// "in" overload (containment)
	public pure bool opBinary(string op)(inout HashSet!T rhs) inout const
		if (op == "in")
	{
		foreach(elem; hash.byKeys) {
			if (elem !in rhs) return false;
		}
		return true;
	}

	// "==" overload
	override pure public pure bool opEquals(Object o) inout const {
		auto a = cast(HashSet!T) o;
		return this in a && this.hash.length == a.hash.length;
	}

	// need to modify :

	// operator "+" overload
	// cup
	public pure Set!(T, less) opBinary(string op)(inout HashSet!(T) set2) inout const
		if (op == "+")
	{
		auto result = new Set!(T, less)();
		foreach (t; this.hash.byKeys) result.add(t);
		foreach (t; set2.hash.byKeys) result.add(t);
		return result;
	}

	// operator "&" overload
	// cap
	public pure Set!(T, less) opBinary(string op)(inout Set!(T, less) set2) inout
		if (op == "&")
	{
		auto result = new Set!(T, less)();
		foreach (t; this.aat.keys) if (t in set2) result.add(t);
		return result;
	}

	// operator "-" overload
	// subtract
	public pure Set!(T, less) opBinary(string op)(inout Set!(T, less) set2) inout
		if (op == "-")
	{
		auto result = new Set!(T, less)();
		foreach (t; this.aat.keys) result.add(t);
		foreach (t; set2.aat.keys) result.remove(t);
		return result;
	}

	public pure Set!(T, less) opOpAssign(string op)(inout Set!(T, less) set2) {
		// operator "+=" overload
		static if (op == "+") {
			foreach (t; set2.aat.keys) this.add(t);
			return this;
		}
		// operator "-=" overload
		else if (op == "-") {
			foreach (t; set2.aat.keys) this.remove(t);
			return this;
		}
		else assert(0, op ~ "= for Set is not implemented.");
	}
}
+/
