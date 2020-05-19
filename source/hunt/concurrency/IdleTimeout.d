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

module hunt.concurrency.IdleTimeout;


/**
 * An Abstract implementation of an Idle Timeout.
 * <p>
 * This implementation is optimised that timeout operations are not cancelled on
 * every operation. Rather timeout are allowed to expire and a check is then
 * made to see when the last operation took place. If the idle timeout has not
 * expired, the timeout is rescheduled for the earliest possible time a timeout
 * could occur.
 */
// abstract class IdleTimeout {
//     private final Scheduler scheduler;
//     private final AtomicReference<Scheduler.Future> timeout = new AtomicReference<>();
//     private long idleTimeout;
//     private long idleTimestamp = Millisecond100Clock.currentTimeMillis();

//     private final Runnable idleTask = new Runnable() {
//         override
//         void run() {
//             long idleLeft = checkIdleTimeout();
//             if (idleLeft >= 0)
//                 scheduleIdleTimeout(idleLeft > 0 ? idleLeft : getIdleTimeout());
//         }
//     };

//     /**
//      * @param scheduler A scheduler used to schedule checks for the idle timeout.
//      */
//     IdleTimeout(Scheduler scheduler) {
//         this.scheduler = scheduler;
//     }

//     Scheduler getScheduler() {
//         return scheduler;
//     }

//     long getIdleTimestamp() {
//         return idleTimestamp;
//     }

//     long getIdleFor() {
//         return Millisecond100Clock.currentTimeMillis() - getIdleTimestamp();
//     }

//     long getIdleTimeout() {
//         return idleTimeout;
//     }

//     void setIdleTimeout(long idleTimeout) {
//         long old = this.idleTimeout;
//         this.idleTimeout = idleTimeout;

//         // Do we have an old timeout
//         if (old > 0) {
//             // if the old was less than or equal to the new timeout, then
//             // nothing more to do
//             if (old <= idleTimeout)
//                 return;

//             // old timeout is too long, so cancel it.
//             deactivate();
//         }

//         // If we have a new timeout, then check and reschedule
//         if (isOpen())
//             activate();
//     }

//     /**
//      * This method should be called when non-idle activity has taken place.
//      */
//     void notIdle() {
//         idleTimestamp = Millisecond100Clock.currentTimeMillis();
//     }

//     private void scheduleIdleTimeout(long delay) {
//         Scheduler.Future newTimeout = null;
//         if (isOpen() && delay > 0 && scheduler !is null)
//             newTimeout = scheduler.schedule(idleTask, delay, TimeUnit.MILLISECONDS);
//         Scheduler.Future oldTimeout = timeout.getAndSet(newTimeout);
//         if (oldTimeout !is null)
//             oldTimeout.cancel();
//     }

//     void onOpen() {
//         activate();
//     }

//     private void activate() {
//         if (idleTimeout > 0)
//             idleTask.run();
//     }

//     void onClose() {
//         deactivate();
//     }

//     private void deactivate() {
//         Scheduler.Future oldTimeout = timeout.getAndSet(null);
//         if (oldTimeout !is null)
//             oldTimeout.cancel();
//     }

//     protected long checkIdleTimeout() {
//         if (isOpen()) {
//             long idleTimestamp = getIdleTimestamp();
//             long idleTimeout = getIdleTimeout();
//             long idleElapsed = Millisecond100Clock.currentTimeMillis() - idleTimestamp;
//             long idleLeft = idleTimeout - idleElapsed;

//             // System.out.println("{} idle timeout check, elapsed: {} ms,
//             // remaining: {} ms", this, idleElapsed, idleLeft);

//             if (idleTimestamp != 0 && idleTimeout > 0) {
//                 if (idleLeft <= 0) {

//                     // System.out.println("{} idle timeout expired", this);
//                     try {
//                         onIdleExpired(new TimeoutException(
//                                 "Idle timeout expired: " ~ idleElapsed ~ "/" ~ idleTimeout ~ " ms"));
//                     } finally {
//                         notIdle();
//                     }
//                 }
//             }

//             return idleLeft >= 0 ? idleLeft : 0;
//         }
//         return -1;
//     }

//     /**
//      * This abstract method is called when the idle timeout has expired.
//      *
//      * @param timeout a TimeoutException
//      */
//     protected abstract void onIdleExpired(TimeoutException timeout);

//     /**
//      * This abstract method should be called to check if idle timeouts should
//      * still be checked.
//      *
//      * @return True if the entity monitored should still be checked for idle
//      * timeouts
//      */
//     abstract bool isOpen();
// }
