module hunt.util.pool.ObjectPool;

import hunt.concurrency.Future;
import hunt.concurrency.Promise;
import hunt.concurrency.FuturePromise;
import hunt.logging.ConsoleLogger;

import core.sync.mutex;

import std.container.dlist;
import core.time;
import std.format;
import std.range : walkLength;

import hunt.util.pool.ObjectFactory;
import hunt.util.pool.PooledObject;

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
    CreationMode creationMode = CreationMode.Lazy;
}


/**
 * 
 */
class ObjectPool(T) {
    private ObjectFactory!(T) _factory;
    private PooledObject!(T)[] _pooledObjects;
    private Mutex _locker;
    private DList!(FuturePromise!T) _waiters;
    private PoolOptions _poolOptions;

    this(PoolOptions options) {
        this(new DefaultObjectFactory!(T)(), options);
    }

    this(ObjectFactory!(T) factory, PoolOptions options) {
        _factory = factory;
        _poolOptions = options;
        _pooledObjects = new PooledObject!(T)[options.size];
        _locker = new Mutex();
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
        }
        return r;
    }    


    /**
     * 
     */
    Future!T borrowAsync() {
        _locker.lock();
        scope(exit) {
            _locker.unlock();
        }
        
        FuturePromise!T promise = new FuturePromise!T();

        if(_waiters.empty()) {
            T r = doBorrow();
            if(r is null) {
                _waiters.stableInsert(promise);
                version(HUNT_DEBUG) {
                    warningf("New waiter...%d", getNumWaiters());
                }
            } else {
                promise.succeeded(r);
            }
        } else {
            _waiters.stableInsert(promise);
            version(HUNT_DEBUG) {
                warningf("New waiter...%d", getNumWaiters());
            }
        }

        return promise;
    }

    /**
     * 
     */
    private T doBorrow() {
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
            version(HUNT_DEBUG) {
                warning("No idle object avaliable.");
            }
            return null;
        }
        
        pooledObj.allocate();

        version(HUNT_DEBUG) {
            infof("borrowed: id=%d, createTime=%s", 
                pooledObj.id, pooledObj.createTime()); 
        }
        return pooledObj.getObject();        
    }

    /**
     * Returns an instance to the pool. By contract, <code>obj</code>
     * <strong>must</strong> have been obtained using {@link #borrowObject()} or
     * a related method as defined in an implementation or sub-interface.
     *
     * @param obj a {@link #borrowObject borrowed} instance to be returned.
     */
    void returnObject(T obj) {
        if(obj is null) {
            version(HUNT_DEBUG) warning("Do nothing for a null object");
            return;
        }

        scope(exit) {
            _locker.lock();
            scope(exit) {
                _locker.unlock();
            }
            handleWaiters();
        }

        doReturning(obj);
    } 

    private bool doReturning(T obj) {
        bool result = false;

        PooledObject!(T) pooledObj;
        for(size_t index; index<_pooledObjects.length; index++) {
            pooledObj = _pooledObjects[index];
            if(pooledObj is null) {
                continue;
            }
            
            T underlyingObj = pooledObj.getObject();
            if(underlyingObj is obj) {
                version(HUNT_DEBUG_MORE) {
                    tracef("returning: id=%d, state=%s, count=%s, createTime=%s", 
                        pooledObj.id, pooledObj.state(), pooledObj.borrowedCount(), pooledObj.createTime()); 
                }
                    
                // pooledObj.returning();
                result = pooledObj.deallocate();
                version(HUNT_DEBUG) {
                    if(result) {
                        infof("Returned: id=%d", pooledObj.id);
                    } else {
                        warningf("Return failed: id=%d", pooledObj.id);
                    }
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
        if(_waiters.empty())
            return;
        
        FuturePromise!T waiter = _waiters.front();

        // clear up all the finished waiter
        while(waiter.isDone()) {
            _waiters.removeFront();
            if(_waiters.empty()) {
                return;
            }

            waiter = _waiters.front();
        }

        // 
        T r = doBorrow();
        if(r is null) {
            warning("No idle object avaliable for waiter");
        } else {
            _waiters.removeFront();
            try {
                waiter.succeeded(r);
            } catch(Exception ex) {
                warning(ex);
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
        string str = format("Total: %d, Active: %d, Idle: %d, Waiters: %d", 
                size(), getNumActive(),  getNumIdle(), getNumWaiters());
        return str;
    }
}