# -*- ruby -*-

require 'loggability'

require 'rhizos/domain' unless defined?( Rhizos::Domain )


class Rhizos::Domain::Geo < Rhizos::Domain

	version '0.0.1'

	prefix 'geo'


	type :GeoPosition, "geographic position with accuracy" do
		string :label
		int32 :ordinal
		float :latitude
		float :longitude
		string :mgrs
		float :hae
		int8 :accuracy
	end


	type :Movement, "vector of change of a geo position" do
	    float :direction    # In degrees
	    float :velocity     # In Km/Hour
	end

	rel :HAS_A, from: :GeoPosition, to: :Movement


	type :GeoArea, "area described by a set of geographic positions" do
		string :label
	end

	rel :HAS_A, from: :GeoArea, to: :GeoPosition


end # class Rhizos::Domain::Geo


