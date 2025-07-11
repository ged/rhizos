# -*- ruby -*-

require_relative 'spec_helper'

require 'rspec'
require 'rhizos'


RSpec.describe( Rhizos ) do

	it "has a semantic version" do
		expect( described_class::VERSION ).to match( /\A\d+(?:\.\d+){2}/ )
	end


	it "can load its config from a file" do
		config_file = tmpfile_pathname( 'other-config.yml' )
		config_file.write( described_class.default_config.dump )

		described_class.load_config( config_file.to_s )

		expect( described_class.config ).to be_a( Configurability::Config )
		expect( described_class.config_loaded? ).to be_truthy
		expect( described_class.config.path ).to eq( config_file )
	end


	it "uses defaults if there is no config file" do
		expect( described_class::LOCAL_CONFIG_FILE ).to receive( :exist? ).
			and_return( false )

		expect( Configurability::Config ).to_not receive( :load )

		expect( described_class.load_config )
		expect( described_class.config ).to be_a( Configurability::Config )
	end


	it "uses defaults if the config file is empty" do
		empty = tmpfile_pathname( 'emptyconf.yml' )
		empty.write( '' )

		expect( Configurability::Config ).to_not receive( :load )

		described_class.load_config( empty )
		expect( described_class.config ).to be_a( Configurability::Config )
		expect( described_class.config_loaded? ).to be_truthy
	end


	it "has a convenience constructor for a Factspace" do
		expect( described_class.factspace ).to be_a( Rhizos::Factspace )
	end

end

