module dacc.graph;

import std.typecons;
import std.algorithm, std.array, std.range;
import dacc.set;

unittest {
	import std.stdio;
	writeln("## graph unittest");
	auto graph = new DirectedGraph(10uL, [
		tuple(0uL, 1uL),
		tuple(1uL, 2uL),
		tuple(1uL, 3uL),
		tuple(2uL, 3uL),
		tuple(2uL, 5uL),
		tuple(2uL, 6uL),
		tuple(3uL, 4uL),
		tuple(3uL, 7uL),
		tuple(4uL, 1uL),
		tuple(5uL, 8uL),
		tuple(6uL, 7uL),
		tuple(7uL, 8uL),
		tuple(8uL, 6uL),
		tuple(8uL, 9uL),
	]);
	auto strong_components = graph.strong_decomposition();
	writeln("Strong components");
	foreach (sc; strong_components) { writeln(sc.array); }
	writeln();

	graph = new DirectedGraph(10uL, [
		tuple(0uL, 3uL),
		tuple(0uL, 6uL),
		tuple(8uL, 7uL),
		tuple(8uL, 2uL),
		tuple(8uL, 9uL),
		tuple(8uL, 6uL),
		tuple(7uL, 1uL),
		tuple(3uL, 5uL),
		tuple(3uL, 1uL),
		tuple(9uL, 6uL),
		tuple(5uL, 1uL),
		tuple(5uL, 4uL),
		tuple(5uL, 6uL),
		tuple(1uL, 4uL),
	]);
	auto vertices = graph.topological_sort();
	writeln("Topological sort\n", vertices);
}

class DirectedGraph {
	immutable size_t vert_num;	// the number of vertices, 0, 1, ..., vert_num - 1
	Set!(size_t)[] paths;			// there is a path i ---> j  iff  j in paths[i]. Each paths[i] must not be null.
	Set!(size_t)[] rev_paths;		// j in paths[i] iff i in paths[j]. Each paths[i] must not be null.
	size_t[][] paths_array;
	size_t[][] rev_paths_array;

	private this(size_t vn) {
		vert_num = vn;
		auto ps = new Set!(size_t)[vn], rp = new Set!(size_t)[vn];
		// initialize
		foreach (v; 0..vn) {
			ps[v] = new Set!(size_t);
			rp[v] = new Set!(size_t);
		}
		paths = ps;
		rev_paths = rp;
		paths_array.length = vn;
		rev_paths_array.length = vn;
	}
	public  this(size_t vn, Tuple!(size_t, size_t)[] edges) {
		this(vn);
		foreach (e; edges) {
			if (e[0] == e[1]) continue;
			paths[e[0]].add(e[1]);
			rev_paths[e[1]].add(e[0]);
		}
		foreach (v; 0..vn) {
			paths_array[v] = paths[v].array;
			rev_paths_array[v] = rev_paths[v].array;
		}
	}

	// return the array of strong components, sorted in order of the representatives.
	public Set!(size_t)[] strong_decomposition()  {
		size_t[] rep;
		Set!(size_t)[] comp;

		// if the vertex v already appeared in some of get_post_order.stack
		auto processed = new bool[vert_num];
		auto pushed_vertices = new size_t[vert_num];

		// get an array of vertices in post order that can be reached from v
		size_t[] get_post_order(size_t v) {
			// DFS
			size_t[] stack = [v]; processed[v] = true;
			size_t[] result;

			while (stack.length > 0) {
				auto top_v = stack[$-1];
				auto edge_index = pushed_vertices[top_v];
				// all vertices w s.t. top_v ---> w are pushed
				if (edge_index >= paths_array[top_v].length) {
					stack.length -= 1; // pop
					result ~= top_v;
					continue;
				}
				auto to_v = paths_array[top_v][edge_index];
				// have not pushed
				if (!processed[to_v]) {
					stack ~= to_v; // push
					processed[to_v] = true;
				}
				++pushed_vertices[top_v];	// dealt with one w s.t. top_v ---> w
			}

			return result;
		}

		auto visited = new bool[vert_num];
		auto pushed_vertices2 = new size_t[vert_num];
		// get strong components from a component
		// vs are in post order
		Set!(size_t)[] get_strong_components(size_t[] vs) {
			Set!(size_t)[] result;

			foreach_reverse (k, v; vs) {
				// if already visited
				if (visited[v]) continue;

				// DFS on rev_paths
				auto stack = [v]; visited[v] = true;
				auto strong_component = new Set!(size_t);

				while (stack.length > 0) {
					auto top_v = stack[$-1];
					auto edge_index = pushed_vertices2[top_v];
					// all vertices w s.t. top_v ---> w are pushed
					if (edge_index >= rev_paths_array[top_v].length) {
						stack.length -= 1;
						strong_component.add(top_v);
						continue;
					}
					auto from_v = rev_paths_array[top_v][edge_index];
					// have not pushed
					if (!visited[from_v]) {
						stack ~= from_v; // push
						visited[from_v] = true;
					}
					++pushed_vertices2[top_v];	// dealt with one w s.t. top_v ---> w
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
	public size_t[] get_representative(Set!(size_t)[] scs)  {
		auto result = new size_t[vert_num];
		foreach (sc; scs) foreach (v; sc) {
			result[v] = sc.front;
		}
		return result;
	}

	public size_t[] get_representative() {
		return get_representative(strong_decomposition());
	}

	// return the graph whose strong components are shrunk into a single vertex
	// i.e. for vertices i and j, i ~ j  iff  i and j belong to the same strong component
	public DirectedGraph shrink(Set!(size_t)[] scs, size_t[] reps) {
		auto scs_reps = scs.map!(a => a.front).assumeSorted();
		Tuple!(size_t, size_t)[] new_edges;
		// from_v ---> to_v
		// index of reps[from_v] ---> index of reps[to_v]
		foreach (i, sc; scs) foreach (from_v; sc) foreach (to_v; paths[from_v]) {
			new_edges ~= tuple(cast(size_t) i, cast(size_t) scs_reps.lowerBound(reps[to_v]).length);
		}
		return new DirectedGraph(cast(size_t) scs.length, new_edges);
	}

	// Be sure that the graph is not circular
	public size_t[] topological_sort() {
		size_t[] result;

		auto inj_deg = new size_t[vert_num];	// injection degree
		size_t[] inj0verts;	// vertices whose injection degree is 0.

		foreach (v; 0 .. vert_num) {
			inj_deg[v] = cast(size_t) rev_paths[v].cardinal;
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

