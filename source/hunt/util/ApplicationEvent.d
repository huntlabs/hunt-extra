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

module hunt.util.ApplicationEvent;

import hunt.util.DateTime;
import hunt.util.ObjectUtils;

/**
 * Class to be extended by all application events. Abstract as it
 * doesn't make sense for generic events to be published directly.
 *
 * @author Rod Johnson
 * @author Juergen Hoeller
 */
abstract class ApplicationEvent : EventObject {

	/** System time when the event happened. */
	private long timestamp;


	/**
	 * Create a new ApplicationEvent.
	 * @param source the object on which the event initially occurred (never {@code null})
	 */
	this(Object source) {
		super(source);
		this.timestamp = DateTime.currentTimeMillis();
	}


	/**
	 * Return the system time in milliseconds when the event happened.
	 */
	final long getTimestamp() {
		return this.timestamp;
	}

}



/**
 * Interface that encapsulates event publication functionality.
 * Serves as super-interface for {@link ApplicationContext}.
 *
 * @author Juergen Hoeller
 * @author Stephane Nicoll
 * @see ApplicationContext
 * @see ApplicationEventPublisherAware
 * @see hunt.framework.context.ApplicationEvent
 * @see hunt.framework.context.event.EventPublicationInterceptor
 */
interface ApplicationEventPublisher {

	/**
	 * Notify all <strong>matching</strong> listeners registered with this
	 * application of an application event. Events may be framework events
	 * (such as RequestHandledEvent) or application-specific events.
	 * @param event the event to publish
	 * @see hunt.framework.web.context.support.RequestHandledEvent
	 */
	final void publishEvent(ApplicationEvent event) {
		publishEvent(cast(Object) event);
	}

	/**
	 * Notify all <strong>matching</strong> listeners registered with this
	 * application of an event.
	 * <p>If the specified {@code event} is not an {@link ApplicationEvent},
	 * it is wrapped in a {@link PayloadApplicationEvent}.
	 * @param event the event to publish
	 * @since 4.2
	 * @see PayloadApplicationEvent
	 */
	void publishEvent(Object event);

}
