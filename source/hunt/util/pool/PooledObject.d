module hunt.util.pool.PooledObject;

import core.atomic;
import std.datetime;

import hunt.util.pool.PooledObjectState;

/**
 * Defines the wrapper that is used to track the additional information, such as
 * state, for the pooled objects.
 * <p>
 * Implementations of this class are required to be thread-safe.
 *
 * @param <T> the type of object in the pool
 *
 */
class PooledObject(T) {
    private size_t _id;
    private T _obj;
    private PooledObjectState _state;
    private SysTime _createTime;
    private SysTime _lastBorrowTime;
    private SysTime _lastUseTime;
    private SysTime _lastReturnTime;
    private shared long _borrowedCount = 0;
    private static shared size_t _counter;

    this(T obj) {
        _obj = obj;
        _state = PooledObjectState.IDLE;
        _createTime = Clock.currTime;
        _id = atomicOp!("+=")(_counter, 1);
    }

    size_t id() {
        return _id;
    }

    /**
     * Obtains the underlying object that is wrapped by this instance of
     * {@link PooledObject}.
     *
     * @return The wrapped object
     */
    T getObject() {
        return _obj;
    }  

    SysTime createTime() {
        return _createTime;
    }    

    SysTime lastBorrowTime() {
        return _lastBorrowTime;
    }

    SysTime lastReturnTime() {
        return _lastReturnTime;
    }

    /**
     * Get the number of times this object has been borrowed.
     * @return The number of times this object has been borrowed.
     */
    long borrowedCount() {
        return _borrowedCount;
    }

    /**
     * Returns the state of this object.
     * @return state
     */
    PooledObjectState state() {
        return _state;
    }

    /**
     * Allocates the object.
     *
     * @return {@code true} if the original state was {@link PooledObjectState#IDLE IDLE}
     */
    bool allocate() {
        if (_state == PooledObjectState.IDLE) {
            _state = PooledObjectState.ALLOCATED;
            _lastBorrowTime = Clock.currTime;
            _lastUseTime = _lastBorrowTime;
            atomicOp!("+=")(_borrowedCount, 1);
            // if (logAbandoned) {
            //     borrowedBy.fillInStackTrace();
            // }
            return true;
        } 
        
        // else if (state == PooledObjectState.EVICTION) {
        //     // TODO Allocate anyway and ignore eviction test
        //     state = PooledObjectState.EVICTION_RETURN_TO_HEAD;
        //     return false;
        // }
        // TODO if validating and testOnBorrow == true then pre-allocate for
        // performance
        return false;        
    }

    /**
     * Deallocates the object and sets it {@link PooledObjectState#IDLE IDLE}
     * if it is currently {@link PooledObjectState#ALLOCATED ALLOCATED}.
     *
     * @return {@code true} if the state was {@link PooledObjectState#ALLOCATED ALLOCATED}
     */
    bool deallocate() {

        if (_state == PooledObjectState.ALLOCATED || _state == PooledObjectState.RETURNING) {
            _state = PooledObjectState.IDLE;
            _lastReturnTime = Clock.currTime;
            return true;
        }

        return false;
    }

    /**
     * Sets the state to {@link PooledObjectState#INVALID INVALID}
     */
    void invalidate() { // synchronized
        _state = PooledObjectState.INVALID;
    }


    /**
     * Marks the pooled object as abandoned.
     */
    void abandoned() { // synchronized
        _state = PooledObjectState.ABANDONED;
    }

    /**
     * Marks the object as returning to the pool.
     */
    void returning() { // synchronized
        _state = PooledObjectState.RETURNING;
    }

    bool isIdle() {
        return _state == PooledObjectState.IDLE;
    }

    bool isInUse() {
        return _state == PooledObjectState.ALLOCATED;
    }
}
