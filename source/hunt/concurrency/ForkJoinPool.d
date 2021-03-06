/*
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */

/*
 * This file is available under and governed by the GNU General Public
 * License version 2 only, as published by the Free Software Foundation.
 * However, the following notice accompanied the original version of this
 * file:
 *
 * Written by Doug Lea with assistance from members of JCP JSR-166
 * Expert Group and released to the domain, as explained at
 * http://creativecommons.org/publicdomain/zero/1.0/
 */

module hunt.concurrency.ForkJoinPool;

import hunt.concurrency.AbstractExecutorService;
import hunt.concurrency.atomic.AtomicHelper;
import hunt.concurrency.Exceptions;
import hunt.concurrency.ForkJoinTask;
import hunt.concurrency.ForkJoinTaskHelper;
import hunt.concurrency.ThreadLocalRandom;
import hunt.concurrency.thread;

import hunt.collection.List;
import hunt.collection.Collection;
import hunt.collection.Collections;
import hunt.logging.ConsoleLogger;
import hunt.Exceptions;
import hunt.Functions;
import hunt.system.Environment;
import hunt.system.Memory;
import hunt.util.Common;
import hunt.util.Configuration;
import hunt.util.DateTime;
import hunt.util.Runnable;

import core.atomic;
import core.sync.mutex;
import core.thread;
import core.time;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;

alias ReentrantLock = Mutex;

// import java.lang.Thread.UncaughtExceptionHandler;
// import java.lang.invoke.MethodHandles;
// import java.lang.invoke.VarHandle;
// import java.security.AccessController;
// import java.security.AccessControlContext;
// import java.security.Permission;
// import java.security.Permissions;
// import java.security.PrivilegedAction;
// import java.security.ProtectionDomain;
// import hunt.collection.ArrayList;
// import hunt.collection.Collection;
// import java.util.Collections;
// import java.util.List;
// import hunt.util.functional.Predicate;
// import hunt.concurrency.locks.LockSupport;


private {

// Constants shared across ForkJoinPool and WorkQueue

// Bounds
enum int SWIDTH       = 16;            // width of short
enum int SMASK        = 0xffff;        // short bits == max index
enum int MAX_CAP      = 0x7fff;        // max #workers - 1
enum int SQMASK       = 0x007e;        // max 64 (even) slots

// Masks and units for WorkQueue.phase and ctl sp subfield
enum int UNSIGNALLED  = 1 << 31;       // must be negative
enum int SS_SEQ       = 1 << 16;       // version count
enum int QLOCK        = 1;             // must be 1

// Mode bits and sentinels, some also used in WorkQueue id and.source fields
enum int OWNED        = 1;             // queue has owner thread
enum int FIFO         = 1 << 16;       // fifo queue or access mode
enum int SHUTDOWN     = 1 << 18;
enum int TERMINATED   = 1 << 19;
enum int STOP         = 1 << 31;       // must be negative
enum int QUIET        = 1 << 30;       // not scanning or working
enum int DORMANT      = QUIET | UNSIGNALLED;

/**
 * The maximum number of top-level polls per worker before
 * checking other queues, expressed as a bit shift to, in effect,
 * multiply by pool size, and then use as random value mask, so
 * average bound is about poolSize*(1<<TOP_BOUND_SHIFT).  See
 * above for rationale.
 */
enum int TOP_BOUND_SHIFT = 10;

/**
 * Initial capacity of work-stealing queue array.
 * Must be a power of two, at least 2.
 */
enum int INITIAL_QUEUE_CAPACITY = 1 << 13;

/**
 * Maximum capacity for queue arrays. Must be a power of two less
 * than or equal to 1 << (31 - width of array entry) to ensure
 * lack of wraparound of index calculations, but defined to a
 * value a bit less than this to help users trap runaway programs
 * before saturating systems.
 */
enum int MAXIMUM_QUEUE_CAPACITY = 1 << 26; // 64M

}

/**
 * An {@link ExecutorService} for running {@link ForkJoinTask}s.
 * A {@code ForkJoinPool} provides the entry point for submissions
 * from non-{@code ForkJoinTask} clients, as well as management and
 * monitoring operations.
 *
 * <p>A {@code ForkJoinPool} differs from other kinds of {@link
 * ExecutorService} mainly by virtue of employing
 * <em>work-stealing</em>: all threads in the pool attempt to find and
 * execute tasks submitted to the pool and/or created by other active
 * tasks (eventually blocking waiting for work if none exist). This
 * enables efficient processing when most tasks spawn other subtasks
 * (as do most {@code ForkJoinTask}s), as well as when many small
 * tasks are submitted to the pool from external clients.  Especially
 * when setting <em>asyncMode</em> to true in constructors, {@code
 * ForkJoinPool}s may also be appropriate for use with event-style
 * tasks that are never joined. All worker threads are initialized
 * with {@link Thread#isDaemon} set {@code true}.
 *
 * <p>A static {@link #commonPool()} is available and appropriate for
 * most applications. The common pool is used by any ForkJoinTask that
 * is not explicitly submitted to a specified pool. Using the common
 * pool normally reduces resource usage (its threads are slowly
 * reclaimed during periods of non-use, and reinstated upon subsequent
 * use).
 *
 * <p>For applications that require separate or custom pools, a {@code
 * ForkJoinPool} may be constructed with a given target parallelism
 * level; by default, equal to the number of available processors.
 * The pool attempts to maintain enough active (or available) threads
 * by dynamically adding, suspending, or resuming internal worker
 * threads, even if some tasks are stalled waiting to join others.
 * However, no such adjustments are guaranteed in the face of blocked
 * I/O or other unmanaged synchronization. The nested {@link
 * ManagedBlocker} interface enables extension of the kinds of
 * synchronization accommodated. The default policies may be
 * overridden using a constructor with parameters corresponding to
 * those documented in class {@link ThreadPoolExecutor}.
 *
 * <p>In addition to execution and lifecycle control methods, this
 * class provides status check methods (for example
 * {@link #getStealCount}) that are intended to aid in developing,
 * tuning, and monitoring fork/join applications. Also, method
 * {@link #toString} returns indications of pool state in a
 * convenient form for informal monitoring.
 *
 * <p>As is the case with other ExecutorServices, there are three
 * main task execution methods summarized in the following table.
 * These are designed to be used primarily by clients not already
 * engaged in fork/join computations in the current pool.  The main
 * forms of these methods accept instances of {@code ForkJoinTask},
 * but overloaded forms also allow mixed execution of plain {@code
 * Runnable}- or {@code Callable}- based activities as well.  However,
 * tasks that are already executing in a pool should normally instead
 * use the within-computation forms listed in the table unless using
 * async event-style tasks that are not usually joined, in which case
 * there is little difference among choice of methods.
 *
 * <table class="plain">
 * <caption>Summary of task execution methods</caption>
 *  <tr>
 *    <td></td>
 *    <th scope="col"> Call from non-fork/join clients</th>
 *    <th scope="col"> Call from within fork/join computations</th>
 *  </tr>
 *  <tr>
 *    <th scope="row" style="text-align:left"> Arrange async execution</th>
 *    <td> {@link #execute(ForkJoinTask)}</td>
 *    <td> {@link ForkJoinTask#fork}</td>
 *  </tr>
 *  <tr>
 *    <th scope="row" style="text-align:left"> Await and obtain result</th>
 *    <td> {@link #invoke(ForkJoinTask)}</td>
 *    <td> {@link ForkJoinTask#invoke}</td>
 *  </tr>
 *  <tr>
 *    <th scope="row" style="text-align:left"> Arrange exec and obtain Future</th>
 *    <td> {@link #submit(ForkJoinTask)}</td>
 *    <td> {@link ForkJoinTask#fork} (ForkJoinTasks <em>are</em> Futures)</td>
 *  </tr>
 * </table>
 *
 * <p>The parameters used to construct the common pool may be controlled by
 * setting the following {@linkplain System#getProperty system properties}:
 * <ul>
 * <li>{@code hunt.concurrency.ForkJoinPool.common.parallelism}
 * - the parallelism level, a non-negative integer
 * <li>{@code hunt.concurrency.ForkJoinPool.common.threadFactory}
 * - the class name of a {@link ForkJoinWorkerThreadFactory}.
 * The {@linkplain ClassLoader#getSystemClassLoader() system class loader}
 * is used to load this class.
 * <li>{@code hunt.concurrency.ForkJoinPool.common.exceptionHandler}
 * - the class name of a {@link UncaughtExceptionHandler}.
 * The {@linkplain ClassLoader#getSystemClassLoader() system class loader}
 * is used to load this class.
 * <li>{@code hunt.concurrency.ForkJoinPool.common.maximumSpares}
 * - the maximum number of allowed extra threads to maintain target
 * parallelism (default 256).
 * </ul>
 * If no thread factory is supplied via a system property, then the
 * common pool uses a factory that uses the system class loader as the
 * {@linkplain Thread#getContextClassLoader() thread context class loader}.
 * In addition, if a {@link SecurityManager} is present, then
 * the common pool uses a factory supplying threads that have no
 * {@link Permissions} enabled.
 *
 * Upon any error in establishing these settings, default parameters
 * are used. It is possible to disable or limit the use of threads in
 * the common pool by setting the parallelism property to zero, and/or
 * using a factory that may return {@code null}. However doing so may
 * cause unjoined tasks to never be executed.
 *
 * <p><b>Implementation notes</b>: This implementation restricts the
 * maximum number of running threads to 32767. Attempts to create
 * pools with greater than the maximum number result in
 * {@code IllegalArgumentException}.
 *
 * <p>This implementation rejects submitted tasks (that is, by throwing
 * {@link RejectedExecutionException}) only when the pool is shut down
 * or internal resources have been exhausted.
 *
 * @author Doug Lea
 */
class ForkJoinPool : AbstractExecutorService { 

    /*
     * Implementation Overview
     *
     * This class and its nested classes provide the main
     * functionality and control for a set of worker threads:
     * Submissions from non-FJ threads enter into submission queues.
     * Workers take these tasks and typically split them into subtasks
     * that may be stolen by other workers. Work-stealing based on
     * randomized scans generally leads to better throughput than
     * "work dealing" in which producers assign tasks to idle threads,
     * in part because threads that have finished other tasks before
     * the signalled thread wakes up (which can be a long time) can
     * take the task instead.  Preference rules give first priority to
     * processing tasks from their own queues (LIFO or FIFO, depending
     * on mode), then to randomized FIFO steals of tasks in other
     * queues.  This framework began as vehicle for supporting
     * tree-structured parallelism using work-stealing.  Over time,
     * its scalability advantages led to extensions and changes to
     * better support more diverse usage contexts.  Because most
     * internal methods and nested classes are interrelated, their
     * main rationale and descriptions are presented here; individual
     * methods and nested classes contain only brief comments about
     * details.
     *
     * WorkQueues
     * ==========
     *
     * Most operations occur within work-stealing queues (in nested
     * class WorkQueue).  These are special forms of Deques that
     * support only three of the four possible end-operations -- push,
     * pop, and poll (aka steal), under the further constraints that
     * push and pop are called only from the owning thread (or, as
     * extended here, under a lock), while poll may be called from
     * other threads.  (If you are unfamiliar with them, you probably
     * want to read Herlihy and Shavit's book "The Art of
     * Multiprocessor programming", chapter 16 describing these in
     * more detail before proceeding.)  The main work-stealing queue
     * design is roughly similar to those in the papers "Dynamic
     * Circular Work-Stealing Deque" by Chase and Lev, SPAA 2005
     * (http://research.sun.com/scalable/pubs/index.html) and
     * "Idempotent work stealing" by Michael, Saraswat, and Vechev,
     * PPoPP 2009 (http://portal.acm.org/citation.cfm?id=1504186).
     * The main differences ultimately stem from GC requirements that
     * we null out taken slots as soon as we can, to maintain as small
     * a footprint as possible even in programs generating huge
     * numbers of tasks. To accomplish this, we shift the CAS
     * arbitrating pop vs poll (steal) from being on the indices
     * ("base" and "top") to the slots themselves.
     *
     * Adding tasks then takes the form of a classic array push(task)
     * in a circular buffer:
     *    q.array[q.top++ % length] = task;
     *
     * (The actual code needs to null-check and size-check the array,
     * uses masking, not mod, for indexing a power-of-two-sized array,
     * adds a release fence for publication, and possibly signals
     * waiting workers to start scanning -- see below.)  Both a
     * successful pop and poll mainly entail a CAS of a slot from
     * non-null to null.
     *
     * The pop operation (always performed by owner) is:
     *   if ((the task at top slot is not null) and
     *        (CAS slot to null))
     *           decrement top and return task;
     *
     * And the poll operation (usually by a stealer) is
     *    if ((the task at base slot is not null) and
     *        (CAS slot to null))
     *           increment base and return task;
     *
     * There are several variants of each of these. Most uses occur
     * within operations that also interleave contention or emptiness
     * tracking or inspection of elements before extracting them, so
     * must interleave these with the above code. When performed by
     * owner, getAndSet is used instead of CAS (see for example method
     * nextLocalTask) which is usually more efficient, and possible
     * because the top index cannot independently change during the
     * operation.
     *
     * Memory ordering.  See "Correct and Efficient Work-Stealing for
     * Weak Memory Models" by Le, Pop, Cohen, and Nardelli, PPoPP 2013
     * (http://www.di.ens.fr/~zappa/readings/ppopp13.pdf) for an
     * analysis of memory ordering requirements in work-stealing
     * algorithms similar to (but different than) the one used here.
     * Extracting tasks in array slots via (fully fenced) CAS provides
     * primary synchronization. The base and top indices imprecisely
     * guide where to extract from. We do not usually require strict
     * orderings of array and index updates. Many index accesses use
     * plain mode, with ordering constrained by surrounding context
     * (usually with respect to element CASes or the two WorkQueue
     * fields source and phase). When not otherwise already
     * constrained, reads of "base" by queue owners use acquire-mode,
     * and some externally callable methods preface accesses with
     * acquire fences.  Additionally, to ensure that index update
     * writes are not coalesced or postponed in loops etc, "opaque"
     * mode is used in a few cases where timely writes are not
     * otherwise ensured. The "locked" versions of push- and pop-
     * based methods for shared queues differ from owned versions
     * because locking already forces some of the ordering.
     *
     * Because indices and slot contents cannot always be consistent,
     * a check that base == top indicates (momentary) emptiness, but
     * otherwise may err on the side of possibly making the queue
     * appear nonempty when a push, pop, or poll have not fully
     * committed, or making it appear empty when an update of top has
     * not yet been visibly written.  (Method isEmpty() checks the
     * case of a partially completed removal of the last element.)
     * Because of this, the poll operation, considered individually,
     * is not wait-free. One thief cannot successfully continue until
     * another in-progress one (or, if previously empty, a push)
     * visibly completes.  This can stall threads when required to
     * consume from a given queue (see method poll()).  However, in
     * the aggregate, we ensure at least probabilistic
     * non-blockingness.  If an attempted steal fails, a scanning
     * thief chooses a different random victim target to try next. So,
     * in order for one thief to progress, it suffices for any
     * in-progress poll or new push on any empty queue to complete.
     *
     * This approach also enables support of a user mode in which
     * local task processing is in FIFO, not LIFO order, simply by
     * using poll rather than pop.  This can be useful in
     * message-passing frameworks in which tasks are never joined.
     *
     * WorkQueues are also used in a similar way for tasks submitted
     * to the pool. We cannot mix these tasks in the same queues used
     * by workers. Instead, we randomly associate submission queues
     * with submitting threads, using a form of hashing.  The
     * ThreadLocalRandom probe value serves as a hash code for
     * choosing existing queues, and may be randomly repositioned upon
     * contention with other submitters.  In essence, submitters act
     * like workers except that they are restricted to executing local
     * tasks that they submitted.  Insertion of tasks in shared mode
     * requires a lock but we use only a simple spinlock (using field
     * phase), because submitters encountering a busy queue move to a
     * different position to use or create other queues -- they block
     * only when creating and registering new queues. Because it is
     * used only as a spinlock, unlocking requires only a "releasing"
     * store (using setRelease) unless otherwise signalling.
     *
     * Management
     * ==========
     *
     * The main throughput advantages of work-stealing stem from
     * decentralized control -- workers mostly take tasks from
     * themselves or each other, at rates that can exceed a billion
     * per second.  The pool itself creates, activates (enables
     * scanning for and running tasks), deactivates, blocks, and
     * terminates threads, all with minimal central information.
     * There are only a few properties that we can globally track or
     * maintain, so we pack them into a small number of variables,
     * often maintaining atomicity without blocking or locking.
     * Nearly all essentially atomic control state is held in a few
     * variables that are by far most often read (not
     * written) as status and consistency checks. We pack as much
     * information into them as we can.
     *
     * Field "ctl" contains 64 bits holding information needed to
     * atomically decide to add, enqueue (on an event queue), and
     * dequeue and release workers.  To enable this packing, we
     * restrict maximum parallelism to (1<<15)-1 (which is far in
     * excess of normal operating range) to allow ids, counts, and
     * their negations (used for thresholding) to fit into 16bit
     * subfields.
     *
     * Field "mode" holds configuration parameters as well as lifetime
     * status, atomically and monotonically setting SHUTDOWN, STOP,
     * and finally TERMINATED bits.
     *
     * Field "workQueues" holds references to WorkQueues.  It is
     * updated (only during worker creation and termination) under
     * lock (using field workerNamePrefix as lock), but is otherwise
     * concurrently readable, and accessed directly. We also ensure
     * that uses of the array reference itself never become too stale
     * in case of resizing, by arranging that (re-)reads are separated
     * by at least one acquiring read access.  To simplify index-based
     * operations, the array size is always a power of two, and all
     * readers must tolerate null slots. Worker queues are at odd
     * indices. Shared (submission) queues are at even indices, up to
     * a maximum of 64 slots, to limit growth even if the array needs
     * to expand to add more workers. Grouping them together in this
     * way simplifies and speeds up task scanning.
     *
     * All worker thread creation is on-demand, triggered by task
     * submissions, replacement of terminated workers, and/or
     * compensation for blocked workers. However, all other support
     * code is set up to work with other policies.  To ensure that we
     * do not hold on to worker references that would prevent GC, all
     * accesses to workQueues are via indices into the workQueues
     * array (which is one source of some of the messy code
     * constructions here). In essence, the workQueues array serves as
     * a weak reference mechanism. Thus for example the stack top
     * subfield of ctl stores indices, not references.
     *
     * Queuing Idle Workers. Unlike HPC work-stealing frameworks, we
     * cannot let workers spin indefinitely scanning for tasks when
     * none can be found immediately, and we cannot start/resume
     * workers unless there appear to be tasks available.  On the
     * other hand, we must quickly prod them into action when new
     * tasks are submitted or generated. In many usages, ramp-up time
     * is the main limiting factor in overall performance, which is
     * compounded at program start-up by JIT compilation and
     * allocation. So we streamline this as much as possible.
     *
     * The "ctl" field atomically maintains total worker and
     * "released" worker counts, plus the head of the available worker
     * queue (actually stack, represented by the lower 32bit subfield
     * of ctl).  Released workers are those known to be scanning for
     * and/or running tasks. Unreleased ("available") workers are
     * recorded in the ctl stack. These workers are made available for
     * signalling by enqueuing in ctl (see method runWorker).  The
     * "queue" is a form of Treiber stack. This is ideal for
     * activating threads in most-recently used order, and improves
     * performance and locality, outweighing the disadvantages of
     * being prone to contention and inability to release a worker
     * unless it is topmost on stack.  To avoid missed signal problems
     * inherent in any wait/signal design, available workers rescan
     * for (and if found run) tasks after enqueuing.  Normally their
     * release status will be updated while doing so, but the released
     * worker ctl count may underestimate the number of active
     * threads. (However, it is still possible to determine quiescence
     * via a validation traversal -- see isQuiescent).  After an
     * unsuccessful rescan, available workers are blocked until
     * signalled (see signalWork).  The top stack state holds the
     * value of the "phase" field of the worker: its index and status,
     * plus a version counter that, in addition to the count subfields
     * (also serving as version stamps) provide protection against
     * Treiber stack ABA effects.
     *
     * Creating workers. To create a worker, we pre-increment counts
     * (serving as a reservation), and attempt to construct a
     * ForkJoinWorkerThread via its factory. Upon construction, the
     * new thread invokes registerWorker, where it constructs a
     * WorkQueue and is assigned an index in the workQueues array
     * (expanding the array if necessary). The thread is then started.
     * Upon any exception across these steps, or null return from
     * factory, deregisterWorker adjusts counts and records
     * accordingly.  If a null return, the pool continues running with
     * fewer than the target number workers. If exceptional, the
     * exception is propagated, generally to some external caller.
     * Worker index assignment avoids the bias in scanning that would
     * occur if entries were sequentially packed starting at the front
     * of the workQueues array. We treat the array as a simple
     * power-of-two hash table, expanding as needed. The seedIndex
     * increment ensures no collisions until a resize is needed or a
     * worker is deregistered and replaced, and thereafter keeps
     * probability of collision low. We cannot use
     * ThreadLocalRandom.getProbe() for similar purposes here because
     * the thread has not started yet, but do so for creating
     * submission queues for existing external threads (see
     * externalPush).
     *
     * WorkQueue field "phase" is used by both workers and the pool to
     * manage and track whether a worker is UNSIGNALLED (possibly
     * blocked waiting for a signal).  When a worker is enqueued its
     * phase field is set. Note that phase field updates lag queue CAS
     * releases so usage requires care -- seeing a negative phase does
     * not guarantee that the worker is available. When queued, the
     * lower 16 bits of scanState must hold its pool index. So we
     * place the index there upon initialization and otherwise keep it
     * there or restore it when necessary.
     *
     * The ctl field also serves as the basis for memory
     * synchronization surrounding activation. This uses a more
     * efficient version of a Dekker-like rule that task producers and
     * consumers sync with each other by both writing/CASing ctl (even
     * if to its current value).  This would be extremely costly. So
     * we relax it in several ways: (1) Producers only signal when
     * their queue is possibly empty at some point during a push
     * operation (which requires conservatively checking size zero or
     * one to cover races). (2) Other workers propagate this signal
     * when they find tasks in a queue with size greater than one. (3)
     * Workers only enqueue after scanning (see below) and not finding
     * any tasks.  (4) Rather than CASing ctl to its current value in
     * the common case where no action is required, we reduce write
     * contention by equivalently prefacing signalWork when called by
     * an external task producer using a memory access with
     * full-semantics or a "fullFence".
     *
     * Almost always, too many signals are issued, in part because a
     * task producer cannot tell if some existing worker is in the
     * midst of finishing one task (or already scanning) and ready to
     * take another without being signalled. So the producer might
     * instead activate a different worker that does not find any
     * work, and then inactivates. This scarcely matters in
     * steady-state computations involving all workers, but can create
     * contention and bookkeeping bottlenecks during ramp-up,
     * ramp-down, and small computations involving only a few workers.
     *
     * Scanning. Method scan (from runWorker) performs top-level
     * scanning for tasks. (Similar scans appear in helpQuiesce and
     * pollScan.)  Each scan traverses and tries to poll from each
     * queue starting at a random index. Scans are not performed in
     * ideal random permutation order, to reduce cacheline
     * contention. The pseudorandom generator need not have
     * high-quality statistical properties in the long term, but just
     * within computations; We use Marsaglia XorShifts (often via
     * ThreadLocalRandom.nextSecondarySeed), which are cheap and
     * suffice. Scanning also includes contention reduction: When
     * scanning workers fail to extract an apparently existing task,
     * they soon restart at a different pseudorandom index.  This form
     * of backoff improves throughput when many threads are trying to
     * take tasks from few queues, which can be common in some usages.
     * Scans do not otherwise explicitly take into account core
     * affinities, loads, cache localities, etc, However, they do
     * exploit temporal locality (which usually approximates these) by
     * preferring to re-poll from the same queue after a successful
     * poll before trying others (see method topLevelExec). However
     * this preference is bounded (see TOP_BOUND_SHIFT) as a safeguard
     * against infinitely unfair looping under unbounded user task
     * recursion, and also to reduce long-term contention when many
     * threads poll few queues holding many small tasks. The bound is
     * high enough to avoid much impact on locality and scheduling
     * overhead.
     *
     * Trimming workers. To release resources after periods of lack of
     * use, a worker starting to wait when the pool is quiescent will
     * time out and terminate (see method runWorker) if the pool has
     * remained quiescent for period given by field keepAlive.
     *
     * Shutdown and Termination. A call to shutdownNow invokes
     * tryTerminate to atomically set a runState bit. The calling
     * thread, as well as every other worker thereafter terminating,
     * helps terminate others by cancelling their unprocessed tasks,
     * and waking them up, doing so repeatedly until stable. Calls to
     * non-abrupt shutdown() preface this by checking whether
     * termination should commence by sweeping through queues (until
     * stable) to ensure lack of in-flight submissions and workers
     * about to process them before triggering the "STOP" phase of
     * termination.
     *
     * Joining Tasks
     * =============
     *
     * Any of several actions may be taken when one worker is waiting
     * to join a task stolen (or always held) by another.  Because we
     * are multiplexing many tasks on to a pool of workers, we can't
     * always just let them block (as in Thread.join).  We also cannot
     * just reassign the joiner's run-time stack with another and
     * replace it later, which would be a form of "continuation", that
     * even if possible is not necessarily a good idea since we may
     * need both an unblocked task and its continuation to progress.
     * Instead we combine two tactics:
     *
     *   Helping: Arranging for the joiner to execute some task that it
     *      would be running if the steal had not occurred.
     *
     *   Compensating: Unless there are already enough live threads,
     *      method tryCompensate() may create or re-activate a spare
     *      thread to compensate for blocked joiners until they unblock.
     *
     * A third form (implemented in tryRemoveAndExec) amounts to
     * helping a hypothetical compensator: If we can readily tell that
     * a possible action of a compensator is to steal and execute the
     * task being joined, the joining thread can do so directly,
     * without the need for a compensation thread.
     *
     * The ManagedBlocker extension API can't use helping so relies
     * only on compensation in method awaitBlocker.
     *
     * The algorithm in awaitJoin entails a form of "linear helping".
     * Each worker records (in field source) the id of the queue from
     * which it last stole a task.  The scan in method awaitJoin uses
     * these markers to try to find a worker to help (i.e., steal back
     * a task from and execute it) that could hasten completion of the
     * actively joined task.  Thus, the joiner executes a task that
     * would be on its own local deque if the to-be-joined task had
     * not been stolen. This is a conservative variant of the approach
     * described in Wagner & Calder "Leapfrogging: a portable
     * technique for implementing efficient futures" SIGPLAN Notices,
     * 1993 (http://portal.acm.org/citation.cfm?id=155354). It differs
     * mainly in that we only record queue ids, not full dependency
     * links.  This requires a linear scan of the workQueues array to
     * locate stealers, but isolates cost to when it is needed, rather
     * than adding to per-task overhead. Searches can fail to locate
     * stealers GC stalls and the like delay recording sources.
     * Further, even when accurately identified, stealers might not
     * ever produce a task that the joiner can in turn help with. So,
     * compensation is tried upon failure to find tasks to run.
     *
     * Compensation does not by default aim to keep exactly the target
     * parallelism number of unblocked threads running at any given
     * time. Some previous versions of this class employed immediate
     * compensations for any blocked join. However, in practice, the
     * vast majority of blockages are byproducts of GC and
     * other JVM or OS activities that are made worse by replacement
     * when they cause longer-term oversubscription.  Rather than
     * impose arbitrary policies, we allow users to override the
     * default of only adding threads upon apparent starvation.  The
     * compensation mechanism may also be bounded.  Bounds for the
     * commonPool (see COMMON_MAX_SPARES) better enable JVMs to cope
     * with programming errors and abuse before running out of
     * resources to do so.
     *
     * Common Pool
     * ===========
     *
     * The static common pool always exists after static
     * initialization.  Since it (or any other created pool) need
     * never be used, we minimize initial construction overhead and
     * footprint to the setup of about a dozen fields.
     *
     * When external threads submit to the common pool, they can
     * perform subtask processing (see externalHelpComplete and
     * related methods) upon joins.  This caller-helps policy makes it
     * sensible to set common pool parallelism level to one (or more)
     * less than the total number of available cores, or even zero for
     * pure caller-runs.  We do not need to record whether external
     * submissions are to the common pool -- if not, external help
     * methods return quickly. These submitters would otherwise be
     * blocked waiting for completion, so the extra effort (with
     * liberally sprinkled task status checks) in inapplicable cases
     * amounts to an odd form of limited spin-wait before blocking in
     * ForkJoinTask.join.
     *
     * As a more appropriate default in managed environments, unless
     * overridden by system properties, we use workers of subclass
     * InnocuousForkJoinWorkerThread when there is a SecurityManager
     * present. These workers have no permissions set, do not belong
     * to any user-defined ThreadGroupEx, and erase all ThreadLocals
     * after executing any top-level task (see
     * WorkQueue.afterTopLevelExec).  The associated mechanics (mainly
     * in ForkJoinWorkerThread) may be JVM-dependent and must access
     * particular Thread class fields to achieve this effect.
     *
     * Memory placement
     * ================
     *
     * Performance can be very sensitive to placement of instances of
     * ForkJoinPool and WorkQueues and their queue arrays. To reduce
     * false-sharing impact, the @Contended annotation isolates
     * adjacent WorkQueue instances, as well as the ForkJoinPool.ctl
     * field. WorkQueue arrays are allocated (by their threads) with
     * larger initial sizes than most ever need, mostly to reduce
     * false sharing with current garbage collectors that use cardmark
     * tables.
     *
     * Style notes
     * ===========
     *
     * Memory ordering relies mainly on VarHandles.  This can be
     * awkward and ugly, but also reflects the need to control
     * outcomes across the unusual cases that arise in very racy code
     * with very few invariants. All fields are read into locals
     * before use, and null-checked if they are references.  Array
     * accesses using masked indices include checks (that are always
     * true) that the array length is non-zero to avoid compilers
     * inserting more expensive traps.  This is usually done in a
     * "C"-like style of listing declarations at the heads of methods
     * or blocks, and using inline assignments on first encounter.
     * Nearly all explicit checks lead to bypass/return, not exception
     * throws, because they may legitimately arise due to
     * cancellation/revocation during shutdown.
     *
     * There is a lot of representation-level coupling among classes
     * ForkJoinPool, ForkJoinWorkerThread, and ForkJoinTask.  The
     * fields of WorkQueue maintain data structures managed by
     * ForkJoinPool, so are directly accessed.  There is little point
     * trying to reduce this, since any associated future changes in
     * representations will need to be accompanied by algorithmic
     * changes anyway. Several methods intrinsically sprawl because
     * they must accumulate sets of consistent reads of fields held in
     * local variables. Some others are artificially broken up to
     * reduce producer/consumer imbalances due to dynamic compilation.
     * There are also other coding oddities (including several
     * unnecessary-looking hoisted null checks) that help some methods
     * perform reasonably even when interpreted (not compiled).
     *
     * The order of declarations in this file is (with a few exceptions):
     * (1) Static utility functions
     * (2) Nested (static) classes
     * (3) Static fields
     * (4) Fields, along with constants used when unpacking some of them
     * (5) Internal control methods
     * (6) Callbacks and other support for ForkJoinTask methods
     * (7) Exported methods
     * (8) Static block initializing statics in minimally dependent order
     */

    // Static utilities

    /**
     * If there is a security manager, makes sure caller has
     * permission to modify threads.
     */
    // private static void checkPermission() {
    //     SecurityManager security = System.getSecurityManager();
    //     if (security !is null)
    //         security.checkPermission(modifyThreadPermission);
    // }


    // static fields (initialized in static initializer below)

    /**
     * Creates a new ForkJoinWorkerThread. This factory is used unless
     * overridden in ForkJoinPool constructors.
     */
    __gshared ForkJoinWorkerThreadFactory defaultForkJoinWorkerThreadFactory;

    /**
     * Permission required for callers of methods that may start or
     * kill threads.
     */
    // __gshared RuntimePermission modifyThreadPermission;

    /**
     * Common (static) pool. Non-null for use unless a static
     * construction exception, but internal usages null-check on use
     * to paranoically avoid potential initialization circularities
     * as well as to simplify generated code.
     */
    __gshared ForkJoinPool common;

    /**
     * Common pool parallelism. To allow simpler use and management
     * when common pool threads are disabled, we allow the underlying
     * common.parallelism field to be zero, but in that case still report
     * parallelism as 1 to reflect resulting caller-runs mechanics.
     */
    __gshared int COMMON_PARALLELISM;

    /**
     * Limit on spare thread construction in tryCompensate.
     */
    private __gshared int COMMON_MAX_SPARES;

    /**
     * Sequence number for creating workerNamePrefix.
     */
    private shared static int poolNumberSequence;

    /**
     * Returns the next sequence number. We don't expect this to
     * ever contend, so use simple builtin sync.
     */
    private static int nextPoolId() {
        return AtomicHelper.increment(poolNumberSequence);
    }

    // static configuration constants

    /**
     * Default idle timeout value (in milliseconds) for the thread
     * triggering quiescence to park waiting for new work
     */
    private enum long DEFAULT_KEEPALIVE = 60_000L;

    /**
     * Undershoot tolerance for idle timeouts
     */
    private enum long TIMEOUT_SLOP = 20L;

    /**
     * The default value for COMMON_MAX_SPARES.  Overridable using the
     * "hunt.concurrency.ForkJoinPool.common.maximumSpares" system
     * property.  The default value is far in excess of normal
     * requirements, but also far short of MAX_CAP and typical OS
     * thread limits, so allows JVMs to catch misuse/abuse before
     * running out of resources needed to do so.
     */
    private enum int DEFAULT_COMMON_MAX_SPARES = 256;

    /**
     * Increment for seed generators. See class ThreadLocal for
     * explanation.
     */
    private enum int SEED_INCREMENT = 0x9e3779b9;

    /*
     * Bits and masks for field ctl, packed with 4 16 bit subfields:
     * RC: Number of released (unqueued) workers minus target parallelism
     * TC: Number of total workers minus target parallelism
     * SS: version count and status of top waiting thread
     * ID: poolIndex of top of Treiber stack of waiters
     *
     * When convenient, we can extract the lower 32 stack top bits
     * (including version bits) as sp=(int)ctl.  The offsets of counts
     * by the target parallelism and the positionings of fields makes
     * it possible to perform the most common checks via sign tests of
     * fields: When ac is negative, there are not enough unqueued
     * workers, when tc is negative, there are not enough total
     * workers.  When sp is non-zero, there are waiting workers.  To
     * deal with possibly negative fields, we use casts in and out of
     * "short" and/or signed shifts to maintain signedness.
     *
     * Because it occupies uppermost bits, we can add one release count
     * using getAndAddLong of RC_UNIT, rather than CAS, when returning
     * from a blocked join.  Other updates entail multiple subfields
     * and masking, requiring CAS.
     *
     * The limits packed in field "bounds" are also offset by the
     * parallelism level to make them comparable to the ctl rc and tc
     * fields.
     */

    // Lower and upper word masks
    private enum long SP_MASK    = 0xffffffffL;
    private enum long UC_MASK    = ~SP_MASK;

    // Release counts
    private enum int  RC_SHIFT   = 48;
    private enum long RC_UNIT    = 0x0001L << RC_SHIFT;
    private enum long RC_MASK    = 0xffffL << RC_SHIFT;

    // Total counts
    private enum int  TC_SHIFT   = 32;
    private enum long TC_UNIT    = 0x0001L << TC_SHIFT;
    private enum long TC_MASK    = 0xffffL << TC_SHIFT;
    private enum long ADD_WORKER = 0x0001L << (TC_SHIFT + 15); // sign

    // Instance fields

    long stealCount;            // collects worker nsteals
    Duration keepAlive;                // milliseconds before dropping if idle
    int indexSeed;                       // next worker index
    int bounds;                    // min, max threads packed as shorts
    int mode;                   // parallelism, runstate, queue mode
    WorkQueue[] workQueues;              // main registry
    string workerNamePrefix;       // for worker thread string; sync lock
    Object workerNameLocker;
    ForkJoinWorkerThreadFactory factory;
    UncaughtExceptionHandler ueh;  // per-worker UEH
    Predicate!(ForkJoinPool) saturate;

    // @jdk.internal.vm.annotation.Contended("fjpctl") // segregate
    shared long ctl;                   // main pool control

    // Creating, registering and deregistering workers

    /**
     * Tries to construct and start one worker. Assumes that total
     * count has already been incremented as a reservation.  Invokes
     * deregisterWorker on any failure.
     *
     * @return true if successful
     */
    private bool createWorker() {
        ForkJoinWorkerThreadFactory fac = factory;
        Throwable ex = null;
        ForkJoinWorkerThread wt = null;
        try {
            if (fac !is null && (wt = fac.newThread(this)) !is null) {
                wt.start();
                return true;
            }
        } catch (Throwable rex) {
            ex = rex;
        }
        deregisterWorker(wt, ex);
        return false;
    }

    /**
     * Tries to add one worker, incrementing ctl counts before doing
     * so, relying on createWorker to back out on failure.
     *
     * @param c incoming ctl value, with total count negative and no
     * idle workers.  On CAS failure, c is refreshed and retried if
     * this holds (otherwise, a new worker is not needed).
     */
    private void tryAddWorker(long c) {
        do {
            long nc = ((RC_MASK & (c + RC_UNIT)) |
                       (TC_MASK & (c + TC_UNIT)));
            if (ctl == c && AtomicHelper.compareAndSet(this.ctl, c, nc)) {
                // version(HUNT_CONCURRENCY_DEBUG) tracef("nc=%d, ctl=%d, c=%d", nc, ctl, c);
                createWorker();
                break;
            }
        } while (((c = ctl) & ADD_WORKER) != 0L && cast(int)c == 0);
    }

    /**
     * Callback from ForkJoinWorkerThread constructor to establish and
     * record its WorkQueue.
     *
     * @param wt the worker thread
     * @return the worker's queue
     */
    final WorkQueue registerWorker(ForkJoinWorkerThread wt) {
        UncaughtExceptionHandler handler;
        wt.isDaemon(true);                             // configure thread
        if ((handler = ueh) !is null)
            wt.setUncaughtExceptionHandler(handler);
        int tid = 0;                                    // for thread name
        int idbits = mode & FIFO;
        string prefix = workerNamePrefix;
        WorkQueue w = new WorkQueue(this, wt);
        if (prefix !is null) {
            synchronized (this) {
                WorkQueue[] ws = workQueues; 
                int n;
                int s = indexSeed += SEED_INCREMENT;
                idbits |= (s & ~(SMASK | FIFO | DORMANT));
                if (ws !is null && (n = cast(int)ws.length) > 1) {
                    int m = n - 1;
                    tid = m & ((s << 1) | 1);           // odd-numbered indices
                    for (int probes = n >>> 1;;) {      // find empty slot
                        WorkQueue q;
                        if ((q = ws[tid]) is null || q.phase == QUIET)
                            break;
                        else if (--probes == 0) {
                            tid = n | 1;                // resize below
                            break;
                        }
                        else
                            tid = (tid + 2) & m;
                    }
                    w.phase = w.id = tid | idbits;      // now publishable

                    if (tid < n)
                        ws[tid] = w;
                    else {                              // expand array
                        int an = n << 1;
                        WorkQueue[] as = new WorkQueue[an];
                        as[tid] = w;
                        int am = an - 1;
                        for (int j = 0; j < n; ++j) {
                            WorkQueue v;                // copy external queue
                            if ((v = ws[j]) !is null)    // position may change
                                as[v.id & am & SQMASK] = v;
                            if (++j >= n)
                                break;
                            as[j] = ws[j];              // copy worker
                        }
                        workQueues = as;
                    }
                }
            }
            wt.name(prefix ~ tid.to!string());
        }
        return w;
    }

    /**
     * Final callback from terminating worker, as well as upon failure
     * to construct or start a worker.  Removes record of worker from
     * array, and adjusts counts. If pool is shutting down, tries to
     * complete termination.
     *
     * @param wt the worker thread, or null if construction failed
     * @param ex the exception causing failure, or null if none
     */
    final void deregisterWorker(ForkJoinWorkerThread wt, Throwable ex) {
        WorkQueue w = null;
        int phase = 0;
        if (wt !is null && (w = wt.workQueue) !is null) {
            int wid = w.id;
            long ns = cast(long)w.nsteals & 0xffffffffL;
            if (!workerNamePrefix.empty()) {
                synchronized (this) {
                    WorkQueue[] ws; size_t n, i;         // remove index from array
                    if ((ws = workQueues) !is null && (n = ws.length) > 0 &&
                        ws[i = wid & (n - 1)] == w)
                        ws[i] = null;
                    stealCount += ns;
                }
            }
            phase = w.phase;
        }
        if (phase != QUIET) {                         // else pre-adjusted
            long c;                                   // decrement counts
            do {} while (!AtomicHelper.compareAndSet(this.ctl, c = ctl, 
                ((RC_MASK & (c - RC_UNIT)) |
                (TC_MASK & (c - TC_UNIT)) |
                (SP_MASK & c))));
        }
        if (w !is null)
            w.cancelAll();                            // cancel remaining tasks

        if (!tryTerminate(false, false) &&            // possibly replace worker
            w !is null && w.array !is null)           // avoid repeated failures
            signalWork();

        if (ex !is null)                              // rethrow
            ForkJoinTaskHelper.rethrow(ex);
    }

    /**
     * Tries to create or release a worker if too few are running.
     */
    final void signalWork() {
        for (;;) {
            long c; int sp; WorkQueue[] ws; int i; WorkQueue v;
            if ((c = ctl) >= 0L)                      // enough workers
                break;
            else if ((sp = cast(int)c) == 0) {            // no idle workers
                if ((c & ADD_WORKER) != 0L)           // too few workers
                    tryAddWorker(c);
                break;
            }
            else if ((ws = workQueues) is null)
                break;                                // unstarted/terminated
            else if (ws.length <= (i = sp & SMASK))
                break;                                // terminated
            else if ((v = ws[i]) is null)
                break;                                // terminating
            else {
                int np = sp & ~UNSIGNALLED;
                int vp = v.phase;
                long nc = (v.stackPred & SP_MASK) | (UC_MASK & (c + RC_UNIT));
                Thread vt = v.owner;
                if (sp == vp && AtomicHelper.compareAndSet(this.ctl, c, nc)) {
                    v.phase = np;
                    if (vt !is null && v.source < 0)
                        LockSupport.unpark(vt);
                    break;
                }
            }
        }
    }

    /**
     * Tries to decrement counts (sometimes implicitly) and possibly
     * arrange for a compensating worker in preparation for blocking:
     * If not all core workers yet exist, creates one, else if any are
     * unreleased (possibly including caller) releases one, else if
     * fewer than the minimum allowed number of workers running,
     * checks to see that they are all active, and if so creates an
     * extra worker unless over maximum limit and policy is to
     * saturate.  Most of these steps can fail due to interference, in
     * which case 0 is returned so caller will retry. A negative
     * return value indicates that the caller doesn't need to
     * re-adjust counts when later unblocked.
     *
     * @return 1: block then adjust, -1: block without adjust, 0 : retry
     */
    private int tryCompensate(WorkQueue w) {
        int t, n, sp;
        long c = ctl;
        WorkQueue[] ws = workQueues;
        if ((t = cast(short)(c >>> TC_SHIFT)) >= 0) {
            if (ws is null || (n = cast(int)ws.length) <= 0 || w is null)
                return 0;                        // disabled
            else if ((sp = cast(int)c) != 0) {       // replace or release
                WorkQueue v = ws[sp & (n - 1)];
                int wp = w.phase;
                long uc = UC_MASK & ((wp < 0) ? c + RC_UNIT : c);
                int np = sp & ~UNSIGNALLED;
                if (v !is null) {
                    int vp = v.phase;
                    Thread vt = v.owner;
                    long nc = (cast(long)v.stackPred & SP_MASK) | uc;
                    if (vp == sp && AtomicHelper.compareAndSet(this.ctl, c, nc)) {
                        v.phase = np;
                        if (vt !is null && v.source < 0)
                            LockSupport.unpark(vt);
                        return (wp < 0) ? -1 : 1;
                    }
                }
                return 0;
            }
            else if (cast(int)(c >> RC_SHIFT) -      // reduce parallelism
                     cast(short)(bounds & SMASK) > 0) {
                long nc = ((RC_MASK & (c - RC_UNIT)) | (~RC_MASK & c));
                return AtomicHelper.compareAndSet(this.ctl, c, nc) ? 1 : 0;
            }
            else {                               // validate
                int md = mode, pc = md & SMASK, tc = pc + t, bc = 0;
                bool unstable = false;
                for (int i = 1; i < n; i += 2) {
                    WorkQueue q; ThreadEx wt; ThreadState ts;
                    if ((q = ws[i]) !is null) {
                        if (q.source == 0) {
                            unstable = true;
                            break;
                        }
                        else {
                            --tc;
                            if ((wt = q.owner) !is null &&
                                ((ts = wt.getState()) == ThreadState.BLOCKED ||
                                 ts == ThreadState.WAITING))
                                ++bc;            // worker is blocking
                        }
                    }
                }
                if (unstable || tc != 0 || ctl != c)
                    return 0;                    // inconsistent
                else if (t + pc >= MAX_CAP || t >= (bounds >>> SWIDTH)) {
                    Predicate!(ForkJoinPool) sat;
                    if ((sat = saturate) !is null && sat(this))
                        return -1;
                    else if (bc < pc) {          // lagging
                        Thread.yield();          // for retry spins
                        return 0;
                    }
                    else
                        throw new RejectedExecutionException(
                            "Thread limit exceeded replacing blocked worker");
                }
            }
        }

        long nc = ((c + TC_UNIT) & TC_MASK) | (c & ~TC_MASK); // expand pool
        return AtomicHelper.compareAndSet(this.ctl, c, nc) && createWorker() ? 1 : 0;
    }

    /**
     * Top-level runloop for workers, called by ForkJoinWorkerThread.run.
     * See above for explanation.
     */
    final void runWorker(WorkQueue w) {
        int r = (w.id ^ ThreadLocalRandom.nextSecondarySeed()) | FIFO; // rng
        w.array = new IForkJoinTask[INITIAL_QUEUE_CAPACITY]; // initialize
        while(true) {
            int phase;
            if (scan(w, r)) {                     // scan until apparently empty
                r ^= r << 13; r ^= r >>> 17; r ^= r << 5; // move (xorshift)
            }
            else if ((phase = w.phase) >= 0) {    // enqueue, then rescan
                long np = (w.phase = (phase + SS_SEQ) | UNSIGNALLED) & SP_MASK;
                long c, nc;
                do {
                    w.stackPred = cast(int)(c = ctl);
                    nc = ((c - RC_UNIT) & UC_MASK) | np;
                } while (!AtomicHelper.compareAndSet(this.ctl, c, nc));

                version(HUNT_CONCURRENCY_DEBUG) {
                    // infof("ctl=%d, c=%d, nc=%d, stackPred=%d", ctl, c, nc, w.stackPred);
                }
            }
            else {                                // already queued

                int pred = w.stackPred;
                ThreadEx.interrupted();           // clear before park
                w.source = DORMANT;               // enable signal
                long c = ctl;
                int md = mode, rc = (md & SMASK) + cast(int)(c >> RC_SHIFT);

                version(HUNT_CONCURRENCY_DEBUG) {
                    // tracef("md=%d, rc=%d, c=%d, pred=%d, phase=%d", md, rc, c, pred, phase);
                }

                if (md < 0) {                      // terminating
                    break;
                } else if (rc <= 0 && (md & SHUTDOWN) != 0 && tryTerminate(false, false)) {
                    break;                        // quiescent shutdown
                } else if (rc <= 0 && pred != 0 && phase == cast(int)c) {
                    long nc = (UC_MASK & (c - TC_UNIT)) | (SP_MASK & pred);
                    MonoTime d = MonoTime.currTime + keepAlive; // DateTime.currentTimeMillis();
                    LockSupport.parkUntil(this, d);
                    if (ctl == c &&               // drop on timeout if all idle
                        d - MonoTime.currTime <= TIMEOUT_SLOP.msecs &&
                        AtomicHelper.compareAndSet(this.ctl, c, nc)) {
                        w.phase = QUIET;
                        break;
                    }
                } else if (w.phase < 0) {
                    LockSupport.park(this);       // OK if spuriously woken
            break;
                }
                w.source = 0;                     // disable signal
            }
        }
    }

    /**
     * Scans for and if found executes one or more top-level tasks from a queue.
     *
     * @return true if found an apparently non-empty queue, and
     * possibly ran task(s).
     */
    private bool scan(WorkQueue w, int r) {
        WorkQueue[] ws; int n;
        if ((ws = workQueues) !is null && (n = cast(int)ws.length) > 0 && w !is null) {
            for (int m = n - 1, j = r & m;;) {
                WorkQueue q; int b;
                if ((q = ws[j]) !is null && q.top != (b = q.base)) {
                    int qid = q.id;
                    IForkJoinTask[] a; 
                    size_t cap, k; 
                    IForkJoinTask t;

                    if ((a = q.array) !is null && (cap = cast(int)a.length) > 0) {
                        k = (cap - 1) & b;
                        // import core.atomic;  
                        // auto ss =     core.atomic.atomicLoad((cast(shared)a[k]));   
                        // FIXME: Needing refactor or cleanup -@zxp at 2/6/2019, 5:12:19 PM               
                        // IForkJoinTask tt = a[k];
                        // t = AtomicHelper.load(tt);
                        t = a[k];
                        // tracef("k=%d, t is null: %s", k, t is null);
                        if (q.base == b++ && t !is null && 
                                AtomicHelper.compareAndSet(a[k], t, cast(IForkJoinTask)null)) {
                            q.base = b;
                            w.source = qid;
                            if (q.top - b > 0) signalWork();

                            // infof("IForkJoinTask: %s", typeid(cast(Object)t));
                            w.topLevelExec(t, q,  // random fairness bound
                                           r & ((n << TOP_BOUND_SHIFT) - 1));
                        }
                    }
                    return true;
                }
                else if (--n > 0) {
                    j = (j + 1) & m;
                }
                else {
                    break;
                }
            }
        }
        return false;
    }

    /**
     * Helps and/or blocks until the given task is done or timeout.
     * First tries locally helping, then scans other queues for a task
     * produced by one of w's stealers; compensating and blocking if
     * none are found (rescanning if tryCompensate fails).
     *
     * @param w caller
     * @param task the task
     * @param deadline for timed waits, if nonzero
     * @return task status on exit
     */
    final int awaitJoin(WorkQueue w, IForkJoinTask task, MonoTime deadline) {
        if(w is null || task is null) {
            return 0;
        }
        int s = 0;
        int seed = ThreadLocalRandom.nextSecondarySeed();
        ICountedCompleter cc = cast(ICountedCompleter)task;
        if(cc !is null) {
            s = w.helpCC(cc, 0, false);
            if(s<0)
                return 0;
        }

        w.tryRemoveAndExec(task);
        int src = w.source, id = w.id;
        int r = (seed >>> 16) | 1, step = (seed & ~1) | 2;
        s = task.getStatus();
        while (s >= 0) {
            WorkQueue[] ws;
            int n = (ws = workQueues) is null ? 0 : cast(int)ws.length, m = n - 1;
            while (n > 0) {
                WorkQueue q; int b;
                if ((q = ws[r & m]) !is null && q.source == id &&
                    q.top != (b = q.base)) {
                    IForkJoinTask[] a; int cap, k;
                    int qid = q.id;
                    if ((a = q.array) !is null && (cap = cast(int)a.length) > 0) {
                        k = (cap - 1) & b;
                        // FIXME: Needing refactor or cleanup -@zxp at 2/6/2019, 5:13:08 PM
                        // 
                        // IForkJoinTask t = AtomicHelper.load(a[k]);
                        IForkJoinTask t = a[k];
                        if (q.source == id && q.base == b++ &&
                            t !is null && AtomicHelper.compareAndSet(a[k], t, cast(IForkJoinTask)null)) {
                            q.base = b;
                            w.source = qid;
                            t.doExec();
                            w.source = src;
                        }
                    }
                    break;
                }
                else {
                    r += step;
                    --n;
                }
            }

            if ((s = task.getStatus()) < 0)
                break;
            else if (n == 0) { // empty scan
                long ms; int block;
                Duration ns;
                if (deadline == MonoTime.zero())
                    ms = 0L;                       // untimed
                else if ((ns = deadline - MonoTime.currTime) <= Duration.zero())
                    break;                         // timeout
                else if ((ms = ns.total!(TimeUnit.Millisecond)()) <= 0L)
                    ms = 1L;                       // avoid 0 for timed wait
                if ((block = tryCompensate(w)) != 0) {
                    task.internalWait(ms);
                    AtomicHelper.getAndAdd(this.ctl, (block > 0) ? RC_UNIT : 0L);
                }
                s = task.getStatus();
            }
        }
        return s;
    }

    /**
     * Runs tasks until {@code isQuiescent()}. Rather than blocking
     * when tasks cannot be found, rescans until all others cannot
     * find tasks either.
     */
    final void helpQuiescePool(WorkQueue w) {
        int prevSrc = w.source;
        int seed = ThreadLocalRandom.nextSecondarySeed();
        int r = seed >>> 16, step = r | 1;
        for (int source = prevSrc, released = -1;;) { // -1 until known
            IForkJoinTask localTask; WorkQueue[] ws;
            while ((localTask = w.nextLocalTask()) !is null)
                localTask.doExec();
            if (w.phase >= 0 && released == -1)
                released = 1;
            bool quiet = true, empty = true;
            int n = (ws = workQueues) is null ? 0 : cast(int)ws.length;
            for (int m = n - 1; n > 0; r += step, --n) {
                WorkQueue q; int b;
                if ((q = ws[r & m]) !is null) {
                    int qs = q.source;
                    if (q.top != (b = q.base)) {
                        quiet = empty = false;
                        IForkJoinTask[] a; int cap, k;
                        int qid = q.id;
                        if ((a = q.array) !is null && (cap = cast(int)a.length) > 0) {
                            if (released == 0) {    // increment
                                released = 1;
                                AtomicHelper.getAndAdd(this.ctl, RC_UNIT);
                            }
                            k = (cap - 1) & b;
                            // IForkJoinTask t = AtomicHelper.load(a[k]);
                            // FIXME: Needing refactor or cleanup -@zxp at 2/6/2019, 9:32:07 PM
                            // 
                            IForkJoinTask t = a[k];
                            if (q.base == b++ && t !is null) {
                                if(AtomicHelper.compareAndSet(a[k], t, null)) {
                                    q.base = b;
                                    w.source = qid;
                                    t.doExec();
                                    w.source = source = prevSrc;
                                }
                            }
                        }
                        break;
                    }
                    else if ((qs & QUIET) == 0)
                        quiet = false;
                }
            }
            if (quiet) {
                if (released == 0) {
                    AtomicHelper.getAndAdd(this.ctl, RC_UNIT);
                }
                w.source = prevSrc;
                break;
            }
            else if (empty) {
                if (source != QUIET)
                    w.source = source = QUIET;
                if (released == 1) {                 // decrement
                    released = 0;
                    AtomicHelper.getAndAdd(this.ctl, RC_MASK & -RC_UNIT);
                }
            }
        }
    }

    /**
     * Scans for and returns a polled task, if available.
     * Used only for untracked polls.
     *
     * @param submissionsOnly if true, only scan submission queues
     */
    private IForkJoinTask pollScan(bool submissionsOnly) {
        WorkQueue[] ws; int n;
        rescan: while ((mode & STOP) == 0 && (ws = workQueues) !is null &&
                      (n = cast(int)ws.length) > 0) {
            int m = n - 1;
            int r = ThreadLocalRandom.nextSecondarySeed();
            int h = r >>> 16;
            int origin, step;
            if (submissionsOnly) {
                origin = (r & ~1) & m;         // even indices and steps
                step = (h & ~1) | 2;
            }
            else {
                origin = r & m;
                step = h | 1;
            }
            bool nonempty = false;
            for (int i = origin, oldSum = 0, checkSum = 0;;) {
                WorkQueue q;
                if ((q = ws[i]) !is null) {
                    int b; IForkJoinTask t;
                    if (q.top - (b = q.base) > 0) {
                        nonempty = true;
                        if ((t = q.poll()) !is null)
                            return t;
                    }
                    else
                        checkSum += b + q.id;
                }
                if ((i = (i + step) & m) == origin) {
                    if (!nonempty && oldSum == (oldSum = checkSum))
                        break rescan;
                    checkSum = 0;
                    nonempty = false;
                }
            }
        }
        return null;
    }

    /**
     * Gets and removes a local or stolen task for the given worker.
     *
     * @return a task, if available
     */
    final IForkJoinTask nextTaskFor(WorkQueue w) {
        IForkJoinTask t;
        if (w is null || (t = w.nextLocalTask()) is null)
            t = pollScan(false);
        return t;
    }

    // External operations

    /**
     * Adds the given task to a submission queue at submitter's
     * current queue, creating one if null or contended.
     *
     * @param task the task. Caller must ensure non-null.
     */
    final void externalPush(IForkJoinTask task) {
        // initialize caller's probe
        int r = ThreadLocalRandom.getProbe();
        if (r == 0) {
            ThreadLocalRandom.localInit();
            r = ThreadLocalRandom.getProbe();
        }

        for (;;) {
            WorkQueue q;
            int md = mode, n;
            WorkQueue[] ws = workQueues;
            if ((md & SHUTDOWN) != 0 || ws is null || (n = cast(int)ws.length) <= 0)
                throw new RejectedExecutionException();
            else if ((q = ws[(n - 1) & r & SQMASK]) is null) { // add queue
                int qid = (r | QUIET) & ~(FIFO | OWNED);
                Object lock = workerNameLocker;
                IForkJoinTask[] qa =
                    new IForkJoinTask[INITIAL_QUEUE_CAPACITY];
                q = new WorkQueue(this, null);
                q.array = qa;
                q.id = qid;
                q.source = QUIET;
                if (lock !is null) {     // unless disabled, lock pool to install
                    synchronized (lock) {
                        WorkQueue[] vs; int i, vn;
                        if ((vs = workQueues) !is null && (vn = cast(int)vs.length) > 0 &&
                            vs[i = qid & (vn - 1) & SQMASK] is null)
                            vs[i] = q;  // else another thread already installed
                    }
                }
            }
            else if (!q.tryLockPhase()) // move if busy
                r = ThreadLocalRandom.advanceProbe(r);
            else {
                if (q.lockedPush(task))
                    signalWork();
                return;
            }
        }
    }

    /**
     * Pushes a possibly-external submission.
     */
    private IForkJoinTask externalSubmit(IForkJoinTask task) {
        if (task is null)
            throw new NullPointerException();
        ForkJoinWorkerThread w = cast(ForkJoinWorkerThread)Thread.getThis(); 
        WorkQueue q;
        if ( w !is null && w.pool is this &&
            (q = w.workQueue) !is null)
            q.push(task);
        else
            externalPush(task);
        return task;
    }

    private ForkJoinTask!(T) externalSubmit(T)(ForkJoinTask!(T) task) {
        if (task is null)
            throw new NullPointerException();
        ForkJoinWorkerThread w = cast(ForkJoinWorkerThread)Thread.getThis(); 
        WorkQueue q;
        if ( w !is null && w.pool is this &&
            (q = w.workQueue) !is null)
            q.push(task);
        else
            externalPush(task);
        return task;
    }

    /**
     * Returns common pool queue for an external thread.
     */
    static WorkQueue commonSubmitterQueue() {
        ForkJoinPool p = common;
        int r = ThreadLocalRandom.getProbe();
        WorkQueue[] ws; int n;
        return (p !is null && (ws = p.workQueues) !is null &&
                (n = cast(int)ws.length) > 0) ?
            ws[(n - 1) & r & SQMASK] : null;
    }

    /**
     * Performs tryUnpush for an external submitter.
     */
    final bool tryExternalUnpush(IForkJoinTask task) {
        int r = ThreadLocalRandom.getProbe();
        WorkQueue[] ws; WorkQueue w; int n;
        return ((ws = workQueues) !is null &&
                (n = cast(int)ws.length) > 0 &&
                (w = ws[(n - 1) & r & SQMASK]) !is null &&
                w.tryLockedUnpush(task));
    }

    /**
     * Performs helpComplete for an external submitter.
     */
    final int externalHelpComplete(ICountedCompleter task, int maxTasks) {
        int r = ThreadLocalRandom.getProbe();
        WorkQueue[] ws; WorkQueue w; int n;
        return ((ws = workQueues) !is null && (n = cast(int)ws.length) > 0 &&
                (w = ws[(n - 1) & r & SQMASK]) !is null) ?
            w.helpCC(task, maxTasks, true) : 0;
    }

    /**
     * Tries to steal and run tasks within the target's computation.
     * The maxTasks argument supports external usages; internal calls
     * use zero, allowing unbounded steps (external calls trap
     * non-positive values).
     *
     * @param w caller
     * @param maxTasks if non-zero, the maximum number of other tasks to run
     * @return task status on exit
     */
    final int helpComplete(WorkQueue w, ICountedCompleter task,
                           int maxTasks) {
        return (w is null) ? 0 : w.helpCC(task, maxTasks, false);
    }

    /**
     * Returns a cheap heuristic guide for task partitioning when
     * programmers, frameworks, tools, or languages have little or no
     * idea about task granularity.  In essence, by offering this
     * method, we ask users only about tradeoffs in overhead vs
     * expected throughput and its variance, rather than how finely to
     * partition tasks.
     *
     * In a steady state strict (tree-structured) computation, each
     * thread makes available for stealing enough tasks for other
     * threads to remain active. Inductively, if all threads play by
     * the same rules, each thread should make available only a
     * constant number of tasks.
     *
     * The minimum useful constant is just 1. But using a value of 1
     * would require immediate replenishment upon each steal to
     * maintain enough tasks, which is infeasible.  Further,
     * partitionings/granularities of offered tasks should minimize
     * steal rates, which in general means that threads nearer the top
     * of computation tree should generate more than those nearer the
     * bottom. In perfect steady state, each thread is at
     * approximately the same level of computation tree. However,
     * producing extra tasks amortizes the uncertainty of progress and
     * diffusion assumptions.
     *
     * So, users will want to use values larger (but not much larger)
     * than 1 to both smooth over shortages and hedge
     * against uneven progress; as traded off against the cost of
     * extra task overhead. We leave the user to pick a threshold
     * value to compare with the results of this call to guide
     * decisions, but recommend values such as 3.
     *
     * When all threads are active, it is on average OK to estimate
     * surplus strictly locally. In steady-state, if one thread is
     * maintaining say 2 surplus tasks, then so are others. So we can
     * just use estimated queue length.  However, this strategy alone
     * leads to serious mis-estimates in some non-steady-state
     * conditions (ramp-up, ramp-down, other stalls). We can detect
     * many of these by further considering the number of "idle"
     * threads, that are known to have zero queued tasks, so
     * compensate by a factor of (#idle/#active) threads.
     */
    static int getSurplusQueuedTaskCount() {
        Thread t = Thread.getThis(); 
        ForkJoinWorkerThread wt = cast(ForkJoinWorkerThread)t; 
        ForkJoinPool pool; WorkQueue q;

        if (wt !is null && (pool = wt.pool) !is null &&
            (q = wt.workQueue) !is null) {
            int p = pool.mode & SMASK;
            int a = p + cast(int)(pool.ctl >> RC_SHIFT);
            int n = q.top - q.base;
            return n - (a > (p >>>= 1) ? 0 :
                        a > (p >>>= 1) ? 1 :
                        a > (p >>>= 1) ? 2 :
                        a > (p >>>= 1) ? 4 :
                        8);
        }
        return 0;
    }

    // Termination

    /**
     * Possibly initiates and/or completes termination.
     *
     * @param now if true, unconditionally terminate, else only
     * if no work and no active workers
     * @param enable if true, terminate when next possible
     * @return true if terminating or terminated
     */
    private bool tryTerminate(bool now, bool enable) {
        int md; // 3 phases: try to set SHUTDOWN, then STOP, then TERMINATED

        while (((md = mode) & SHUTDOWN) == 0) {
            if (!enable || this == common)        // cannot shutdown
                return false;
            else {
                AtomicHelper.compareAndSet(this.mode, md, md | SHUTDOWN);
            }
                
        }

        while (((md = mode) & STOP) == 0) {       // try to initiate termination
            if (!now) {                           // check if quiescent & empty
                for (long oldSum = 0L;;) {        // repeat until stable
                    bool running = false;
                    long checkSum = ctl;
                    WorkQueue[] ws = workQueues;
                    if ((md & SMASK) + cast(int)(checkSum >> RC_SHIFT) > 0)
                        running = true;
                    else if (ws !is null) {
                        WorkQueue w;
                        for (int i = 0; i < ws.length; ++i) {
                            if ((w = ws[i]) !is null) {
                                int s = w.source, p = w.phase;
                                int d = w.id, b = w.base;
                                if (b != w.top ||
                                    ((d & 1) == 1 && (s >= 0 || p >= 0))) {
                                    running = true;
                                    break;     // working, scanning, or have work
                                }
                                checkSum += ((cast(long)s << 48) + (cast(long)p << 32) +
                                             (cast(long)b << 16) + cast(long)d);
                            }
                        }
                    }
                    if (((md = mode) & STOP) != 0)
                        break;                 // already triggered
                    else if (running)
                        return false;
                    else if (workQueues == ws && oldSum == (oldSum = checkSum))
                        break;
                }
            }
            if ((md & STOP) == 0)
                AtomicHelper.compareAndSet(this.mode, md, md | STOP);
        }

        while (((md = mode) & TERMINATED) == 0) { // help terminate others
            for (long oldSum = 0L;;) {            // repeat until stable
                WorkQueue[] ws; WorkQueue w;
                long checkSum = ctl;
                if ((ws = workQueues) !is null) {
                    for (int i = 0; i < ws.length; ++i) {
                        if ((w = ws[i]) !is null) {
                            ForkJoinWorkerThread wt = w.owner;
                            w.cancelAll();        // clear queues
                            if (wt !is null) {
                                try {             // unblock join or park
                                    wt.interrupt();
                                } catch (Throwable ignore) {
                                }
                            }
                            checkSum += (cast(long)w.phase << 32) + w.base;
                        }
                    }
                }
                if (((md = mode) & TERMINATED) != 0 ||
                    (workQueues == ws && oldSum == (oldSum = checkSum)))
                    break;
            }
            if ((md & TERMINATED) != 0)
                break;
            else if ((md & SMASK) + cast(short)(ctl >>> TC_SHIFT) > 0)
                break;
            else if (AtomicHelper.compareAndSet(this.mode, md, md | TERMINATED)) {
                synchronized (this) {
                    // notifyAll();                  // for awaitTermination
                    // TODO: Tasks pending completion -@zxp at 2/4/2019, 11:03:21 AM
                    // 
                }
                break;
            }
        }
        return true;
    }

    // Exported methods

    // Constructors

    /**
     * Creates a {@code ForkJoinPool} with parallelism equal to {@link
     * java.lang.Runtime#availableProcessors}, using defaults for all
     * other parameters (see {@link #ForkJoinPool(int,
     * ForkJoinWorkerThreadFactory, UncaughtExceptionHandler, bool,
     * int, int, int, Predicate, long, TimeUnit)}).
     *
     * @throws SecurityException if a security manager exists and
     *         the caller is not permitted to modify threads
     *         because it does not hold {@link
     *         java.lang.RuntimePermission}{@code ("modifyThread")}
     */
    this() {
        this(min(MAX_CAP, totalCPUs),
             defaultForkJoinWorkerThreadFactory, null, false,
             0, MAX_CAP, 1, null, dur!(TimeUnit.Millisecond)(DEFAULT_KEEPALIVE));
    }

    /**
     * Creates a {@code ForkJoinPool} with the indicated parallelism
     * level, using defaults for all other parameters (see {@link
     * #ForkJoinPool(int, ForkJoinWorkerThreadFactory,
     * UncaughtExceptionHandler, bool, int, int, int, Predicate,
     * long, TimeUnit)}).
     *
     * @param parallelism the parallelism level
     * @throws IllegalArgumentException if parallelism less than or
     *         equal to zero, or greater than implementation limit
     * @throws SecurityException if a security manager exists and
     *         the caller is not permitted to modify threads
     *         because it does not hold {@link
     *         java.lang.RuntimePermission}{@code ("modifyThread")}
     */
    this(int parallelism) {
        this(parallelism, defaultForkJoinWorkerThreadFactory, null, false,
             0, MAX_CAP, 1, null, dur!(TimeUnit.Millisecond)(DEFAULT_KEEPALIVE));
    }

    /**
     * Creates a {@code ForkJoinPool} with the given parameters (using
     * defaults for others -- see {@link #ForkJoinPool(int,
     * ForkJoinWorkerThreadFactory, UncaughtExceptionHandler, bool,
     * int, int, int, Predicate, long, TimeUnit)}).
     *
     * @param parallelism the parallelism level. For default value,
     * use {@link java.lang.Runtime#availableProcessors}.
     * @param factory the factory for creating new threads. For default value,
     * use {@link #defaultForkJoinWorkerThreadFactory}.
     * @param handler the handler for internal worker threads that
     * terminate due to unrecoverable errors encountered while executing
     * tasks. For default value, use {@code null}.
     * @param asyncMode if true,
     * establishes local first-in-first-out scheduling mode for forked
     * tasks that are never joined. This mode may be more appropriate
     * than default locally stack-based mode in applications in which
     * worker threads only process event-style asynchronous tasks.
     * For default value, use {@code false}.
     * @throws IllegalArgumentException if parallelism less than or
     *         equal to zero, or greater than implementation limit
     * @throws NullPointerException if the factory is null
     * @throws SecurityException if a security manager exists and
     *         the caller is not permitted to modify threads
     *         because it does not hold {@link
     *         java.lang.RuntimePermission}{@code ("modifyThread")}
     */
    this(int parallelism,
                        ForkJoinWorkerThreadFactory factory,
                        UncaughtExceptionHandler handler,
                        bool asyncMode) {
        this(parallelism, factory, handler, asyncMode,
             0, MAX_CAP, 1, null, dur!(TimeUnit.Millisecond)(DEFAULT_KEEPALIVE));
    }

    /**
     * Creates a {@code ForkJoinPool} with the given parameters.
     *
     * @param parallelism the parallelism level. For default value,
     * use {@link java.lang.Runtime#availableProcessors}.
     *
     * @param factory the factory for creating new threads. For
     * default value, use {@link #defaultForkJoinWorkerThreadFactory}.
     *
     * @param handler the handler for internal worker threads that
     * terminate due to unrecoverable errors encountered while
     * executing tasks. For default value, use {@code null}.
     *
     * @param asyncMode if true, establishes local first-in-first-out
     * scheduling mode for forked tasks that are never joined. This
     * mode may be more appropriate than default locally stack-based
     * mode in applications in which worker threads only process
     * event-style asynchronous tasks.  For default value, use {@code
     * false}.
     *
     * @param corePoolSize the number of threads to keep in the pool
     * (unless timed out after an elapsed keep-alive). Normally (and
     * by default) this is the same value as the parallelism level,
     * but may be set to a larger value to reduce dynamic overhead if
     * tasks regularly block. Using a smaller value (for example
     * {@code 0}) has the same effect as the default.
     *
     * @param maximumPoolSize the maximum number of threads allowed.
     * When the maximum is reached, attempts to replace blocked
     * threads fail.  (However, because creation and termination of
     * different threads may overlap, and may be managed by the given
     * thread factory, this value may be transiently exceeded.)  To
     * arrange the same value as is used by default for the common
     * pool, use {@code 256} plus the {@code parallelism} level. (By
     * default, the common pool allows a maximum of 256 spare
     * threads.)  Using a value (for example {@code
     * Integer.MAX_VALUE}) larger than the implementation's total
     * thread limit has the same effect as using this limit (which is
     * the default).
     *
     * @param minimumRunnable the minimum allowed number of core
     * threads not blocked by a join or {@link ManagedBlocker}.  To
     * ensure progress, when too few unblocked threads exist and
     * unexecuted tasks may exist, new threads are constructed, up to
     * the given maximumPoolSize.  For the default value, use {@code
     * 1}, that ensures liveness.  A larger value might improve
     * throughput in the presence of blocked activities, but might
     * not, due to increased overhead.  A value of zero may be
     * acceptable when submitted tasks cannot have dependencies
     * requiring additional threads.
     *
     * @param saturate if non-null, a predicate invoked upon attempts
     * to create more than the maximum total allowed threads.  By
     * default, when a thread is about to block on a join or {@link
     * ManagedBlocker}, but cannot be replaced because the
     * maximumPoolSize would be exceeded, a {@link
     * RejectedExecutionException} is thrown.  But if this predicate
     * returns {@code true}, then no exception is thrown, so the pool
     * continues to operate with fewer than the target number of
     * runnable threads, which might not ensure progress.
     *
     * @param keepAliveTime the elapsed time since last use before
     * a thread is terminated (and then later replaced if needed).
     * For the default value, use {@code 60, TimeUnit.SECONDS}.
     *
     * @param unit the time unit for the {@code keepAliveTime} argument
     *
     * @throws IllegalArgumentException if parallelism is less than or
     *         equal to zero, or is greater than implementation limit,
     *         or if maximumPoolSize is less than parallelism,
     *         of if the keepAliveTime is less than or equal to zero.
     * @throws NullPointerException if the factory is null
     * @throws SecurityException if a security manager exists and
     *         the caller is not permitted to modify threads
     *         because it does not hold {@link
     *         java.lang.RuntimePermission}{@code ("modifyThread")}
     */
    this(int parallelism,
                        ForkJoinWorkerThreadFactory factory,
                        UncaughtExceptionHandler handler,
                        bool asyncMode,
                        int corePoolSize,
                        int maximumPoolSize,
                        int minimumRunnable,
                        Predicate!(ForkJoinPool) saturate,
                        Duration keepAliveTime) {
        // check, encode, pack parameters
        if (parallelism <= 0 || parallelism > MAX_CAP ||
            maximumPoolSize < parallelism || keepAliveTime <= Duration.zero)
            throw new IllegalArgumentException();
        if (factory is null)
            throw new NullPointerException();
        long ms = max(keepAliveTime.total!(TimeUnit.Millisecond), TIMEOUT_SLOP);

        int corep = min(max(corePoolSize, parallelism), MAX_CAP);
        long c = (((cast(long)(-corep)       << TC_SHIFT) & TC_MASK) |
                  ((cast(long)(-parallelism) << RC_SHIFT) & RC_MASK));
        int m = parallelism | (asyncMode ? FIFO : 0);
        int maxSpares = min(maximumPoolSize, MAX_CAP) - parallelism;
        int minAvail = min(max(minimumRunnable, 0), MAX_CAP);
        int b = ((minAvail - parallelism) & SMASK) | (maxSpares << SWIDTH);
        int n = (parallelism > 1) ? parallelism - 1 : 1; // at least 2 slots
        n |= n >>> 1; n |= n >>> 2; n |= n >>> 4; n |= n >>> 8; n |= n >>> 16;
        n = (n + 1) << 1; // power of two, including space for submission queues

        this.workerNamePrefix = "ForkJoinPool-" ~ nextPoolId().to!string() ~ "-worker-";
        this.workQueues = new WorkQueue[n];
        this.factory = factory;
        this.ueh = handler;
        this.saturate = saturate;
        this.keepAlive = ms.msecs;
        this.bounds = b;
        this.mode = m;
        this.ctl = c;
        // checkPermission();
        workerNameLocker = new Object(); 
    }

    private static Object newInstanceFrom(string className) {
        return (className.empty) ? null : Object.factory(className);
    }

    /**
     * Constructor for common pool using parameters possibly
     * overridden by system properties
     */
    private this(byte forCommonPoolOnly) {
        int parallelism = -1;
        ForkJoinWorkerThreadFactory fac = null;
        UncaughtExceptionHandler handler = null;
        try {  // ignore exceptions in accessing/parsing properties
            ConfigBuilder config = Environment.getProperties();
            string pp = config.getProperty("hunt.concurrency.ForkJoinPool.common.parallelism");
            if (!pp.empty) {
                parallelism = pp.to!int();
            }

            string className = config.getProperty("hunt.concurrency.ForkJoinPool.common.threadFactory");
            fac = cast(ForkJoinWorkerThreadFactory) newInstanceFrom(className);

            className = config.getProperty("hunt.concurrency.ForkJoinPool.common.exceptionHandler");
            handler = cast(UncaughtExceptionHandler) newInstanceFrom(className);
        } catch (Exception ignore) {
            version(HUNT_DEBUG) {
                warning(ignore);
            }
        }

        if (fac is null) {
            // if (System.getSecurityManager() is null)
                fac = defaultForkJoinWorkerThreadFactory;
            // else // use security-managed default
            //     fac = new InnocuousForkJoinWorkerThreadFactory();
        }
        if (parallelism < 0 && // default 1 less than #cores
            (parallelism = totalCPUs - 1) <= 0)
            parallelism = 1;
        if (parallelism > MAX_CAP)
            parallelism = MAX_CAP;

        long c = (((cast(long)(-parallelism) << TC_SHIFT) & TC_MASK) |
                  ((cast(long)(-parallelism) << RC_SHIFT) & RC_MASK));
        int b = ((1 - parallelism) & SMASK) | (COMMON_MAX_SPARES << SWIDTH);
        int n = (parallelism > 1) ? parallelism - 1 : 1;
        n |= n >>> 1; n |= n >>> 2; n |= n >>> 4; n |= n >>> 8; n |= n >>> 16;
        n = (n + 1) << 1;

        this.workerNamePrefix = "ForkJoinPool.commonPool-worker-";
        this.workerNameLocker = new Object(); 
        this.workQueues = new WorkQueue[n];
        this.factory = fac;
        this.ueh = handler;
        this.saturate = null;
        this.keepAlive = DEFAULT_KEEPALIVE.msecs;
        this.bounds = b;
        this.mode = parallelism;
        this.ctl = c;
    }

    /**
     * Returns the common pool instance. This pool is statically
     * constructed; its run state is unaffected by attempts to {@link
     * #shutdown} or {@link #shutdownNow}. However this pool and any
     * ongoing processing are automatically terminated upon program
     * {@link System#exit}.  Any program that relies on asynchronous
     * task processing to complete before program termination should
     * invoke {@code commonPool().}{@link #awaitQuiescence awaitQuiescence},
     * before exit.
     *
     * @return the common pool instance
     */
    static ForkJoinPool commonPool() {
        return common;
    }

    // Execution methods

    /**
     * Performs the given task, returning its result upon completion.
     * If the computation encounters an unchecked Exception or Error,
     * it is rethrown as the outcome of this invocation.  Rethrown
     * exceptions behave in the same way as regular exceptions, but,
     * when possible, contain stack traces (as displayed for example
     * using {@code ex.printStackTrace()}) of both the current thread
     * as well as the thread actually encountering the exception;
     * minimally only the latter.
     *
     * @param task the task
     * @param (T) the type of the task's result
     * @return the task's result
     * @throws NullPointerException if the task is null
     * @throws RejectedExecutionException if the task cannot be
     *         scheduled for execution
     */
    T invoke(T)(ForkJoinTask!(T) task) {
        if (task is null)
            throw new NullPointerException();
        externalSubmit!(T)(task);
        version(HUNT_CONCURRENCY_DEBUG) {
            infof("waiting the result...");
            T c = task.join();
            infof("final result: %s", c);
            return c;
        } else {
            return task.join();
        }
    }

    /**
     * Arranges for (asynchronous) execution of the given task.
     *
     * @param task the task
     * @throws NullPointerException if the task is null
     * @throws RejectedExecutionException if the task cannot be
     *         scheduled for execution
     */
    void execute(IForkJoinTask task) {
        externalSubmit(task);
    }

    // AbstractExecutorService methods

    /**
     * @throws NullPointerException if the task is null
     * @throws RejectedExecutionException if the task cannot be
     *         scheduled for execution
     */
    void execute(Runnable task) {
        if (task is null)
            throw new NullPointerException();
        IForkJoinTask job = cast(IForkJoinTask) task;
        if (job is null) { // avoid re-wrap
            warning("job is null");
            job = new RunnableExecuteAction(task);
        }
        externalSubmit(job);
    }

    /**
     * Submits a ForkJoinTask for execution.
     *
     * @param task the task to submit
     * @param (T) the type of the task's result
     * @return the task
     * @throws NullPointerException if the task is null
     * @throws RejectedExecutionException if the task cannot be
     *         scheduled for execution
     */
    ForkJoinTask!(T) submitTask(T)(ForkJoinTask!(T) task) {
        return externalSubmit(task);
    }

    /**
     * @throws NullPointerException if the task is null
     * @throws RejectedExecutionException if the task cannot be
     *         scheduled for execution
     */
    ForkJoinTask!(T) submitTask(T)(Callable!(T) task) {
        return externalSubmit(new AdaptedCallable!(T)(task));
    }

    /**
     * @throws NullPointerException if the task is null
     * @throws RejectedExecutionException if the task cannot be
     *         scheduled for execution
     */
    ForkJoinTask!(T) submitTask(T)(Runnable task, T result) {
        return externalSubmit(new AdaptedRunnable!(T)(task, result));
    }

    /**
     * @throws NullPointerException if the task is null
     * @throws RejectedExecutionException if the task cannot be
     *         scheduled for execution
     */

    IForkJoinTask submitTask(Runnable task) {
        if (task is null)
            throw new NullPointerException();
        IForkJoinTask t = cast(IForkJoinTask)task;
        return externalSubmit(t !is null
            ? cast(ForkJoinTask!(void)) task // avoid re-wrap
            : new AdaptedRunnableAction(task));
    }

    /**
     * @throws NullPointerException       {@inheritDoc}
     * @throws RejectedExecutionException {@inheritDoc}
     */
    List!(Future!(T)) invokeAll(T)(Collection!(Callable!(T)) tasks) {
        // In previous versions of this class, this method constructed
        // a task to run ForkJoinTask.invokeAll, but now external
        // invocation of multiple tasks is at least as efficient.
        ArrayList!(Future!(T)) futures = new ArrayList!(Future!(T))(tasks.size());

        try {
            foreach (Callable!(T) t ; tasks) {
                ForkJoinTask!(T) f = new AdaptedCallable!(T)(t);
                futures.add(f);
                externalSubmit(f);
            }
            for (int i = 0, size = futures.size(); i < size; i++)
                (cast(IForkJoinTask)(futures.get(i))).quietlyJoin();
            return futures;
        } catch (Throwable t) {
            for (int i = 0, size = futures.size(); i < size; i++)
                futures.get(i).cancel(false);
            throw t;
        }
    }

    /**
     * Returns the factory used for constructing new workers.
     *
     * @return the factory used for constructing new workers
     */
    ForkJoinWorkerThreadFactory getFactory() {
        return factory;
    }

    /**
     * Returns the handler for internal worker threads that terminate
     * due to unrecoverable errors encountered while executing tasks.
     *
     * @return the handler, or {@code null} if none
     */
    UncaughtExceptionHandler getUncaughtExceptionHandler() {
        return ueh;
    }

    /**
     * Returns the targeted parallelism level of this pool.
     *
     * @return the targeted parallelism level of this pool
     */
    int getParallelism() {
        int par = mode & SMASK;
        return (par > 0) ? par : 1;
    }

    /**
     * Returns the targeted parallelism level of the common pool.
     *
     * @return the targeted parallelism level of the common pool
     */
    static int getCommonPoolParallelism() {
        return COMMON_PARALLELISM;
    }

    /**
     * Returns the number of worker threads that have started but not
     * yet terminated.  The result returned by this method may differ
     * from {@link #getParallelism} when threads are created to
     * maintain parallelism when others are cooperatively blocked.
     *
     * @return the number of worker threads
     */
    int getPoolSize() {
        return ((mode & SMASK) + cast(short)(ctl >>> TC_SHIFT));
    }

    /**
     * Returns {@code true} if this pool uses local first-in-first-out
     * scheduling mode for forked tasks that are never joined.
     *
     * @return {@code true} if this pool uses async mode
     */
    bool getAsyncMode() {
        return (mode & FIFO) != 0;
    }

    /**
     * Returns an estimate of the number of worker threads that are
     * not blocked waiting to join tasks or for other managed
     * synchronization. This method may overestimate the
     * number of running threads.
     *
     * @return the number of worker threads
     */
    int getRunningThreadCount() {
        WorkQueue[] ws; WorkQueue w;
        // VarHandle.acquireFence();
        int rc = 0;
        if ((ws = workQueues) !is null) {
            for (int i = 1; i < cast(int)ws.length; i += 2) {
                if ((w = ws[i]) !is null && w.isApparentlyUnblocked())
                    ++rc;
            }
        }
        return rc;
    }

    /**
     * Returns an estimate of the number of threads that are currently
     * stealing or executing tasks. This method may overestimate the
     * number of active threads.
     *
     * @return the number of active threads
     */
    int getActiveThreadCount() {
        int r = (mode & SMASK) + cast(int)(ctl >> RC_SHIFT);
        return (r <= 0) ? 0 : r; // suppress momentarily negative values
    }

    /**
     * Returns {@code true} if all worker threads are currently idle.
     * An idle worker is one that cannot obtain a task to execute
     * because none are available to steal from other threads, and
     * there are no pending submissions to the pool. This method is
     * conservative; it might not return {@code true} immediately upon
     * idleness of all threads, but will eventually become true if
     * threads remain inactive.
     *
     * @return {@code true} if all threads are currently idle
     */
    bool isQuiescent() {
        for (;;) {
            long c = ctl;
            int md = mode, pc = md & SMASK;
            int tc = pc + cast(short)(c >>> TC_SHIFT);
            int rc = pc + cast(int)(c >> RC_SHIFT);
            if ((md & (STOP | TERMINATED)) != 0)
                return true;
            else if (rc > 0)
                return false;
            else {
                WorkQueue[] ws; WorkQueue v;
                if ((ws = workQueues) !is null) {
                    for (int i = 1; i < ws.length; i += 2) {
                        if ((v = ws[i]) !is null) {
                            if (v.source > 0)
                                return false;
                            --tc;
                        }
                    }
                }
                if (tc == 0 && ctl == c)
                    return true;
            }
        }
    }

    /**
     * Returns an estimate of the total number of tasks stolen from
     * one thread's work queue by another. The reported value
     * underestimates the actual total number of steals when the pool
     * is not quiescent. This value may be useful for monitoring and
     * tuning fork/join programs: in general, steal counts should be
     * high enough to keep threads busy, but low enough to avoid
     * overhead and contention across threads.
     *
     * @return the number of steals
     */
    long getStealCount() {
        long count = stealCount;
        WorkQueue[] ws; WorkQueue w;
        if ((ws = workQueues) !is null) {
            for (int i = 1; i < ws.length; i += 2) {
                if ((w = ws[i]) !is null)
                    count += cast(long)w.nsteals & 0xffffffffL;
            }
        }
        return count;
    }

    /**
     * Returns an estimate of the total number of tasks currently held
     * in queues by worker threads (but not including tasks submitted
     * to the pool that have not begun executing). This value is only
     * an approximation, obtained by iterating across all threads in
     * the pool. This method may be useful for tuning task
     * granularities.
     *
     * @return the number of queued tasks
     */
    long getQueuedTaskCount() {
        WorkQueue[] ws; WorkQueue w;
        // VarHandle.acquireFence();
        int count = 0;
        if ((ws = workQueues) !is null) {
            for (int i = 1; i < cast(int)ws.length; i += 2) {
                if ((w = ws[i]) !is null)
                    count += w.queueSize();
            }
        }
        return count;
    }

    /**
     * Returns an estimate of the number of tasks submitted to this
     * pool that have not yet begun executing.  This method may take
     * time proportional to the number of submissions.
     *
     * @return the number of queued submissions
     */
    int getQueuedSubmissionCount() {
        WorkQueue[] ws; WorkQueue w;
        // VarHandle.acquireFence();
        int count = 0;
        if ((ws = workQueues) !is null) {
            for (int i = 0; i < cast(int)ws.length; i += 2) {
                if ((w = ws[i]) !is null)
                    count += w.queueSize();
            }
        }
        return count;
    }

    /**
     * Returns {@code true} if there are any tasks submitted to this
     * pool that have not yet begun executing.
     *
     * @return {@code true} if there are any queued submissions
     */
    bool hasQueuedSubmissions() {
        WorkQueue[] ws; WorkQueue w;
        // VarHandle.acquireFence();
        if ((ws = workQueues) !is null) {
            for (int i = 0; i < cast(int)ws.length; i += 2) {
                if ((w = ws[i]) !is null && !w.isEmpty())
                    return true;
            }
        }
        return false;
    }

    /**
     * Removes and returns the next unexecuted submission if one is
     * available.  This method may be useful in extensions to this
     * class that re-assign work in systems with multiple pools.
     *
     * @return the next submission, or {@code null} if none
     */
    protected IForkJoinTask pollSubmission() {
        return pollScan(true);
    }

    /**
     * Removes all available unexecuted submitted and forked tasks
     * from scheduling queues and adds them to the given collection,
     * without altering their execution status. These may include
     * artificially generated or wrapped tasks. This method is
     * designed to be invoked only when the pool is known to be
     * quiescent. Invocations at other times may not remove all
     * tasks. A failure encountered while attempting to add elements
     * to collection {@code c} may result in elements being in
     * neither, either or both collections when the associated
     * exception is thrown.  The behavior of this operation is
     * undefined if the specified collection is modified while the
     * operation is in progress.
     *
     * @param c the collection to transfer elements into
     * @return the number of elements transferred
     */
    protected int drainTasksTo(Collection!IForkJoinTask c) {
        WorkQueue[] ws; WorkQueue w; IForkJoinTask t;
        // VarHandle.acquireFence();
        int count = 0;
        if ((ws = workQueues) !is null) {
            for (int i = 0; i < ws.length; ++i) {
                if ((w = ws[i]) !is null) {
                    while ((t = w.poll()) !is null) {
                        c.add(t);
                        ++count;
                    }
                }
            }
        }
        return count;
    }

    /**
     * Returns a string identifying this pool, as well as its state,
     * including indications of run state, parallelism level, and
     * worker and task counts.
     *
     * @return a string identifying this pool, as well as its state
     */
    override string toString() {
        // Use a single pass through workQueues to collect counts
        int md = mode; // read fields first
        long c = ctl;
        long st = stealCount;
        long qt = 0L, qs = 0L; int rc = 0;
        WorkQueue[] ws; WorkQueue w;
        if ((ws = workQueues) !is null) {
            for (int i = 0; i < ws.length; ++i) {
                if ((w = ws[i]) !is null) {
                    int size = w.queueSize();
                    if ((i & 1) == 0)
                        qs += size;
                    else {
                        qt += size;
                        st += cast(long)w.nsteals & 0xffffffffL;
                        if (w.isApparentlyUnblocked())
                            ++rc;
                    }
                }
            }
        }

        int pc = (md & SMASK);
        int tc = pc + cast(short)(c >>> TC_SHIFT);
        int ac = pc + cast(int)(c >> RC_SHIFT);
        if (ac < 0) // ignore negative
            ac = 0;
        string level = ((md & TERMINATED) != 0 ? "Terminated" :
                        (md & STOP)       != 0 ? "Terminating" :
                        (md & SHUTDOWN)   != 0 ? "Shutting down" :
                        "Running");
        return super.toString() ~
            "[" ~ level ~
            ", parallelism = " ~ pc.to!string() ~
            ", size = " ~ tc.to!string() ~
            ", active = " ~ ac.to!string() ~
            ", running = " ~ rc.to!string() ~
            ", steals = " ~ st.to!string() ~
            ", tasks = " ~ qt.to!string() ~
            ", submissions = " ~ qs.to!string() ~
            "]";
    }

    /**
     * Possibly initiates an orderly shutdown in which previously
     * submitted tasks are executed, but no new tasks will be
     * accepted. Invocation has no effect on execution state if this
     * is the {@link #commonPool()}, and no additional effect if
     * already shut down.  Tasks that are in the process of being
     * submitted concurrently during the course of this method may or
     * may not be rejected.
     *
     * @throws SecurityException if a security manager exists and
     *         the caller is not permitted to modify threads
     *         because it does not hold {@link
     *         java.lang.RuntimePermission}{@code ("modifyThread")}
     */
    void shutdown() {
        // checkPermission();
        tryTerminate(false, true);
    }

    /**
     * Possibly attempts to cancel and/or stop all tasks, and reject
     * all subsequently submitted tasks.  Invocation has no effect on
     * execution state if this is the {@link #commonPool()}, and no
     * additional effect if already shut down. Otherwise, tasks that
     * are in the process of being submitted or executed concurrently
     * during the course of this method may or may not be
     * rejected. This method cancels both existing and unexecuted
     * tasks, in order to permit termination in the presence of task
     * dependencies. So the method always returns an empty list
     * (unlike the case for some other Executors).
     *
     * @return an empty list
     * @throws SecurityException if a security manager exists and
     *         the caller is not permitted to modify threads
     *         because it does not hold {@link
     *         java.lang.RuntimePermission}{@code ("modifyThread")}
     */
    List!(Runnable) shutdownNow() {
        // checkPermission();
        tryTerminate(true, true);
        return Collections.emptyList!(Runnable)();
    }

    /**
     * Returns {@code true} if all tasks have completed following shut down.
     *
     * @return {@code true} if all tasks have completed following shut down
     */
    bool isTerminated() {
        return (mode & TERMINATED) != 0;
    }

    /**
     * Returns {@code true} if the process of termination has
     * commenced but not yet completed.  This method may be useful for
     * debugging. A return of {@code true} reported a sufficient
     * period after shutdown may indicate that submitted tasks have
     * ignored or suppressed interruption, or are waiting for I/O,
     * causing this executor not to properly terminate. (See the
     * advisory notes for class {@link ForkJoinTask} stating that
     * tasks should not normally entail blocking operations.  But if
     * they do, they must abort them on interrupt.)
     *
     * @return {@code true} if terminating but not yet terminated
     */
    bool isTerminating() {
        int md = mode;
        return (md & STOP) != 0 && (md & TERMINATED) == 0;
    }

    /**
     * Returns {@code true} if this pool has been shut down.
     *
     * @return {@code true} if this pool has been shut down
     */
    bool isShutdown() {
        return (mode & SHUTDOWN) != 0;
    }

    /**
     * Blocks until all tasks have completed execution after a
     * shutdown request, or the timeout occurs, or the current thread
     * is interrupted, whichever happens first. Because the {@link
     * #commonPool()} never terminates until program shutdown, when
     * applied to the common pool, this method is equivalent to {@link
     * #awaitQuiescence(long, TimeUnit)} but always returns {@code false}.
     *
     * @param timeout the maximum time to wait
     * @param unit the time unit of the timeout argument
     * @return {@code true} if this executor terminated and
     *         {@code false} if the timeout elapsed before termination
     * @throws InterruptedException if interrupted while waiting
     */
    bool awaitTermination(Duration timeout)
        {
        if (ThreadEx.interrupted())
            throw new InterruptedException();
        if (this == common) {
            awaitQuiescence(timeout);
            return false;
        }
        long nanos = timeout.total!(TimeUnit.HectoNanosecond);
        if (isTerminated())
            return true;
        if (nanos <= 0L)
            return false;
        long deadline = Clock.currStdTime + nanos;
        synchronized (this) {
            for (;;) {
                if (isTerminated())
                    return true;
                if (nanos <= 0L)
                    return false;
                // long millis = TimeUnit.NANOSECONDS.toMillis(nanos);
                // wait(millis > 0L ? millis : 1L);
                // ThreadEx.currentThread().par
                ThreadEx.sleep(dur!(TimeUnit.HectoNanosecond)(nanos));
                nanos = deadline - Clock.currStdTime;
            }
        }
    }

    /**
     * If called by a ForkJoinTask operating in this pool, equivalent
     * in effect to {@link ForkJoinTask#helpQuiesce}. Otherwise,
     * waits and/or attempts to assist performing tasks until this
     * pool {@link #isQuiescent} or the indicated timeout elapses.
     *
     * @param timeout the maximum time to wait
     * @param unit the time unit of the timeout argument
     * @return {@code true} if quiescent; {@code false} if the
     * timeout elapsed.
     */
    bool awaitQuiescence(Duration timeout) {
        long nanos = timeout.total!(TimeUnit.HectoNanosecond)();
        Thread thread = Thread.getThis();
        ForkJoinWorkerThread wt = cast(ForkJoinWorkerThread)thread;
        if (wt !is null && wt.pool is this) {
            helpQuiescePool(wt.workQueue);
            return true;
        }
        else {
            for (long startTime = Clock.currStdTime;;) {
                IForkJoinTask t;
                if ((t = pollScan(false)) !is null)
                    t.doExec();
                else if (isQuiescent())
                    return true;
                else if ((Clock.currStdTime - startTime) > nanos)
                    return false;
                else
                    Thread.yield(); // cannot block
            }
        }
    }

    /**
     * Waits and/or attempts to assist performing tasks indefinitely
     * until the {@link #commonPool()} {@link #isQuiescent}.
     */
    static void quiesceCommonPool() {
        common.awaitQuiescence(Duration.max);
    }

    /**
     * Runs the given possibly blocking task.  When {@linkplain
     * ForkJoinTask#inForkJoinPool() running in a ForkJoinPool}, this
     * method possibly arranges for a spare thread to be activated if
     * necessary to ensure sufficient parallelism while the current
     * thread is blocked in {@link ManagedBlocker#block blocker.block()}.
     *
     * <p>This method repeatedly calls {@code blocker.isReleasable()} and
     * {@code blocker.block()} until either method returns {@code true}.
     * Every call to {@code blocker.block()} is preceded by a call to
     * {@code blocker.isReleasable()} that returned {@code false}.
     *
     * <p>If not running in a ForkJoinPool, this method is
     * behaviorally equivalent to
     * <pre> {@code
     * while (!blocker.isReleasable())
     *   if (blocker.block())
     *     break;}</pre>
     *
     * If running in a ForkJoinPool, the pool may first be expanded to
     * ensure sufficient parallelism available during the call to
     * {@code blocker.block()}.
     *
     * @param blocker the blocker task
     * @throws InterruptedException if {@code blocker.block()} did so
     */
    static void managedBlock(ManagedBlocker blocker) {
        if (blocker is null) throw new NullPointerException();
        ForkJoinPool p;
        WorkQueue w;
        Thread t = Thread.getThis();
        ForkJoinWorkerThread wt = cast(ForkJoinWorkerThread)t;
        if (wt !is null && (p = wt.pool) !is null &&
            (w = wt.workQueue) !is null) {
            int block;
            while (!blocker.isReleasable()) {
                if ((block = p.tryCompensate(w)) != 0) {
                    try {
                        do {} while (!blocker.isReleasable() &&
                                     !blocker.block());
                    } finally {
                        AtomicHelper.getAndAdd(p.ctl, (block > 0) ? RC_UNIT : 0L);
                    }
                    break;
                }
            }
        }
        else {
            do {} while (!blocker.isReleasable() &&
                         !blocker.block());
        }
    }

    /**
     * If the given executor is a ForkJoinPool, poll and execute
     * AsynchronousCompletionTasks from worker's queue until none are
     * available or blocker is released.
     */
    static void helpAsyncBlocker(Executor e, ManagedBlocker blocker) {
        ForkJoinPool p = cast(ForkJoinPool)e;
        if (p !is null) {
            WorkQueue w; WorkQueue[] ws; int r, n;
            
            Thread thread = Thread.getThis();
            ForkJoinWorkerThread wt = cast(ForkJoinWorkerThread)thread; 
            if (wt !is null && wt.pool is p)
                w = wt.workQueue;
            else if ((r = ThreadLocalRandom.getProbe()) != 0 &&
                     (ws = p.workQueues) !is null && (n = cast(int)ws.length) > 0)
                w = ws[(n - 1) & r & SQMASK];
            else
                w = null;
            if (w !is null)
                w.helpAsyncBlocker(blocker);
        }
    }

    // AbstractExecutorService overrides.  These rely on undocumented
    // fact that ForkJoinTask.adapt returns ForkJoinTasks that also
    // implement RunnableFuture.

    protected RunnableFuture!(T) newTaskFor(T)(Runnable runnable, T value) {
        return new AdaptedRunnable!(T)(runnable, value);
    }

    protected RunnableFuture!(T) newTaskFor(T)(Callable!(T) callable) {
        return new AdaptedCallable!(T)(callable);
    }

    shared static this() {
        int commonMaxSpares = DEFAULT_COMMON_MAX_SPARES;
        try {
            ConfigBuilder config = Environment.getProperties();
            string p = config.getProperty
                ("hunt.concurrency.ForkJoinPool.common.maximumSpares");
            if (!p.empty())
                commonMaxSpares = p.to!int();
        } catch (Exception ignore) {
            version(HUNT_DEBUG) warning(ignore.toString());
        }
        COMMON_MAX_SPARES = commonMaxSpares;

        defaultForkJoinWorkerThreadFactory =
            new DefaultForkJoinWorkerThreadFactory();
        common = new ForkJoinPool(cast(byte)0);
        COMMON_PARALLELISM = max(common.mode & SMASK, 1);
    }
}


/**
 * Factory for innocuous worker threads.
 */
private final class InnocuousForkJoinWorkerThreadFactory
    : ForkJoinWorkerThreadFactory {

    /**
     * An ACC to restrict permissions for the factory itself.
     * The constructed workers have no permissions set.
     */
    // private static final AccessControlContext ACC = contextWithPermissions(
    //     modifyThreadPermission,
    //     new RuntimePermission("enableContextClassLoaderOverride"),
    //     new RuntimePermission("modifyThreadGroup"),
    //     new RuntimePermission("getClassLoader"),
    //     new RuntimePermission("setContextClassLoader"));

    final ForkJoinWorkerThread newThread(ForkJoinPool pool) {
        return new InnocuousForkJoinWorkerThread(pool);
        // return AccessController.doPrivileged(
        //     new PrivilegedAction<>() {
        //         ForkJoinWorkerThread run() {
        //             return new ForkJoinWorkerThread.
        //                 InnocuousForkJoinWorkerThread(pool); }},
        //     ACC);
    }
}


/**
 * Factory for creating new {@link ForkJoinWorkerThread}s.
 * A {@code ForkJoinWorkerThreadFactory} must be defined and used
 * for {@code ForkJoinWorkerThread} subclasses that extend base
 * functionality or initialize threads with different contexts.
 */
interface ForkJoinWorkerThreadFactory {
    /**
     * Returns a new worker thread operating in the given pool.
     * Returning null or throwing an exception may result in tasks
     * never being executed.  If this method throws an exception,
     * it is relayed to the caller of the method (for example
     * {@code execute}) causing attempted thread creation. If this
     * method returns null or throws an exception, it is not
     * retried until the next attempted creation (for example
     * another call to {@code execute}).
     *
     * @param pool the pool this thread works in
     * @return the new worker thread, or {@code null} if the request
     *         to create a thread is rejected
     * @throws NullPointerException if the pool is null
     */
    ForkJoinWorkerThread newThread(ForkJoinPool pool);
}    

// Nested classes

// static AccessControlContext contextWithPermissions(Permission ... perms) {
//     Permissions permissions = new Permissions();
//     for (Permission perm : perms)
//         permissions.add(perm);
//     return new AccessControlContext(
//         new ProtectionDomain[] { new ProtectionDomain(null, permissions) });
// }

/**
 * Default ForkJoinWorkerThreadFactory implementation; creates a
 * new ForkJoinWorkerThread using the system class loader as the
 * thread context class loader.
 */
private final class DefaultForkJoinWorkerThreadFactory : ForkJoinWorkerThreadFactory {
    // private static final AccessControlContext ACC = contextWithPermissions(
    //     new RuntimePermission("getClassLoader"),
    //     new RuntimePermission("setContextClassLoader"));

    final ForkJoinWorkerThread newThread(ForkJoinPool pool) {
        return new ForkJoinWorkerThread(pool);
        // return AccessController.doPrivileged(
        //     new PrivilegedAction<>() {
        //         ForkJoinWorkerThread run() {
        //             return new ForkJoinWorkerThread(
        //                 pool, ClassLoader.getSystemClassLoader()); }},
        //     ACC);
    }
}


/**
 * Interface for extending managed parallelism for tasks running
 * in {@link ForkJoinPool}s.
 *
 * <p>A {@code ManagedBlocker} provides two methods.  Method
 * {@link #isReleasable} must return {@code true} if blocking is
 * not necessary. Method {@link #block} blocks the current thread
 * if necessary (perhaps internally invoking {@code isReleasable}
 * before actually blocking). These actions are performed by any
 * thread invoking {@link ForkJoinPool#managedBlock(ManagedBlocker)}.
 * The unusual methods in this API accommodate synchronizers that
 * may, but don't usually, block for long periods. Similarly, they
 * allow more efficient internal handling of cases in which
 * additional workers may be, but usually are not, needed to
 * ensure sufficient parallelism.  Toward this end,
 * implementations of method {@code isReleasable} must be amenable
 * to repeated invocation.
 *
 * <p>For example, here is a ManagedBlocker based on a
 * ReentrantLock:
 * <pre> {@code
 * class ManagedLocker implements ManagedBlocker {
 *   final ReentrantLock lock;
 *   bool hasLock = false;
 *   ManagedLocker(ReentrantLock lock) { this.lock = lock; }
 *   bool block() {
 *     if (!hasLock)
 *       lock.lock();
 *     return true;
 *   }
 *   bool isReleasable() {
 *     return hasLock || (hasLock = lock.tryLock());
 *   }
 * }}</pre>
 *
 * <p>Here is a class that possibly blocks waiting for an
 * item on a given queue:
 * <pre> {@code
 * class QueueTaker!(E) : ManagedBlocker {
 *   final BlockingQueue!(E) queue;
 *   E item = null;
 *   QueueTaker(BlockingQueue!(E) q) { this.queue = q; }
 *   bool block() {
 *     if (item is null)
 *       item = queue.take();
 *     return true;
 *   }
 *   bool isReleasable() {
 *     return item !is null || (item = queue.poll()) !is null;
 *   }
 *   E getItem() { // call after pool.managedBlock completes
 *     return item;
 *   }
 * }}</pre>
 */
static interface ManagedBlocker {
    /**
     * Possibly blocks the current thread, for example waiting for
     * a lock or condition.
     *
     * @return {@code true} if no additional blocking is necessary
     * (i.e., if isReleasable would return true)
     * @throws InterruptedException if interrupted while waiting
     * (the method is not required to do so, but is allowed to)
     */
    bool block();

    /**
     * Returns {@code true} if blocking is unnecessary.
     * @return {@code true} if blocking is unnecessary
     */
    bool isReleasable();
}



/**
 * A thread managed by a {@link ForkJoinPool}, which executes
 * {@link ForkJoinTask}s.
 * This class is subclassable solely for the sake of adding
 * functionality -- there are no overridable methods dealing with
 * scheduling or execution.  However, you can override initialization
 * and termination methods surrounding the main task processing loop.
 * If you do create such a subclass, you will also need to supply a
 * custom {@link ForkJoinPool.ForkJoinWorkerThreadFactory} to
 * {@linkplain ForkJoinPool#ForkJoinPool(int, ForkJoinWorkerThreadFactory,
 * UncaughtExceptionHandler, bool, int, int, int, Predicate, long, TimeUnit)
 * use it} in a {@code ForkJoinPool}.
 *
 * @author Doug Lea
 */
class ForkJoinWorkerThread : ThreadEx {
    /*
     * ForkJoinWorkerThreads are managed by ForkJoinPools and perform
     * ForkJoinTasks. For explanation, see the internal documentation
     * of class ForkJoinPool.
     *
     * This class just maintains links to its pool and WorkQueue.  The
     * pool field is set immediately upon construction, but the
     * workQueue field is not set until a call to registerWorker
     * completes. This leads to a visibility race, that is tolerated
     * by requiring that the workQueue field is only accessed by the
     * owning thread.
     *
     * Support for (non-public) subclass InnocuousForkJoinWorkerThread
     * requires that we break quite a lot of encapsulation (via helper
     * methods in ThreadLocalRandom) both here and in the subclass to
     * access and set Thread fields.
     */

    ForkJoinPool pool;                // the pool this thread works in
    WorkQueue workQueue;              // work-stealing mechanics

    /**
     * Creates a ForkJoinWorkerThread operating in the given pool.
     *
     * @param pool the pool this thread works in
     * @throws NullPointerException if pool is null
     */
    protected this(ForkJoinPool pool) {
        // Use a placeholder until a useful name can be set in registerWorker
        super("aForkJoinWorkerThread");
        this.pool = pool;
        this.workQueue = pool.registerWorker(this);
    }

    /**
     * Version for use by the default pool.  Supports setting the
     * context class loader.  This is a separate constructor to avoid
     * affecting the protected constructor.
     */
    // this(ForkJoinPool pool, ClassLoader ccl) {
    //     super("aForkJoinWorkerThread");
    //     super.setContextClassLoader(ccl);
    //     this.pool = pool;
    //     this.workQueue = pool.registerWorker(this);
    // }

    /**
     * Version for InnocuousForkJoinWorkerThread.
     */
    this(ForkJoinPool pool,
                        //  ClassLoader ccl,
                         ThreadGroupEx threadGroup,
                        ) { //  AccessControlContext acc
        super(threadGroup, null, "aForkJoinWorkerThread");
        // super.setContextClassLoader(ccl);
        // ThreadLocalRandom.setInheritedAccessControlContext(this, acc);
        // ThreadLocalRandom.eraseThreadLocals(this); // clear before registering
        this.pool = pool;
        this.workQueue = pool.registerWorker(this);
    }

    /**
     * Returns the pool hosting this thread.
     *
     * @return the pool
     */
    ForkJoinPool getPool() {
        return pool;
    }

    /**
     * Returns the unique index number of this thread in its pool.
     * The returned value ranges from zero to the maximum number of
     * threads (minus one) that may exist in the pool, and does not
     * change during the lifetime of the thread.  This method may be
     * useful for applications that track status or collect results
     * per-worker-thread rather than per-task.
     *
     * @return the index number
     */
    int getPoolIndex() {
        return workQueue.getPoolIndex();
    }

    /**
     * Initializes internal state after construction but before
     * processing any tasks. If you override this method, you must
     * invoke {@code super.onStart()} at the beginning of the method.
     * Initialization requires care: Most fields must have legal
     * default values, to ensure that attempted accesses from other
     * threads work correctly even before this thread starts
     * processing tasks.
     */
    protected void onStart() {
    }

    /**
     * Performs cleanup associated with termination of this worker
     * thread.  If you override this method, you must invoke
     * {@code super.onTermination} at the end of the overridden method.
     *
     * @param exception the exception causing this thread to abort due
     * to an unrecoverable error, or {@code null} if completed normally
     */
    protected void onTermination(Throwable exception) {
    }

    /**
     * This method is required to be public, but should never be
     * called explicitly. It performs the main run loop to execute
     * {@link ForkJoinTask}s.
     */
    override void run() {
        if (workQueue.array !is null)
            return;
        // only run once
        Throwable exception = null;

        try {
            onStart();
            pool.runWorker(workQueue);
        } catch (Throwable ex) {
            version(HUNT_DEBUG) {
                warning(ex);
            } else {
                warning(ex.msg);
            }
            exception = ex;
        }

        try {
            onTermination(exception);
        } catch(Throwable ex) {
            version(HUNT_DEBUG) {
                warning(ex);
            } else {
                warning(ex.msg);
            }
            if (exception is null)
                exception = ex;
        }
        pool.deregisterWorker(this, exception);  
    }

    /**
     * Non-hook method for InnocuousForkJoinWorkerThread.
     */
    void afterTopLevelExec() {
    }


    int awaitJoin(IForkJoinTask task) {
        int s = task.getStatus(); 
        WorkQueue w = workQueue;
            if(w.tryUnpush(task) && (s = task.doExec()) < 0 )
                return s;
            else
                return pool.awaitJoin(w, task, MonoTime.zero());
    }

    /**
     * If the current thread is operating in a ForkJoinPool,
     * unschedules and returns, without executing, a task externally
     * submitted to the pool, if one is available. Availability may be
     * transient, so a {@code null} result does not necessarily imply
     * quiescence of the pool.  This method is designed primarily to
     * support extensions, and is unlikely to be useful otherwise.
     *
     * @return a task, or {@code null} if none are available
     */
    protected static IForkJoinTask pollSubmission() {
        ForkJoinWorkerThread t = cast(ForkJoinWorkerThread)Thread.getThis();
        return t !is null ? t.pool.pollSubmission() : null;
    }
}


/**
 * A worker thread that has no permissions, is not a member of any
 * user-defined ThreadGroupEx, uses the system class loader as
 * thread context class loader, and erases all ThreadLocals after
 * running each top-level task.
 */
final class InnocuousForkJoinWorkerThread : ForkJoinWorkerThread {
    /** The ThreadGroupEx for all InnocuousForkJoinWorkerThreads */
    private __gshared ThreadGroupEx innocuousThreadGroup;
        // AccessController.doPrivileged(new PrivilegedAction<>() {
        //     ThreadGroupEx run() {
        //         ThreadGroupEx group = Thread.getThis().getThreadGroup();
        //         for (ThreadGroupEx p; (p = group.getParent()) !is null; )
        //             group = p;
        //         return new ThreadGroupEx(
        //             group, "InnocuousForkJoinWorkerThreadGroup");
        //     }});

    /** An AccessControlContext supporting no privileges */
    // private static final AccessControlContext INNOCUOUS_ACC =
    //     new AccessControlContext(
    //         new ProtectionDomain[] { new ProtectionDomain(null, null) });

    shared static this() {
        // ThreadGroupEx group = Thread.getThis().getThreadGroup();
        // for (ThreadGroupEx p; (p = group.getParent()) !is null; )
        //     group = p;
        innocuousThreadGroup = new ThreadGroupEx(
                    null, "InnocuousForkJoinWorkerThreadGroup");
    }

    this(ForkJoinPool pool) {
        super(pool,
            //   ClassLoader.getSystemClassLoader(),
              innocuousThreadGroup,
            //   INNOCUOUS_ACC
              );
    }

    override // to erase ThreadLocals
    void afterTopLevelExec() {
        // ThreadLocalRandom.eraseThreadLocals(this);
    }

    override // to silently fail
    void setUncaughtExceptionHandler(UncaughtExceptionHandler x) { }

    // override // paranoically
    // void setContextClassLoader(ClassLoader cl) {
    //     throw new SecurityException("setContextClassLoader");
    // }
}


/**
 * Queues supporting work-stealing as well as external task
 * submission. See above for descriptions and algorithms.
 */
final class WorkQueue {
    int source;       // source queue id, or sentinel
    int id;                    // pool index, mode, tag
    shared int base;                  // index of next slot for poll
    shared int top;                   // index of next slot for push
    shared int phase;        // versioned, negative: queued, 1: locked
    int stackPred;             // pool stack (ctl) predecessor link
    int nsteals;               // number of steals
    IForkJoinTask[] array;   // the queued tasks; power of 2 size
    ForkJoinPool pool;   // the containing pool (may be null)
    ForkJoinWorkerThread owner; // owning thread or null if shared

    this(ForkJoinPool pool, ForkJoinWorkerThread owner) {
        this.pool = pool;
        this.owner = owner;
        // Place indices in the center of array (that is not yet allocated)
        base = top = INITIAL_QUEUE_CAPACITY >>> 1;
    }

    /**
     * Tries to lock shared queue by CASing phase field.
     */
    final bool tryLockPhase() {
        return cas(&this.phase, 0, 1);
        // return PHASE.compareAndSet(this, 0, 1);
    }

    final void releasePhaseLock() {
        // PHASE.setRelease(this, 0);
        atomicStore(this.phase, 0);
    }

    /**
     * Returns an exportable index (used by ForkJoinWorkerThread).
     */
    final int getPoolIndex() {
        return (id & 0xffff) >>> 1; // ignore odd/even tag bit
    }

    /**
     * Returns the approximate number of tasks in the queue.
     */
    final int queueSize() {
        // int n = cast(int)BASE.getAcquire(this) - top;
        int n = atomicLoad(this.base) - top;
        return (n >= 0) ? 0 : -n; // ignore negative
    }

    /**
     * Provides a more accurate estimate of whether this queue has
     * any tasks than does queueSize, by checking whether a
     * near-empty queue has at least one unclaimed task.
     */
    final bool isEmpty() {
        IForkJoinTask[] a; int n, cap, b;
        // VarHandle.acquireFence(); // needed by external callers
        return ((n = (b = base) - top) >= 0 || // possibly one task
                (n == -1 && ((a = array) is null ||
                             (cap = cast(int)a.length) == 0 ||
                             a[(cap - 1) & b] is null)));
    }

    /**
     * Pushes a task. Call only by owner in unshared queues.
     *
     * @param task the task. Caller must ensure non-null.
     * @throws RejectedExecutionException if array cannot be resized
     */
    final void push(IForkJoinTask task) {
        IForkJoinTask[] a;
        int s = top, d, cap, m;
        ForkJoinPool p = pool;
        if ((a = array) !is null && (cap = cast(int)a.length) > 0) {
            m = cap - 1;
            // FIXME: Needing refactor or cleanup -@zxp at 2019/2/9 8:40:55
            // 
            // AtomicHelper.store(a[m & s], task);
            a[m & s] = task;
            // QA.setRelease(a, (m = cap - 1) & s, task);
            top = s + 1;
            if (((d = s - atomicLoad(this.base)) & ~1) == 0 &&
                p !is null) {                 // size 0 or 1
                // VarHandle.fullFence();
                p.signalWork();
            }
            else if (d == m)
                growArray(false);
        }
    }

    /**
     * Version of push for shared queues. Call only with phase lock held.
     * @return true if should signal work
     */
    final bool lockedPush(IForkJoinTask task) {
        IForkJoinTask[] a;
        bool signal = false;
        int s = top, b = base, cap, d;
        if ((a = array) !is null && (cap = cast(int)a.length) > 0) {
            a[(cap - 1) & s] = task;
            top = s + 1;
            if (b - s + cap - 1 == 0)
                growArray(true);
            else {
                phase = 0; // full unlock
                if (((s - base) & ~1) == 0) // size 0 or 1
                    signal = true;
            }
        }
        return signal;
    }

    /**
     * Doubles the capacity of array. Call either by owner or with
     * lock held -- it is OK for base, but not top, to move while
     * resizings are in progress.
     */
    final void growArray(bool locked) {
        IForkJoinTask[] newA = null;
        try {
            IForkJoinTask[] oldA; int oldSize, newSize;
            if ((oldA = array) !is null && (oldSize = cast(int)oldA.length) > 0 &&
                (newSize = oldSize << 1) <= MAXIMUM_QUEUE_CAPACITY &&
                newSize > 0) {
                try {
                    newA = new IForkJoinTask[newSize];
                } catch (OutOfMemoryError ex) {
                }
                if (newA !is null) { // poll from old array, push to new
                    int oldMask = oldSize - 1, newMask = newSize - 1;
                    for (int s = top - 1, k = oldMask; k >= 0; --k) {
                        // IForkJoinTask x = AtomicHelper.getAndSet(oldA[s & oldMask], null);
                        // FIXME: Needing refactor or cleanup -@zxp at 2019/2/9 下午8:57:26
                        // 
                        IForkJoinTask x = oldA[s & oldMask];
                        oldA[s & oldMask] = null;

                        if (x !is null)
                            newA[s-- & newMask] = x;
                        else
                            break;
                    }
                    array = newA;
                    // VarHandle.releaseFence();
                }
            }
        } finally {
            if (locked)
                phase = 0;
        }
        if (newA is null)
            throw new RejectedExecutionException("Queue capacity exceeded");
    }

    /**
     * Takes next task, if one exists, in FIFO order.
     */
    final IForkJoinTask poll() {
        int b, k, cap; 
        IForkJoinTask[] a;
        while ((a = array) !is null && (cap = cast(int)a.length) > 0 &&
               top - (b = base) > 0) {
            k = (cap - 1) & b;
            // FIXME: Needing refactor or cleanup -@zxp at 2019/2/9 8:42:05
            // 
            
            // IForkJoinTask t = AtomicHelper.load(a[k]);
            IForkJoinTask t = a[k];
            if (base == b++) {
                if (t is null)
                    Thread.yield(); // await index advance
                else if (AtomicHelper.compareAndSet(a[k], t, null)) {
                // else if (QA.compareAndSet(a, k, t, null)) {
                    AtomicHelper.store(this.base, b);
                    return t;
                }
            }
        }
        return null;
    }

    /**
     * Takes next task, if one exists, in order specified by mode.
     */
    final IForkJoinTask nextLocalTask() {
        IForkJoinTask t = null;
        int md = id, b, s, d, cap; IForkJoinTask[] a;
        if ((a = array) !is null && (cap = cast(int)a.length) > 0 &&
            (d = (s = top) - (b = base)) > 0) {
            if ((md & FIFO) == 0 || d == 1) {
                auto index = (cap - 1) & --s;
                t = AtomicHelper.getAndSet(a[index], cast(IForkJoinTask)null);
                if(t !is null) {
                    AtomicHelper.store(this.top, s);
                }
            } else {
                auto index = (cap - 1) & b++;
                t = AtomicHelper.getAndSet(a[index], cast(IForkJoinTask)null);
                if (t !is null) {
                    AtomicHelper.store(this.base, b);
                }
                else // on contention in FIFO mode, use regular poll
                    t = poll();
            } 
        }
        return t;
    }

    /**
     * Returns next task, if one exists, in order specified by mode.
     */
    final IForkJoinTask peek() {
        int cap; IForkJoinTask[] a;
        return ((a = array) !is null && (cap = cast(int)a.length) > 0) ?
            a[(cap - 1) & ((id & FIFO) != 0 ? base : top - 1)] : null;
    }

    /**
     * Pops the given task only if it is at the current top.
     */
    final bool tryUnpush(IForkJoinTask task) {
        bool popped = false;
        int s, cap; IForkJoinTask[] a;
        if ((a = array) !is null && (cap = cast(int)a.length) > 0 &&
            (s = top) != base) {
            popped = AtomicHelper.compareAndSet(a[(cap - 1) & --s], task, null);
            if(popped) {
                AtomicHelper.store(this.top, s);
            }
        }
        return popped;
    }

    /**
     * Shared version of tryUnpush.
     */
    final bool tryLockedUnpush(IForkJoinTask task) {
        bool popped = false;
        int s = top - 1, k, cap; IForkJoinTask[] a;
        if ((a = array) !is null && (cap = cast(int)a.length) > 0 &&
            a[k = (cap - 1) & s] == task && tryLockPhase()) {
            if (top == s + 1 && array == a) {
                popped = AtomicHelper.compareAndSet(a[k], task, null);
                if(popped) top = s;
            }
            releasePhaseLock();
        }
        return popped;
    }

    /**
     * Removes and cancels all known tasks, ignoring any exceptions.
     */
    final void cancelAll() {
        for (IForkJoinTask t; (t = poll()) !is null; )
            IForkJoinTask.cancelIgnoringExceptions(t);
    }

    // Specialized execution methods

    /**
     * Runs the given (stolen) task if nonnull, as well as
     * remaining local tasks and others available from the given
     * queue, up to bound n (to avoid infinite unfairness).
     */
    final void topLevelExec(IForkJoinTask t, WorkQueue q, int n) {
        if (t !is null && q !is null) { // hoist checks
            int nstolen = 1;
            for (;;) {
                t.doExec();
                if (n-- < 0)
                    break;
                else if ((t = nextLocalTask()) is null) {
                    if ((t = q.poll()) is null)
                        break;
                    else
                        ++nstolen;
                }
            }
            ForkJoinWorkerThread thread = owner;
            nsteals += nstolen;
            source = 0;
            if (thread !is null)
                thread.afterTopLevelExec();
        }
    }

    /**
     * If present, removes task from queue and executes it.
     */
    final void tryRemoveAndExec(IForkJoinTask task) {
        IForkJoinTask[] a; int s, cap;
        if ((a = array) !is null && (cap = cast(int)a.length) > 0 &&
            (s = top) - base > 0) { // traverse from top
            for (int m = cap - 1, ns = s - 1, i = ns; ; --i) {
                int index = i & m;
                IForkJoinTask t = a[index]; //QA.get(a, index);
                if (t is null)
                    break;
                else if (t == task) {
                    // if (AtomicHelper.compareAndSet(a[index], t, null)) 
                    if(a[index] == t) {
                        a[index] = null;
                        top = ns;   // safely shift down
                        for (int j = i; j != ns; ++j) {
                            IForkJoinTask f;
                            int pindex = (j + 1) & m;
                            f = a[pindex];// QA.get(a, pindex);
                            a[pindex] = null;
                            // AtomicHelper.store(a[pindex], null);
                            // QA.setVolatile(a, pindex, null);
                            int jindex = j & m;
                            a[jindex] = f;
                            // AtomicHelper.store(a[jindex], f);
                            // QA.setRelease(a, jindex, f);
                        }
                        // VarHandle.releaseFence();
                        t.doExec();
                    }
                    break;
                }
            }
        }
    }

    /**
     * Tries to pop and run tasks within the target's computation
     * until done, not found, or limit exceeded.
     *
     * @param task root of CountedCompleter computation
     * @param limit max runs, or zero for no limit
     * @param shared true if must lock to extract task
     * @return task status on exit
     */
    final int helpCC(ICountedCompleter task, int limit, bool isShared) {
        int status = 0;
        if (task !is null && (status = task.getStatus()) >= 0) {
            int s, k, cap; IForkJoinTask[] a;
            while ((a = array) !is null && (cap = cast(int)a.length) > 0 &&
                   (s = top) - base > 0) {
                ICountedCompleter v = null;
                IForkJoinTask o = a[k = (cap - 1) & (s - 1)];
                ICountedCompleter t = cast(ICountedCompleter)o;
                if (t !is null) {
                    for (ICountedCompleter f = t;;) {
                        if (f != task) {
                            if ((f = f.getCompleter()) is null)
                                break;
                        }
                        else if (isShared) {
                            if (tryLockPhase()) {
                                if (top == s && array == a &&
                                    AtomicHelper.compareAndSet(a[k], t, cast(IForkJoinTask)null)) {
                                    top = s - 1;
                                    v = t;
                                }
                                releasePhaseLock();
                            }
                            break;
                        }
                        else {
                            if (AtomicHelper.compareAndSet(a[k], t, cast(IForkJoinTask)null)) {
                                top = s - 1;
                                v = t;
                            }
                            break;
                        }
                    }
                }
                if (v !is null)
                    v.doExec();
                if ((status = task.getStatus()) < 0 || v is null ||
                    (limit != 0 && --limit == 0))
                    break;
            }
        }
        return status;
    }

    /**
     * Tries to poll and run AsynchronousCompletionTasks until
     * none found or blocker is released
     *
     * @param blocker the blocker
     */
    final void helpAsyncBlocker(ManagedBlocker blocker) {
        if (blocker !is null) {
            int b, k, cap; IForkJoinTask[] a; IForkJoinTask t;
            while ((a = array) !is null && (cap = cast(int)a.length) > 0 &&
                   top - (b = base) > 0) {
                k = (cap - 1) & b;
                // t = AtomicHelper.load(a[k]);
                t = a[k];
                if (blocker.isReleasable())
                    break;
                else if (base == b++ && t !is null) {
                    AsynchronousCompletionTask at = cast(AsynchronousCompletionTask)t;
                    if (at is null)
                        break;
                    else if (AtomicHelper.compareAndSet(a[k], t, null)) {
                        AtomicHelper.store(this.base, b);
                        t.doExec();
                    }
                }
            }
        }
    }

    /**
     * Returns true if owned and not known to be blocked.
     */
    final bool isApparentlyUnblocked() {
        ThreadEx wt; ThreadState s;
        return ((wt = owner) !is null &&
                (s = wt.getState()) != ThreadState.BLOCKED &&
                s != ThreadState.WAITING &&
                s != ThreadState.TIMED_WAITING);
    }

    // VarHandle mechanics.
    // static final VarHandle PHASE;
    // static final VarHandle BASE;
    // static final VarHandle TOP;
    // static {
    //     try {
    //         MethodHandles.Lookup l = MethodHandles.lookup();
    //         PHASE = l.findVarHandle(WorkQueue.class, "phase", int.class);
    //         BASE = l.findVarHandle(WorkQueue.class, "base", int.class);
    //         TOP = l.findVarHandle(WorkQueue.class, "top", int.class);
    //     } catch (ReflectiveOperationException e) {
    //         throw new ExceptionInInitializerError(e);
    //     }
    // }
}



/**
 * A marker interface identifying asynchronous tasks produced by
 * {@code async} methods. This may be useful for monitoring,
 * debugging, and tracking asynchronous activities.
 *
 */
interface AsynchronousCompletionTask {
}