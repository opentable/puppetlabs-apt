require 'spec_helper'
describe 'apt' do
  let(:facts) { { :lsbdistid => 'Debian', :osfamily => 'Debian', :lsbdistcodename => 'wheezy'} }

  context 'defaults' do
    it { is_expected.to contain_file('sources.list').that_notifies('Exec[apt_update]').only_with({
      :ensure  => 'file',
      :path    => '/etc/apt/sources.list',
      :owner   => 'root',
      :group   => 'root',
      :mode    => '0644',
      :content => "# Repos managed by puppet.\n",
      :notify  => 'Exec[apt_update]',
    })}

    it { is_expected.to contain_file('sources.list.d').that_notifies('Exec[apt_update]').only_with({
      :ensure  => 'directory',
      :path    => '/etc/apt/sources.list.d',
      :owner   => 'root',
      :group   => 'root',
      :mode    => '0644',
      :purge   => true,
      :recurse => true,
      :notify  => 'Exec[apt_update]',
    })}

    it { is_expected.to contain_file('preferences').that_notifies('Exec[apt_update]').only_with({
      :ensure  => 'absent',
      :path    => '/etc/apt/preferences',
      :owner   => 'root',
      :group   => 'root',
      :mode    => '0644',
      :notify  => 'Exec[apt_update]',
    })}

    it { is_expected.to contain_file('preferences.d').that_notifies('Exec[apt_update]').only_with({
      :ensure  => 'directory',
      :path    => '/etc/apt/preferences.d',
      :owner   => 'root',
      :group   => 'root',
      :mode    => '0644',
      :purge   => true,
      :recurse => true,
      :notify  => 'Exec[apt_update]',
    })}

    it 'should lay down /etc/apt/apt.conf.d/15update-stamp' do
      is_expected.to contain_file('/etc/apt/apt.conf.d/15update-stamp').with({
        :group => 'root',
        :mode  => '0644',
        :owner => 'root',
      }).with_content(/APT::Update::Post-Invoke-Success \{"touch \/var\/lib\/apt\/periodic\/update-success-stamp 2>\/dev\/null \|\| true";\};/)
    end

    it { is_expected.to contain_exec('apt_update').with({
      :refreshonly => 'true',
    })}

    it { is_expected.not_to contain_apt__setting('conf-proxy') }
  end

  describe 'proxy=' do
    context 'host=localhost' do
      let(:params) { { :proxy => { 'host' => 'localhost'} } }
      it { is_expected.to contain_apt__setting('conf-proxy').with({
        :priority => '01',
      }).with_content(
        /Acquire::http::proxy "http:\/\/localhost:8080\/";/
      ).without_content(
        /Acquire::https::proxy/
      )}
    end

    context 'host=localhost and port=8180' do
      let(:params) { { :proxy => { 'host' => 'localhost', 'port' => 8180} } }
      it { is_expected.to contain_apt__setting('conf-proxy').with({
        :priority => '01',
      }).with_content(
        /Acquire::http::proxy "http:\/\/localhost:8180\/";/
      ).without_content(
        /Acquire::https::proxy/
      )}
    end

    context 'host=localhost and https=true' do
      let(:params) { { :proxy => { 'host' => 'localhost', 'https' => true} } }
      it { is_expected.to contain_apt__setting('conf-proxy').with({
        :priority => '01',
      }).with_content(
        /Acquire::http::proxy "http:\/\/localhost:8080\/";/
      ).with_content(
        /Acquire::https::proxy "https:\/\/localhost:8080\/";/
      )}
    end
  end
  context 'lots of non-defaults' do
    let :params do
      {
        :update => { 'frequency' => 'always', 'timeout' => 1, 'tries' => 3 },
        :purge  => { 'sources.list' => false, 'sources.list.d' => false,
                     'preferences' => false, 'preferences.d' => false, },
      }
    end

    it { is_expected.to contain_file('sources.list').without({
      :content => "# Repos managed by puppet.\n",
    })}

    it { is_expected.to contain_file('sources.list.d').with({
      :purge   => false,
      :recurse => false,
    })}

    it { is_expected.to contain_file('preferences').with({
      :ensure => 'file',
    })}

    it { is_expected.to contain_file('preferences.d').with({
      :purge   => false,
      :recurse => false,
    })}

    it { is_expected.to contain_exec('apt_update').with({
      :refreshonly => false,
      :timeout     => 1,
      :tries       => 3,
    })}

  end

  context 'with sources defined on valid osfamily' do
    let :facts do
      { :osfamily        => 'Debian',
        :lsbdistcodename => 'precise',
        :lsbdistid       => 'Debian',
      }
    end
    let(:params) { { :sources => {
      'debian_unstable' => {
        'location'          => 'http://debian.mirror.iweb.ca/debian/',
        'release'           => 'unstable',
        'repos'             => 'main contrib non-free',
        'key'               => { 'id' => '55BE302B', 'server' => 'subkeys.pgp.net' },
        'pin'               => '-10',
        'include'           => {'src' => true,},
      },
      'puppetlabs' => {
        'location'   => 'http://apt.puppetlabs.com',
        'repos'      => 'main',
        'key'        => { 'id' => '4BD6EC30', 'server' => 'pgp.mit.edu' },
      }
    } } }

    it {
      is_expected.to contain_apt__setting('list-debian_unstable').with({
        :ensure => 'present',
      })
    }

    it { is_expected.to contain_file('/etc/apt/sources.list.d/debian_unstable.list').with_content(/^deb http:\/\/debian.mirror.iweb.ca\/debian\/ unstable main contrib non-free$/) }
    it { is_expected.to contain_file('/etc/apt/sources.list.d/debian_unstable.list').with_content(/^deb-src http:\/\/debian.mirror.iweb.ca\/debian\/ unstable main contrib non-free$/) }

    it {
      is_expected.to contain_apt__setting('list-puppetlabs').with({
        :ensure => 'present',
      })
    }

    it { is_expected.to contain_file('/etc/apt/sources.list.d/puppetlabs.list').with_content(/^deb http:\/\/apt.puppetlabs.com precise main$/) }
  end

  context 'with keys defined on valid osfamily' do
    let :facts do
      { :osfamily        => 'Debian',
        :lsbdistcodename => 'precise',
        :lsbdistid       => 'Debian',
      }
    end
    let(:params) { { :keys => {
      '55BE302B' => {
        'server' => 'subkeys.pgp.net',
      },
      '4BD6EC30' => {
        'server' => 'pgp.mit.edu',
      }
    } } }

    it { is_expected.to contain_apt__key('55BE302B').with({
        :server => 'subkeys.pgp.net',
    })}

    it { is_expected.to contain_apt__key('4BD6EC30').with({
        :server => 'pgp.mit.edu',
    })}
  end

  context 'with ppas defined on valid osfamily' do
    let :facts do
      { :osfamily        => 'Debian',
        :lsbdistcodename => 'precise',
        :lsbdistid       => 'ubuntu',
      }
    end
    let(:params) { { :ppas => {
      'ppa:drizzle-developers/ppa' => {},
      'ppa:nginx/stable' => {},
    } } }

    it { is_expected.to contain_apt__ppa('ppa:drizzle-developers/ppa')}
    it { is_expected.to contain_apt__ppa('ppa:nginx/stable')}
  end

  context 'with settings defined on valid osfamily' do
    let :facts do
      { :osfamily        => 'Debian',
        :lsbdistcodename => 'precise',
        :lsbdistid       => 'Debian',
      }
    end
    let(:params) { { :settings => {
      'conf-banana' => { 'content' => 'banana' },
      'pref-banana' => { 'content' => 'banana' },
    } } }

    it { is_expected.to contain_apt__setting('conf-banana')}
    it { is_expected.to contain_apt__setting('pref-banana')}
  end

  describe 'failing tests' do
    context "purge['sources.list']=>'banana'" do
      let(:params) { { :purge => { 'sources.list' => 'banana' }, } }
      it do
        expect {
          is_expected.to compile
        }.to raise_error(Puppet::Error)
      end
    end

    context "purge['sources.list.d']=>'banana'" do
      let(:params) { { :purge => { 'sources.list.d' => 'banana' }, } }
      it do
        expect {
          is_expected.to compile
        }.to raise_error(Puppet::Error)
      end
    end

    context "purge['preferences']=>'banana'" do
      let(:params) { { :purge => { 'preferences' => 'banana' }, } }
      it do
        expect {
          is_expected.to compile
        }.to raise_error(Puppet::Error)
      end
    end

    context "purge['preferences.d']=>'banana'" do
      let(:params) { { :purge => { 'preferences.d' => 'banana' }, } }
      it do
        expect {
          is_expected.to compile
        }.to raise_error(Puppet::Error)
      end
    end

    context 'with unsupported osfamily' do
      let :facts do
        { :osfamily => 'Darwin', }
      end

      it do
        expect {
          is_expected.to compile
        }.to raise_error(Puppet::Error, /This module only works on Debian or derivatives like Ubuntu/)
      end
    end
  end
end
