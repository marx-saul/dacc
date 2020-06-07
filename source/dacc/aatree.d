module dacc.aatree;

import std.algorithm: min;

unittest {
	import std.stdio: writeln;
    import std.algorithm.comparison: equal;
    writeln("## AATree.d unittest1");

    // CTFE check
    static const aatree = new AATree!int(3, 9, 4);
    aatree.test();
    static assert ( equal(aatree.keys, [3, 4, 9]) );
    static assert ( aatree.hasKey(9) );
    static assert ( aatree.cardinal == 3 );
    
    // run time check
    auto aatree2 = new AATree!(int, (a,b) => a>b, int)();
    aatree2[-9] = -9;    aatree2[9] = 9;
    aatree2[-8] = -8;    aatree2[8] = 8;
    aatree2[-7] = -7;    aatree2[7] = 7;
    aatree2[-6] = -6;    aatree2[6] = 6;
    aatree2[-5] = -5;    aatree2[5] = 5;
    aatree2[-4] = -4;    aatree2[4] = 4;
    aatree2[-3] = -3;    aatree2[3] = 3;
    aatree2[-2] = -2;    aatree2[2] = 2;
    aatree2[-1] = -1;    aatree2[1] = 1;
    aatree2[0] = 0;
    
    foreach (key, value; aatree2) {
    	writeln(key, " ", value);
    }
    writeln();
    
    aatree2.remove(-5, 5, 9, 1, 7, -3, -8, 5, 1);
    assert (equal(aatree2.keys, [8, 6, 4, 3, 2, 0, -1, -2, -4, -6, -7, -9]));
    
    foreach (key, value; aatree2) {
    	writeln(key, " ", value, " ", aatree2[key]);
    }
    writeln();
}

// K is key, V is value
class AATree(K, alias less = (a,b) => a < b, V = bool)
    if ( is(typeof(less(K.init, K.init))) )
{
    // if left and right are null (i.e., the node is a leaf), level = 1
    // left.level = this.level - 1
    // right.level = this.level or this.level - 1
    // right.right, right.left < this.level
    // if level > 1, then left !is null and right !is null
    private struct Node {
        K key;
        Node* left, right;
        size_t level;
        V value;
    }
    private Node* root;
    
    pure this(K[] args...) {
        insert(args);
    }
    
    // returns the keys of the elements in the ascending order
    public pure inout(K)[] keys() @property inout const {
        return array_(cast(inout(Node*)) root);
    }
    deprecated("Use keys() instead.") public inout(K)[] array() @property inout const {
        return array_(cast(inout(Node*)) root);
    }
    private pure inout(K)[] array_(inout(Node*) node) inout const {
        if (node == null) return [];
        return array_(node.left) ~ [node.key] ~ array_(node.right);
    }
    // array.length
    private size_t cardinal_;
    public pure @nogc @safe size_t cardinal() @property inout const {
        return cardinal_;
    }
    public pure @nogc @safe bool empty() @property inout const {
        return root == null;
    }
    // return the minimal key
    public pure @nogc K front() @property inout const {
    	auto node = cast(Node*) root;
    	while (node) {
    		if (!node.left) return node.key;
    		else node = node.left;
    	}
    	assert(0, "Tried to get the front key of an empty AATree.");
    }
    
    // foreach loop by key and value in the ascending order of the key
    public int opApply(int delegate(K, V) dg) {
    	const(Node*)[] node_stacks = [root];
    	bool[]  visited_stacks = [false];
    	while (node_stacks.length > 0) {
    		auto top_node = node_stacks[$-1];
    		// null
    		if (top_node == null) { node_stacks.length -= 1, visited_stacks.length -= 1; continue; }
    		// push and mark the top node as visited
    		if (!visited_stacks[$-1]) node_stacks ~= top_node.left, visited_stacks[$-1] = true, visited_stacks ~= false;
    		// already visited
    		else {
    			if (dg(cast(K) top_node.key, cast(V) top_node.value)) return 1;				// do the loop-body
    			node_stacks.length -= 1, visited_stacks.length -= 1;		// get rid of the current node
    			node_stacks ~= top_node.right, visited_stacks ~= false;		// push the right
    		}
    	}
    	return 1;	// stop
    }
    
    public pure bool hasKey(inout K key) inout {
        return hasKey(key, cast(Node*) root) != null;
    }
    private pure Node* hasKey(inout K key, Node* node) inout {
        while (true) {
            // not found
            if (node == null) return null;
            
            // go left
            if      (less(key, node.key)) node = node.left;
            // go right
            else if (less(node.key, key)) node = node.right;
            // found
            else return node;
        }
    }
    
    public pure ref V getValue(inout K key) inout const {
        return hasKey(key, cast(Node*) root).value;
    }
    
    // [] overload
    public pure ref V opIndex(K index) inout const {
        return getValue(index);
    }
    // aatree[index] = s
    public pure V opIndexAssign(V s, K index) {
        root = insert(index, root, s);
        return s;
    }
    //            v                      v
    //   left <- node -                left ->   node
    //   |  |          |       =>        |      |    |
    //   v  v          v                 v      v    v
    //   a  b        right               a      b  right
    private pure Node* skew(Node* node) inout {
        if (node == null)           return null;
        else if (node.left == null) return node;
        else if (node.left.level == node.level) {
            auto L = node.left;
            node.left = L.right;
            L.right = node;
            return L;
        }
        else return node;
    }
    //                                 v
    //                               - r -
    //                     =>       |     |
    //  v                           v     v
    // node  ->  r  ->  x          node   x
    //   |       |                |    |
    //   v       v                v    v
    //   a       b                a    b
    private pure Node* split(Node* node) inout {
        if      (node == null)                                   return null;
        else if (node.right == null || node.right.right == null) return node;
        else if (node.level == node.right.right.level) {
            auto R = node.right;
            node.right = R.left;
            R.left = node;
            ++R.level;
            return R;
        }
        else return node;
    }
    /////////////
    // insert
    public pure void insert(K[] keys...) {
        foreach (key; keys)
            root = insert(key, root);
    }
    private pure Node* insert(K key, Node* node, V value = V.init) {
        if      (node == null) {
            auto new_node = new Node();
            new_node.key = key, new_node.level = 1, new_node.value = value; 
            ++cardinal_;
            return new_node;
        }
        else if (less(key, node.key)) {
            node.left  = insert(key, node.left, value);
        }
        else if (less(node.key, key)) {
            node.right = insert(key, node.right, value);
        }
        else {
            node.value = value;
        }
        node = skew (node);
        node = split(node);
        return node;
    }
    
    /////////////
    // remove
    public pure void remove(K[] keys...) {
        foreach (key; keys)
            root = remove(key, root);
    }
    private pure Node* remove(K key, Node* node) {
        if (node == null)
            return null;
        else if (less(node.key, key))
            node.right = remove(key, node.right);
        else if (less(key, node.key))
            node.left  = remove(key, node.left);
        else {
            // leaf
            if (node.left == null && node.right == null) {
                --cardinal_;
                return null;
            }
            else if (node.left == null) {
                auto R = successor(node);
                node.right = remove(R.key, node.right);
                node.key = R.key;
                node.value = R.value;
            }
            else {
                auto L = predecessor(node);
                node.left = remove(L.key, node.left);
                node.key = L.key;
                node.value = L.value;
            }
        }
        // 
        node = decrease_level(node);
        node = skew(node);
        node.right = skew(node.right);
        if (node.right != null) node.right.right = skew(node.right.right);
        node = split(node);
        node.right = split(node.right);
        return node;
    }
    
    private pure Node* decrease_level(Node* node) {
        if (node == null) return null;
        auto normalize
           = min(
               node.left  ? node.left.level  : 0,
               node.right ? node.right.level : 0
             )
           + 1;
        if (normalize < node.level) {
            node.level = normalize;
            if (node.right && normalize < node.right.level)
                node.right.level = normalize;
        }
        return node;
    }
    
    private pure Node* predecessor(Node* node) {
        node = node.left;
        while (node.right)
            node = node.right;
        return node;
    }
    
    private pure Node* successor(Node* node) {
        node = node.right;
        while (node.left)
            node = node.left;
        return node;
    }
    
    version (unittest) {
        public void test() inout {
            {
                //     l <---- n      m = l ---->  n
                //   |   |     |    =>    |      |   |
                //   v   v     v          v      v   v
                //   a   b     r          a      b   r
                Node n, l, r, a, b;
                //n.key = 0, l.key = 1, r.key = 2, a.key = 3, b.key = 4;
                n.left = &l, n.right = &r, l.left = &a, l.right = &b;
                a.level = 1, b.level = 1, r.level = 1, l.level = 2, n.level = 2;
                
                auto m = skew(&n);
                static assert ( is(typeof(*m.left) == Node) );
                static assert ( is(typeof(m.left) == Node*) );
                static assert ( is(typeof(m.left.left) == Node*) );
                static assert ( is(typeof(*m.left.left) == Node) );
                static assert ( is(typeof((*m.left).left) == Node*) );
                assert ( m == &l && m.left == &a && m.right == &n && m.right.left == &b && m.right.right == &r );
            }
            {
                //   n -> r -> x              -r=m-
                //   |    |         =>       |     |
                //   v    v                  v     v
                //   a    b                - n -   x
                //                         |   |
                //                         v   v
                //                         a   b
                Node n, x, r, a, b;
                //n.key = 0, x.key = 1, r.key = 2, a.key = 3, b.key = 4;
                n.left = &a, n.right = &r, r.left = &b, r.right = &x;
                a.level = 1, b.level = 1, n.level = 2, r.level = 2, x.level = 2;
                
                auto m = split(&n);
                assert ( m == &r && m.left == &n && m.right == &x && m.left.left == &a && m.left.right == &b );
                
            }
        }
    }
}
