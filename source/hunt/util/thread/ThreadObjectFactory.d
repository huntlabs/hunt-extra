module hunt.util.thread.ThreadObjectFactory;

import hunt.util.pool.ObjectFactory;

import hunt.logging.ConsoleLogger;
import hunt.util.thread.PooledThread;

import core.atomic;
import core.time;


/** 
 * 
 */
class ObjectFactoryOptions {
    Duration timeout = 5.seconds;
}

/**
 * 
 */
class ThreadObjectFactory : ObjectFactory!(PooledThread) {

    private shared static int idCounter = 0;
    private ObjectFactoryOptions _options;

    this(ObjectFactoryOptions options) {
        _options = options;
    }

    override PooledThread makeObject() {
        int id = atomicOp!("+=")(idCounter, 1) - 1;
        warningf("making thread %d", id);
        PooledThread r = new PooledThread(id, _options.timeout);
        r.start();

        return r;
    }    

    override void destroyObject(PooledThread p) {
        tracef("thread %s destroying", p.name);
        p.stop();
        p.join();
        tracef("thread %s destroyed", p.name);
    }

    override bool isValid(PooledThread p) {
		return p.state != PooledThreadState.Stopped;
    }
}