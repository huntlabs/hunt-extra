module test.PromiseTest;

import hunt.logging.ConsoleLogger;
import hunt.util.UnitTest;

import hunt.concurrency.FuturePromise;
import hunt.concurrency.Promise;

import core.thread;
import core.time;

import std.conv;
import std.parallelism;

class PromiseTest {
    void testBasic() {
        FuturePromise!int promise = new FuturePromise!int();

        
        auto t2 = task(&doSomething, promise);
        taskPool.put(t2);

        int r = promise.get();

        tracef("Thre result is %d", r);
         
    }

    void testThen() {
        FuturePromise!int promise = new FuturePromise!int();

        FuturePromise!string stringPromise = promise.then(&intToString);
        
        auto t2 = task(&doSomething, promise);
        taskPool.put(t2);

        string r = stringPromise.get();

        tracef("Thre result is => %s", r);
         
    }  

    private string intToString(int value)   {
        return "converted value: " ~ value.to!string();
    }

    private void doSomething(FuturePromise!int promise) {

        Thread.sleep(3.seconds);

        promise.succeeded(12);
        // promise.failed(new Exception("a test exception"));
    }

    void testVoidThen1() {
        FuturePromise!void promise = new FuturePromise!void();

        FuturePromise!string stringPromise = promise.then(&voidToString);
        
        auto t2 = task(&doSomething1, promise);
        taskPool.put(t2);

        string r = stringPromise.get(10.seconds);

        tracef("Thre result is => %s", r);
    } 

    private string voidToString()   {
        return "converted value: void";
    }

    private void doSomething1(FuturePromise!void promise) {

        Thread.sleep(3.seconds);

        promise.succeeded();
        // promise.failed(new Exception("a test exception"));
    }

    void testVoidThen2() {
        FuturePromise!int promise = new FuturePromise!int();

        FuturePromise!void stringPromise = promise.then(&intToVoid);
        
        auto t2 = task(&doSomething, promise);
        taskPool.put(t2);

        stringPromise.get(10.seconds);
    } 

    private void intToVoid(int value)   {
        trace("converted value: " ~ value.to!string());
    } 
}