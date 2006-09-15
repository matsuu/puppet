if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

class TestProvider < Test::Unit::TestCase
	include TestPuppet

    def echo
        echo = Puppet::Util.binary("echo")

        unless echo
            raise "Could not find 'echo' binary; cannot complete test"
        end

        return echo
    end

    def newprovider
        # Create our provider
        provider = Class.new(Puppet::Provider) do
            @name = :fakeprovider
        end
        provider.initvars

        return provider
    end

    def test_confine
        provider = newprovider

        assert(provider.suitable?,
            "Marked unsuitable with no confines")

        {
            {:true => true} => true,
            {:true => false} => false,
            {:false => false} => true,
            {:false => true} => false,
            {:operatingsystem => Facter.value(:operatingsystem)} => true,
            {:operatingsystem => :yayness} => false,
            {:nothing => :yayness} => false,
            {:exists => echo} => true,
            {:exists => "/this/file/does/not/exist"} => false,
        }.each do |hash, result|
            # First test :true
            hash.each do |test, val|
                assert_nothing_raised do
                    provider.confine test => val
                end
            end

            assert_equal(result, provider.suitable?,
                "Failed for %s" % [hash.inspect])

            provider.initvars
        end

        # Make sure multiple confines don't overwrite each other
        provider.confine :true => false
        assert(! provider.suitable?)
        provider.confine :true => true
        assert(! provider.suitable?)

        provider.initvars

        # Make sure we test multiple of them, and that a single false wins
        provider.confine :true => true, :false => false
        assert(provider.suitable?)
        provider.confine :true => false
        assert(! provider.suitable?)
    end

    def test_command
        provider = newprovider

        assert_nothing_raised do
            provider.commands :echo => "echo"
        end

        assert_equal(echo, provider.command(:echo))

        assert(provider.method_defined?(:echo), "Instance method not defined")
        assert(provider.respond_to?(:echo), "Class method not defined")

        # Now make sure they both work
        inst = provider.new(nil)
        assert_nothing_raised do
            [provider, inst].each do |thing|
                out = thing.echo "some text"
                assert_equal("some text\n", out)
            end
        end

        assert(provider.suitable?, "Provider considered unsuitable")

        # Now add an invalid command
        assert_nothing_raised do
            provider.commands :fake => "nosuchcommanddefinitely"
        end
        assert(! provider.suitable?, "Provider considered suitable")

        assert_raise(Puppet::Error) do
            provider.command(:fake)
        end

        assert_raise(Puppet::DevError) do
            provider.command(:nosuchcmd)
        end

        # Lastly, verify that we can find our superclass commands
        newprov = Class.new(provider)
        newprov.initvars

        assert_equal(echo, newprov.command(:echo))
    end
end

# $Id$