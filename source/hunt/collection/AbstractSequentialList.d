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

module hunt.collection.AbstractSequentialList;

import hunt.collection.AbstractList;
import hunt.collection.Deque;
import hunt.collection.List;

import hunt.Exceptions;


/**
 * This class provides a skeletal implementation of the <tt>List</tt>
 * interface to minimize the effort required to implement this interface
 * backed by a "sequential access" data store (such as a linked list).  For
 * random access data (such as an array), <tt>AbstractList</tt> should be used
 * in preference to this class.<p>
 *
 * This class is the opposite of the <tt>AbstractList</tt> class in the sense
 * that it implements the "random access" methods (<tt>get(int index)</tt>,
 * <tt>set(int index, E element)</tt>, <tt>add(int index, E element)</tt> and
 * <tt>remove(int index)</tt>) on top of the list's list iterator, instead of
 * the other way around.<p>
 *
 * To implement a list the programmer needs only to extend this class and
 * provide implementations for the <tt>listIterator</tt> and <tt>size</tt>
 * methods.  For an unmodifiable list, the programmer need only implement the
 * list iterator's <tt>hasNext</tt>, <tt>next</tt>, <tt>hasPrevious</tt>,
 * <tt>previous</tt> and <tt>index</tt> methods.<p>
 *
 * For a modifiable list the programmer should additionally implement the list
 * iterator's <tt>set</tt> method.  For a variable-size list the programmer
 * should additionally implement the list iterator's <tt>remove</tt> and
 * <tt>add</tt> methods.<p>
 *
 * The programmer should generally provide a void (no argument) and collection
 * constructor, as per the recommendation in the <tt>Collection</tt> interface
 * specification.<p>
 *
 * This class is a member of the
 * <a href="{@docRoot}/../technotes/guides/collections/index.html">
 * Java Collections Framework</a>.
 *
 * @author  Josh Bloch
 * @author  Neal Gafter
 * @see Collection
 * @see List
 * @see AbstractList
 * @see AbstractCollection
 */

abstract class AbstractSequentialList(E) : AbstractList!E {
    /**
     * Sole constructor.  (For invocation by subclass constructors, typically
     * implicit.)
     */
    protected this() {
    }

//     /**
//      * Returns the element at the specified position in this list.
//      *
//      * <p>This implementation first gets a list iterator pointing to the
//      * indexed element (with <tt>listIterator(index)</tt>).  Then, it gets
//      * the element using <tt>ListIterator.next</tt> and returns it.
//      *
//      * @throws IndexOutOfBoundsException {@inheritDoc}
//      */
//     override E get(int index) {
//         try {
//             return listIterator(index).next();
//         } catch (NoSuchElementException exc) {
//             throw new IndexOutOfBoundsException("Index: " ~ index);
//         }
//     }

//     /**
//      * Replaces the element at the specified position in this list with the
//      * specified element (optional operation).
//      *
//      * <p>This implementation first gets a list iterator pointing to the
//      * indexed element (with <tt>listIterator(index)</tt>).  Then, it gets
//      * the current element using <tt>ListIterator.next</tt> and replaces it
//      * with <tt>ListIterator.set</tt>.
//      *
//      * <p>Note that this implementation will throw an
//      * <tt>UnsupportedOperationException</tt> if the list iterator does not
//      * implement the <tt>set</tt> operation.
//      *
//      * @throws UnsupportedOperationException {@inheritDoc}
//      * @throws ClassCastException            {@inheritDoc}
//      * @throws NullPointerException          {@inheritDoc}
//      * @throws IllegalArgumentException      {@inheritDoc}
//      * @throws IndexOutOfBoundsException     {@inheritDoc}
//      */
//     E set(int index, E element) {
//         try {
//             ListIterator!E e = listIterator(index);
//             E oldVal = e.next();
//             e.set(element);
//             return oldVal;
//         } catch (NoSuchElementException exc) {
//             throw new IndexOutOfBoundsException("Index: " ~index);
//         }
//     }

//     /**
//      * Inserts the specified element at the specified position in this list
//      * (optional operation).  Shifts the element currently at that position
//      * (if any) and any subsequent elements to the right (adds one to their
//      * indices).
//      *
//      * <p>This implementation first gets a list iterator pointing to the
//      * indexed element (with <tt>listIterator(index)</tt>).  Then, it
//      * inserts the specified element with <tt>ListIterator.add</tt>.
//      *
//      * <p>Note that this implementation will throw an
//      * <tt>UnsupportedOperationException</tt> if the list iterator does not
//      * implement the <tt>add</tt> operation.
//      *
//      * @throws UnsupportedOperationException {@inheritDoc}
//      * @throws ClassCastException            {@inheritDoc}
//      * @throws NullPointerException          {@inheritDoc}
//      * @throws IllegalArgumentException      {@inheritDoc}
//      * @throws IndexOutOfBoundsException     {@inheritDoc}
//      */
//     void add(int index, E element) {
//         try {
//             listIterator(index).add(element);
//         } catch (NoSuchElementException exc) {
//             throw new IndexOutOfBoundsException("Index: " ~ index.to!string);
//         }
//     }

//     /**
//      * Removes the element at the specified position in this list (optional
//      * operation).  Shifts any subsequent elements to the left (subtracts one
//      * from their indices).  Returns the element that was removed from the
//      * list.
//      *
//      * <p>This implementation first gets a list iterator pointing to the
//      * indexed element (with <tt>listIterator(index)</tt>).  Then, it removes
//      * the element with <tt>ListIterator.remove</tt>.
//      *
//      * <p>Note that this implementation will throw an
//      * <tt>UnsupportedOperationException</tt> if the list iterator does not
//      * implement the <tt>remove</tt> operation.
//      *
//      * @throws UnsupportedOperationException {@inheritDoc}
//      * @throws IndexOutOfBoundsException     {@inheritDoc}
//      */
//     E remove(int index) {
//         try {
//             ListIterator!E e = listIterator(index);
//             E outCast = e.next();
//             e.remove();
//             return outCast;
//         } catch (NoSuchElementException exc) {
//             throw new IndexOutOfBoundsException("Index: " ~ index.to!string);
//         }
//     }


//     // Bulk Operations

//     /**
//      * Inserts all of the elements in the specified collection into this
//      * list at the specified position (optional operation).  Shifts the
//      * element currently at that position (if any) and any subsequent
//      * elements to the right (increases their indices).  The new elements
//      * will appear in this list in the order that they are returned by the
//      * specified collection's iterator.  The behavior of this operation is
//      * undefined if the specified collection is modified while the
//      * operation is in progress.  (Note that this will occur if the specified
//      * collection is this list, and it's nonempty.)
//      *
//      * <p>This implementation gets an iterator over the specified collection and
//      * a list iterator over this list pointing to the indexed element (with
//      * <tt>listIterator(index)</tt>).  Then, it iterates over the specified
//      * collection, inserting the elements obtained from the iterator into this
//      * list, one at a time, using <tt>ListIterator.add</tt> followed by
//      * <tt>ListIterator.next</tt> (to skip over the added element).
//      *
//      * <p>Note that this implementation will throw an
//      * <tt>UnsupportedOperationException</tt> if the list iterator returned by
//      * the <tt>listIterator</tt> method does not implement the <tt>add</tt>
//      * operation.
//      *
//      * @throws UnsupportedOperationException {@inheritDoc}
//      * @throws ClassCastException            {@inheritDoc}
//      * @throws NullPointerException          {@inheritDoc}
//      * @throws IllegalArgumentException      {@inheritDoc}
//      * @throws IndexOutOfBoundsException     {@inheritDoc}
//      */
//     // bool addAll(int index, Collection<E> c) {
//     //     try {
//     //         bool modified = false;
//     //         ListIterator!E e1 = listIterator(index);
//     //         Iterator<E> e2 = c.iterator();
//     //         while (e2.hasNext()) {
//     //             e1.add(e2.next());
//     //             modified = true;
//     //         }
//     //         return modified;
//     //     } catch (NoSuchElementException exc) {
//     //         throw new IndexOutOfBoundsException("Index: " ~index);
//     //     }
//     // }


    // Iterators

}