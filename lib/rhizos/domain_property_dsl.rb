# -*- ruby -*-

require 'rhizos' unless defined?( Rhizos )


# DSL methods for declaring a property for a Rhizos::DomainType or
# Rhizos::DomainRelation.
#
# The general form of the declaration is:
#
#     <datatype> :<name>, **<options>
#
# E.g.,
#
#     timestamp :created_at, default: :current_timestamp
#
# See Rhizos::DomainType#add_property and Rhizos::DomainRelation#add_property
# for the list of supported options.
module Rhizos::DomainPropertyDSL

	### Inclusion hook -- make sure the including +mod+ has logging enabled.
	def self::included( mod )
		super

		unless mod.respond_to?( :log )
			mod.extend( Loggability )
			mod.log_to( :rhizos )
		end
	end


	### Define a new property type method for the specified +datatype+.
	def self::define_property_type( name, cypher_datatype=name.upcase ) # :nodoc:
		define_method( name ) do |prop_name, **options|
			self.add_property( prop_name, cypher_datatype.to_s, **options )
		end
	end


	##
	# Declare an `INT` property
	define_property_type :int

	##
	# Declare an `INT8` property
	define_property_type :int8

	##
	# Declare a `INT16` property
	define_property_type :int16

	##
	# Declare a `INT32` property
	define_property_type :int32

	##
	# Declare a `INT64` property
	define_property_type :int64

	##
	# Declare a `INT128` property
	define_property_type :int128

	##
	# Declare a `UINT8` property
	define_property_type :uint8

	##
	# Declare a `UINT16` property
	define_property_type :uint16

	##
	# Declare a `UINT32` property
	define_property_type :uint32

	##
	# Declare a `UINT64` property
	define_property_type :uint64

	##
	# Declare a `FLOAT` property
	define_property_type :float

	##
	# Declare a `DOUBLE` property
	define_property_type :double

	##
	# Declare a `DECIMAL` property
	define_property_type :decimal

	##
	# Declare a `BOOLEAN` property
	define_property_type :boolean

	##
	# Declare a `UUID` property
	define_property_type :uuid

	##
	# Declare a `STRING` property
	define_property_type :string

	##
	# Declare a `NULL` property
	define_property_type :null

	##
	# Declare a `DATE` property
	define_property_type :date

	##
	# Declare a `TIMESTAMP` property
	define_property_type :timestamp

	##
	# Declare a `INTERVAL` property
	define_property_type :interval

	##
	# Declare a `STRUCT` property
	define_property_type :struct

	##
	# Declare a `MAP` property
	define_property_type :map

	##
	# Declare a `BLOB` property
	define_property_type :blob

	##
	# Declare a `SERIAL` property
	define_property_type :serial

	##
	# Declare a `LIST` property
	define_property_type :list

	##
	# Declare a `ARRAY` property
	define_property_type :array

	##
	# Declare a `JSON` property
	define_property_type :json


	### Declare a `UNION` property
	def union( * )
		raise NotImplemented, "the DSL doesn't support UNIONs yet"
	end


	### Return the specified +default_value+ represented as a String for a
	### cypher query.
	###
	### Most `default_value`s are just stringified via their #to_s method, with
	### the following exceptions:
	###
	### Strings
	### : Strings are quoted
	###
	### Symbols
	### : Symbols turn into function calls, e.g., `:current_timestamp` is rendered
	###   as `current_timestamp()`
	###
	def stringify_default( default_value )
		return nil if default_value.nil?

		case default_value
		when Symbol
			return "%s()" % [ default_value ]
		when String
			return default_value.dump
		else
			self.log.debug "Using default handler for %p default values." % [ default_value.class ]
			return default_value.to_s
		end
	end

end # module Rhizos::DomainPropertyDSL
