actions :create, :delete
default_action :create

attribute :apex,            kind_of: String,            name_attribute: true
attribute :path,            kind_of: String,            default: nil
attribute :suffix,          kind_of: String,            default: nil
attribute :source_host,     kind_of: String,            default: node.name
attribute :ptr,             equal_to: [true, false],    default: false
attribute :default_ttl,     kind_of: Fixnum,            default: 300
attribute :contact_email,   kind_of: String,            required: true
attribute :refresh_time,    kind_of: [String, Fixnum],  default: '3600'
attribute :retry_time,      kind_of: [String, Fixnum],  default: '600'
attribute :expire_time,     kind_of: [String, Fixnum],  default: '86400'
attribute :nxdomain_ttl,    kind_of: [String, Fixnum],  default: '300'
attribute :vpcs,            kind_of: Array,             default: []
attribute :static_records,  kind_of: Hash,              default: {}
attribute :avoid_subnets,   kind_of: Array,             default: []
attribute :stub,            equal_to: [true, false],    default: false
attribute :ns_zone,         kind_of: String,            default: nil
