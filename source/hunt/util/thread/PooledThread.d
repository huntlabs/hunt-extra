module hunt.util.thread.PooledThread;

import hunt.Functions;
import hunt.logging;
import hunt.util.thread.Task;

import core.atomic;
// import core.memory;
import core.thread;
import core.sync.condition;
import core.sync.mutex;

import std.conv;
import std.format;


enum PooledThreadState {
    Idle,
    Busy, // occupied
    Stopped
}

alias PooledThreadHandler = Action2!(PooledThread, Task);

/** 
 * 
 */
class PooledThread : Thread {

    private shared PooledThreadState _state;
    private size_t _index;
    private Task _task;
    private Duration _timeout;

    private Condition _condition;
    private Mutex _mutex;

    private PooledThreadHandler _taskDoneHandler;

    this(size_t index, Duration timeout = 5.seconds, size_t stackSize = 0) {
        _index = index;
        _timeout = timeout;
        _state = PooledThreadState.Idle;
        _mutex = new Mutex();
        _condition = new Condition(_mutex);
        this.name = "PooledThread-" ~ _index.to!string();
        super(&run, stackSize);
    }

    void onTaskDone(PooledThreadHandler handler) {
        _taskDoneHandler = handler;
    }

    void stop() {
        version(HUNT_POOL_DEBUG_MORE) {
            infof("Stopping thread %s", this.name);
        }

        _mutex.lock();
        scope (exit) {
            version(HUNT_POOL_DEBUG_MORE) {
                infof("thread [%s] stopped", this.name);
            }
            _mutex.unlock();
        }
        _state = PooledThreadState.Stopped;
        _condition.notify();
    }

    bool isBusy() {
        return _state == PooledThreadState.Busy;
    }
    
    bool isIdle() {
        return _state == PooledThreadState.Idle;
    }

    PooledThreadState state() {
        return _state;
    }

    size_t index() {
        return _index;
    }

    Task task() {
        return _task;
    }

    bool attatch(Task task) {
        assert(task !is null);
        version(HUNT_POOL_DEBUG_MORE) {
            tracef("attatching task %s with thread %s (state: %s)", task.name, this.name, _state);
        }

        bool r = cas(&_state, PooledThreadState.Idle, PooledThreadState.Busy);

        if (r) {
            _mutex.lock();
            scope (exit) {
                version(HUNT_POOL_DEBUG) {
                    infof("task [%s] attatched with thread %s", task.name, this.name);
                }
                _mutex.unlock();
            }
            _task = task;
            _condition.notify();
            
        } else {
            string msg = format("Thread [%s] is unavailable. state: %s", this.name(), _state);
            warningf(msg);
            throw new Exception(msg);
        }

        return r;
    }

    private void run() nothrow {
        while (_state != PooledThreadState.Stopped) {

            try {
                doRun();
            } catch (Throwable ex) {
                warning(ex);
            } 

            version (HUNT_POOL_DEBUG_MORE) {
                tracef("%s Done. state: %s", this.name(), _state);
            }

            Task task = _task;
            if(_state != PooledThreadState.Stopped) {
                bool r = cas(&_state, PooledThreadState.Busy, PooledThreadState.Idle);
                version(HUNT_POOL_DEBUG_MORE) {
                    if(!r) {
                        warningf("Failed to set thread %s to Idle, its state is %s", this.name, _state);
                    }
                }
            }

            version(HUNT_POOL_DEBUG_MORE) tracef("Run done: %s", this.toString());
            _task = null;

            if(_taskDoneHandler !is null && task !is null) {
                try {
                    _taskDoneHandler(this, task);
                } catch(Throwable t) {
                    warning(t);
                }
            }
        }
        
        version (HUNT_POOL_DEBUG) {
            tracef("Thread [%s] stopped. State: %s", this.name(), _state);
        }
    }

    private bool _isWaiting = false;

    private void doRun() {
        _mutex.lock();
        
        Task task = _task;
        while(task is null && _state != PooledThreadState.Stopped) {
            bool r = _condition.wait(_timeout);
            task = _task;

            version(HUNT_POOL_DEBUG_MORE) {
                if(!r && _state == PooledThreadState.Busy) {
                    if(task is null) {
                        warningf("No task attatched on a busy thread %s in %s, task: %s", this.name, _timeout);
                    } else {
                        warningf("more tests need for this status, thread %s in %s", this.name, _timeout);
                    }
                }
            }
        }

        _mutex.unlock();

        if(task !is null) {
            version(HUNT_POOL_DEBUG) {
                tracef("Try to exeucte task [%s] in thread %s. task: %s", task.name, this.name, task.status);
            }
            task.execute();
        }
    }
    
    override string toString() {
        import std.format;
        string r = format("name: %s, state: %s", name, _state);
        Task task = _task;
        if(task !is null) {
            return r ~ ", task: " ~ task.toString();
        } else {
            return r;
        }
        
    }
}
