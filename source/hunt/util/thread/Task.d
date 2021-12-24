module hunt.util.thread.Task;

import hunt.logging;

import core.atomic;
import core.time;
import std.format;


enum TaskStatus : ubyte {
    Ready,
    Processing,
    Terminated,
    Done
}


/**
 * 
 */
abstract class Task {
    protected shared TaskStatus _status;

    private string _name;
    
    private MonoTime _createTime;
    private MonoTime _startTime;
    private MonoTime _endTime;

    this(string name) {
        _name = name;
        _status = TaskStatus.Ready;
        _createTime = MonoTime.currTime;
    }

    string name() {
        return _name;
    }

    Duration survivalTime() {
        return _endTime - _createTime;
    }

    Duration executionTime() {
        return _endTime - _startTime;
    }

    Duration lifeTime() {
        if(_endTime > _createTime) {
            return survivalTime();
        } else {
            return MonoTime.currTime - _createTime;
        }
    }

    TaskStatus status() {
        return _status;
    }

    bool isReady() {
        return _status == TaskStatus.Ready;
    }

    bool isProcessing() {
        return _status == TaskStatus.Processing;
    }

    bool isTerminated() {
        return _status == TaskStatus.Terminated;
    }

    bool isDone() {
        return _status == TaskStatus.Done;
    }

    void stop() {
        
        version(HUNT_POOL_DEBUG_MORE) {
            tracef("The task status: %s", _status);
        }

        if(!cas(&_status, TaskStatus.Processing, TaskStatus.Terminated) && 
            !cas(&_status, TaskStatus.Ready, TaskStatus.Terminated)) {
            version(HUNT_POOL_DEBUG) {
                warningf("The task [%s] stopped. The status is %s",  _name, _status);
            }
        }
    }

    void finish() {
        version(HUNT_POOL_DEBUG_MORE) {
            tracef("The status of task [%s]: %s", _name, _status);
        }

        if(cas(&_status, TaskStatus.Processing, TaskStatus.Done) || 
            cas(&_status, TaskStatus.Ready, TaskStatus.Done)) {
                
            _endTime = MonoTime.currTime;
            version(HUNT_POOL_DEBUG) {
                infof("The task [%s] done.", _name);
            }
        } else {
            version(HUNT_POOL_DEBUG) {
                warningf("Failed to set the status of task [%s] to Done: %s", _name, _status);
            }
        }
    }

    protected void doExecute();

    void execute() {
        if(cas(&_status, TaskStatus.Ready, TaskStatus.Processing)) {
            version(HUNT_POOL_DEBUG_MORE) {
                tracef("Task %s executing... status: %s", _name, _status);
            }
            _startTime = MonoTime.currTime;
            scope(exit) {
                finish();
                version(HUNT_POOL_DEBUG_MORE) {
                    infof("The task [%s] is done!", _name);
                }
            }

            try {
                doExecute();
            } catch(Throwable t) {
                warningf("task [%s] failed: %s", _name, t.msg);
                version(HUNT_POOL_DEBUG_MORE) {
                    warning(t);
                }
            }
        } else {
            warningf("Failed to execute task [%s]. Its status is: %s", _name, _status);
        }
    }

    override string toString() {
        return format("name: %s, status: %s", _name, _status);
    }

}

