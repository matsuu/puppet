#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/rails'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'
require 'puppettest/railstesting'

class TestRailsHost < Test::Unit::TestCase
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::RailsTesting

    def setup
        super
        railsinit if Puppet.features.rails?
    end

    def teardown
        railsteardown if Puppet.features.rails?
        super
    end

    def test_includerails
        assert_nothing_raised {
            require 'puppet/rails'
        }
    end

    # Don't do any tests w/out this class
    if Puppet.features.rails?
    def test_store
        @interp, @scope, @source = mkclassframing
        # First make some objects
        resources = []
        10.times { |i|
            # Make a file
            resources << mkresource(:type => "file",
                :title => "/tmp/file#{i.to_s}",
                :params => {:owner => "user#{i}"})

            # And an exec, so we're checking multiple types
            resources << mkresource(:type => "exec",
                :title => "/bin/echo file#{i.to_s}",
                :params => {:user => "user#{i}"})
        }

        # Now collect our facts
        facts = {"hostname" => Facter.value(:hostname), "test1" => "funtest",
            "ipaddress" => Facter.value(:ipaddress)}

        # Now try storing our crap
        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.store(
                :resources => resources,
                :facts => facts,
                :name => facts["hostname"],
                :classes => ["one", "two::three", "four"]
            )
        }

        assert(host, "Did not create host")

        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.find_by_name(facts["hostname"])
        }
        assert(host, "Could not find host object")

        assert(host.resources, "No objects on host")

        facts.each do |fact, value|
            assert_equal(value, host.fact(fact), "fact %s is wrong" % fact)
        end
        assert_equal(facts["ipaddress"], host.ip, "IP did not get set")

        count = 0
        host.resources.each do |resource|
            assert_equal(host, resource.host)
            count += 1
            i = nil
            if resource[:title] =~ /file([0-9]+)/
                i = $1
            else
                raise "Got weird resource %s" % resource.inspect
            end
            assert(resource[:restype] != "", "Did not get a type from the resource")
            case resource["restype"]
            when "file":
                assert_equal("user#{i}", resource.parameter("owner"),
                    "got no owner for %s" % resource.ref)
            when "exec":
                assert_equal("user#{i}", resource.parameter("user"),
                    "got no user for %s" % resource.ref)
            else
                raise "Unknown type %s" % resource[:restype].inspect
            end
        end

        assert_equal(20, count, "Did not get enough resources")

        # Now remove a couple of resources and change a fact
        resources.reject! { |r| r.title =~ /file9/ }
        facts["test2"] = "yaytest"
        facts.delete("test1")
        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.store(
                :resources => resources,
                :facts => facts,
                :name => facts["hostname"],
                :classes => ["one", "two::three", "four"]
            )
        }

        assert_nil(host.fact('test1'), "removed fact was not deleted")
        facts.each do |fact, value|
            assert_equal(value, host.fact(fact), "fact %s is wrong" % fact)
        end

        assert(! host.resources.find(:all).detect { |r| r.title =~ /file9/ },
            "Removed resources are still present")
    end
    else
        $stderr.puts "Install Rails for Rails and Caching tests"
    end
end

# $Id$