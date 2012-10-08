require "rubygems"
require 'pg'
require "uri"
require 'activeRecord'

db = URI.parse  ENV['DATABASE_URL']||"postgres://grape:@127.0.0.1:5432/grape"
ActiveRecord::Base.establish_connection(
	:adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
	:host     => db.host,
	:username => db.user,
	:password => db.password,
	:database => db.path[1..-1],
	:encoding => 'utf8',
	:min_messages => 'NOTICE'
)

ActiveRecord::Schema.define do
	create_table(:users) do |table|
		table.column :phoneNumber,    :string
		table.column :salt,           :string	
		table.column :passwordhash,   :string
		table.column :created,        :datetime #time
		table.column :plan,           :integer
		table.column :active,         :boolean
	end
end