module parser1;
import std.variant;
import std.conv;
import lexer1;

// lexer
interface dacc_Lexer {
    Variant token();
    TokenKind token_kind();
    void nextToken();
}
import std.traits: ReturnType;
enum dacc_isLexer(T) = (
    is(ReturnType!((T t) => t.token()) == Variant) &&
    is(ReturnType!((T t) => t.token_kind()) == TokenKind) &&
    is(typeof({T t; t.nextToken();}))
);
// LR Actions
enum dacc_Action : ubyte {
    error = 0, accept = 1, shift = 2, reduce = 3, goto_ = 4,
}
struct dacc_LREntry {
    align(1):
    int sym;
    dacc_Action action;
    uint num;
}
private pure dacc_LREntry_cmp(dacc_LREntry a, dacc_LREntry b) {
    return a.sym < b.sym;
}
alias dacc_Sorted_Column = std.range.SortedRange!(dacc_LREntry[], dacc_LREntry_cmp);
alias dacc_Sorted_column = std.range.assumeSorted!(dacc_LREntry_cmp, dacc_LREntry[]);

dacc_Sorted_Column[21] dacc_table = [
	/* state 0
	 */
	dacc_Sorted_column([
		dacc_LREntry(1, dacc_Action.goto_ , 5u),	// Expr	<--> 
		dacc_LREntry(2, dacc_Action.goto_ , 6u),	// Term	<--> 
		dacc_LREntry(3, dacc_Action.goto_ , 7u),	// UExp	<--> 
		dacc_LREntry(4, dacc_Action.goto_ , 8u),	// Fact	<--> 
		dacc_LREntry(5, dacc_Action.shift , 1u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 2u),	// -	<--> 
		dacc_LREntry(9, dacc_Action.shift , 3u),	// (	<--> 
		dacc_LREntry(11, dacc_Action.shift , 4u),	// digit	<--> 
	]),
	/* state 1
	 * UExp => + . UExp 
	 */
	dacc_Sorted_column([
		dacc_LREntry(3, dacc_Action.goto_ , 9u),	// UExp	<--> 
		dacc_LREntry(4, dacc_Action.goto_ , 8u),	// Fact	<--> 
		dacc_LREntry(5, dacc_Action.shift , 1u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 2u),	// -	<--> 
		dacc_LREntry(9, dacc_Action.shift , 3u),	// (	<--> 
		dacc_LREntry(11, dacc_Action.shift , 4u),	// digit	<--> 
	]),
	/* state 2
	 * UExp => - . UExp 
	 */
	dacc_Sorted_column([
		dacc_LREntry(3, dacc_Action.goto_ , 10u),	// UExp	<--> 
		dacc_LREntry(4, dacc_Action.goto_ , 8u),	// Fact	<--> 
		dacc_LREntry(5, dacc_Action.shift , 1u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 2u),	// -	<--> 
		dacc_LREntry(9, dacc_Action.shift , 3u),	// (	<--> 
		dacc_LREntry(11, dacc_Action.shift , 4u),	// digit	<--> 
	]),
	/* state 3
	 * Fact => ( . Expr ) 
	 */
	dacc_Sorted_column([
		dacc_LREntry(1, dacc_Action.goto_ , 11u),	// Expr	<--> 
		dacc_LREntry(2, dacc_Action.goto_ , 6u),	// Term	<--> 
		dacc_LREntry(3, dacc_Action.goto_ , 7u),	// UExp	<--> 
		dacc_LREntry(4, dacc_Action.goto_ , 8u),	// Fact	<--> 
		dacc_LREntry(5, dacc_Action.shift , 1u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 2u),	// -	<--> 
		dacc_LREntry(9, dacc_Action.shift , 3u),	// (	<--> 
		dacc_LREntry(11, dacc_Action.shift , 4u),	// digit	<--> 
	]),
	/* state 4
	 * Fact => digit . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 10u),	// +	<--> reduce by Fact => digit 
		dacc_LREntry(6, dacc_Action.reduce, 10u),	// -	<--> reduce by Fact => digit 
		dacc_LREntry(7, dacc_Action.reduce, 10u),	// /	<--> reduce by Fact => digit 
		dacc_LREntry(8, dacc_Action.reduce, 10u),	// *	<--> reduce by Fact => digit 
		dacc_LREntry(10, dacc_Action.reduce, 10u),	// )	<--> reduce by Fact => digit 
		dacc_LREntry(12, dacc_Action.reduce, 10u),	// EOF	<--> reduce by Fact => digit 
	]),
	/* state 5
	 * Expr => Expr . + Term 
	 * Expr => Expr . - Term 
	 * S' => Expr . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.shift , 12u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 13u),	// -	<--> 
		dacc_LREntry(12, dacc_Action.accept, 0u),	// EOF	<--> 
	]),
	/* state 6
	 * Expr => Term . 
	 * Term => Term . * UExp 
	 * Term => Term . / UExp 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 2u),	// +	<--> reduce by Expr => Term 
		dacc_LREntry(6, dacc_Action.reduce, 2u),	// -	<--> reduce by Expr => Term 
		dacc_LREntry(7, dacc_Action.shift , 14u),	// /	<--> 
		dacc_LREntry(8, dacc_Action.shift , 15u),	// *	<--> 
		dacc_LREntry(10, dacc_Action.reduce, 2u),	// )	<--> reduce by Expr => Term 
		dacc_LREntry(12, dacc_Action.reduce, 2u),	// EOF	<--> reduce by Expr => Term 
	]),
	/* state 7
	 * Term => UExp . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 5u),	// +	<--> reduce by Term => UExp 
		dacc_LREntry(6, dacc_Action.reduce, 5u),	// -	<--> reduce by Term => UExp 
		dacc_LREntry(7, dacc_Action.reduce, 5u),	// /	<--> reduce by Term => UExp 
		dacc_LREntry(8, dacc_Action.reduce, 5u),	// *	<--> reduce by Term => UExp 
		dacc_LREntry(10, dacc_Action.reduce, 5u),	// )	<--> reduce by Term => UExp 
		dacc_LREntry(12, dacc_Action.reduce, 5u),	// EOF	<--> reduce by Term => UExp 
	]),
	/* state 8
	 * UExp => Fact . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 8u),	// +	<--> reduce by UExp => Fact 
		dacc_LREntry(6, dacc_Action.reduce, 8u),	// -	<--> reduce by UExp => Fact 
		dacc_LREntry(7, dacc_Action.reduce, 8u),	// /	<--> reduce by UExp => Fact 
		dacc_LREntry(8, dacc_Action.reduce, 8u),	// *	<--> reduce by UExp => Fact 
		dacc_LREntry(10, dacc_Action.reduce, 8u),	// )	<--> reduce by UExp => Fact 
		dacc_LREntry(12, dacc_Action.reduce, 8u),	// EOF	<--> reduce by UExp => Fact 
	]),
	/* state 9
	 * UExp => + UExp . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 6u),	// +	<--> reduce by UExp => + UExp 
		dacc_LREntry(6, dacc_Action.reduce, 6u),	// -	<--> reduce by UExp => + UExp 
		dacc_LREntry(7, dacc_Action.reduce, 6u),	// /	<--> reduce by UExp => + UExp 
		dacc_LREntry(8, dacc_Action.reduce, 6u),	// *	<--> reduce by UExp => + UExp 
		dacc_LREntry(10, dacc_Action.reduce, 6u),	// )	<--> reduce by UExp => + UExp 
		dacc_LREntry(12, dacc_Action.reduce, 6u),	// EOF	<--> reduce by UExp => + UExp 
	]),
	/* state 10
	 * UExp => - UExp . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 7u),	// +	<--> reduce by UExp => - UExp 
		dacc_LREntry(6, dacc_Action.reduce, 7u),	// -	<--> reduce by UExp => - UExp 
		dacc_LREntry(7, dacc_Action.reduce, 7u),	// /	<--> reduce by UExp => - UExp 
		dacc_LREntry(8, dacc_Action.reduce, 7u),	// *	<--> reduce by UExp => - UExp 
		dacc_LREntry(10, dacc_Action.reduce, 7u),	// )	<--> reduce by UExp => - UExp 
		dacc_LREntry(12, dacc_Action.reduce, 7u),	// EOF	<--> reduce by UExp => - UExp 
	]),
	/* state 11
	 * Expr => Expr . + Term 
	 * Expr => Expr . - Term 
	 * Fact => ( Expr . ) 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.shift , 12u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 13u),	// -	<--> 
		dacc_LREntry(10, dacc_Action.shift , 16u),	// )	<--> 
	]),
	/* state 12
	 * Expr => Expr + . Term 
	 */
	dacc_Sorted_column([
		dacc_LREntry(2, dacc_Action.goto_ , 17u),	// Term	<--> 
		dacc_LREntry(3, dacc_Action.goto_ , 7u),	// UExp	<--> 
		dacc_LREntry(4, dacc_Action.goto_ , 8u),	// Fact	<--> 
		dacc_LREntry(5, dacc_Action.shift , 1u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 2u),	// -	<--> 
		dacc_LREntry(9, dacc_Action.shift , 3u),	// (	<--> 
		dacc_LREntry(11, dacc_Action.shift , 4u),	// digit	<--> 
	]),
	/* state 13
	 * Expr => Expr - . Term 
	 */
	dacc_Sorted_column([
		dacc_LREntry(2, dacc_Action.goto_ , 18u),	// Term	<--> 
		dacc_LREntry(3, dacc_Action.goto_ , 7u),	// UExp	<--> 
		dacc_LREntry(4, dacc_Action.goto_ , 8u),	// Fact	<--> 
		dacc_LREntry(5, dacc_Action.shift , 1u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 2u),	// -	<--> 
		dacc_LREntry(9, dacc_Action.shift , 3u),	// (	<--> 
		dacc_LREntry(11, dacc_Action.shift , 4u),	// digit	<--> 
	]),
	/* state 14
	 * Term => Term / . UExp 
	 */
	dacc_Sorted_column([
		dacc_LREntry(3, dacc_Action.goto_ , 19u),	// UExp	<--> 
		dacc_LREntry(4, dacc_Action.goto_ , 8u),	// Fact	<--> 
		dacc_LREntry(5, dacc_Action.shift , 1u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 2u),	// -	<--> 
		dacc_LREntry(9, dacc_Action.shift , 3u),	// (	<--> 
		dacc_LREntry(11, dacc_Action.shift , 4u),	// digit	<--> 
	]),
	/* state 15
	 * Term => Term * . UExp 
	 */
	dacc_Sorted_column([
		dacc_LREntry(3, dacc_Action.goto_ , 20u),	// UExp	<--> 
		dacc_LREntry(4, dacc_Action.goto_ , 8u),	// Fact	<--> 
		dacc_LREntry(5, dacc_Action.shift , 1u),	// +	<--> 
		dacc_LREntry(6, dacc_Action.shift , 2u),	// -	<--> 
		dacc_LREntry(9, dacc_Action.shift , 3u),	// (	<--> 
		dacc_LREntry(11, dacc_Action.shift , 4u),	// digit	<--> 
	]),
	/* state 16
	 * Fact => ( Expr ) . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 9u),	// +	<--> reduce by Fact => ( Expr ) 
		dacc_LREntry(6, dacc_Action.reduce, 9u),	// -	<--> reduce by Fact => ( Expr ) 
		dacc_LREntry(7, dacc_Action.reduce, 9u),	// /	<--> reduce by Fact => ( Expr ) 
		dacc_LREntry(8, dacc_Action.reduce, 9u),	// *	<--> reduce by Fact => ( Expr ) 
		dacc_LREntry(10, dacc_Action.reduce, 9u),	// )	<--> reduce by Fact => ( Expr ) 
		dacc_LREntry(12, dacc_Action.reduce, 9u),	// EOF	<--> reduce by Fact => ( Expr ) 
	]),
	/* state 17
	 * Expr => Expr + Term . 
	 * Term => Term . * UExp 
	 * Term => Term . / UExp 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 0u),	// +	<--> reduce by Expr => Expr + Term 
		dacc_LREntry(6, dacc_Action.reduce, 0u),	// -	<--> reduce by Expr => Expr + Term 
		dacc_LREntry(7, dacc_Action.shift , 14u),	// /	<--> 
		dacc_LREntry(8, dacc_Action.shift , 15u),	// *	<--> 
		dacc_LREntry(10, dacc_Action.reduce, 0u),	// )	<--> reduce by Expr => Expr + Term 
		dacc_LREntry(12, dacc_Action.reduce, 0u),	// EOF	<--> reduce by Expr => Expr + Term 
	]),
	/* state 18
	 * Expr => Expr - Term . 
	 * Term => Term . * UExp 
	 * Term => Term . / UExp 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 1u),	// +	<--> reduce by Expr => Expr - Term 
		dacc_LREntry(6, dacc_Action.reduce, 1u),	// -	<--> reduce by Expr => Expr - Term 
		dacc_LREntry(7, dacc_Action.shift , 14u),	// /	<--> 
		dacc_LREntry(8, dacc_Action.shift , 15u),	// *	<--> 
		dacc_LREntry(10, dacc_Action.reduce, 1u),	// )	<--> reduce by Expr => Expr - Term 
		dacc_LREntry(12, dacc_Action.reduce, 1u),	// EOF	<--> reduce by Expr => Expr - Term 
	]),
	/* state 19
	 * Term => Term / UExp . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 4u),	// +	<--> reduce by Term => Term / UExp 
		dacc_LREntry(6, dacc_Action.reduce, 4u),	// -	<--> reduce by Term => Term / UExp 
		dacc_LREntry(7, dacc_Action.reduce, 4u),	// /	<--> reduce by Term => Term / UExp 
		dacc_LREntry(8, dacc_Action.reduce, 4u),	// *	<--> reduce by Term => Term / UExp 
		dacc_LREntry(10, dacc_Action.reduce, 4u),	// )	<--> reduce by Term => Term / UExp 
		dacc_LREntry(12, dacc_Action.reduce, 4u),	// EOF	<--> reduce by Term => Term / UExp 
	]),
	/* state 20
	 * Term => Term * UExp . 
	 */
	dacc_Sorted_column([
		dacc_LREntry(5, dacc_Action.reduce, 3u),	// +	<--> reduce by Term => Term * UExp 
		dacc_LREntry(6, dacc_Action.reduce, 3u),	// -	<--> reduce by Term => Term * UExp 
		dacc_LREntry(7, dacc_Action.reduce, 3u),	// /	<--> reduce by Term => Term * UExp 
		dacc_LREntry(8, dacc_Action.reduce, 3u),	// *	<--> reduce by Term => Term * UExp 
		dacc_LREntry(10, dacc_Action.reduce, 3u),	// )	<--> reduce by Term => Term * UExp 
		dacc_LREntry(12, dacc_Action.reduce, 3u),	// EOF	<--> reduce by Term => Term * UExp 
	]),
];

int dacc_reduce(uint dacc_num, ref Variant[] dacc_ast_stack, ref uint[] dacc_state_stack) {
    switch (dacc_num) {
	//Expr => Expr + Term 
	case 0u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-3].peek!(long);
		assert(dacc_s1);
		auto dacc_s2 = dacc_ast_stack[$-2].peek!(Token);
		assert(dacc_s2);
		auto dacc_s3 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s3);

		dacc_s_result = (*dacc_s1) + (*dacc_s3);

		dacc_ast_stack.length -= 2; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 3;
		return 1;
	//Expr => Expr - Term 
	case 1u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-3].peek!(long);
		assert(dacc_s1);
		auto dacc_s2 = dacc_ast_stack[$-2].peek!(Token);
		assert(dacc_s2);
		auto dacc_s3 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s3);

		dacc_s_result = (*dacc_s1) - (*dacc_s3); 

		dacc_ast_stack.length -= 2; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 3;
		return 1;
	//Expr => Term 
	case 2u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s1);

		dacc_s_result = (*dacc_s1);

		dacc_ast_stack.length -= 0; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 1;
		return 1;
	//Term => Term * UExp 
	case 3u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-3].peek!(long);
		assert(dacc_s1);
		auto dacc_s2 = dacc_ast_stack[$-2].peek!(Token);
		assert(dacc_s2);
		auto dacc_s3 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s3);

		dacc_s_result = (*dacc_s1) * (*dacc_s3); 

		dacc_ast_stack.length -= 2; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 3;
		return 2;
	//Term => Term / UExp 
	case 4u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-3].peek!(long);
		assert(dacc_s1);
		auto dacc_s2 = dacc_ast_stack[$-2].peek!(Token);
		assert(dacc_s2);
		auto dacc_s3 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s3);

		dacc_s_result = (*dacc_s1) / (*dacc_s3);

		dacc_ast_stack.length -= 2; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 3;
		return 2;
	//Term => UExp 
	case 5u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s1);

		dacc_s_result = (*dacc_s1); 

		dacc_ast_stack.length -= 0; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 1;
		return 2;
	//UExp => + UExp 
	case 6u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-2].peek!(Token);
		assert(dacc_s1);
		auto dacc_s2 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s2);

		dacc_s_result = (*dacc_s2);

		dacc_ast_stack.length -= 1; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 2;
		return 3;
	//UExp => - UExp 
	case 7u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-2].peek!(Token);
		assert(dacc_s1);
		auto dacc_s2 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s2);

		 dacc_s_result = -(*dacc_s2); 

		dacc_ast_stack.length -= 1; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 2;
		return 3;
	//UExp => Fact 
	case 8u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-1].peek!(long);
		assert(dacc_s1);

		dacc_s_result = (*dacc_s1);

		dacc_ast_stack.length -= 0; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 1;
		return 3;
	//Fact => ( Expr ) 
	case 9u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-3].peek!(Token);
		assert(dacc_s1);
		auto dacc_s2 = dacc_ast_stack[$-2].peek!(long);
		assert(dacc_s2);
		auto dacc_s3 = dacc_ast_stack[$-1].peek!(Token);
		assert(dacc_s3);

		 dacc_s_result = (*dacc_s2); 

		dacc_ast_stack.length -= 2; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 3;
		return 4;
	//Fact => digit 
	case 10u:
		long dacc_s_result;
		auto dacc_s1 = dacc_ast_stack[$-1].peek!(Token);
		assert(dacc_s1);

		 dacc_s_result = (*dacc_s1).str.to!long;

		dacc_ast_stack.length -= 0; dacc_ast_stack[$-1] = dacc_s_result;
		dacc_state_stack.length -= 1;
		return 4;
	default: assert(0);
	}
}

long* parse(L)(L lexer)
    if (dacc_isLexer!L)
{
    Variant[] dacc_ast_stack;
    uint[] state_stack = [0u];

    dacc_LREntry getEntry(uint state, int symbol) {
        auto ent = dacc_table[state].equalRange(dacc_LREntry(symbol, dacc_Action.init, uint.init));
        if (ent.empty) return dacc_LREntry(symbol, dacc_Action.error, 0u);
        else return ent.front;
    }
    parsing_routine:
    while (true) {
    	import std.stdio;
    	writeln(state_stack);
    	writeln("ast:", dacc_ast_stack);
        auto current_state = state_stack[$-1];
        auto entry = getEntry(current_state, lexer.token_kind +5); // terminal symbols start from 5 in the internal processing
        writeln(entry);
        final switch (entry.action) {
        case dacc_Action.shift:
            state_stack ~= entry.num; // push
            dacc_ast_stack ~= lexer.token(); //push
            lexer.nextToken();
            break;
        case dacc_Action.reduce:
            auto symbol = dacc_reduce(entry.num, dacc_ast_stack, state_stack);
            auto goto_entry = getEntry(state_stack[$-1], symbol);
            //assert(goto_entry.action == dacc_Action.goto_);
            state_stack ~= goto_entry.num;
            break;
        case dacc_Action.accept:
            break parsing_routine;
        case dacc_Action.error:
            //error();
            return null;    // error
        case dacc_Action.goto_:
            assert(0);
        }
    }
    return dacc_ast_stack[0].peek!(long);
}


