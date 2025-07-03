# -*- ruby -*-

require 'rhizos' unless defined?( Rhizos )


module Rhizos


	# Refinements to Numeric to add convenience methods
	module NumericRefinements

		# Approximate Time Constants (in seconds)
		MINUTES = 60
		HOURS   = 60  * MINUTES
		DAYS    = 24  * HOURS
		WEEKS   = 7   * DAYS
		MONTHS  = 30  * DAYS
		YEARS   = 365.25 * DAYS

		refine Numeric do

			### Number of seconds (returns receiver unmodified)
			def milliseconds
				return self * 0.001
			end
			alias_method :millisecond, :milliseconds


			### Number of seconds (returns receiver unmodified)
			alias_method :second, :itself
			alias_method :seconds, :itself


			### Returns number of seconds in <receiver> minutes
			def minutes
				return TimeFunctions.calculate_seconds( self, :minutes )
			end
			alias_method :minute, :minutes


			### Returns the number of seconds in <receiver> hours
			def hours
				return TimeFunctions.calculate_seconds( self, :hours )
			end
			alias_method :hour, :hours


			### Returns the number of seconds in <receiver> days
			def days
				return TimeFunctions.calculate_seconds( self, :day )
			end
			alias_method :day, :days


			### Return the number of seconds in <receiver> weeks
			def weeks
				return TimeFunctions.calculate_seconds( self, :weeks )
			end
			alias_method :week, :weeks


			### Returns the number of seconds in <receiver> fortnights
			def fortnights
				return TimeFunctions.calculate_seconds( self, :fortnights )
			end
			alias_method :fortnight, :fortnights


			### Returns the number of seconds in <receiver> months (approximate)
			def months
				return TimeFunctions.calculate_seconds( self, :months )
			end
			alias_method :month, :months


			### Returns the number of seconds in <receiver> years (approximate)
			def years
				return TimeFunctions.calculate_seconds( self, :years )
			end
			alias_method :year, :years


			### Returns the Time <receiver> number of seconds before the
			### specified +time+. E.g., 2.hours.before( header.expiration )
			def before( time )
				return time - self
			end


			### Returns the Time <receiver> number of seconds ago. (e.g.,
			### expiration > 2.hours.ago )
			def ago
				return self.before( ::Time.now )
			end


			### Returns the Time <receiver> number of seconds after the given +time+.
			### E.g., 10.minutes.after( header.expiration )
			def after( time )
				return time + self
			end


			### Return a new Time <receiver> number of seconds from now.
			def from_now
				return self.after( ::Time.now )
			end


			### Number of bytes (returns receiver unmodified)
			def bytes
				return self
			end
			alias_method :byte, :bytes


			### Returns the number of bytes in <receiver> kilobytes
			def kilobytes
				return self * 1024
			end
			alias_method :kilobyte, :kilobytes


			### Return the number of bytes in <receiver> megabytes
			def megabytes
				return self * 1024 ** 2
			end
			alias_method :megabyte, :megabytes


			### Return the number of bytes in <receiver> gigabytes
			def gigabytes
				return self * 1024 ** 3
			end
			alias_method :gigabyte, :gigabytes


			### Return the number of bytes in <receiver> terabytes
			def terabytes
				return self * 1024 ** 4
			end
			alias_method :terabyte, :terabytes


			### Return the number of bytes in <receiver> petabytes
			def petabytes
				return self * 1024 ** 5
			end
			alias_method :petabyte, :petabytes


			### Return the number of bytes in <receiver> exabytes
			def exabytes
				return self * 1024 ** 6
			end
			alias_method :exabyte, :exabytes


			### Return a human readable file size.
			def size_suffix
				bytes = Float( self )
				return case
					when bytes >= 1.petabyte
						"%0.1fP" % [ bytes / 1.petabyte ]
					when bytes >= 1.terabyte
						"%0.1fT" % [ bytes / 1.terabyte ]
					when bytes >= 1.gigabyte
						"%0.1fG" % [ bytes / 1.gigabyte ]
					when bytes >= 1.megabyte
						"%0.1fM" % [ bytes / 1.megabyte ]
					when bytes >= 1.kilobyte
						"%0.1fK" % [ bytes / 1.kilobyte ]
					else
						"%db" % [ self ]
					end
			end

		end # refine Numeric

	end # module NumericRefinements


	# Refinements to Time to add convenience methods
	module TimeRefinements

		refine Time do

			### Returns +true+ if the receiver is a Time in the future.
			def future?
				return self > Time.now
			end


			### Returns +true+ if the receiver is a Time in the past.
			def past?
				return self < Time.now
			end


			### Return a description of the receiving Time object in relation to the current
			### time.
			###
			### Example:
			###
			###    "Saved %s ago." % object.updated_at.as_delta
			def as_delta
				now = Time.now
				if now > self
					seconds = now - self
					return "%s ago" % [ timeperiod(seconds) ]
				else
					seconds = self - now
					return "%s from now" % [ timeperiod(seconds) ]
				end
			end


			### Return a description of +seconds+ as the nearest whole unit of time.
			def timeperiod( seconds )
				return case
					when seconds < MINUTES - 5
						'less than a minute'
					when seconds < 50 * MINUTES
						if seconds <= 89
							"a minute"
						else
							"%d minutes" % [ (seconds.to_f / MINUTES).ceil ]
						end
					when seconds < 90 * MINUTES
						'about an hour'
					when seconds < 18 * HOURS
						"%d hours" % [ (seconds.to_f / HOURS).ceil ]
					when seconds < 30 * HOURS
						'about a day'
					when seconds < WEEKS
						"%d days" % [ (seconds.to_f / DAYS).ceil ]
					when seconds < 2 * WEEKS
						'about a week'
					when seconds < 3 * MONTHS
						"%d weeks" % [ (seconds.to_f / WEEKS).round ]
					when seconds < 18 * MONTHS
						"%d months" % [ (seconds.to_f / MONTHS).ceil ]
					else
						"%d years" % [ (seconds.to_f / YEARS).ceil ]
					end
			end

		end # refine Time

	end # module TimeRefinements


	# Refinements to String to add convenience methods
	module StringRefinements

		refine String do

			### Refinement: return a copy of the receiving string with camelCased
			### words turned into under_barred ones.
			def uncamelcase
				return self.gsub( /([a-z0-9])([A-Z])/ ) { $1 << '_' << $2.downcase }
			end

		end

	end # module StringRefinements

end # module Rhizos
