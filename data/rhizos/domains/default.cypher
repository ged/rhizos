/*
 * Schema info
 */

CREATE NODE TABLE RhizosDomain (
	id SERIAL PRIMARY KEY,
	name STRING,
	version STRING
);
COMMENT ON TABLE RhizosDomain IS 'Loaded Rhizos domains';


/*
 * Rhizos domain (middle ontology)
 */

CREATE (:RhizosDomain {name: 'default', version: '0.1.0'});

CREATE NODE TABLE Fact (
    id UUID DEFAULT gen_random_uuid(),
    createdAt TIMESTAMP DEFAULT current_timestamp(),
    updatedAt TIMESTAMP,
    confidence INT8 DEFAULT 0,
    PRIMARY KEY (id)
);
COMMENT ON TABLE Fact IS 'Core entity type';


CREATE NODE TABLE Lifetime (
    id UUID DEFAULT gen_random_uuid(),
    beginsAt TIMESTAMP,  // Can be null for indeterminate start
    endsAt TIMESTAMP,    // Can be null for indeterminate end
    description STRING,
    PRIMARY KEY (id)
);
COMMENT ON TABLE Lifetime IS 'Interval during which a Fact is current.';


CREATE NODE TABLE Actor (
    id UUID DEFAULT gen_random_uuid(),
    identifier STRING,
    isLocal BOOLEAN DEFAULT true,
    PRIMARY KEY (id)
);
COMMENT ON TABLE Actor IS 'system or entity that creates Facts';


CREATE NODE TABLE GeoPosition (
    id UUID DEFAULT gen_random_uuid(),
	label STRING,
    ordinal INT32,
    latitude FLOAT,
    longitude FLOAT,
    accuracy INT8,
    hae FLOAT,
    PRIMARY KEY (id)
);
COMMENT ON TABLE GeoPosition IS 'geographic position with accuracy';


CREATE NODE TABLE Movement (
    id UUID DEFAULT gen_random_uuid(),
    direction FLOAT, // In degrees
    velocity FLOAT,  // In Km/Hour
    PRIMARY KEY (id)
);
COMMENT ON TABLE Movement IS 'movement vector of a geo position';


CREATE NODE TABLE GeoArea (
    id UUID DEFAULT gen_random_uuid(),
    label STRING,
    PRIMARY KEY (id)
);
COMMENT ON TABLE GeoArea IS 'area described by a set of geo positions';


/*
 * Tactical Domain -- Helios
 */

CREATE (:RhizosDomain {name: 'tactical', version: '0.1.0'});

CREATE NODE TABLE Communication (
    id UUID DEFAULT gen_random_uuid(),
    callsign STRING,
    PRIMARY KEY (id)
);
COMMENT ON TABLE Communication IS 'coordinating tactical communication';


CREATE NODE TABLE ISRRequest (
    id UUID DEFAULT gen_random_uuid(),
    PRIMARY KEY (id)
);
COMMENT ON TABLE ISRRequest IS 'request for information, surveillance, or reconnaissance';


/*
 * RELs (for every domain)
 */

CREATE REL TABLE IS_A (
    from Communication to Fact,
    from ISRRequest to Fact,
    from Actor to Fact
);
COMMENT ON TABLE IS_A IS 'type-of relations';


CREATE REL TABLE HAS_A (
    from Fact to Lifetime,
    from Fact to Actor,
    from Communication to ISRRequest,
    from ISRRequest to GeoPosition,
    from GeoPosition to Movement,
    from GeoArea to GeoPosition,
    label STRING,
    ordinal INT32,
    MANY_ONE
);
COMMENT ON TABLE HAS_A IS 'composition relations';

