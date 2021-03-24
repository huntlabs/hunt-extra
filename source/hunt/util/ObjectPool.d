module hunt.util.ObjectPool;

import hunt.logging.ConsoleLogger;

import core.atomic;
import core.sync.mutex;

import std.format;
import std.datetime;

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


abstract class ObjectFactory(T) {

    T makeObject();

    void destroyObject(T p) {
        version(HUNT_DEBUG) tracef("Do noting");
    }
}


class DefaultObjectFactory(T) : ObjectFactory!(T) {

    override T makeObject() {
        return new T();
    }

}


/**
 * Provides the possible states that a {@link PooledObject} may be in.
 *
 */
enum PooledObjectState {
    /**
     * In the queue, not in use.
     */
    IDLE,

    /**
     * In use.
     */
    ALLOCATED,

    // /**
    //  * In the queue, currently being tested for possible eviction.
    //  */
    // EVICTION,

    // /**
    //  * Not in the queue, currently being tested for possible eviction. An
    //  * attempt to borrow the object was made while being tested which removed it
    //  * from the queue. It should be returned to the head of the queue once
    //  * eviction testing completes.
    //  * TODO: Consider allocating object and ignoring the result of the eviction
    //  *       test.
    //  */
    // EVICTION_RETURN_TO_HEAD,

    /**
     * In the queue, currently being validated.
     */
    VALIDATION,

    // /**
    //  * Not in queue, currently being validated. The object was borrowed while
    //  * being validated and since testOnBorrow was configured, it was removed
    //  * from the queue and pre-allocated. It should be allocated once validation
    //  * completes.
    //  */
    // VALIDATION_PREALLOCATED,

    // /**
    //  * Not in queue, currently being validated. An attempt to borrow the object
    //  * was made while previously being tested for eviction which removed it from
    //  * the queue. It should be returned to the head of the queue once validation
    //  * completes.
    //  */
    // VALIDATION_RETURN_TO_HEAD,

    /**
     * Failed maintenance (e.g. eviction test or validation) and will be / has
     * been destroyed
     */
    INVALID,

    /**
     * Deemed abandoned, to be invalidated.
     */
    ABANDONED,

    /**
     * Returning to the pool.
     */
    RETURNING
}


/**
 * 
 */
class ObjectPool(T) {
    private ObjectFactory!(T) _factory;
    private PooledObject!(T)[] _pooledObjects;
    private Mutex _locker;

    this(size_t size) {
        this(new DefaultObjectFactory!(T)(), size);
    }

    this(ObjectFactory!(T) factory, size_t size) {
        _factory = factory;
        _pooledObjects = new PooledObject!(T)[size];
        _locker = new Mutex();
    }

    size_t size() {
        return _pooledObjects.length;
    }

    /**
     * Obtains an instance from this pool.
     * <p>
     * By contract, clients <strong>must</strong> return the borrowed instance
     * using {@link #returnObject}, {@link #invalidateObject}, or a related
     * method as defined in an implementation or sub-interface.
     * </p>
     * <p>
     * The behaviour of this method when the pool has been exhausted
     * is not strictly specified (although it may be specified by
     * implementations).
     * </p>
     *
     * @return an instance from this pool.
     */
    T borrow(bool isQuiet = false) {
        _locker.lock();
        scope(exit) {
            _locker.unlock();
        }

        PooledObject!(T) pooledObj;
        for(size_t index; index<_pooledObjects.length; index++) {
            pooledObj = _pooledObjects[index];
            if(pooledObj is null) {
                T underlyingObj = _factory.makeObject();
                pooledObj = new PooledObject!(T)(underlyingObj);
                _pooledObjects[index] = pooledObj;
                break;
            } else if(pooledObj.isIdle()) {
                break;
            }

            pooledObj = null;
        }
        
        if(pooledObj is null) {
            if(isQuiet) return T.init;
            else {
                throw new Exception("No object avaliable");
            }
        }
        
        pooledObj.allocate();
        tracef("borrowed: id=%d, createTime=%s", 
            pooledObj.id, pooledObj.createTime()); 
        return pooledObj.getObject();
    }

    // TODO: Tasks pending completion -@zhangxueping at 2021-03-21T16:02:17+08:00
    // 
    // T borrowAsync() {

    // }    

    /**
     * Returns an instance to the pool. By contract, <code>obj</code>
     * <strong>must</strong> have been obtained using {@link #borrowObject()} or
     * a related method as defined in an implementation or sub-interface.
     *
     * @param obj a {@link #borrowObject borrowed} instance to be returned.
     */
    void returnObject(T obj) {
        if(obj is null) {
            warning("Do nothing");
            return;
        }

        PooledObject!(T) pooledObj;
        for(size_t index; index<_pooledObjects.length; index++) {
            pooledObj = _pooledObjects[index];
            if(pooledObj is null) {
                continue;
            }
            
            T underlyingObj = pooledObj.getObject();
            if(underlyingObj is obj) {
                tracef("returning: id=%d, state=%s, count=%s, createTime=%s", 
                    pooledObj.id, pooledObj.state(), pooledObj.borrowedCount(), pooledObj.createTime()); 
                bool r = pooledObj.deallocate();
                if(r) {
                    infof("Returned: id=%d", pooledObj.id);
                } else {
                    warningf("Return failed: id=%d", pooledObj.id);
                }
                break;
            }
        }
    } 


    /**
     * Returns the number of instances currently idle in this pool. This may be
     * considered an approximation of the number of objects that can be
     * {@link #borrowObject borrowed} without creating any new instances.
     * Returns a negative value if this information is not available.
     * @return the number of instances currently idle in this pool.
     */
    size_t getNumIdle() {
        size_t count = 0;

        foreach(PooledObject!(T) obj; _pooledObjects) {
            if(obj is null || obj.isIdle()) {
                count++;
            } 
        }

        return count;
    }

    /**
     * Returns the number of instances currently borrowed from this pool. Returns
     * a negative value if this information is not available.
     * @return the number of instances currently borrowed from this pool.
     */
    size_t getNumActive() {
        size_t count = 0;

        foreach(PooledObject!(T) obj; _pooledObjects) {
            if(obj !is null && obj.isInUse()) {
                count++;
            } 
        }

        return count;        
    }

    /**
     * Clears any objects sitting idle in the pool, releasing any associated
     * resources (optional operation). Idle objects cleared must be
     * {@link PooledObjectFactory#destroyObject(PooledObject)}.
     *
     * @throws Exception if the pool cannot be cleared
     */
    void clear() {
        
        warning("TODO");
    }

    /**
     * Closes this pool, and free any resources associated with it.
     * <p>
     * Calling {@link #borrowObject} after invoking this
     * method on a pool will cause them to throw an {@link IllegalStateException}.
     * </p>
     * <p>
     * Implementations should silently fail if not all resources can be freed.
     * </p>
     */
    void close() {
        version(HUNT_DEBUG) {
            info("Pool is closing...");
        }

        _locker.lock();
        scope(exit) {
            _locker.unlock();
        }

        for(size_t index; index<_pooledObjects.length; index++) {
            PooledObject!(T) obj = _pooledObjects[index];

            if(obj !is null) {
                _pooledObjects[index] = null;
                obj.abandoned();
                _factory.destroyObject(obj.getObject());
            }
        }

    }

    override string toString() {
        string str = format("Total: %d, Active: %d, Idle: %d", 
                size(), getNumActive(),  getNumIdle());
        return str;
    }
}