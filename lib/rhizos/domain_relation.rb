# -*- ruby -*-

require 'loggability'

require 'rhizos' unless defined?( Rhizos )
require 'rhizos/domain_property_dsl'


# A relationship between two nodes in a Rhizos::Domain.
class Rhizos::DomainRelation
	extend Loggability
	include Rhizos::DomainPropertyDSL


	# A struct type for describing properties of the DomainRelation
	Property = Struct.new( 'RelationProperty', :name, :type, :default )


	# The Cypher query template to use for creating node tables
	CREATE_QUERY = <<~END_OF_QUERY
		CREATE REL TABLE %{name} (
		%{contents}
		);
		COMMENT ON TABLE %{name} IS '%{description}';
	END_OF_QUERY


	# Loggability API -- use the Rhizos logger
	log_to :rhizos


	### Create a new type for a domain with the given +name+, which should
	### be a title-cased Symbol, and +description+.
	def initialize( name, description=nil )
		@name         = name.to_sym
		@description  = description
		@connections  = Set.new
		@properties   = []
		@multiplicity = nil
	end


	######
	public
	######

	##
	# The name of the relation
	attr_accessor :name

	##
	# The description of the relation, to be added to the rel table as a comment.
	attr_accessor :description

	##
	# The node types the relation connects, as from/to Symbol key-value pairs.
	attr_accessor :connections

	##
	# The relation's properties as Rhizos::DomainRelation::Property structs.
	attr_reader :properties

	##
	# The multiplicity of the relation, if specified.
	attr_accessor :multiplicity


	### Add a connection +from+ the given type +to+ another type. Both should be Symbols.
	def add_connection( from:, to:, **options )
		self.connections.add([ from, to ])
	end
	alias_method :add, :add_connection


	### Add a property with the specified +name+ and +datatype+ to the DomainRelation.
	### The supported +options+ are:
	###
	### `:default`
	### :  Specify a DEFAULT for the property. See #stringify_default for the values
	###    you can give for a default.
	def add_property( name, datatype, **options )
		prop = Rhizos::DomainRelation::Property.new( name:, type: datatype.to_s, **options )
		return self.properties.push( prop )
	end


	### Declare the Relation's multiplicity to be `ONE_ONE`.
	def one_one
		self.multiplicity = :ONE_ONE
	end


	### Declare the Relation's multiplicity to be `MANY_MANY`.
	def many_many
		self.multiplicity = :MANY_MANY
	end


	### Declare the Relation's multiplicity to be `ONE_MANY`.
	def one_many
		self.multiplicity = :ONE_MANY
	end


	### Declare the Relation's multiplicity to be `MANY_ONE`.
	def many_one
		self.multiplicity = :MANY_ONE
	end


	### Return a new DomainRelation object that merges the receiver with
	### +other_relation+.
	def merge( other_relation )
		merged = self.dup

		merged.merge_name( other_relation )
		merged.merge_description( other_relation )
		merged.merge_properties( other_relation )
		merged.merge_multiplicities( other_relation )

		merged.connections = self.connections | other_relation.connections

		return merged
	end


	### Check for conflicting #name during a #merge and raise a Rhizos::SchemaError
	### if there's a conflict.
	def merge_name( other_relation )
		raise Rhizos::SchemaError, "conflicting names in %s" % [ self.name ] if
			self.name != other_relation.name
	end


	### Merge descriptions with +other_relation+, raising a Rhizos::SchemaError if
	### the descriptions conflict.
	def merge_description( other_relation )
		return unless other_relation.description

		raise Rhizos::SchemaError, "conflicting descriptions in %s" % [ self.name ] if
			self.description && self.description != other_relation.description

		self.description = other_relation.description.dup
	end


	### Merge properties with +other_relation+, raising a Rhizos::SchemaError if
	### both +other_relation+ and the receiver define properties.
	def merge_properties( other_relation )
		return if other_relation.properties.empty?

		raise Rhizos::SchemaError, "conflicting property declarations in %s" % [ self.name ] if
			!self.properties.empty?

		self.properties.replace( other_relation.properties )
	end


	### Merge the multiplicity specification with +other_relation+, raising a
	### Rhizos::SchemaError if there's a conflict.
	def merge_multiplicities( other_relation )
		return unless other_relation.multiplicity

		raise Rhizos::SchemaError,
			"conflicting multiplicity declarations in %s" % [ self.name ] if
				self.multiplicity && self.multiplicity != other_relation.multiplicity

		self.multiplicity = other_relation.multiplicity
	end


	### Return a String containing a Cypher CREATE query for this DomainRelation.
	def cypher
		if self.connections.empty?
			self.log.warn "Ignoring REL type %s: no connections added" % [ self.name ]
			return nil
		end

		contents = [
			self.connections_cypher,
			self.properties_cypher,
			self.multiplicity
		]

		return CREATE_QUERY % {
			name: self.name,
			description: self.description,
			contents: contents.flatten.compact.join( ",\n" )
		}
	end


	### Return a String containing Cypher language declarations for each of the
	### DomainRelation's connections.
	def connections_cypher
		lines = self.connections.map do |from_type, to_type|
			"  from %s to %s" % [ from_type, to_type ]
		end

		return lines
	end


	### Return a String containing Cypher language declarations for each of
	### the DomainRelation's properties.
	def properties_cypher
		lines = self.properties.map do |property|
			self.log.debug "Adding property %p to %p" % [ property.name, self.class ]
			line = "  %s %s" % [ property.name, property.type ]
			if (default_cypher = stringify_default( property.default ))
				line << " DEFAULT %s" % [ default_cypher ]
			end

			line
		end

		return lines
	end

end # class Rhizos::DomainRelation
