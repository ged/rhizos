# -*- ruby -*-

require 'loggability'
require 'concurrent/timer_task'

require 'rhizos' unless defined?( Rhizos )


# A wrapper around a periodic callback.
class Rhizos::Timer
	extend Loggability


	# Loggability API -- log to the Rhizos logger
	log_to :rhizos


	class LoggingTaskObserver # :nodoc:
		extend Loggability

		# Loggability API -- log to the Rhizos logger
		log_to :rhizos


		### Create a new observer that will track the status of the given +observable_name+.
		def initialize( observable_name )
			@observable_name = observable_name
		end


		######
		public
		######

		##
		# The name of the object being observed.
		attr_reader :observable_name


		### Concurrent::Observable API -- update the status of the object being observed.
		def update( time, result, ex )
			if ex&.is_a?( Concurrent::TimeoutError )
				self.log.warn "%s (%0.3f) Execution timed out" % [ self.observable_name, time ]
			elsif ex
				self.log.error "%s (%0.3f) Execution failed: %s" %
					[ self.observable_name, time, ex.full_message(order: :bottom) ]
			else
				self.log.debug "%s (%0.3f) Execution successful; returned %p" %
					[ self.observable_name, time, result ]
			end
		end

	end # class LoggingObserver


	### Fetch the observer responsible for logging TimerTask execution.
	def self::logging_task_observer
		return @logging_task_observer ||= LoggingTaskObserver.new( "Rhizos timer" )
	end


	### Create a new Timer that will call the specified +callback+ after +interval+
	### seconds (after it's started).
	def initialize( interval, &callback )
		raise ArgumentError, "missing callback" unless callback

		@interval = interval
		@callback = callback
		@task = nil
	end


	######
	public
	######

	##
	# The number of seconds between callbacks
	attr_reader :interval

	##
	# The callable object that will be called on the interval
	attr_reader :callback

	##
	# The underlying Concurrent::TimerTask that the Timer is wrapping
	attr_accessor :task


	### Manually call the Timer's callback, passing the Timer itself as an argument, and returning
	### the return value of the call.
	def fire( * )
		self.log.debug "Firing the callback: %p" % [ self.callback ]
		return self.callback.call( self )
	end


	### Start calling the callback on the Timer's #interval. If +fire_immediately+ is `true`,
	### fire the callback immediately instead of waiting for the interval for the
	### first call.
	def start( fire_now: false )
		self.log.debug "Starting the timer for callback: %p" % [ self.callback ]
		self.task = Concurrent::TimerTask.
			execute( execution_interval: @interval, run_now: fire_now, &self.method(:fire) ).
			with_observer( self.class.logging_task_observer )
	end


	### Stop calling the callback.
	def stop
		self.log.debug "Stopping the timer for callback: %p" % [ self.callback ]
		self.task&.shutdown
		self.task = nil
	end


	### Returns +true+ if the callback is not being called on the interval.
	def stopped?
		return ! self.started?
	end
	alias_method :is_stopped?, :stopped?


	### Returns +true+ if the callback is being called on the interval.
	def started?
		return self.task&.running?
	end
	alias_method :is_started?, :started?

end # class Rhizos::Timer
