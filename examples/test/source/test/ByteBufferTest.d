module test.ByteBufferTest;

import hunt.io.ByteBuffer;
import hunt.io.BufferUtils;
import hunt.io.HeapByteBuffer;
import hunt.util.ByteOrder;

import hunt.Byte;

import hunt.logging.ConsoleLogger;
import hunt.Assert;

import std.conv;
import std.format;

alias IntUnaryOperator = int delegate(int);


class ByteBufferTest {

    enum int SIZE = 32;

    static ByteBuffer allocate() {
        return allocate(i => i);
    }

    static ByteBuffer allocate(int size) {
        ByteBuffer buf = BufferUtils.allocate(size);
        return buf;
    }

    static ByteBuffer allocate(IntUnaryOperator o) {
        ByteBuffer buf = BufferUtils.allocate(SIZE);
        return fill(buf, o);
    }

    static ByteBuffer fill(ByteBuffer bb, IntUnaryOperator o) {
        for (int i = 0; i < bb.limit(); i++) {
            bb.put(i, cast(byte)o(i));
        }
        return bb;
    }

    static void assertValues(T)(int i, T bValue, T bbValue, ByteBuffer bb) {
        if (bValue != bbValue) {
            fail(format("Values %s and %s differ at index %d for %s",
                               bValue, bbValue, i, bb));
        }
    }

    void testCopy() {
        ByteBuffer src = allocate(4);
        ByteBuffer dst = allocate(5);
        src.put('a');
        dst.put('b');
        tracef("dst: %s", dst.toString());
        dst.clear();
        tracef("dst: %s", dst.toString());
        dst.put(src).flip();
        tracef("dst: %s", dst.toString());
        dst.flip();
        tracef("dst: %s", dst.toString());
        trace("============");
    }

    void testInt() {
        ByteBuffer bbfilled = allocate();
        ByteBuffer bb = allocate(i => 0);
        
        byte[] data = bbfilled.peekRemaining();
        // tracef("bbfilled: %(%02X %)", data);
        data = bb.peekRemaining();
        // tracef("bb: %(%02X %)", data);

        for (int i = 0; i < bb.limit(); i = i + 4) {
            int fromFilled = bbfilled.getInt(i);

            bb.putInt(i, fromFilled);
            int fromMethodView = bb.getInt(i);

            data = bb.peekRemaining();
            // tracef("%(%02X %)", data);
            assertValues(i, fromFilled, fromMethodView, bb);
        }
    }

    void testLong() {
        ByteBuffer bbfilled = allocate();
        ByteBuffer bb = allocate(i => 0);
        byte[] data = bbfilled.peekRemaining();

        // tracef("bbfilled: %(%02X %)", data);
        data = bb.peekRemaining();

        // tracef("bb: %(%02X %)", data);

        for (int i = 0; i < bb.limit(); i = i + 8) {
            long fromFilled = bbfilled.getLong(i);

            bb.putLong(i, fromFilled);
            long fromMethodView = bb.getLong(i);

            data = bb.peekRemaining();
            // tracef("%(%02X %)", data);
            assertValues(i, fromFilled, fromMethodView, bb);
        }
    }

    void testShort() {
        byte[] data = [0x03, 0x03, 0x00, 0x00];
        ByteBuffer b = BufferUtils.wrap(data);
        assert(b.order == ByteOrder.BigEndian);
        b.putShort(2, 61);
        trace(data);

        assert(b.getShort(2) == 61);
        assert(HeapByteBuffer.makeShort(0x00, 0x3D) == cast(short)15616);
    }

}