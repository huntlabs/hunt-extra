module test.ThreadPoolTest;


import std.stdio;

import hunt.util.pool;
import hunt.util.thread;

import hunt.logging.ConsoleLogger;

import core.thread;

import core.atomic;
import core.memory;
import core.thread;
import core.sync.condition;
import core.sync.mutex;
import std.conv;
import std.format;


shared int requestCounter = 0;
shared int borrowedCounter = 0;
shared int succeededCounter = 0;
shared int failedCounter = 0;

enum PoolSize = 5;
enum ThreadTotal = 20;
enum RequestPerThread = 10;

enum Duration WaitTimeout = 5.seconds;
enum Duration TaskTime = 1.seconds;

__gshared bool isExiting = false;

// void main()
// {
    
//     // info("Start test in 5 seconds");
//     // Thread.sleep(5.seconds);

//     // singleThread();
    
//     mutltiThread();
// }

class ThreadPoolTest {
    void test() {
        // info("Start test in 5 seconds");
        // Thread.sleep(5.seconds);

        // singleThread();
        
        // mutltiThread();        
    }
}


void mutltiThread() {
    import std.parallelism;

    MonoTime startTime = MonoTime.currTime;

	ObjectFactoryOptions options = new ObjectFactoryOptions();
    options.timeout = WaitTimeout;

    ThreadObjectFactory factory = new ThreadObjectFactory(options);
    PoolOptions poolOptions = new PoolOptions();
    poolOptions.size = PoolSize;
    poolOptions.name = "ThreadPool";


    ThreadPool pool = new ThreadPool(factory, poolOptions);

    int[] number = new int[ThreadTotal];
    for(int index = 0; index<number.length; index++) {
        number[index] = index;
    }

    foreach (int index; parallel(number) ) {

        int current = index;
        for(size_t i=0; i< RequestPerThread; i++) {
            atomicOp!"+="(requestCounter, 1);
            
            string name = format("test%d[%d, %d]", (current*RequestPerThread + i), current, i);

            try {
                infof("Borrowing for task %s", name);
                PooledThread thread = pool.borrow(WaitTimeout);
                atomicOp!"+="(borrowedCounter, 1);
                
                thread.onTaskDone((thisThread, task) {
                    atomicOp!"+="(succeededCounter, 1);
                    infof("task [%s] done, status: %s, thread: {%s}", task.name(), task.status(), thisThread.toString());
                    pool.returnObject(thisThread);
                });

                infof("Borrowed {%s} for task %s", thread.toString(), name);
                thread.attatch(new TestTask(name));
            } catch(Exception ex) {
                atomicOp!"+="(failedCounter, 1);
                warningf("%s => %s", name, ex.msg);
                tracef("Pool: %s", pool.toString());
            }

            if(isExiting) break;
        }
    }

    MonoTime endTime = MonoTime.currTime;
    warningf("Press any key to close pool. Elapsed: %s", endTime - startTime);
    
    getchar();
    isExiting = true;
    warningf("%s", pool.toString());
    pool.close();
    warningf("%s", pool.toString());

    infof("Test done. Total: %d, borrowedCounter: %d, succeeded: %d, failed: %d", 
        requestCounter, borrowedCounter, succeededCounter, failedCounter);
}

void singleThread()
{
	ObjectFactoryOptions options = new ObjectFactoryOptions();
    options.timeout = 5.seconds;

    ThreadObjectFactory factory = new ThreadObjectFactory(options);
    PoolOptions poolOptions = new PoolOptions();
    poolOptions.size = 5;
    poolOptions.name = "ThreadPool";

    ThreadPool pool = new ThreadPool(factory, poolOptions);

    //
    PooledThread thread = pool.borrow(2.seconds);

    thread.onTaskDone((thisThread, task) {
        if(task is null) {
            warning("task is null");
        } else {
            tracef("task [%s] done, status: %s", task.name(), task.status());
        }
        pool.returnObject(thisThread);
        // pool.returnObject(null);
        // pool.returnObject(thread);
    });

    thread.attatch(new TestTask("test 1"));

    warning("Press any key to close pool");
    getchar();
    // pool.returnObject(thread);
    pool.close();

    info("test done");

}

class TestTask : Task {

	this(string name) {
		super(name);
	}

	override void doExecute() {
		// infof("Task [%s] is running.", name);
		Thread.sleep(TaskTime);
		infof("Task [%s] is done.", name);
	}
}

// private ThreadPool buildEventLoopPool() {
//     PoolOptions options = new PoolOptions();
//     options.size = 5;
//     options.name = "ThreadPool";

//     ThreadPool objPool = new ThreadPool(new ThreadObjectFactory(), options);
//     return objPool;
// }

/** Basic interface for all queues implemented here.
    Is an input and output range. 
*/
interface Queue(T) {
    /** Atomically put one element into the queue. */
    void enqueue(T t);

    /** Atomically take one element from the queue.
      Wait blocking or spinning. */
    T dequeue();

    /**
      If at least one element is in the queue,
      atomically take one element from the queue
      store it into e, and return true.
      Otherwise return false; */
    bool tryDequeue(out T e);
}

/** blocking multi-producer multi-consumer queue  */
class BlockingQueue(T) : Queue!T {
    private QueueNode!T head;
    private QueueNode!T tail;
    private Mutex head_lock;
    private Mutex tail_lock;
    private shared bool isWaking = false;

    /** Wait queue for waiting takes */
    private Condition notEmpty;
    private Duration _timeout;

    this(Duration timeout = 5.seconds) {
        auto n = new QueueNode!T();
        this.head = this.tail = n;
        this.head_lock = new Mutex();
        this.tail_lock = new Mutex();
        notEmpty = new Condition(head_lock);
        _timeout = timeout;
    }

    void enqueue(T t) {
        auto end = new QueueNode!T();
        this.tail_lock.lock();
        scope (exit)
            this.tail_lock.unlock();
        auto tl = this.tail;
        this.tail = end;
        tl.value = t;
        atomicFence();
        tl.nxt = end; // accessible to dequeue
        notEmpty.notify();
    }

    T dequeue() {
        this.head_lock.lock();
        scope (exit)
            this.head_lock.unlock();
        while (true) { // FIXME non-blocking!
            auto hd = this.head;
            auto scnd = hd.nxt;
            if (scnd !is null) {
                this.head = scnd;
                return hd.value;
            } else {
                if(isWaking)
                    return T.init;
                bool r = notEmpty.wait(_timeout);
                if(!r) return T.init;
            }
        }
        assert(0);
    }

    bool tryDequeue(out T e) {
        this.head_lock.lock();
        scope (exit)
            this.head_lock.unlock();
        auto hd = this.head;
        auto scnd = hd.nxt;
        if (scnd !is null) {
            this.head = scnd;
            e = hd.value;
            return true;
        }
        return false;
    }

    bool isEmpty() {
        return this.head.nxt is null;
    }

    void clear() {
        this.head_lock.lock();
        scope (exit)
            this.head_lock.unlock();
        
        auto n = new QueueNode!T();
        this.head = this.tail = n;
    }

    void wakeup() {
        if(cas(&isWaking, false, true))
            notEmpty.notify();
    }
}


