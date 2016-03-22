# coding=utf-8
name             'ec2dnsserver'
maintainer       'EverTrue, Inc.'
maintainer_email 'devops@evertrue.com'
license          'Apache 2.0'
description      'Installs/Configures ec2dnsserver'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '2.2.1'

issues_url 'https://github.com/evertrue/ec2dnsserver-cookbook/issues' if respond_to? :issues_url
source_url 'https://github.com/evertrue/ec2dnsserver-cookbook/' if respond_to? :source_url

depends 'build-essential'
depends 'et_fog', '~> 1.0'
