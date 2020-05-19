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

module hunt.collection.AbstractMap;

import hunt.collection.Collection;
import hunt.collection.Iterator;
import hunt.collection.Map;
import hunt.collection.Set;

import hunt.Exceptions;
import hunt.Object;
import hunt.util.ObjectUtils;

import std.array;
// import std.container.array;
import hunt.collection.Array;
import std.conv;
import std.exception;
import std.range;

/**
*/
abstract class AbstractMap(K, V) : Map!(K, V) {

    /**
     * The number of key-value mappings contained in this map.
     */
    protected int _size;

    /**
     * Sole constructor.  (For invocation by subclass constructors, typically
     * implicit.)
     */
    protected this() {
    }

    // Query Operations

    /**
     * Returns the number of key-value mappings in this map.
     *
     * @return the number of key-value mappings in this map
     */
    int size() {
        return _size;
    }

    /**
     * Returns <tt>true</tt> if this map contains no key-value mappings.
     *
     * @return <tt>true</tt> if this map contains no key-value mappings
     */
    bool isEmpty() {
        return _size == 0;
    }

    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation iterates over <tt>entrySet()</tt> searching
     * for an entry with the specified value.  If such an entry is found,
     * <tt>true</tt> is returned.  If the iteration terminates without
     * finding such an entry, <tt>false</tt> is returned.  Note that this
     * implementation requires linear time in the size of the map.
     *
     * @throws ClassCastException   {@inheritDoc}
     * @throws NullPointerException {@inheritDoc}
     */
    bool containsKey(K key) {
        throw new UnsupportedOperationException();
    }
    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation iterates over <tt>entrySet()</tt> searching
     * for an entry with the specified value.  If such an entry is found,
     * <tt>true</tt> is returned.  If the iteration terminates without
     * finding such an entry, <tt>false</tt> is returned.  Note that this
     * implementation requires linear time in the size of the map.
     *
     * @throws ClassCastException   {@inheritDoc}
     * @throws NullPointerException {@inheritDoc}
     */
    bool containsValue(V value) {
        throw new UnsupportedOperationException();
    }

    V opIndex(K key) {
        return get(key);
    }

    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation iterates over <tt>entrySet()</tt> searching
     * for an entry with the specified key.  If such an entry is found,
     * the entry's value is returned.  If the iteration terminates without
     * finding such an entry, <tt>null</tt> is returned.  Note that this
     * implementation requires linear time in the size of the map; many
     * implementations will override this method.
     *
     * @throws ClassCastException            {@inheritDoc}
     * @throws NullPointerException          {@inheritDoc}
     */
    V get(K key) {
        throw new UnsupportedOperationException();
    }

    /**
     * Returns the value to which the specified key is mapped, or
     * {@code defaultValue} if this map contains no mapping for the key.
     *
     * @implSpec
     * The default implementation makes no guarantees about synchronization
     * or atomicity properties of this method. Any implementation providing
     * atomicity guarantees must override this method and document its
     * concurrency properties.
     *
     * @param key the key whose associated value is to be returned
     * @param defaultValue the default mapping of the key
     * @return the value to which the specified key is mapped, or
     * {@code defaultValue} if this map contains no mapping for the key
     * @throws ClassCastException if the key is of an inappropriate type for
     * this map
     * (<a href="{@docRoot}/java/util/Collection.html#optional-restrictions">optional</a>)
     * @throws NullPointerException if the specified key is null and this map
     * does not permit null keys
     * (<a href="{@docRoot}/java/util/Collection.html#optional-restrictions">optional</a>)
     */
    V getOrDefault(K k, V value) {
        throw new UnsupportedOperationException();
    }

    // Modification Operations

    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation always throws an
     * <tt>UnsupportedOperationException</tt>.
     *
     * @throws UnsupportedOperationException {@inheritDoc}
     * @throws ClassCastException            {@inheritDoc}
     * @throws NullPointerException          {@inheritDoc}
     * @throws IllegalArgumentException      {@inheritDoc}
     */
    V put(K key, V value) {
        throw new UnsupportedOperationException();
    }

    V putIfAbsent(K key, V value) {
        V v = V.init;

        if (!containsKey(key))
            v = put(key, value);

        return v;
    }

    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation iterates over <tt>entrySet()</tt> searching for an
     * entry with the specified key.  If such an entry is found, its value is
     * obtained with its <tt>getValue</tt> operation, the entry is removed
     * from the collection (and the backing map) with the iterator's
     * <tt>remove</tt> operation, and the saved value is returned.  If the
     * iteration terminates without finding such an entry, <tt>null</tt> is
     * returned.  Note that this implementation requires linear time in the
     * size of the map; many implementations will override this method.
     *
     * <p>Note that this implementation throws an
     * <tt>UnsupportedOperationException</tt> if the <tt>entrySet</tt>
     * iterator does not support the <tt>remove</tt> method and this map
     * contains a mapping for the specified key.
     *
     * @throws UnsupportedOperationException {@inheritDoc}
     * @throws ClassCastException            {@inheritDoc}
     * @throws NullPointerException          {@inheritDoc}
     */
    V remove(K key) {
        throw new UnsupportedOperationException();
    }

    bool remove(K key, V value) {
        V curValue = get(key);
        if (curValue != value || !containsKey(key))
            return false;
        remove(key);
        return true;
    }

    // Bulk Operations

    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation iterates over the specified map's
     * <tt>entrySet()</tt> collection, and calls this map's <tt>put</tt>
     * operation once for each entry returned by the iteration.
     *
     * <p>Note that this implementation throws an
     * <tt>UnsupportedOperationException</tt> if this map does not support
     * the <tt>put</tt> operation and the specified map is nonempty.
     *
     * @throws UnsupportedOperationException {@inheritDoc}
     * @throws ClassCastException            {@inheritDoc}
     * @throws NullPointerException          {@inheritDoc}
     * @throws IllegalArgumentException      {@inheritDoc}
     */
    void putAll(Map!(K, V) m) {
        foreach (K k, V v; m)
            put(k, v);
    }

    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation calls <tt>entrySet().clear()</tt>.
     *
     * <p>Note that this implementation throws an
     * <tt>UnsupportedOperationException</tt> if the <tt>entrySet</tt>
     * does not support the <tt>clear</tt> operation.
     *
     * @throws UnsupportedOperationException {@inheritDoc}
     */
    void clear() {
        throw new NotImplementedException("");
    }

    bool replace(K key, V oldValue, V newValue) {
        V curValue = get(key);
        if (curValue != oldValue || !containsKey(key)) {
            return false;
        }
        put(key, newValue);
        return true;
    }

    V replace(K key, V value) {
        V curValue = V.init;
        if (containsKey(key)) {
            curValue = put(key, value);
        }
        return curValue;
    }

    int opApply(scope int delegate(ref K, ref V) dg) {
        throw new NotImplementedException();
    }

    int opApply(scope int delegate(MapEntry!(K, V) entry) dg) {
        throw new NotImplementedException();
    }

    InputRange!K byKey() {
        throw new NotImplementedException();
    }

    InputRange!V byValue() {
        throw new NotImplementedException();
    }

    // Views

    /**
     * Each of these fields are initialized to contain an instance of the
     * appropriate view the first time this view is requested.  The views are
     * stateless, so there's no reason to create more than one of each.
     *
     * <p>Since there is no synchronization performed while accessing these fields,
     * it is expected that java.util.Map view classes using these fields have
     * no non-final fields (or any fields at all except for outer-this). Adhering
     * to this rule would make the races on these fields benign.
     *
     * <p>It is also imperative that implementations read the field only once,
     * as in:
     *
     * <pre> {@code
     * public Set!K keySet() {
     *   Set!K ks = keySet;  // single racy read
     *   if (ks is null) {
     *     ks = new KeySet();
     *     keySet = ks;
     *   }
     *   return ks;
     * }
     *}</pre>
     */
    // protected Set!K       _keySet;
    // protected Collection!V _values;

    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation returns a set that subclasses {@link AbstractSet}.
     * The subclass's iterator method returns a "wrapper object" over this
     * map's <tt>entrySet()</tt> iterator.  The <tt>size</tt> method
     * delegates to this map's <tt>size</tt> method and the
     * <tt>contains</tt> method delegates to this map's
     * <tt>containsKey</tt> method.
     *
     * <p>The set is created the first time this method is called,
     * and returned in response to all subsequent calls.  No synchronization
     * is performed, so there is a slight chance that multiple calls to this
     * method will not all return the same set.
     */
    K[] keySet() {
        Array!K arr;
        foreach (K key; byKey()) {
            arr.insertBack(key);
        }
        return arr.array();
    }

    /**
     * {@inheritDoc}
     *
     * @implSpec
     * This implementation returns a collection that subclasses {@link
     * AbstractCollection}.  The subclass's iterator method returns a
     * "wrapper object" over this map's <tt>entrySet()</tt> iterator.
     * The <tt>size</tt> method delegates to this map's <tt>size</tt>
     * method and the <tt>contains</tt> method delegates to this map's
     * <tt>containsValue</tt> method.
     *
     * <p>The collection is created the first time this method is called, and
     * returned in response to all subsequent calls.  No synchronization is
     * performed, so there is a slight chance that multiple calls to this
     * method will not all return the same collection.
     */
    V[] values() {
        // FIXME: Needing refactor or cleanup -@zxp at 9/26/2018, 6:00:54 PM
        // 
        // Array!V arr;
        // foreach(V value; byValue()) {
        //     arr.insertBack(value);
        // }
        // return arr.array();
        // V[] arr;
        // foreach (V value; byValue()) {
        //     arr ~= value;
        // }
        // return arr;
        return byValue().array();
    }

    // Comparison and hashing

    /**
     * Compares the specified object with this map for equality.  Returns
     * <tt>true</tt> if the given object is also a map and the two maps
     * represent the same mappings.  More formally, two maps <tt>m1</tt> and
     * <tt>m2</tt> represent the same mappings if
     * <tt>m1.entrySet().equals(m2.entrySet())</tt>.  This ensures that the
     * <tt>equals</tt> method works properly across different implementations
     * of the <tt>Map</tt> interface.
     *
     * @implSpec
     * This implementation first checks if the specified object is this map;
     * if so it returns <tt>true</tt>.  Then, it checks if the specified
     * object is a map whose size is identical to the size of this map; if
     * not, it returns <tt>false</tt>.  If so, it iterates over this map's
     * <tt>entrySet</tt> collection, and checks that the specified map
     * contains each mapping that this map contains.  If the specified map
     * fails to contain such a mapping, <tt>false</tt> is returned.  If the
     * iteration completes, <tt>true</tt> is returned.
     *
     * @param o object to be compared for equality with this map
     * @return <tt>true</tt> if the specified object is equal to this map
     */
    override bool opEquals(Object o) {
        if(o is null) return false;
        if (o is this) return true;

        auto m = cast(Map!(K, V)) o;
        if(m is null) return false;
        if (m.size() != size())
            return false;

        try {
            foreach(K key, V value; this) {
                if(value != m.get(key))
                    return false;
            }
        } catch (Exception) {
            return false;
        }

        return true;
    }

    bool opEquals(IObject o) {
        return opEquals(cast(Object) o);
    }

    // Iterator!(MapEntry!(K,V)) iterator()
    // {
    //     throw new UnsupportedOperationException();
    // }

    /**
     * Returns the hash code value for this map.  The hash code of a map is
     * defined to be the sum of the hash codes of each entry in the map's
     * <tt>entrySet()</tt> view.  This ensures that <tt>m1.equals(m2)</tt>
     * implies that <tt>m1.toHash()==m2.toHash()</tt> for any two maps
     * <tt>m1</tt> and <tt>m2</tt>, as required by the general contract of
     * {@link Object#toHash}.
     *
     * @implSpec
     * This implementation iterates over <tt>entrySet()</tt>, calling
     * {@link MapEntry#toHash toHash()} on each element (entry) in the
     * set, and adding up the results.
     *
     * @return the hash code value for this map
     * @see MapEntry#toHash()
     * @see Object#equals(Object)
     * @see Set#equals(Object)
     */
    override size_t toHash() @trusted nothrow {
        size_t h = 0;
        try {
            foreach (MapEntry!(K, V) i; this) {
                h += i.toHash();
            }
        } catch (Exception ex) {
        }
        return h;
    }

    /**
     * Returns a string representation of this map.  The string representation
     * consists of a list of key-value mappings in the order returned by the
     * map's <tt>entrySet</tt> view's iterator, enclosed in braces
     * (<tt>"{}"</tt>).  Adjacent mappings are separated by the characters
     * <tt>", "</tt> (comma and space).  Each key-value mapping is rendered as
     * the key followed by an equals sign (<tt>"="</tt>) followed by the
     * associated value.  Keys and values are converted to strings as by
     * {@link string#valueOf(Object)}.
     *
     * @return a string representation of this map
     */
    override string toString() {
        if (isEmpty())
            return "{}";

        Appender!string sb;
        sb.put("{");
        bool isFirst = true;
        foreach (K key, V value; this) {
            if (!isFirst) {
                sb.put(", ");
            }
            sb.put(key.to!string() ~ "=" ~ value.to!string());
            isFirst = false;
        }
        sb.put("}");

        return sb.data;
    }

    /**
     * Returns a shallow copy of this <tt>AbstractMap</tt> instance: the keys
     * and values themselves are not cloned.
     *
     * @return a shallow copy of this map
     */
    mixin CloneMemberTemplate!(typeof(this));

    /**
     * Utility method for SimpleEntry and SimpleImmutableEntry.
     * Test for equality, checking for nulls.
     *
     * NB: Do not replace with Object.equals until JDK-8015417 is resolved.
     */
    // private static bool eq(Object o1, Object o2) {
    //     return o1 is null ? o2 is null : o1.equals(o2);
    // }

    // Implementation Note: SimpleEntry and SimpleImmutableEntry
    // are distinct unrelated classes, even though they share
    // some code. Since you can't add or subtract final-ness
    // of a field in a subclass, they can't share representations,
    // and the amount of duplicated code is too small to warrant
    // exposing a common abstract class.

    /**
     * An Entry maintaining a key and a value.  The value may be
     * changed using the <tt>setValue</tt> method.  This class
     * facilitates the process of building custom map
     * implementations. For example, it may be convenient to return
     * arrays of <tt>SimpleEntry</tt> instances in method
     * <tt>Map.entrySet().toArray</tt>.
     *
     */
    // static class SimpleEntry!(K,V)
    //     implements Entry!(K,V), java.io.Serializable
    // {
    //     private static final long serialVersionUID = -8499721149061103585L;

    //     private final K key;
    //     private V value;

    //     /**
    //      * Creates an entry representing a mapping from the specified
    //      * key to the specified value.
    //      *
    //      * @param key the key represented by this entry
    //      * @param value the value represented by this entry
    //      */
    //     SimpleEntry(K key, V value) {
    //         this.key   = key;
    //         this.value = value;
    //     }

    //     /**
    //      * Creates an entry representing the same mapping as the
    //      * specified entry.
    //      *
    //      * @param entry the entry to copy
    //      */
    //     SimpleEntry(Entry!(K, V) entry) {
    //         this.key   = entry.getKey();
    //         this.value = entry.getValue();
    //     }

    //     /**
    //      * Returns the key corresponding to this entry.
    //      *
    //      * @return the key corresponding to this entry
    //      */
    //     K getKey() {
    //         return key;
    //     }

    //     /**
    //      * Returns the value corresponding to this entry.
    //      *
    //      * @return the value corresponding to this entry
    //      */
    //     V getValue() {
    //         return value;
    //     }

    //     /**
    //      * Replaces the value corresponding to this entry with the specified
    //      * value.
    //      *
    //      * @param value new value to be stored in this entry
    //      * @return the old value corresponding to the entry
    //      */
    //     V setValue(V value) {
    //         V oldValue = this.value;
    //         this.value = value;
    //         return oldValue;
    //     }

    //     /**
    //      * Compares the specified object with this entry for equality.
    //      * Returns {@code true} if the given object is also a map entry and
    //      * the two entries represent the same mapping.  More formally, two
    //      * entries {@code e1} and {@code e2} represent the same mapping
    //      * if<pre>
    //      *   (e1.getKey()==null ?
    //      *    e2.getKey()==null :
    //      *    e1.getKey().equals(e2.getKey()))
    //      *   &amp;&amp;
    //      *   (e1.getValue()==null ?
    //      *    e2.getValue()==null :
    //      *    e1.getValue().equals(e2.getValue()))</pre>
    //      * This ensures that the {@code equals} method works properly across
    //      * different implementations of the {@code MapEntry} interface.
    //      *
    //      * @param o object to be compared for equality with this map entry
    //      * @return {@code true} if the specified object is equal to this map
    //      *         entry
    //      * @see    #toHash
    //      */
    //     bool equals(Object o) {
    //         if (!(o instanceof MapEntry))
    //             return false;
    //         MapEntry<?,?> e = (MapEntry<?,?>)o;
    //         return eq(key, e.getKey()) && eq(value, e.getValue());
    //     }

    //     /**
    //      * Returns the hash code value for this map entry.  The hash code
    //      * of a map entry {@code e} is defined to be: <pre>
    //      *   (e.getKey()==null   ? 0 : e.getKey().toHash()) ^
    //      *   (e.getValue()==null ? 0 : e.getValue().toHash())</pre>
    //      * This ensures that {@code e1.equals(e2)} implies that
    //      * {@code e1.toHash()==e2.toHash()} for any two Entries
    //      * {@code e1} and {@code e2}, as required by the general
    //      * contract of {@link Object#toHash}.
    //      *
    //      * @return the hash code value for this map entry
    //      * @see    #equals
    //      */
    //     size_t toHash() @trusted nothrow {
    //         return (key   is null ? 0 :   key.toHash()) ^
    //                (value is null ? 0 : value.toHash());
    //     }

    //     /**
    //      * Returns a string representation of this map entry.  This
    //      * implementation returns the string representation of this
    //      * entry's key followed by the equals character ("<tt>=</tt>")
    //      * followed by the string representation of this entry's value.
    //      *
    //      * @return a string representation of this map entry
    //      */
    //     string toString() {
    //         return key ~ "=" ~ value;
    //     }

    // }
}

/**
* An Entry maintaining an immutable key and value.  This class
* does not support method <tt>setValue</tt>.  This class may be
* convenient in methods that return thread-safe snapshots of
* key-value mappings.
*
* @since 1.6
*/
class SimpleImmutableEntry(K, V) : AbstractMapEntry!(K, V) {

    /**
        * Creates an entry representing a mapping from the specified
        * key to the specified value.
        *
        * @param key the key represented by this entry
        * @param value the value represented by this entry
        */
    this(K key, V value) {
        super(key, value);
    }

    /**
        * Creates an entry representing the same mapping as the
        * specified entry.
        *
        * @param entry the entry to copy
        */
    this(MapEntry!(K, V) entry) {
        super(entry.getKey(), entry.getValue());
    }

    /**
    * Replaces the value corresponding to this entry with the specified
    * value (optional operation).  This implementation simply throws
    * <tt>UnsupportedOperationException</tt>, as this class implements
    * an <i>immutable</i> map entry.
    *
    * @param value new value to be stored in this entry
    * @return (Does not return)
    * @throws UnsupportedOperationException always
    */
    override V setValue(V value) {
        throw new UnsupportedOperationException();
    }

    /**
     * Returns the hash code value for this map entry.  The hash code
     * of a map entry {@code e} is defined to be: <pre>
     *   (e.getKey()==null   ? 0 : e.getKey().toHash()) ^
     *   (e.getValue()==null ? 0 : e.getValue().toHash())</pre>
     * This ensures that {@code e1.equals(e2)} implies that
     * {@code e1.toHash()==e2.toHash()} for any two Entries
     * {@code e1} and {@code e2}, as required by the general
     * contract of {@link Object#toHash}.
     *
     * @return the hash code value for this map entry
     * @see    #equals
     */
    override size_t toHash() @trusted nothrow {
        static if (is(K == class)) {
            size_t kHash = 0;
            if (key !is null)
                kHash = key.toHash();
        } else {
            size_t kHash = hashOf(key);
        }

        static if (is(V == class)) {
            size_t vHash = 0;
            if (value !is null)
                vHash = value.toHash();
        } else {
            size_t vHash = hashOf(value);
        }

        return kHash ^ vHash;
    }
}

/**
*/
class EmptyMap(K, V) : AbstractMap!(K, V) {

    override int size() {
        return 0;
    }

    override bool isEmpty() {
        return true;
    }

    override bool containsKey(K key) {
        return false;
    }

    // override
    // bool containsValue(V value) {return false;}

    override V get(K key) {
        return V.init;
    }

    override K[] keySet() {
        return null;
    }

    override V[] values() {
        return null;
    }
    // Collection!(V) values()              {return emptySet();}
    // Set!(MapEntry!(K,V)) entrySet()      {return emptySet();}

    override bool opEquals(Object o) {
        return (typeid(o) == typeid(Map!(K, V))) && (cast(Map!(K, V)) o).isEmpty();
    }

    override size_t toHash() {
        return 0;
    }

    // Override default methods in Map
    override V getOrDefault(K k, V defaultValue) {
        return defaultValue;
    }

    override int opApply(scope int delegate(ref K, ref V) dg) {
        return 0;
    }

    // override
    // void replaceAll(BiFunction!(K, V, V) function) {
    //     Objects.requireNonNull(function);
    // }

    // override
    // V putIfAbsent(K key, V value) {
    //     throw new UnsupportedOperationException();
    // }

    // override
    // bool remove(Object key, Object value) {
    //     throw new UnsupportedOperationException();
    // }

    // override
    // bool replace(K key, V oldValue, V newValue) {
    //     throw new UnsupportedOperationException();
    // }

    // override
    // V replace(K key, V value) {
    //     throw new UnsupportedOperationException();
    // }

    // override
    // V computeIfAbsent(K key,
    //         Function!(K, V) mappingFunction) {
    //     throw new UnsupportedOperationException();
    // }

    // override
    // V computeIfPresent(K key,
    //         BiFunction!(K, V, V) remappingFunction) {
    //     throw new UnsupportedOperationException();
    // }

    // override
    // V compute(K key,
    //         BiFunction!(K, V, V) remappingFunction) {
    //     throw new UnsupportedOperationException();
    // }

    // override
    // V merge(K key, V value,
    //         BiFunction!(V, V, V) remappingFunction) {
    //     throw new UnsupportedOperationException();
    // }

    // // Preserves singleton property
    // private Object readResolve() {
    //     return EMPTY_MAP;
    // }
}
