# -*- ruby -*-

require 'loggability'

require 'rhizos/domain' unless defined?( Rhizos::Domain )


class Rhizos::Domain::Default < Rhizos::Domain


	type :Fact, "The base unit of knowledge" do
		timestamp :created_at, default: 'current_timestamp()'
		timestamp :updated_at

		int8 :confidence, default: 0
	end


	type :Lifetime, "Interval during which a Fact is current" do
		timestamp :begins_at
		timestamp :ends_at
		string :description
	end

	rel :Fact, has: :Lifetime


	type :Actor, "system that created a Fact" do
		string :identifier
		boolean :is_local, default: true
	end

	rel :Fact, has: :Actor


	type :GeoPosition, "geographic position with accuracy" do
		string :label
		int32 :ordinal
		float :latitude
		float :longitude
		float :hae
		int8 :accuracy
	end


	type :Movement, "vector of change of a geo position" do
	    float :direction    # In degrees
	    float :velocity     # In Km/Hour
	end

	rel :GeoPosition, has: :Movement



	

end # class Rhizos::Domain::Default


