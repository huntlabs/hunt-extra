module hunt.util.thread.Task;

import hunt.logging.ConsoleLogger;

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
        
        version(HUNT_DEBUG_MORE) {
            tracef("The task status: %s", _status);
        }

        if(!cas(&_status, TaskStatus.Processing, TaskStatus.Terminated) && 
            !cas(&_status, TaskStatus.Ready, TaskStatus.Terminated)) {
            version(HUNT_DEBUG_MORE) {
                warningf("The task status: %s", _status);
            }
        }
    }

    void finish() {
        version(HUNT_DEBUG_MORE) {
            tracef("The task [%s] status: %s", _name, _status);
        }

        if(cas(&_status, TaskStatus.Processing, TaskStatus.Done) || 
            cas(&_status, TaskStatus.Ready, TaskStatus.Done)) {
                
            _endTime = MonoTime.currTime;
            version(HUNT_DEBUG_MORE) {
                infof("The task [%s] done.", _name);
            }
        } else {
            version(HUNT_DEBUG_MORE) {
                warningf("The task [%s] status is %s", _name, _status);
                warningf("Failed to set the task status to Done: %s", _status);
            }
        }
    }

    protected void doExecute();

    void execute() {
        if(cas(&_status, TaskStatus.Ready, TaskStatus.Processing)) {
            version(HUNT_DEBUG_MORE) {
                tracef("Task %s executing... status: %s", _name, _status);
            }
            _startTime = MonoTime.currTime;
            scope(exit) {
                finish();
                version(HUNT_DEBUG_MORE) {
                    infof("Task [%s] Done!", _name);
                }
            }
            doExecute();
        } else {
            warningf("Failed to execute task [%s]. Its status is: %s", _name, _status);
        }
    }

    override string toString() {
        return format("name: %s, status: %s", _name, _status);
    }

}

