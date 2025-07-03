# -*- ruby -*-

require 'loggability'

require 'rhizos/evolver' unless defined?( Rhizos::Evolver )
require 'rhizos/refinements'

using Rhizos::NumericRefinements


# An evolver that cleans up Facts whose Lifetime has expired.
#
# - A Lifetime is expired if it has an `endsAt` that is in the past
# - A Fact expires if it doesn't have an associated Lifetime.
#
class Rhizos::Evolver::LifetimeExpirer < Rhizos::Evolver


end # class Rhizos::Evolver::LifetimeExpirer
