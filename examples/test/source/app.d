import hunt.concurrency.thread;
import hunt.logging;
import hunt.system.Locale;
import hunt.system.Memory;
import hunt.system.TimeZone;
import hunt.util.Common;
import hunt.util.DateTime;
import hunt.util.UnitTest;

import test.AtomicTest;
import test.BigIntegerTest;
import test.ByteBufferTest;
import test.DeductionTest;
import test.JsonSerializerTest;
import test.LocaleTest;
import test.LinkedBlockingQueueTest;
import test.MagedQueueTest;
import test.MimeTypeTest;
import test.NullableTest;
import test.NumberTest;
import test.ObjectMappingTest;
import test.PathMatcherTest;
import test.PropertySetterTest;
import test.PromiseTest;
import test.ScheduledThreadPoolTest;
import test.SerializationTest;
import test.StringTokenizerTest;
import test.TaskPoolTest;
import test.ThreadPoolExecutorTest;
import test.ThreadTest;
import test.ConverterUtilsTest;

import common;
import core.thread;
import std.stdio;



import benchmark.LinkedBlockingQueueBench;


void main()
{
    writeln("Thread id: ", Thread.getThis().id);
    writeln("CPU: ", totalCPUs);
    writeln("Memory page: ", pageSize);
    writeln("TimeZone: ", getSystemTimeZoneId());
    writeln("Locale: ", Locale.getUserDefault());
    tracef("isDaemon: %s", Thread.getThis().isDaemon());

    // testClone();
    // testGetFieldValues();

    // trace(Locale.getUserUI());
    // trace(Locale.getSystemDefault());

    // testPropertySetter();

    // testUnits!(MagedQueueTest);

    // testUnits!(AtomicTest);
    // testUnits!(BigIntegerTest);


    // testUnits!(LocaleTest);
    // testUnits!(LinkedBlockingQueueTest);
    // testUnits!(MimeTypeTest);
    // testUnits!(NullableTest);
    // testUnits!(NumberTest);
    // // TODO: Tasks pending completion -@zxp at 2/28/2019, 5:45:41 PM
    // // 
    // // testUnits!(PathMatcherTest); 
    // testUnits!(StringTokenizerTest);
    // testUnits!(ThreadTest);

    // // These tests belown will block the test procession.

    // // LinkedBlockingQueueBench b = new LinkedBlockingQueueBench();
    // // b.bench();
    // testLockSupport01();

    // testUnits!(TaskPoolTest);
    // testUnits!(ScheduledThreadPoolTest);
    // testUnits!(ThreadPoolExecutorTest);
    // testUnits!(ConverterUtilsTest);
    testUnits!(DeductionTest);

    // testUnits!(JsonSerializerTest);
    // testUnits!(SerializationTest);
    // testUnits!(ObjectMappingTest);

    // testUnits!(ByteBufferTest);

    
    // testUnits!(PromiseTest);

}


void testLockSupport01() {
    Thread thread = Thread.getThis();  
    
    LockSupport.unpark(thread);  
    
    writeln("a");  
    LockSupport.park();  
    writeln("b");  
    LockSupport.park();  
    writeln("c");  
}