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

module hunt.Short;

import hunt.Byte;
import hunt.Nullable;
import hunt.Number;
import std.conv;
/**
 * The {@code Short} class wraps a value of primitive type {@code
 * short} in an object.  An object of type {@code Short} contains a
 * single field whose type is {@code short}.
 *
 * <p>In addition, this class provides several methods for converting
 * a {@code short} to a {@code string} and a {@code string} to a
 * {@code short}, as well as other constants and methods useful when
 * dealing with a {@code short}.
 *
 * @author  Nakul Saraiya
 * @author  Joseph D. Darcy
 * @see     java.lang.Number
 */
class Short : AbstractNumber!short /*implements Comparable<Short> */{

    /**
     * A constant holding the minimum value a {@code short} can
     * have, -2<sup>15</sup>.
     */
    enum  short   MIN_VALUE = -32768;

    /**
     * A constant holding the maximum value a {@code short} can
     * have, 2<sup>15</sup>-1.
     */
    enum  short   MAX_VALUE = 32767;

    /**
     * The {@code Class} instance representing the primitive type
     * {@code short}.
     */
    // @SuppressWarnings("unchecked")
    // static  Class<Short>    TYPE = (Class<Short>) Class.getPrimitiveClass("short");

    /**
     * Returns a new {@code string} object representing the
     * specified {@code short}. The radix is assumed to be 10.
     *
     * @param s the {@code short} to be converted
     * @return the string representation of the specified {@code short}
     * @see java.lang.Integer#toString(int)
     */
    static string toString(short s) {
        return to!string(s);
    }

    /**
     * Parses the string argument as a signed {@code short} in the
     * radix specified by the second argument. The characters in the
     * string must all be digits, of the specified radix (as
     * determined by whether {@link java.lang.Character#digit(char,
     * int)} returns a nonnegative value) except that the first
     * character may be an ASCII minus sign {@code '-'}
     * ({@code '\u005Cu002D'}) to indicate a negative value or an
     * ASCII plus sign {@code '+'} ({@code '\u005Cu002B'}) to
     * indicate a positive value.  The resulting {@code short} value
     * is returned.
     *
     * <p>An exception of type {@code NumberFormatException} is
     * thrown if any of the following situations occurs:
     * <ul>
     * <li> The first argument is {@code null} or is a string of
     * length zero.
     *
     * <li> The radix is either smaller than {@link
     * java.lang.Character#MIN_RADIX} or larger than {@link
     * java.lang.Character#MAX_RADIX}.
     *
     * <li> Any character of the string is not a digit of the
     * specified radix, except that the first character may be a minus
     * sign {@code '-'} ({@code '\u005Cu002D'}) or plus sign
     * {@code '+'} ({@code '\u005Cu002B'}) provided that the
     * string is longer than length 1.
     *
     * <li> The value represented by the string is not a value of type
     * {@code short}.
     * </ul>
     *
     * @param s         the {@code string} containing the
     *                  {@code short} representation to be parsed
     * @param radix     the radix to be used while parsing {@code s}
     * @return          the {@code short} represented by the string
     *                  argument in the specified radix.
     * @throws          NumberFormatException If the {@code string}
     *                  does not contain a parsable {@code short}.
     */
    // static short parseShort(string s, int radix)
    //     throws NumberFormatException {
    //     int i = Integer.parseInt(s, radix);
    //     if (i < MIN_VALUE || i > MAX_VALUE)
    //         throw new NumberFormatException(
    //             "Value out of range. Value:\"" ~ s ~ "\" Radix:" ~ radix);
    //     return (short)i;
    // }

    /**
     * Parses the string argument as a signed decimal {@code
     * short}. The characters in the string must all be decimal
     * digits, except that the first character may be an ASCII minus
     * sign {@code '-'} ({@code '\u005Cu002D'}) to indicate a
     * negative value or an ASCII plus sign {@code '+'}
     * ({@code '\u005Cu002B'}) to indicate a positive value.  The
     * resulting {@code short} value is returned, exactly as if the
     * argument and the radix 10 were given as arguments to the {@link
     * #parseShort(java.lang.string, int)} method.
     *
     * @param s a {@code string} containing the {@code short}
     *          representation to be parsed
     * @return  the {@code short} value represented by the
     *          argument in decimal.
     * @throws  NumberFormatException If the string does not
     *          contain a parsable {@code short}.
     */
    // static short parseShort(string s) throws NumberFormatException {
    //     return parseShort(s, 10);
    // }

    /**
     * Returns a {@code Short} object holding the value
     * extracted from the specified {@code string} when parsed
     * with the radix given by the second argument. The first argument
     * is interpreted as representing a signed {@code short} in
     * the radix specified by the second argument, exactly as if the
     * argument were given to the {@link #parseShort(java.lang.string,
     * int)} method. The result is a {@code Short} object that
     * represents the {@code short} value specified by the string.
     *
     * <p>In other words, this method returns a {@code Short} object
     * equal to the value of:
     *
     * <blockquote>
     *  {@code new Short(Short.parseShort(s, radix))}
     * </blockquote>
     *
     * @param s         the string to be parsed
     * @param radix     the radix to be used in interpreting {@code s}
     * @return          a {@code Short} object holding the value
     *                  represented by the string argument in the
     *                  specified radix.
     * @throws          NumberFormatException If the {@code string} does
     *                  not contain a parsable {@code short}.
     */
    // static Short valueOf(string s, int radix)
    //     throws NumberFormatException {
    //     return valueOf(parseShort(s, radix));
    // }

    /**
     * Returns a {@code Short} object holding the
     * value given by the specified {@code string}. The argument
     * is interpreted as representing a signed decimal
     * {@code short}, exactly as if the argument were given to
     * the {@link #parseShort(java.lang.string)} method. The result is
     * a {@code Short} object that represents the
     * {@code short} value specified by the string.
     *
     * <p>In other words, this method returns a {@code Short} object
     * equal to the value of:
     *
     * <blockquote>
     *  {@code new Short(Short.parseShort(s))}
     * </blockquote>
     *
     * @param s the string to be parsed
     * @return  a {@code Short} object holding the value
     *          represented by the string argument
     * @throws  NumberFormatException If the {@code string} does
     *          not contain a parsable {@code short}.
     */
    // static Short valueOf(string s) throws NumberFormatException {
    //     return valueOf(s, 10);
    // }

    // private static class ShortCache {
    //     private ShortCache(){}

    //     static  Short cache[] = new Short[-(-128) + 127 + 1];

    //     static {
    //         for(int i = 0; i < cache.length; i++)
    //             cache[i] = new Short((short)(i - 128));
    //     }
    // }

    /**
     * Returns a {@code Short} instance representing the specified
     * {@code short} value.
     * If a new {@code Short} instance is not required, this method
     * should generally be used in preference to the constructor
     * {@link #Short(short)}, as this method is likely to yield
     * significantly better space and time performance by caching
     * frequently requested values.
     *
     * This method will always cache values in the range -128 to 127,
     * inclusive, and may cache other values outside of this range.
     *
     * @param  s a short value.
     * @return a {@code Short} instance representing {@code s}.
     */
    // static Short valueOf(short s) {
    //      int offset = 128;
    //     int sAsInt = s;
    //     if (sAsInt >= -128 && sAsInt <= 127) { // must cache
    //         return ShortCache.cache[sAsInt + offset];
    //     }
    //     return new Short(s);
    // }

    /**
     * Decodes a {@code string} into a {@code Short}.
     * Accepts decimal, hexadecimal, and octal numbers given by
     * the following grammar:
     *
     * <blockquote>
     * <dl>
     * <dt><i>DecodableString:</i>
     * <dd><i>Sign<sub>opt</sub> DecimalNumeral</i>
     * <dd><i>Sign<sub>opt</sub></i> {@code 0x} <i>HexDigits</i>
     * <dd><i>Sign<sub>opt</sub></i> {@code 0X} <i>HexDigits</i>
     * <dd><i>Sign<sub>opt</sub></i> {@code #} <i>HexDigits</i>
     * <dd><i>Sign<sub>opt</sub></i> {@code 0} <i>OctalDigits</i>
     *
     * <dt><i>Sign:</i>
     * <dd>{@code -}
     * <dd>{@code +}
     * </dl>
     * </blockquote>
     *
     * <i>DecimalNumeral</i>, <i>HexDigits</i>, and <i>OctalDigits</i>
     * are as defined in section 3.10.1 of
     * <cite>The Java&trade; Language Specification</cite>,
     * except that underscores are not accepted between digits.
     *
     * <p>The sequence of characters following an optional
     * sign and/or radix specifier ("{@code 0x}", "{@code 0X}",
     * "{@code #}", or leading zero) is parsed as by the {@code
     * Short.parseShort} method with the indicated radix (10, 16, or
     * 8).  This sequence of characters must represent a positive
     * value or a {@link NumberFormatException} will be thrown.  The
     * result is negated if first character of the specified {@code
     * string} is the minus sign.  No whitespace characters are
     * permitted in the {@code string}.
     *
     * @param     nm the {@code string} to decode.
     * @return    a {@code Short} object holding the {@code short}
     *            value represented by {@code nm}
     * @throws    NumberFormatException  if the {@code string} does not
     *            contain a parsable {@code short}.
     * @see java.lang.Short#parseShort(java.lang.string, int)
     */
    // static Short decode(string nm) throws NumberFormatException {
    //     int i = Integer.decode(nm);
    //     if (i < MIN_VALUE || i > MAX_VALUE)
    //         throw new NumberFormatException(
    //                 "Value " ~ i ~ " out of range from input " ~ nm);
    //     return valueOf((short)i);
    // }

    /**
     * The value of the {@code Short}.
     *
     * @serial
     */
    // private  short value;

    /**
     * Constructs a newly allocated {@code Short} object that
     * represents the specified {@code short} value.
     *
     * @param value     the value to be represented by the
     *                  {@code Short}.
     */
    this(short value) {
        super(value);
    }

    this(int value) {
        super(cast(short)value);
    }

    /**
     * Constructs a newly allocated {@code Short} object that
     * represents the {@code short} value indicated by the
     * {@code string} parameter. The string is converted to a
     * {@code short} value in exactly the manner used by the
     * {@code parseShort} method for radix 10.
     *
     * @param s the {@code string} to be converted to a
     *          {@code Short}
     * @throws  NumberFormatException If the {@code string}
     *          does not contain a parsable {@code short}.
     * @see     java.lang.Short#parseShort(java.lang.string, int)
     */
    // Short(string s) throws NumberFormatException {
    //     this.value = parseShort(s, 10);
    // }


    /**
     * Returns a hash code for this {@code Short}; equal to the result
     * of invoking {@code intValue()}.
     *
     * @return a hash code value for this {@code Short}
     */
    override 
    size_t toHash() @trusted nothrow {
        return cast(int)(value);
    }


    /**
     * The number of bits used to represent a {@code short} value in two's
     * complement binary form.
     */
    enum int SIZE = 16;

    /**
     * The number of bytes used to represent a {@code short} value in two's
     * complement binary form.
     *
     */
    enum int BYTES = SIZE / Byte.SIZE;

    /**
     * Returns the value obtained by reversing the order of the bytes in the
     * two's complement representation of the specified {@code short} value.
     *
     * @param i the value whose bytes are to be reversed
     * @return the value obtained by reversing (or, equivalently, swapping)
     *     the bytes in the specified {@code short} value.
     */
    static short reverseBytes(short i) {
        return cast(short) (((i & 0xFF00) >> 8) | (i << 8));
    }


    /**
     * Converts the argument to an {@code int} by an unsigned
     * conversion.  In an unsigned conversion to an {@code int}, the
     * high-order 16 bits of the {@code int} are zero and the
     * low-order 16 bits are equal to the bits of the {@code short} argument.
     *
     * Consequently, zero and positive {@code short} values are mapped
     * to a numerically equal {@code int} value and negative {@code
     * short} values are mapped to an {@code int} value equal to the
     * input plus 2<sup>16</sup>.
     *
     * @param  x the value to convert to an unsigned {@code int}
     * @return the argument converted to {@code int} by an unsigned
     *         conversion
     */
    static int toUnsignedInt(short x) {
        return (cast(int) x) & 0xffff;
    }

    /**
     * Converts the argument to a {@code long} by an unsigned
     * conversion.  In an unsigned conversion to a {@code long}, the
     * high-order 48 bits of the {@code long} are zero and the
     * low-order 16 bits are equal to the bits of the {@code short} argument.
     *
     * Consequently, zero and positive {@code short} values are mapped
     * to a numerically equal {@code long} value and negative {@code
     * short} values are mapped to a {@code long} value equal to the
     * input plus 2<sup>16</sup>.
     *
     * @param  x the value to convert to an unsigned {@code long}
     * @return the argument converted to {@code long} by an unsigned
     *         conversion
     */
    static long toUnsignedLong(short x) {
        return (cast(long) x) & 0xffffL;
    }

    /** use serialVersionUID from JDK 1.1. for interoperability */
    private static  long serialVersionUID = 7515723908773894738L;

    static short parseShort(string s)  {
        auto i = to!int(s);
        if (i < MIN_VALUE || i > MAX_VALUE)
        {
            throw new Exception(
                    "Value " ~s ~ " out of range from input ");
        }

         return cast(short)i;
    }
}
