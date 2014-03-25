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
  describe command('dig SOA priv.yourdomain.local @localhost') do
    it { should return_stdout(/status: NOERROR/) }
    it { should return_stdout(/hostmaster\.yourdomain\.local\./) }
  end

  describe file('/etc/bind/named.conf.local') do
    it { should contain 'zone "priv.yourdomain.local" {' }
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

  describe file('/etc/bind/db.priv.yourdomain.local') do
    it { should contain '$ORIGIN priv.yourdomain.local' }
    it { should contain ' NS ' }
    it { should contain ' IN A 10.' }
  end
end

describe 'Overrides' do
  describe command('dig +short test-value-host.yourdomain.local '\
    '@localhost') do
    it { should return_stdout('1.1.1.1') }
  end

  describe command('dig +short stage-storm.priv.yourdomain.local '\
    '@localhost') do
    it { should return_stdout('stage-ops-haproxy-1b.priv.yourdomain.local.') }
  end
end

describe 'Company specific overrides' do
  # These overrides require that your Amazon cluster actually contain specific
  # servers meeting the search requirements (defined in .kitchen.yml).  You
  # will need to set the IP below to match the IP of your real instances.
  describe command('dig +short test-cookbook-host.yourdomain.local '\
    '@localhost') do
    it { should return_stdout('10.0.5.177') } # <-- SET THIS IP
  end
end
