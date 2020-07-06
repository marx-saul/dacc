module dacc.graph;

import std.typecons;
import std.algorithm, std.array, std.range;
import dacc.set;

unittest {
	import std.stdio;
	writeln("## graph unittest");
	auto graph = new DirectedGraph(10u, [
		tuple(0u, 1u),
		tuple(1u, 2u),
		tuple(1u, 3u),
		tuple(2u, 3u),
		tuple(2u, 5u),
		tuple(2u, 6u),
		tuple(3u, 4u),
		tuple(3u, 7u),
		tuple(4u, 1u),
		tuple(5u, 8u),
		tuple(6u, 7u),
		tuple(7u, 8u),
		tuple(8u, 6u),
		tuple(8u, 9u),
	]);
	auto strong_components = graph.strong_decomposition();
	foreach (sc; strong_components) { writeln(sc.array); }

	graph = new DirectedGraph(10u, [
		tuple(0u, 3u),
		tuple(0u, 6u),
		tuple(8u, 7u),
		tuple(8u, 2u),
		tuple(8u, 9u),
		tuple(8u, 6u),
		tuple(7u, 1u),
		tuple(3u, 5u),
		tuple(3u, 1u),
		tuple(9u, 6u),
		tuple(5u, 1u),
		tuple(5u, 4u),
		tuple(5u, 6u),
		tuple(1u, 4u),
	]);
	auto vertices = graph.topological_sort();
	writeln(vertices);
}

class DirectedGraph {
	immutable uint vert_num;	// the number of vertices, 0, 1, ..., vert_num - 1
	Set!(uint)[] paths;			// there is a path i ---> j  iff  j in paths[i]. Each paths[i] must not be null.
	Set!(uint)[] rev_paths;		// j in paths[i] iff i in paths[j]. Each paths[i] must not be null.

	private this(uint vn) {
		vert_num = vn;
		auto ps = new Set!(uint)[vn], rp = new Set!(uint)[vn];
		// initialize
		foreach (v; 0..vn) {
			ps[v] = new Set!(uint);
			rp[v] = new Set!(uint);
		}
		paths = ps;
		rev_paths = rp;
	}
	public  this(uint vn, Tuple!(uint, uint)[] edges) {
		this(vn);
		foreach (e; edges) {
			if (e[0] == e[1]) continue;
			paths[e[0]].add(e[1]);
			rev_paths[e[1]].add(e[0]);
		}
	}

	// return the array of strong components, sorted in order of the representatives.
	public Set!(uint)[] strong_decomposition()  {
		uint[] rep;
		Set!(uint)[] comp;

		// if the vertex v already appeared in get_post_order.stack
		auto processed = new bool[vert_num];

		// get an array of vertices in post order that can be reached from v
		uint[] get_post_order(uint v) {
			// DFS
			uint[] stack = [v];
			uint[] result;

			while (stack.length > 0) {
				auto top_v = stack[$-1];
				// already visited this vertex.
				if (processed[top_v]) {
					result ~= top_v;	// post_order
					stack.length -= 1;
					continue;
				}
				// push all unvisited vertices to_v that can reach from top_v
				foreach (to_v; paths[top_v]) if (!processed[to_v]) {
					stack ~= to_v;
				}
				processed[top_v] = true;
			}
			return result;
		}

		// get strong components from a component
		// vs are in post order
		Set!(uint)[] get_strong_components(uint[] vs) {
			Set!(uint)[] result;
			auto visited = new bool[vert_num];

			foreach_reverse (k, v; vs) {
				// if already visited
				if (visited[v]) continue;

				// reverse DFS (DFS on rev_paths)
				auto stack = [v];
				auto strong_component = new Set!(uint);

				while (stack.length > 0) {
					auto top_v = stack[$-1];
					// already visited
					if (visited[stack[$-1]]) {
						strong_component.add(top_v);
						stack.length -= 1;
						continue;
					}
					// push
					foreach (from_v; rev_paths[top_v]) if (!visited[from_v]) {
						stack ~= from_v;
					}
					visited[top_v] = true;
				}
				result ~= strong_component;
			}
			return result.sort!((a,b) => a.front < b.front).array;
		}

		// get all strong components
		foreach (v; 0 .. vert_num) if (!processed[v]) {
			comp ~= get_strong_components(get_post_order(v));
		}

		return comp;
	}

	// get_representative[i] is the least vertex of the strong component which i belong to.
	public uint[] get_representative(Set!(uint)[] scs)  {
		auto result = new uint[vert_num];
		foreach (sc; scs) foreach (v; sc) {
			result[v] = sc.front;
		}
		return result;
	}

	public uint[] get_representative() {
		return get_representative(strong_decomposition());
	}

	// return the graph whose strong components are shrunk into a single vertex
	// i.e. for vertices i and j, i ~ j  iff  i and j belong to the same strong component
	public DirectedGraph shrink(Set!(uint)[] scs, uint[] reps) {
		auto scs_reps = scs.map!(a => a.front).assumeSorted();
		Tuple!(uint, uint)[] new_edges;
		// from_v ---> to_v
		// index of reps[from_v] ---> index of reps[to_v]
		foreach (i, sc; scs) foreach (from_v; sc) foreach (to_v; paths[from_v]) {
			new_edges ~= tuple(cast(uint) i, cast(uint) scs_reps.lowerBound(reps[to_v]).length);
		}
		return new DirectedGraph(cast(uint) scs.length, new_edges);
	}

	// Be sure that the graph is not circular
	public uint[] topological_sort() {
		uint[] result;

		auto inj_deg = new uint[vert_num];	// injection degree
		uint[] inj0verts;	// vertices whose injection degree is 0.

		foreach (v; 0 .. vert_num) {
			inj_deg[v] = cast(uint) rev_paths[v].cardinal;
			if (inj_deg[v] == 0) inj0verts ~= v;
		}
		// circular
		if (inj0verts.length == 0) return null;

		while (inj0verts.length > 0) {
			auto v = inj0verts[0];
			result ~= v;
			foreach (to_v; paths[v]) {
				// circular
				if (inj_deg[to_v] == 0) return null;
				--inj_deg[to_v];	// eliminate an edge v ---> to_v
				if (inj_deg[to_v] == 0) inj0verts ~= to_v;

			}
			inj0verts = inj0verts[1 .. $];
		}

		return result;
	}
}
