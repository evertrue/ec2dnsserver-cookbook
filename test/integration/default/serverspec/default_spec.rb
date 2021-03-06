require 'spec_helper'

describe 'Bind Service' do
  describe port(53) do
    %w(tcp udp).each do |proto|
      it { should be_listening.with(proto) }
    end
  end

  describe command('dig google.com @localhost') do
    its(:stdout) { should match(/status: NOERROR/) }
  end

  describe service('bind9') do
    it { should be_running }
    it { should be_enabled }
  end
end

describe 'Bind Config' do
  describe file('/etc/bind/named.conf.options') do
    # WARNING: This is totally dependent on the actual subnet address of
    # EverTrue's actual VPC.  It won't play well for other users.
    it do
      should contain <<EOS
  forwarders {
    10.99.0.2;
  };
EOS
    end
  end
end

describe 'Zone Data' do
  describe command('dig SOA priv.yourdomain.local @localhost') do
    its(:stdout) { should match(/status: NOERROR/) }
    its(:stdout) { should match(/hostmaster\.yourdomain\.local\./) }
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

  describe file('/etc/bind/named.conf.remote') do
    it do
      should contain(
        'zone "testforwardzone" IN {
  type forward;
  forward only;
  forwarders { 127.0.0.1 port 8600 };
};'
      )
    end
  end

  describe file('/etc/rsyslog.d/25-named.conf') do
    it { should contain '$DirGroup bind' }
    it { should contain '/var/log/named/named.log;BindLog' }
  end

  describe file('/etc/bind/db.priv.yourdomain.local') do
    [
      '$ORIGIN priv.yourdomain.local',
      ' NS ',
      ' IN A 10.',
      'some-other-host IN CNAME foo-bar',
      'some-host IN A 1.2.3.4'
    ].each do |search_str|
      it { should contain search_str }
    end
  end
end

describe 'Overrides' do
  describe command('dig +short test-value-host.yourdomain.local '\
    '@localhost') do
    its(:stdout) { should match('1.1.1.1') }
  end

  describe command('dig +short test-storm.priv.yourdomain.local '\
    '@localhost') do
    its(:stdout) do
      should match(/prod-dns-1c-1\.priv\.yourdomain\.local\./)
    end
  end
end

describe 'Company specific overrides' do
  # These overrides require that your Amazon cluster actually contain specific
  # servers meeting the search requirements (defined in .kitchen.yml).  You
  # will need to set the IP below to match the IP of your real instances. I
  # realize it sucks to have a company-specific test in a community cookbook but
  # this is such a good integration test that it's hard to pass up in the name
  # of making it easy to use.
  #
  # In the case of Evertrue the instance should be (as of this writing):
  # prod-dns-1c-1 10.0.112.248
  describe command('dig +short test-cookbook-host.yourdomain.local '\
    '@localhost') do
    its(:stdout) { should match('1.2.3.4') } # <-- SET THIS IP
  end

  describe command('dig +short -x 10.0.112.248 @localhost') do # <-- SET THIS IP, too!
    its(:stdout) do
      should match(/^prod-dns-1c-1\.priv\.yourdomain\.local\.$/)
    end
  end
end
