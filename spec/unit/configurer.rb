#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-12.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/configurer'

describe Puppet::Configurer do
    it "should include the Plugin Handler module" do
        Puppet::Configurer.ancestors.should be_include(Puppet::Configurer::PluginHandler)
    end

    it "should include the Fact Handler module" do
        Puppet::Configurer.ancestors.should be_include(Puppet::Configurer::FactHandler)
    end

    it "should use the puppetdlockfile as its lockfile path" do
        Puppet.settings.expects(:value).with(:puppetdlockfile).returns("/my/lock")
        Puppet::Configurer.lockfile_path.should == "/my/lock"
    end
end

describe Puppet::Configurer, "when executing a catalog run" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Configurer.new
    end

    it "should prepare for the run" do
        @agent.expects(:prepare)

        @agent.run
    end

    it "should retrieve the catalog" do
        @agent.expects(:retrieve_catalog)

        @agent.run
    end

    it "should log a failure and do nothing if no catalog can be retrieved" do
        @agent.expects(:retrieve_catalog).returns nil

        Puppet.expects(:err)

        @agent.run
    end

    it "should apply the catalog with all options to :run" do
        catalog = stub 'catalog', :retrieval_duration= => nil
        @agent.expects(:retrieve_catalog).returns catalog

        catalog.expects(:apply).with(:one => true)
        @agent.run :one => true
    end
    
    it "should benchmark how long it takes to apply the catalog" do
        @agent.expects(:benchmark).with(:notice, "Finished catalog run")

        catalog = stub 'catalog', :retrieval_duration= => nil
        @agent.expects(:retrieve_catalog).returns catalog

        catalog.expects(:apply).never # because we're not yielding
        @agent.run
    end
end

describe Puppet::Configurer, "when retrieving a catalog" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Configurer.new

        @catalog = Puppet::Resource::Catalog.new

        @agent.stubs(:convert_catalog).returns @catalog
    end

    it "should use the Catalog class to get its catalog" do
        Puppet::Resource::Catalog.expects(:find).returns @catalog

        @agent.retrieve_catalog
    end

    it "should use its Facter name to retrieve the catalog" do
        Facter.stubs(:value).returns "eh"
        Facter.expects(:value).with("hostname").returns "myhost"
        Puppet::Resource::Catalog.expects(:find).with { |name, options| name == "myhost" }.returns @catalog

        @agent.retrieve_catalog
    end

    it "should default to returning a catalog retrieved directly from the server, skipping the cache" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return the cached catalog when no catalog can be retrieved from the server" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should not look in the cache for a catalog if one is returned from the server" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns @catalog
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_terminus] == true }.never

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return the cached catalog when retrieving the remote catalog throws an exception" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_cache] == true }.raises "eh"
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return nil if no cached catalog is available and no catalog can be retrieved from the server" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns nil

        @agent.retrieve_catalog.should be_nil
    end

    it "should convert the catalog before returning" do
        Puppet::Resource::Catalog.stubs(:find).returns @catalog

        @agent.expects(:convert_catalog).with { |cat, dur| cat == @catalog }.returns "converted catalog"
        @agent.retrieve_catalog.should == "converted catalog"
    end

    it "should return nil if there is an error while retrieving the catalog" do
        Puppet::Resource::Catalog.expects(:find).raises "eh"

        @agent.retrieve_catalog.should be_nil
    end
end

describe Puppet::Configurer, "when converting the catalog" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Configurer.new

        @catalog = Puppet::Resource::Catalog.new
        @oldcatalog = stub 'old_catalog', :to_ral => @catalog
    end

    it "should convert the catalog to a RAL-formed catalog" do
        @oldcatalog.expects(:to_ral).returns @catalog

        @agent.convert_catalog(@oldcatalog, 10).should equal(@catalog)
    end

    it "should record the passed retrieval time with the RAL catalog" do
        @catalog.expects(:retrieval_duration=).with 10

        @agent.convert_catalog(@oldcatalog, 10)
    end

    it "should write the RAL catalog's class file" do
        @catalog.expects(:write_class_file)

        @agent.convert_catalog(@oldcatalog, 10)
    end

    it "should mark the RAL catalog as a host catalog" do
        @catalog.expects(:host_config=).with true

        @agent.convert_catalog(@oldcatalog, 10)
    end
end

describe Puppet::Configurer, "when preparing for a run" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Configurer.new
        @agent.stubs(:dostorage)
        @agent.stubs(:upload_facts)
        @facts = {"one" => "two", "three" => "four"}
    end

    it "should initialize the metadata store" do
        @agent.class.stubs(:facts).returns(@facts)
        @agent.expects(:dostorage)
        @agent.prepare
    end

    it "should download fact plugins" do
        @agent.stubs(:dostorage)
        @agent.expects(:download_fact_plugins)

        @agent.prepare
    end

    it "should download plugins" do
        @agent.stubs(:dostorage)
        @agent.expects(:download_plugins)

        @agent.prepare
    end

    it "should upload facts to use for catalog retrieval" do
        @agent.stubs(:dostorage)
        @agent.expects(:upload_facts)
        @agent.prepare
    end
end
