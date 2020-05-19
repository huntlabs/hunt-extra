/*
 * Hunt - A refined core library for D programming language.
 *
 * Copyright (C) 2018-2019 HuntLabs
 *
 * Website: https://www.huntlabs.net/
 *
 * Licensed under the Apache-2.0 License.
 *
 */

module hunt.collection.MultiMap;

import hunt.collection.ArrayList;
import hunt.collection.HashMap;
import hunt.collection.List;
import hunt.collection.Map;

import hunt.text;

/**
 * A multi valued Map.
 * 
 * @param !V
 *            the entry type for multimap values
 */
class MultiMap(V) : HashMap!(string, List!(V)) {

	// TODO: Tasks pending completion -@zxp at 10/15/2018, 6:24:35 PM
	// replace this with hunt.collection.MultiValueMap

	this() {
		super();
	}

	this(Map!(string, List!(V)) map) {
		super(map);
	}

	this(MultiMap!V map) {
		super(map);
	}

	/**
	 * Get multiple values. Single valued entries are converted to singleton
	 * lists.
	 * 
	 * @param name
	 *            The entry key.
	 * @return Unmodifieable List of values.
	 */
	List!(V) getValues(string name) {
		List!(V) vals = super.get(name);
		if ((vals is null) || vals.isEmpty()) {
			return null;
		}
		return vals;
	}

	/**
	 * Get a value from a multiple value. If the value is not a multivalue, then
	 * index 0 retrieves the value or null.
	 * 
	 * @param name
	 *            The entry key.
	 * @param i
	 *            Index of element to get.
	 * @return Unmodifieable List of values.
	 */
	V getValue(string name, int i=0) {
		List!(V) vals = getValues(name);
		if (vals is null) {
			return V.init;
		}
		if (i == 0 && vals.isEmpty()) {
			return V.init;
		}
		return vals.get(i);
	}

	/**
	 * Get value as string. Single valued items are converted to a string with
	 * the toString() Object method. Multi valued entries are converted to a
	 * comma separated List. No quoting of commas within values is performed.
	 * 
	 * @param name
	 *            The entry key.
	 * @return string value.
	 */
	string getString(string name) {
		List!(V) vals = get(name);
		if ((vals is null) || (vals.isEmpty())) {
			return null;
		}

		if (vals.size() == 1) {
			// simple form.
			static if(is(V == string))
				return vals.get(0);
			else
				return vals.get(0).toString();
		}

		// delimited form
		StringBuilder values = new StringBuilder(128);
		foreach (V e ; vals) {
			if (e !is null) {
				if (values.length() > 0)
					values.append(',');
			static if(is(V == string))
				values.append(e);
			else
				values.append(e.toString());
			}
		}
		return values.toString();
	}

	/**
	 * Put multi valued entry.
	 * 
	 * @param name
	 *            The entry key.
	 * @param value
	 *            The simple value
	 * @return The previous value or null.
	 */
	List!(V) put(string name, V value) {
		if (value is null) {
			return super.put(name, null);
		}
		List!(V) vals = new ArrayList!(V)();
		vals.add(value);
		return put(name, vals);
	}

	alias put = HashMap!(string, List!(V)).put;

	/**
	 * Shorthand version of putAll
	 * 
	 * @param input
	 *            the input map
	 */
	void putAllValues(Map!(string, V) input) {
		foreach (string key, V value ; input) {
			put(key, value);
		}
	}

	/**
	 * Put multi valued entry.
	 * 
	 * @param name
	 *            The entry key.
	 * @param values
	 *            The List of multiple values.
	 * @return The previous value or null.
	 */
	List!(V) putValues(string name, List!(V) values) {
		return super.put(name, values);
	}

	/**
	 * Put multi valued entry.
	 * 
	 * @param name
	 *            The entry key.
	 * @param values
	 *            The array of multiple values.
	 * @return The previous value or null.
	 */
	final List!(V) putValues(string name, V[] values...) {
		List!(V) list = new ArrayList!(V)();
		// list.addAll(Arrays.asList(values));
		foreach(V v; values)
			list.add(v);
		return super.put(name, list);
	}

	/**
	 * Add value to multi valued entry. If the entry is single valued, it is
	 * converted to the first value of a multi valued entry.
	 * 
	 * @param name
	 *            The entry key.
	 * @param value
	 *            The entry value.
	 */
	void add(string name, V value) {
		List!(V) lo = get(name);
		if (lo is null) {
			lo = new ArrayList!(V)();
		}
		lo.add(value);
		super.put(name, lo);
	}

	/**
	 * Add values to multi valued entry. If the entry is single valued, it is
	 * converted to the first value of a multi valued entry.
	 * 
	 * @param name
	 *            The entry key.
	 * @param values
	 *            The List of multiple values.
	 */
	void addValues(string name, List!(V) values) {
		List!(V) lo = get(name);
		if (lo is null) {
			lo = new ArrayList!(V)();
		}
		lo.addAll(values);
		put(name, lo);
	}

	/**
	 * Add values to multi valued entry. If the entry is single valued, it is
	 * converted to the first value of a multi valued entry.
	 * 
	 * @param name
	 *            The entry key.
	 * @param values
	 *            The string array of multiple values.
	 */
	void addValues(string name, V[] values) {
		List!(V) lo = get(name);
		if (lo is null) {
			lo = new ArrayList!(V)();
		}
		// lo.addAll(Arrays.asList(values));
		foreach(V v; values)
			lo.add(v);
		put(name, lo);
	}

	/**
	 * Merge values.
	 * 
	 * @param map
	 *            the map to overlay on top of this one, merging together values
	 *            if needed.
	 * @return true if an existing key was merged with potentially new values,
	 *         false if either no change was made, or there were only new keys.
	 */
	// bool addAllValues(MultiMap!V map) {
	// 	bool merged = false;

	// 	if ((map is null) || (map.isEmpty())) {
	// 		// done
	// 		return merged;
	// 	}

	// 	for (MapEntry!(string, List!(V)) entry : map.entrySet()) {
	// 		string name = entry.getKey();
	// 		List!(V) values = entry.getValue();

	// 		if (this.containsKey(name)) {
	// 			merged = true;
	// 		}

	// 		this.addValues(name, values);
	// 	}

	// 	return merged;
	// }

	/**
	 * Remove value.
	 * 
	 * @param name
	 *            The entry key.
	 * @param value
	 *            The entry value.
	 * @return true if it was removed.
	 */
	bool removeValue(string name, V value) {
		List!(V) lo = get(name);
		if ((lo is null) || (lo.isEmpty())) {
			return false;
		}
		bool ret = lo.remove(value);
		if (lo.isEmpty()) {
			remove(name);
		} else {
			put(name, lo);
		}
		return ret;
	}

	/**
	 * Test for a specific single value in the map.
	 * <p>
	 * NOTE: This is a SLOW operation, and is actively discouraged.
	 * 
	 * @param value
	 *            the value to search for
	 * @return true if contains simple value
	 */
	bool containsSimpleValue(V value) {
		foreach (List!(V) vals ; byValue()) {
			if ((vals.size() == 1) && vals.contains(value)) {
				return true;
			}
		}
		return false;
	}

	override
	string toString() {
		StringBuilder sb = new StringBuilder();
		sb.append('{');
		bool delim = false;
		import std.conv;
		foreach(string key, List!(V) vals; this) {
			if (delim) {
				sb.append(", ");
			}
			sb.append(key);
			sb.append('=');
			if (vals.size() == 1) {
				sb.append(vals.get(0).to!string());
			} else {
				sb.append(vals.toString());
			}
			delim = true;
		}
		sb.append('}');
		return sb.toString();
	}

	/**
	 * @return Map of string arrays
	 */
	// Map!(string, string[]) toStringArrayMap() {
	// 	int s = size();
	// 	HashMap!(string, string[]) map = new (s * 3 / 2) class HashMap!(string, string[]) {

	// 		// private enum long serialVersionUID = -6129887569971781626L;
	// 		this(int initialCapacity) {
	// 			super(initialCapacity)
	// 		}

	// 		override
	// 		string toString() {
	// 			StringBuilder b = new StringBuilder();
	// 			b.append('{');
	// 			for (string k : super.keySet()) {
	// 				if (b.length() > 1)
	// 					b.append(',');
	// 				b.append(k);
	// 				b.append('=');
	// 				b.append(Arrays.asList(super.get(k)));
	// 			}

	// 			b.append('}');
	// 			return b.toString();
	// 		}
	// 	};

	// 	foreach (string key, List!(V) vals; this) {
	// 		string[] a = null;
	// 		if (vals !is null) {
	// 			a = new string[vals.size()];
	// 			a = vals.toArray(a);
	// 		}
	// 		map.put(key, a);
	// 	}
	// 	return map;
	// }

}
