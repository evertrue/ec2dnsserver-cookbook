# coding=utf-8
name             'ec2dnsserver'
maintainer       'EverTrue, Inc.'
maintainer_email 'devops@evertrue.com'
license          'All rights reserved'
description      'Installs/Configures ec2dnsserver'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.4.0'

depends 'build-essential'
depends 'et_fog', '= 1.0.3'
