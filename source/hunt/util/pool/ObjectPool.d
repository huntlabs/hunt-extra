module hunt.util.pool.ObjectPool;

import hunt.concurrency.Future;
import hunt.concurrency.Promise;
import hunt.concurrency.FuturePromise;
import hunt.logging.ConsoleLogger;

import core.atomic;
import core.sync.mutex;
import core.time;

import std.container.dlist;
import std.conv;
import std.format;
import std.range : walkLength;

import hunt.util.pool.ObjectFactory;
import hunt.util.pool.PooledObject;
import hunt.util.pool.PooledObjectState;

/**
 * 
 */
enum CreationMode {
    Lazy,
    Eager
}

/**
 * 
 */
class PoolOptions {
    size_t size = 5;
    int maxWaitQueueSize = -1;
    string name;
    CreationMode creationMode = CreationMode.Lazy;
}


enum ObjectPoolState {
    Open,
    Closing,
    Closed
}

/**
 * 
 */
class ObjectPool(T) {

    private PoolOptions _poolOptions;
    private shared ObjectPoolState _state = ObjectPoolState.Open;
    private shared bool _isClearing = false;
    private ObjectFactory!(T) _factory;
    private PooledObject!(T)[] _pooledObjects;
    private Mutex _locker;
    // private Mutex _pooledObjectsLocker;
    private DList!(FuturePromise!T) _waiters;

    static if(is(T == class) && __traits(compiles, new T())) {
        this(PoolOptions options) {
            this(new DefaultObjectFactory!(T)(), options);
        } 
    }

    this(ObjectFactory!(T) factory, PoolOptions options) {
        _factory = factory;
        _poolOptions = options;
        _pooledObjects = new PooledObject!(T)[options.size];
        // _pooledObjectsLocker = new Mutex();
        _locker = new Mutex();
    }

    ObjectPoolState state() {
        return _state;
    }

    size_t size() {
        return _poolOptions.size;
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
    T borrow(Duration timeout = 10.seconds, bool isQuiet = true) {
        T r;
        if(timeout == Duration.zero) {
            _locker.lock();
            scope(exit) {
                _locker.unlock();
            }

            r = doBorrow();
            if(r is null && !isQuiet) {
                throw new Exception("No idle object avaliable.");
            }
        } else {
            Future!T future = borrowAsync();
            if(timeout.isNegative()) {
                r = future.get();
            } else {
                r = future.get(timeout);
            }

            version(HUNT_POOL_DEBUG_MORE) {
                tracef("Borrowed {%s} from promise [%s]", r.to!string(), (cast(FuturePromise!T)future).id());
            }
        }
        

        return r;
    }    


    /**
     * 
     */
    Future!T borrowAsync() {
        // trace("Borrowing...");
        
        _locker.lock();
        scope(exit) {
            // trace("Borrowing done...");
            _locker.unlock();
        }
        
        import std.conv;
        FuturePromise!T promise = new FuturePromise!T("PoolWaiter " ~ _waiterNumber.to!string());
        _waiterNumber++;

        if(_waiters.empty()) {
            version (HUNT_POOL_DEBUG_MORE) tracef("Borrowing for promise [%s]", promise.id());

            T r = doBorrow();
            if(r is null) {
                version(HUNT_POOL_DEBUG_MORE) {
                    warningf("Pool: %s, new waiter with %s...%d", _poolOptions.name, promise.id(), getNumWaiters());
                }
                _waiters.stableInsert(promise);
            } else {
                bool isSucceeded = false;
                try {
                    isSucceeded = promise.succeeded(r);
                } catch(Throwable ex) {
                    warning(ex);
                }

                if(isSucceeded) {
                    version(HUNT_POOL_DEBUG_MORE) {
                        tracef("Borrowed a result for promise %s with %s", promise.id(), (cast(Object)r).toString());
                    }
                } else {
                    warningf("Failed to set the result for promise %s with %s", promise.id(), (cast(Object)r).toString());
                    doReturning(r);
                }
            }
        } else {
            version(HUNT_POOL_DEBUG_MORE) {
                warningf("Pool: %s, new waiter with %s...%d", _poolOptions.name, promise.id(), getNumWaiters());
            }

            size_t number = getNumWaiters();
            if(_poolOptions.maxWaitQueueSize == -1 || number < _poolOptions.maxWaitQueueSize) {
                _waiters.stableInsert(promise);
            } else {
                string msg = format("Reach to the max WaitNumber (%d), the current: %d", _poolOptions.maxWaitQueueSize, number);
                version(HUNT_DEBUG) {
                    warning(msg);
                }
                promise.failed(new Exception(msg));
                
                // _waiters.stableInsert(promise);
            }
        }

        return promise;
    }

    private int _waiterNumber = 0;

    /**
     * 
     */
    private T doBorrow() {
        // _pooledObjectsLocker.lock();
        // scope(exit) {
        //     _pooledObjectsLocker.unlock();
        // }

        PooledObject!(T) pooledObj;
        
        size_t index = 0;

        for(; index<_pooledObjects.length; index++) {
            pooledObj = _pooledObjects[index];

            if(pooledObj is null) {
                T underlyingObj = _factory.makeObject();
                pooledObj = new PooledObject!(T)(underlyingObj);
                _pooledObjects[index] = pooledObj;
                break;
            } else if(pooledObj.isIdle()) {
                T underlyingObj = pooledObj.getObject();
                bool isValid = _factory.isValid(underlyingObj);
                if(!isValid) {
                    pooledObj.invalidate();
                    version(HUNT_POOL_DEBUG) {
                        warningf("An invalid object (id=%d) detected at slot %d.", pooledObj.id, index);
                    }
                    _factory.destroyObject(underlyingObj);
                    underlyingObj = _factory.makeObject();
                    pooledObj = new PooledObject!(T)(underlyingObj);
                    _pooledObjects[index] = pooledObj;
                }
                break;
            } else if(pooledObj.isInvalid()) {
                T underlyingObj = pooledObj.getObject();
                version(HUNT_POOL_DEBUG) {
                    warningf("An invalid object (id=%d) detected at slot %d.", pooledObj.id, index);
                }
                _factory.destroyObject(underlyingObj);
                underlyingObj = _factory.makeObject();
                pooledObj = new PooledObject!(T)(underlyingObj);
                _pooledObjects[index] = pooledObj;
                break;
            }

            pooledObj = null;
        }
        
        if(pooledObj is null) {
            version(HUNT_DEBUG) {
                warningf("Failed to borrow. pool status = {%s}",  toString());
            }
            return null;
        }
        
        version(HUNT_POOL_DEBUG) {
            tracef("borrowed: slot[%d] => {%s}", index, pooledObj.toString());
        }

        bool r = pooledObj.allocate();
        if(r) {
            T result = pooledObj.getObject(); 
            version(HUNT_POOL_DEBUG) {
                infof("allocate: %s, borrowed: {%s}", r, pooledObj.toString()); 
            }
            return result;
        } else {
            warningf("Borrowing collision: slot[%d]", index, pooledObj.toString());
            return null;
        }
    }

    /**
     * Returns an instance to the pool. By contract, <code>obj</code>
     * <strong>must</strong> have been obtained using {@link #borrowObject()} or
     * a related method as defined in an implementation or sub-interface.
     *
     * @param obj a {@link #borrowObject borrowed} instance to be returned.
     */
    void returnObject(T obj) {
        if(obj !is null) {
            doReturning(obj);
        }

        handleWaiters();
    } 

    private bool doReturning(T obj) {
        // _pooledObjectsLocker.lock();
        // scope(exit) {
        //     _pooledObjectsLocker.unlock();
        // }

        bool result = false;

        PooledObject!(T) pooledObj;
        for(size_t index; index<_pooledObjects.length; index++) {
            pooledObj = _pooledObjects[index];
            if(pooledObj is null) {
                continue;
            }
            
            T underlyingObj = pooledObj.getObject();
            if(underlyingObj is obj) {
                version(HUNT_POOL_DEBUG_MORE) {
                    tracef("Pool: %s, slot: %d, returning: {%s}", _poolOptions.name, index, pooledObj.toString()); 
                }
                    
                result = pooledObj.returning();
                
                if(result) {
                    version(HUNT_DEBUG) {
                        tracef("Pool: %s; slot: %d, Returned: %s", 
                            _poolOptions.name, index, pooledObj.toString());
                    }
                } else {
                    errorf("Pool: %s, slot: %d, Return failed: {%s}", _poolOptions.name, index, pooledObj.toString());
                }
                break;
            }
        }

        version(HUNT_DEBUG) {
            info(toString());
        }
        return result;
    }

    private void handleWaiters() {

        if(_state == ObjectPoolState.Closing || _state == ObjectPoolState.Closed) {
            return;
        }

        if(_state != ObjectPoolState.Open) {
            warningf("Failed to query the waiters. The state is %s.", _state);
            return;
        }
  
        if(_waiters.empty()) {
            version(HUNT_POOL_DEBUG_MORE) warning("No waiter avaliable.");
            return;
        }

        bool lockResult = _locker.tryLock_nothrow();
        
        if(!lockResult) {
            warningf("Waiter-lock failed. Busy handling waiter");
            return;
        }

        if(lockResult) {
            _locker.unlock();
        }

        while(true) {
            FuturePromise!T waiter = _waiters.front();

            // Clear up all the finished waiter until a awaiting waiter found
            while(waiter.isDone()) {
                version(HUNT_DEBUG_MORE) tracef("Waiter %s is done, so removed.", waiter.id());
                _waiters.removeFront();
                if(_waiters.empty()) {
                    trace("No awaiting waiter found.");
                    return;
                }

                waiter = _waiters.front();
            } 

            version(HUNT_POOL_DEBUG) {
                tracef("Borrowing for promise [%s], isDone: %s", waiter.id(), waiter.isDone());
            }
            
            // 
            T r = doBorrow();
            if(r is null) {
                version(HUNT_POOL_DEBUG) warningf("No idle object avaliable for waiter [%s]", waiter.id());
                break;
            } 

            //
            try {

                if(!_waiters.empty()) {
                    _waiters.removeFront();
                }

                if(waiter.succeeded(r)) {
                    version(HUNT_POOL_DEBUG) {
                        tracef("Borrowed for promise [%s], result: %s", waiter.id(), r.toString());
                    }                    
                } else {
                    warningf("Failed to set the result for promise [%s] with %s", 
                        waiter.id(), (cast(Object)r).toString());

                    doReturning(r);
                }
            } catch(Throwable ex) {
                warning(ex);
                doReturning(r);
            }

            if(_waiters.empty()) {
                trace("No waiter found");
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
     * Returns an estimate of the number of threads currently blocked waiting for
     * an object from the pool. This is intended for monitoring only, not for
     * synchronization control.
     *
     * @return The estimate of the number of threads currently blocked waiting
     *         for an object from the pool
     */
    size_t getNumWaiters() {
        return walkLength(_waiters[]);
    }

    /**
     * Clears any objects sitting idle in the pool, releasing any associated
     * resources (optional operation). Idle objects cleared must be
     * {@link PooledObjectFactory#destroyObject(PooledObject)}.
     *
     * @throws Exception if the pool cannot be cleared
     */
    void clear() {
        version(HUNT_POOL_DEBUG) {
            infof("Pool [%s] is clearing...", _poolOptions.name);
        }

        bool r = cas(&_isClearing, false, true);
        if(!r) {
            return;
        }

        _locker.lock();
        scope(exit) {
            _isClearing = false;
            version(HUNT_POOL_DEBUG) infof("Pool [%s] is cleared...", _poolOptions.name);
            _locker.unlock();        
        }

        for(size_t index; index<_pooledObjects.length; index++) {
            PooledObject!(T) obj = _pooledObjects[index];

            if(obj !is null) {
                version(HUNT_POOL_DEBUG) {
                    tracef("clearing object: id=%d, slot=%d", obj.id, index);
                }

                _pooledObjects[index] = null;
                obj.abandoned();

                // TODO: It's better to run it asynchronously
                _factory.destroyObject(obj.getObject());
            }
        }
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
            // infof("Closing pool %s (state=%s)...", _poolOptions.name, _state);
            tracef(toString());
        }

        bool r = cas(&_state, ObjectPoolState.Open, ObjectPoolState.Closing);
        if(!r) {
            return;
        }

        scope(exit) {
            _state = ObjectPoolState.Closed;
            version(HUNT_POOL_DEBUG) {
                infof("Pool %s closed...", _poolOptions.name);
            }
        }

        for(size_t index; index<_pooledObjects.length; index++) {
            PooledObject!(T) obj = _pooledObjects[index];

            if(obj !is null) {
                version(HUNT_POOL_DEBUG) {
                    tracef("Pool: %s, destroying object: id=%d, slot=%d, state: %s", 
                        _poolOptions.name,  obj.id, index, obj.state());

                    if(obj.state() == PooledObjectState.ALLOCATED) {
                        warningf("binded obj: %s", obj.getObject().toString());
                    }
                }

                _pooledObjects[index] = null;
                obj.abandoned();

                // TODO: It's better to run it asynchronously
                _factory.destroyObject(obj.getObject());
            }
        }

    }

    override string toString() {
        string str = format("Name: %s, Total: %d, Active: %d, Idle: %d, Waiters: %d", 
                _poolOptions.name, size(), getNumActive(),  getNumIdle(), getNumWaiters());
        return str;
    }
}