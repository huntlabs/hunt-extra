/*
 * Hunt - A refined core library for D programming language.
 *
 * Copyright (C) 2018-2019 HuntLabs
 *
 * Website: https://www.huntlabs.net/
 *
 * Licensed under the Apache-2.0 License.
 *
 */

module hunt.concurrency.FuturePromise;

import hunt.concurrency.Future;
import hunt.concurrency.Promise;

import hunt.Exceptions;
import hunt.logging.ConsoleLogger;

import core.atomic;
import core.thread;
import core.sync.mutex;
import core.sync.condition;

import std.format;
import std.datetime;

/**
 * 
 */
class FuturePromise(T) : Future!T, Promise!T {
	private shared bool _isCompleting = false;
	private bool _isCompleted = false;
	private Exception _cause;
	private string _id;
	private Mutex _waiterLocker;
	private Condition _waiterCondition;

	this() {
		_waiterLocker = new Mutex(this);
		_waiterCondition = new Condition(_waiterLocker);
	}

	string id() {
		return _id;
	}

	void id(string id) {
		_id = id;
	}

static if(is(T == void)) {
	
	/**
	 * TODO: 
	 * 	1) keep this operation atomic
	 * 	2) return a flag to indicate whether this option is successful.
	 */
	void succeeded() {
		if (cas(&_isCompleting, false, true)) {
			// _cause = COMPLETED;
			onCompleted();
		} else {
			warningf("This promise has been done, and can't be set again. cause: %s", 
				typeid(_cause));
		}
	}

} else {

	/**
	 * TODO: 
	 * 	1) keep this operation atomic
	 * 	2) return a flag to indicate whether this option is successful.
	 */
	void succeeded(T result) {
		if (cas(&_isCompleting, false, true)) {
			_result = result;
			onCompleted();
		} else {
			warning("This promise has been done, and can't be set again.");
		}
	}
	private T _result;
}

	/**
	 * TODO: 
	 * 	1) keep this operation atomic
	 * 	2) return a flag to indicate whether this option is successful.
	 */
	void failed(Exception cause) {
		if (cas(&_isCompleting, false, true)) {
			_cause = cause;	
			onCompleted();		
		} else {
			warningf("This promise has been done, and can't be set again. cause: %s", 
				typeid(_cause));
		}
	}

	bool cancel(bool mayInterruptIfRunning) {
		if (cas(&_isCompleting, false, true)) {
			static if(!is(T == void)) {
				_result = T.init;
			}
			_cause = new CancellationException("");
			onCompleted();
			return true;
		}
		return false;
	}

	private void onCompleted() {
		_waiterLocker.lock();
		_isCompleted = true;
		scope(exit) {
			_waiterLocker.unlock();
		}
		_waiterCondition.notifyAll();
	}

	bool isCancelled() {
		if (_isCompleted) {
			try {
				// _latch.await();
				// TODO: Tasks pending completion -@zhangxueping at 2019-12-26T15:18:42+08:00
				// 
			} catch (InterruptedException e) {
				throw new RuntimeException(e.msg);
			}
			return typeid(_cause) == typeid(CancellationException);
		}
		return false;
	}

	bool isDone() {
		return _isCompleted;
	}

	T get() {
		return get(-1.msecs);
	}

	T get(Duration timeout) {
		// waitting for the completion
		if(!_isCompleted) {
			_waiterLocker.lock();
			scope(exit) {
				_waiterLocker.unlock();
			}

			if(timeout.isNegative()) {
				version (HUNT_DEBUG) info("Waiting for a promise...");
				_waiterCondition.wait();
			} else {
				version (HUNT_DEBUG) {
					infof("Waiting for a promise in %s...", timeout);
				}
				bool r = _waiterCondition.wait(timeout);
				if(!r) {
					debug warningf("Timeout for a promise in %s...", timeout);
					if (cas(&_isCompleting, false, true)) {
						_isCompleted = true;
						_cause = new TimeoutException("Timeout in " ~ timeout.toString());
					}
				}
			}
			
			if(_cause is null) {
				version (HUNT_DEBUG) infof("Got a succeeded promise.");
			} else {
				version (HUNT_DEBUG) warningf("Got a failed promise: %s", typeid(_cause));
			}
		} 

		// succeeded
		if (_cause is null) {
			static if(is(T == void)) {
				return;
			} else {
				return _result;
			}
		}

		CancellationException c = cast(CancellationException) _cause;
		if (c !is null) {
			version(HUNT_DEBUG) info("A promise cancelled.");
			throw c;
		}
		
		debug warning("Get a exception in a promise: ", _cause.msg);
		version (HUNT_DEBUG) warning(_cause);
		throw new ExecutionException(_cause);
	}	

	override string toString() {
		static if(is(T == void)) {
			return format("FutureCallback@%x{%b, %b, void}", toHash(), _isCompleted, _cause is null);
		} else {
			return format("FutureCallback@%x{%b, %b, %s}", toHash(), _isCompleted, _cause is null, _result);
		}
	}
}
