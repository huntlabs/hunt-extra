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

module hunt.text.Common;

import hunt.Exceptions;

import std.algorithm;
import std.exception;
import std.string;

bool equalsIgnoreCase(string s1, string s2) {
    return icmp(s1, s2) == 0;
}

bool equals(string s1, string s2) {
    return s1 == s2;
}

string substring(string s, int beginIndex, int endIndex = -1) {
    if (endIndex == -1)
        endIndex = cast(int) s.length;
    return s[beginIndex .. endIndex];
}

string substring(string s, ulong beginIndex, ulong endIndex = -1) {
    return substring(s, cast(int) beginIndex, cast(int) endIndex);
}

char charAt(string s, int i) nothrow {
    return s[i];
}

char charAt(string s, size_t i) nothrow {
    return s[i];
}

bool contains(string items, string item) {
    return items.canFind(item);
}

bool contains(T)(T[] items, T item) {
    return items.canFind(item);
}

int compareTo(string value, string another) {
    import std.algorithm.comparison;

    int len1 = cast(int) value.length;
    int len2 = cast(int) another.length;
    int lim = min(len1, len2);
    // char v1[] = value;
    // char v2[] = another.value;

    int k = 0;
    while (k < lim) {
        char c1 = value[k];
        char c2 = another[k];
        if (c1 != c2) {
            return c1 - c2;
        }
        k++;
    }
    return len1 - len2;
}

bool isEmpty(string str)
{
    return str.length == 0;
}