# -*- ruby -*-

require_relative '../spec_helper'

require 'rhizos/timer'


RSpec.describe( Rhizos::Timer ) do

	it "can be created with an interval and a callback" do
		it_was_called = false
		instance = described_class.new( 2 ) do
			it_was_called = true
		end

		expect( instance ).to be_an_instance_of( described_class )
		expect( instance.interval ).to eq( 2 )
		expect( instance.callback ).to be_a( Proc )
	end


	it "errors if created with no callback" do
		expect {
			described_class.new( 2 )
		}.to raise_error( ArgumentError, /missing callback/i )
	end


	it "can manually fire the callback" do
		it_was_called = false
		instance = described_class.new( 2 ) do
			it_was_called = true
		end

		expect { instance.fire }.to change { it_was_called }.to( true )
	end


	it "can be started" do
		called_count = 0
		callback = ->( * ) { called_count += 1 }

		instance = described_class.new( 0.4, &callback )

		instance.start
		sleep 1
		instance.stop

		expect( called_count ).to be >= 2
	end


	it "can be started and run right away" do
		called_count = 0
		callback = ->( * ) { called_count += 1 }

		instance = described_class.new( 3, &callback )

		instance.start( fire_now: true )
		sleep 0.1
		instance.stop

		expect( called_count ).to be >= 1
	end


	it "can be stopped" do
		instance = described_class.new( 0.4 ) {}

		instance.start
		instance.stop

		expect( instance ).to be_stopped
		expect( instance.task ).to be_nil
	end

end

