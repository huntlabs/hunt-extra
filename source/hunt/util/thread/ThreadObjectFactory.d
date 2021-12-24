module hunt.util.thread.ThreadObjectFactory;

import hunt.util.pool.ObjectFactory;

import hunt.logging;
import hunt.util.thread.PooledThread;

import core.atomic;
import core.time;


/** 
 * 
 */
class ThreadPoolOptions {
    Duration timeout = 5.seconds;
}

/**
 * 
 */
class ThreadObjectFactory : ObjectFactory!(PooledThread) {

    private shared static int idCounter = 0;
    private ThreadPoolOptions _options;

    this(ThreadPoolOptions options) {
        _options = options;
    }

    override PooledThread makeObject() {
        int id = atomicOp!("+=")(idCounter, 1) - 1;
        version(HUNT_POOL_DEBUG) tracef("making thread %d", id);
        PooledThread r = new PooledThread(id, _options.timeout);
        r.start();

        return r;
    }    

    override void destroyObject(PooledThread p) {
        version(HUNT_POOL_DEBUG) tracef("thread %s destroying", p.name);
        p.stop();
        p.join();
        version(HUNT_POOL_DEBUG) tracef("thread %s destroyed", p.name);
    }

    override bool isValid(PooledThread p) {
		return p.state != PooledThreadState.Stopped;
    }
}