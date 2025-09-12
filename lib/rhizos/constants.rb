# -*- ruby -*-

require 'uri'
require 'rhizos' unless defined?( Rhizos )


# Useful constants for Rhizos systems.
module Rhizos::Constants

	#
	# General constants
	#

	# Pattern for matching UUIDs.
	UUID_PATTERN = %r{
		\A
		\h{8}
		(?:-\h{4}){3}
		-\h{12}
		\z
	}mx

	# Pattern for matching semantic versions. Not strict.
	SEMVER_VERSION_PATTERN = %r{
		\A
		(?<major>\d+)
		\.
		(?<minor>\d+)
		\.
		(?<patch>\d+)
		(?:-
			(?<prerelease>
				[a-z0-9-]+
				(?:\.[a-z0-9-]+)*
			)
		)?
		(?:\+
			(?<buildnum>
				[a-z0-9-]+
				(?:\.[a-z0-9-]+)*
			)
		)?
		\z
	}xi

	#
	# Schema info constants
	#

	# The name of the table which holds the loaded domains and their versions
	DOMAIN_INFO_TABLE = 'RhizosDomain'


	#
	# Domain constants
	#

	# The URI prefix used when deriving a domain's default or shorthand prefix
	DEFAULT_PREFIX_URI = URI( 'https://rhizos.info/' )

	# The URI of the default Rhizos domain
	DEFAULT_DOMAIN_URI = DEFAULT_PREFIX_URI + 'default'


	#
	# Cypher Queries
	#

	# A query that lists all tables in the current schema
	SHOW_TABLES_QUERY = 'CALL show_tables() RETURN *'


	# A query that returns tuples for each Fact
	MATCH_FACTS_QUERY = 'MATCH (f:Fact) RETURN f'


	# A query that returns tuples for each Lifetime
	MATCH_LIFETIMES_QUERY = 'MATCH (l:Lifetime) RETURN l'


	# A query that returns tuples for each Actor
	MATCH_ACTORS_QUERY = 'MATCH (a:Actor) RETURN a'


	# The Cypher query used to create the schema info table
	DOMAIN_INFO_TABLE_SCHEMA = <<~END_OF_QUERY
		CREATE NODE TABLE #{DOMAIN_INFO_TABLE} (
			id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
			name STRING,
			version STRING
		);
		COMMENT ON TABLE #{DOMAIN_INFO_TABLE} IS 'Loaded Rhizos domains'
	END_OF_QUERY


	# The Cypher source used to add a domain to the schema info table
	ADD_DOMAIN_INFO_QUERY = <<~END_OF_QUERY
		CREATE (:#{DOMAIN_INFO_TABLE} {name: $name, version: $version});
	END_OF_QUERY


	# The Cypher source used to alter the version of a loaded domain
	SET_DOMAIN_VERSION_QUERY = <<~END_OF_QUERY
		MATCH (d:#{DOMAIN_INFO_TABLE})
		WHERE d.name = $name
		SET d.version = $version
		RETURN d.*;
	END_OF_QUERY


	# The Cypher query used to create the local Actor Fact
	CREATE_LOCAL_ACTOR_QUERY = <<~END_OF_QUERY
		MERGE (a:Actor {id: uuid($id), isLocal: true})
			-[i:IS_A]->(fact:Fact {confidence: 100})
			-[h:HAS_A]->(life:Lifetime { description: "Actor is running" })
		ON CREATE SET
			life.beginsAt = current_timestamp()
		ON MATCH SET
			fact.updatedAt = current_timestamp()
		RETURN fact.id
	END_OF_QUERY


	# The Cypher query used to create an entry in the schema info table
	DOMAIN_INFO_CREATE_QUERY = <<~END_OF_QUERY
		CREATE (e:#{DOMAIN_INFO_TABLE} {name: $name, version: $version})
	END_OF_QUERY


	# The Cypher query used to select entries in the schema info table, returned
	# as tuples of `name`, `version`.
	DOMAIN_INFO_MATCH_QUERY = <<~END_OF_QUERY
		MATCH (e:#{DOMAIN_INFO_TABLE}) RETURN e.name AS name, e.version AS version;
	END_OF_QUERY


end # module Rhizos::Constants
