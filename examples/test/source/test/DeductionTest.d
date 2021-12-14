module test.DeductionTest;

import common;
import hunt.logging.ConsoleLogger;
import hunt.util.Traits;

import std.conv;
import std.traits;

class DeductionTest {

    void testArray() {
        ubyte[] data;
        // deduce!(ubyte[], CaseSensitive.no)(data);

        // {
        //     GreetingBase[] greetings;
        //     deduce(greetings);
        // }

        // {
        //     GreetingBase[][] greetings;
        //     deduce(greetings);
        // }

        // {
        //     GreetingBase[string][] greetings;
        //     deduce(greetings);
        // }

        {
            GreetingBase[2] greetings;
            deduce(greetings);
        }        
    }

    // void testConstructor() {
    //     Class1 class1;
    //     deduce(class1);

    //     Exception ex;
    //     deduce(ex);
    // }

 

    // void test2() {
    //     assert(isByteArray!(ubyte[]));
    //     assert(!isByteArray!(int[]));
    // }
}

import std.typecons;

/**
   Flag indicating whether a search is case-sensitive.
*/
alias CaseSensitive = Flag!"caseSensitive";


void deduce(T, CaseSensitive sensitive = CaseSensitive.yes)(T v) { // if(!is(T == class)) 
    trace(sensitive);


    static if(is(T : U[], U)) {
        tracef("T[], T: %s, U: %s", T.stringof, U.stringof);


        static if(is(U : S[], S)) {
            infof("T[][], T: %s, U: %s, S: %s", T.stringof, U.stringof, S.stringof);
        }


        static if(is(U : S[K], S, K)) {
            infof("T[][], T: %s, U: %s, S: %s, K: %s", T.stringof, U.stringof, S.stringof, K.stringof);
        }

        static if(isStaticArray!(T)) {
            infof("T[]: %s[%d]", U.stringof, T.length);
        }
    }


    // static if(is(T : U[], U) && is(U : S[], S)) {
    //     infof("T[][], T: %s, U: %s, S: %s", T.stringof, U.stringof, S.stringof);
    // }

    // static if(is(T : S[][], S)) {
    //     infof("T[][], T: %s, S: %s", T.stringof, S.stringof);
    // }


    static if(isBuiltinType!T) {
        tracef("isBuiltinType: %s", T.stringof);
    }

    static if(is(T == class)) {
        static if(is(typeof(new T()))) {
            tracef("class: %s, with this()", T.stringof);
        } else {
            tracef("class: %s, without this()", T.stringof);
        }
    }

}

// void deduce(T)(T v) if(is(T == class)) {

//     static if(is(typeof(new T()))) {
//         tracef("class: %s, with this()", T.stringof);
//     } else {
//         tracef("class: %s, without this()", T.stringof);
//     }
// }

// void deduce(T : U[], U)(T v) if(is(U == class)) {
//     infof("Array, T: %s, U: %s", T.stringof, U.stringof);
// }

// void deduce(T)(T v) if(is(T : U[], U) && is(U == interface)) {
//     static if(is(T : U[], U)) {
//         tracef("T: %s, U: %s", T.stringof, U.stringof);
//     }

// }

class Class1 {
    @disable this() {

    }

    this(int id, string v) {

    }
}

