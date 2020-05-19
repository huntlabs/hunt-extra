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

module hunt.stream.FileOutputStream;

import hunt.Exceptions;
import hunt.logging.ConsoleLogger;
import hunt.stream.Common;

import std.array;
import std.stdio;


/**
 * A file output stream is an output stream for writing data to a
 * <code>File</code> or to a <code>FileDescriptor</code>. Whether or not
 * a file is available or may be created depends upon the underlying
 * platform.  Some platforms, in particular, allow a file to be opened
 * for writing by only one {@code FileOutputStream} (or other
 * file-writing object) at a time.  In such situations the constructors in
 * this class will fail if the file involved is already open.
 *
 * <p><code>FileOutputStream</code> is meant for writing streams of raw bytes
 * such as image data. For writing streams of characters, consider using
 * <code>FileWriter</code>.
 *
 * @apiNote
 * To release resources used by this stream {@link #close} should be called
 * directly or by try-with-resources. Subclasses are responsible for the cleanup
 * of resources acquired by the subclass.
 * Subclasses that override {@link #finalize} in order to perform cleanup
 * should be modified to use alternative cleanup mechanisms such as
 * {@link java.lang.ref.Cleaner} and remove the overriding {@code finalize} method.
 *
 * @implSpec
 * If this FileOutputStream has been subclassed and the {@link #close}
 * method has been overridden, the {@link #close} method will be
 * called when the FileInputStream is unreachable.
 * Otherwise, it is implementation specific how the resource cleanup described in
 * {@link #close} is performed.
 *
 * @author  Arthur van Hoff
 * @see     java.io.File
 * @see     java.io.FileDescriptor
 * @see     java.io.FileInputStream
 * @see     java.nio.file.Files#newOutputStream
 */
class FileOutputStream : OutputStream
{
    /**
     * Access to FileDescriptor internals.
     */
    // private static final JavaIOFileDescriptorAccess fdAccess =
    //     SharedSecrets.getJavaIOFileDescriptorAccess();

    /**
     * The system dependent file descriptor.
     */
    // private FileDescriptor fd;

    /**
     * The associated channel, initialized lazily.
     */
    // private FileChannel channel;
    private File file;

    /**
     * The path of the referenced file
     * (null if the stream is created with a file descriptor)
     */
    // private string path;

    private Object closeLock;

    private bool closed;

    // private Object altFinalizer;

    /**
     * Creates a file output stream to write to the file with the
     * specified name. A new <code>FileDescriptor</code> object is
     * created to represent this file connection.
     * <p>
     * First, if there is a security manager, its <code>checkWrite</code>
     * method is called with <code>name</code> as its argument.
     * <p>
     * If the file exists but is a directory rather than a regular file, does
     * not exist but cannot be created, or cannot be opened for any other
     * reason then a <code>FileNotFoundException</code> is thrown.
     *
     * @implSpec Invoking this constructor with the parameter {@code name} is
     * equivalent to invoking {@link #FileOutputStream(string,bool)
     * new FileOutputStream(name, false)}.
     *
     * @param      name   the system-dependent filename
     * @exception  FileNotFoundException  if the file exists but is a directory
     *                   rather than a regular file, does not exist but cannot
     *                   be created, or cannot be opened for any other reason
     * @exception  SecurityException  if a security manager exists and its
     *               <code>checkWrite</code> method denies write access
     *               to the file.
     * @see        java.lang.SecurityManager#checkWrite(java.lang.string)
     */
    this(string name) {
        this(name, false);
    }

    /**
     * Creates a file output stream to write to the file with the specified
     * name.  If the second argument is <code>true</code>, then
     * bytes will be written to the end of the file rather than the beginning.
     * A new <code>FileDescriptor</code> object is created to represent this
     * file connection.
     * <p>
     * First, if there is a security manager, its <code>checkWrite</code>
     * method is called with <code>name</code> as its argument.
     * <p>
     * If the file exists but is a directory rather than a regular file, does
     * not exist but cannot be created, or cannot be opened for any other
     * reason then a <code>FileNotFoundException</code> is thrown.
     *
     * @param     name        the system-dependent file name
     * @param     append      if <code>true</code>, then bytes will be written
     *                   to the end of the file rather than the beginning
     * @exception  FileNotFoundException  if the file exists but is a directory
     *                   rather than a regular file, does not exist but cannot
     *                   be created, or cannot be opened for any other reason.
     * @exception  SecurityException  if a security manager exists and its
     *               <code>checkWrite</code> method denies write access
     *               to the file.
     * @see        java.lang.SecurityManager#checkWrite(java.lang.string)
     */
    this(string name, bool append) {
        if(name.empty)
            throw new NullPointerException();
        if(append)
            this(File(name, "a"));
        else
            this(File(name, "w"));
    }

    /**
     * Creates a file output stream to write to the file represented by
     * the specified <code>File</code> object. A new
     * <code>FileDescriptor</code> object is created to represent this
     * file connection.
     * <p>
     * First, if there is a security manager, its <code>checkWrite</code>
     * method is called with the path represented by the <code>file</code>
     * argument as its argument.
     * <p>
     * If the file exists but is a directory rather than a regular file, does
     * not exist but cannot be created, or cannot be opened for any other
     * reason then a <code>FileNotFoundException</code> is thrown.
     *
     * @param      file               the file to be opened for writing.
     * @exception  FileNotFoundException  if the file exists but is a directory
     *                   rather than a regular file, does not exist but cannot
     *                   be created, or cannot be opened for any other reason
     * @exception  SecurityException  if a security manager exists and its
     *               <code>checkWrite</code> method denies write access
     *               to the file.
     */
    this(File file) {
        this.file = file;

        version(HUNT_DEBUG_MORE) {
            infof("Outputing to file: %s", file.name());
        }

        initialize();
    }

    private void initialize() {
        closeLock = new Object();
    }

    /**
     * Opens a file, with the specified name, for overwriting or appending.
     * @param name name of file to be opened
     * @param append whether the file is to be opened in append mode
     */
    // private void open0(string name, bool append);

    // wrap call to allow instrumentation
    /**
     * Opens a file, with the specified name, for overwriting or appending.
     * @param name name of file to be opened
     * @param append whether the file is to be opened in append mode
     */
    // private void open(string name, bool append) {
    //     open0(name, append);
    // }

    /**
     * Writes the specified byte to this file output stream.
     *
     * @param   b   the byte to be written.
     * @param   append   {@code true} if the write operation first
     *     advances the position to the end of file
     */
    // private void write(int b, bool append);

    /**
     * Writes the specified byte to this file output stream. Implements
     * the <code>write</code> method of <code>OutputStream</code>.
     *
     * @param      b   the byte to be written.
     * @exception  IOException  if an I/O error occurs.
     */
    override void write(int b) {
        // write(b, fdAccess.getAppend(fd));
        file.rawWrite([cast(byte)b]);
    }

    /**
     * Writes a sub array as a sequence of bytes.
     * @param b the data to be written
     * @param off the start offset in the data
     * @param len the number of bytes that are written
     * @param append {@code true} to first advance the position to the
     *     end of file
     * @exception IOException If an I/O error has occurred.
     */
    // private void writeBytes(byte b[], int off, int len, bool append);

    /**
     * Writes <code>b.length</code> bytes from the specified byte array
     * to this file output stream.
     *
     * @param      b   the data.
     * @exception  IOException  if an I/O error occurs.
     */
    override void write(byte[] b) {
        // writeBytes(b, 0, b.length, fdAccess.getAppend(fd));
        file.rawWrite(b);
    }

    /**
     * Writes <code>len</code> bytes from the specified byte array
     * starting at offset <code>off</code> to this file output stream.
     *
     * @param      b     the data.
     * @param      off   the start offset in the data.
     * @param      len   the number of bytes to write.
     * @exception  IOException  if an I/O error occurs.
     */
    override void write(byte[] b, int off, int len) {
        // writeBytes(b, off, len, fdAccess.getAppend(fd));
        file.rawWrite(b[off .. off+len]);
    }

    /**
     * Closes this file output stream and releases any system resources
     * associated with this stream. This file output stream may no longer
     * be used for writing bytes.
     *
     * <p> If this stream has an associated channel then the channel is closed
     * as well.
     *
     * @apiNote
     * Overriding {@link #close} to perform cleanup actions is reliable
     * only when called directly or when called by try-with-resources.
     * Do not depend on finalization to invoke {@code close};
     * finalization is not reliable and is deprecated.
     * If cleanup of resources is needed, other mechanisms such as
     * {@linkplain java.lang.ref.Cleaner} should be used.
     *
     * @exception  IOException  if an I/O error occurs.
     *
     * @revised 1.4
     * @spec JSR-51
     */
    override void close() {
        if (closed) 
            return;

        synchronized (closeLock) {
            if (closed) return;
            closed = true;
        }

        this.file.close();

        // FileChannel fc = channel;
        // if (fc != null) {
        //     // possible race with getChannel(), benign since
        //     // FileChannel.close is final and idempotent
        //     fc.close();
        // }

        // fd.closeAll(new Closeable() {
        //     void close() {
        //        fd.close();
        //    }
        // });
    }

    /**
     * Returns the file descriptor associated with this stream.
     *
     * @return  the <code>FileDescriptor</code> object that represents
     *          the connection to the file in the file system being used
     *          by this <code>FileOutputStream</code> object.
     *
     * @exception  IOException  if an I/O error occurs.
     * @see        java.io.FileDescriptor
     */
    //  final FileDescriptor getFD()  {
    //     if (fd != null) {
    //         return fd;
    //     }
    //     throw new IOException();
    //  }

    /**
     * Returns the unique {@link java.nio.channels.FileChannel FileChannel}
     * object associated with this file output stream.
     *
     * <p> The initial {@link java.nio.channels.FileChannel#position()
     * position} of the returned channel will be equal to the
     * number of bytes written to the file so far unless this stream is in
     * append mode, in which case it will be equal to the size of the file.
     * Writing bytes to this stream will increment the channel's position
     * accordingly.  Changing the channel's position, either explicitly or by
     * writing, will change this stream's file position.
     *
     * @return  the file channel associated with this file output stream
     *
     * @spec JSR-51
     */
    // FileChannel getChannel() {
    //     FileChannel fc = this.channel;
    //     if (fc == null) {
    //         synchronized (this) {
    //             fc = this.channel;
    //             if (fc == null) {
    //                 this.channel = fc = FileChannelImpl.open(fd, path, false,
    //                     true, false, this);
    //                 if (closed) {
    //                     try {
    //                         // possible race with close(), benign since
    //                         // FileChannel.close is final and idempotent
    //                         fc.close();
    //                     } catch (IOException ioe) {
    //                         throw new InternalError(ioe); // should not happen
    //                     }
    //                 }
    //             }
    //         }
    //     }
    //     return fc;
    // }

    /**
     * Cleans up the connection to the file, and ensures that the
     * {@link #close} method of this file output stream is
     * called when there are no more references to this stream.
     * The {@link #finalize} method does not call {@link #close} directly.
     *
     * @apiNote
     * To release resources used by this stream {@link #close} should be called
     * directly or by try-with-resources.
     *
     * @implSpec
     * If this FileOutputStream has been subclassed and the {@link #close}
     * method has been overridden, the {@link #close} method will be
     * called when the FileOutputStream is unreachable.
     * Otherwise, it is implementation specific how the resource cleanup described in
     * {@link #close} is performed.
     *
     * @deprecated The {@code finalize} method has been deprecated and will be removed.
     *     Subclasses that override {@code finalize} in order to perform cleanup
     *     should be modified to use alternative cleanup mechanisms and
     *     to remove the overriding {@code finalize} method.
     *     When overriding the {@code finalize} method, its implementation must explicitly
     *     ensure that {@code super.finalize()} is invoked as described in {@link Object#finalize}.
     *     See the specification for {@link Object#finalize()} for further
     *     information about migration options.
     *
     * @exception  IOException  if an I/O error occurs.
     * @see        java.io.FileInputStream#close()
     */
    // @Deprecated(since="9", forRemoval = true)
    // protected void finalize() {
    // }

    // private static void initIDs();

    // static {
    //     initIDs();
    // }

    /*
     * Returns a finalizer object if the FOS needs a finalizer; otherwise null.
     * If the FOS has a close method; it needs an AltFinalizer.
     */
    // private static Object getFinalizer(FileOutputStream fos) {
    //     Class<?> clazz = fos.getClass();
    //     while (clazz != FileOutputStream.class) {
    //         try {
    //             clazz.getDeclaredMethod("close");
    //             return new AltFinalizer(fos);
    //         } catch (NoSuchMethodException nsme) {
    //             // ignore
    //         }
    //         clazz = clazz.getSuperclass();
    //     }
    //     return null;
    // }

    /**
     * Class to call {@code FileOutputStream.close} when finalized.
     * If finalization of the stream is needed, an instance is created
     * in its constructor(s).  When the set of instances
     * related to the stream is unreachable, the AltFinalizer performs
     * the needed call to the stream's {@code close} method.
     */
    // static class AltFinalizer {
    //     private final FileOutputStream fos;

    //     this(FileOutputStream fos) {
    //         this.fos = fos;
    //     }

    //     override
    //     @SuppressWarnings("deprecation")
    //     protected final void finalize() {
    //         try {
    //             if (fos.fd != null) {
    //                 if (fos.fd == FileDescriptor.out || fos.fd == FileDescriptor.err) {
    //                     // Subclass may override flush; otherwise it is no-op
    //                     fos.flush();
    //                 } else {
    //                     /* if fd is shared, the references in FileDescriptor
    //                      * will ensure that finalizer is only called when
    //                      * safe to do so. All references using the fd have
    //                      * become unreachable. We can call close()
    //                      */
    //                     fos.close();
    //                 }
    //             }
    //         } catch (IOException ioe) {
    //             // ignore
    //         }
    //     }
    // }

}