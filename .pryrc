#!/usr/bin/ruby -*- ruby -*-

require 'loggability'

$LOAD_PATH.unshift( 'lib' )

begin
	require 'rhizos'

	Rhizos.load_config

	Loggability.level = :debug
rescue Exception => e
	$stderr.puts "Ack! Libraries failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end


