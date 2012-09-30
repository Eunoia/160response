require "rubygems"
require 'pg'
require "uri"
require 'activeRecord'
# require "ruby-aws"
#require "twilio-ruby"

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
	create_table(:questions) do |table|
		#mturk fields
		table.column :hitid,         :string
		table.column :hittypeid,     :string	
		table.column :workerid,      :string
		table.column :timeFinished,  :datetime #time
		table.column :response,      :text
		table.column :value,         :real
		#user fields
		table.column :questionText,  :text
		table.column :phoneNumber,   :string
		table.column :timeRecived,   :datatime #time
		table.column :timeSent,      :datetime #time
	end
	#add_index(:hitid,:unique => true) #does not work yet
end