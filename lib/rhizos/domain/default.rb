# -*- ruby -*-

require 'loggability'

require 'rhizos/domain' unless defined?( Rhizos::Domain )


class Rhizos::Domain::Default < Rhizos::Domain

	version Rhizos::VERSION


	rel :IS_A, "type-of relations"

	rel :HAS_A, "composition relations" do
		string :label
		int32 :ordinal

		many_one
	end


	type :Fact, "The base unit of knowledge" do
		timestamp :createdAt, default: :current_timestamp
		timestamp :updatedAt

		int8 :confidence, default: 0
	end


	type :Lifetime, "Interval during which a Fact is current" do
		timestamp :beginsAt
		timestamp :endsAt
		string :description
	end

	rel :HAS_A, from: :Fact, to: :Lifetime


	type :Actor, "system that created a Fact", is_a: :Fact do
		string :identifier
		boolean :isLocal, default: true
	end

	rel :HAS_A, from: :Fact, to: :Actor


end # class Rhizos::Domain::Default


