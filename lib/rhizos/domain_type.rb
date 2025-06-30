# -*- ruby -*-

require 'loggability'

require 'rhizos' unless defined?( Rhizos )
require 'rhizos/domain_property_dsl'


# A type description for a Rhizos::Domain.
class Rhizos::DomainType
	extend Loggability
	include Rhizos::DomainPropertyDSL


	# A struct type for describing properties of the DomainType
	Property = Struct.new( 'TypeProperty', :name, :type, :default )

	# The default `id` property used by all DomainTypes that don't override it
	DEFAULT_ID_PROPERTY = Property.new( :id, 'UUID', :gen_random_uuid )

	# Properties all DomainTypes start out with
	DEFAULT_PROPERTIES = [
		DEFAULT_ID_PROPERTY,
	].freeze

	# The Cypher query template to use for creating node tables
	CREATE_QUERY = <<~END_OF_QUERY
		CREATE NODE TABLE %{name} (
		%{properties}
		);
		COMMENT ON TABLE %{name} IS '%{description}';
	END_OF_QUERY


	# Loggability API -- use the Rhizos logger
	log_to :rhizos


	### Create a new type for a domain with the given +name+, which should
	### be a title-cased Symbol, and +description+.
	def initialize( name, description=nil, source: nil )
		@name        = name.to_sym
		@description = description
		@properties  = DEFAULT_PROPERTIES.dup
		@primary_key = DEFAULT_ID_PROPERTY.name

		@source      = source
	end


	######
	public
	######

	##
	# The name of the type
	attr_reader :name

	##
	# The description of the type, to be added to the node table as a comment.
	attr_reader :description

	##
	# The type's properties as Rhizos::DomainType::Property structs.
	attr_reader :properties

	##
	# The name of the primary key property, as a Symbol
	attr_accessor :primary_key

	##
	# The source location where the type was declared (for troubleshooting)
	attr_reader :source


	### Add a property with the specified +name+ and +datatype+ to the DomainType.
	### The supported +options+ are:
	###
	### `:default`
	### :  Specify a DEFAULT for the property. See Rhizos::DomainType::DSL#stringify_default
	###    for the values you can give for a default.
	def add_property( name, datatype, **options )
		prop = Rhizos::DomainType::Property.new( name:, type: datatype.to_s, **options )
		return self.properties.push( prop )
	end


	### Return a String containing a Cypher CREATE query for this DomainType.
	def cypher
		return CREATE_QUERY % {
			name: self.name,
			description: self.description,
			properties: self.properties_cypher
		}
	end


	### Return a String containing Cypher language declarations for each of
	### the DomainType's properties.
	def properties_cypher
		lines = self.properties.map do |property|
			self.log.debug "Adding property %p to %p" % [ property.name, self.class ]
			line = "  %s %s" % [ property.name, property.type ]
			if (default_cypher = stringify_default( property.default ))
				line << " DEFAULT %s" % [ default_cypher ]
			end

			line
		end
		lines << "  PRIMARY KEY (%s)" % [ self.primary_key ]

		return lines.join( ",\n" )
	end


end # class Rhizos::DomainType
