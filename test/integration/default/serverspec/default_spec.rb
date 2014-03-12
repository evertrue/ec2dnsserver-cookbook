require 'spec_helper'

describe 'Bind Service' do
  describe port(53) do
    %w(tcp udp).each do |proto|
      it { should be_listening.with(proto) }
    end
  end

  describe command('dig google.com @localhost') do
    it { should return_stdout(/status: NOERROR/) }
  end

  describe service('bind9') do
    it { should be_running }
    it { should be_enabled }
  end
end

describe 'Zone Data' do
  describe command('dig SOA priv.evertrue.com @localhost') do
    it { should return_stdout(/status: NOERROR/) }
    it { should return_stdout(/hostmaster\.evertrue\.com\./) }
  end

  describe file('/etc/bind/named.conf.local') do
    it { should contain 'zone "priv.evertrue.com" {' }
    it { should contain 'zone "10.in-addr.arpa" {' }
  end

  describe file('/etc/bind/named.conf.options') do
    it { should contain '192.168.19.0/24;' }
    it { should contain 'listen-on-v6 { none; };' }
    it { should contain '/var/cache/bind' }
  end

  describe file('/etc/rsyslog.d/25-named.conf') do
    it { should contain '$DirGroup bind' }
    it { should contain '/var/log/named/named.log;BindLog' }
  end

  describe file('/etc/bind/db.priv.evertrue.com') do
    it { should contain '$ORIGIN priv.evertrue.com' }
    it { should contain ' NS ' }
    it { should contain ' IN A 10.' }
  end
end

describe 'Overrides' do
  describe command('dig +short test-cookbook-host.evertrue.com '\
    '@localhost') do
    it { should return_stdout('10.0.5.177') }
  end

  describe command('dig +short test-value-host.evertrue.com '\
    '@localhost') do
    it { should return_stdout('1.1.1.1') }
  end

  describe command('dig +short stage-storm.priv.evertrue.com '\
    '@localhost') do
    it { should return_stdout('stage-ops-haproxy-1b.priv.evertrue.com.') }
  end
end
