require "rubygems"
require 'active_record'
require "ruby-aws"
require "twilio-ruby"
require 'pg'
require "uri"
# require 'ruby-debug'

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

class Questions < ActiveRecord::Base
end
class Users < ActiveRecord::Base
end

@@mturk = Amazon::WebServices::MechanicalTurkRequester.new({
	#:Config => File.join( File.dirname(__FILE__), 'mturk.yml' ),
	:Host => "Sandbox",
	:AWSAccessKeyId => ENV["AWS_KEY"],
	:AWSAccessKey => ENV["AWS_SECRET"]
})
@@twilio = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_TOKEN'])
# @@phoneNum = ENV["VALID_NUMBER"]
@@twillo_number = ENV["TWILIO_NUM"]

#get list of answered questions 
hitids = @@mturk.getReviewableHITs(:Status => "Reviewable", :PageSize => 100)[:HIT]
exit if hitids.nil?
puts hitids.length.to_s+" Reviewable tasks"
puts hitids.map{ |hit| hit[1]||hit[:HITId] }.join(" ")
hitids.map do |hit|
	hitId = hit[1]||hit[:HITId]
	puts "########## #{hitId} ##########"
	question = Questions.where(:hitid => hitId)
	#dispose of hit if it doesnt belong to question.
	if(question==[])
		@@mturk.forceExpireHIT(:HITId => hitId );
		puts "forced experation of HIT, it had no question"
		next
	end
	puts question.questionText
	#ask mturk for response
	assignments = @@mturk.getAssignmentsForHITAll( :HITId => hitId)
	#send alert if question expired w/o answer
	if(assignments[0].nil?)
		@@mturk.disposeHIT(:HITId => hitId );
		question[0].response = "EXPIRED"
		question[0].workerid = nil
		question[0].timeFinished = Time.at(0);
		@@twilio.account.sms.messages.create(
			:from => @@twillo_number,
			:to => question[0].phoneNumber,
			:body => "EXPIRED: #{question[0].questionText}"[0..158]
		)
		puts "\tx_x";
		next;
	end
	@@mturk.setHITAsReviewing( :HITId => hitId )
	answers = @@mturk.simplifyAnswer( assignments[0][:Answer])
	mturk_response = ""
	answers.each do |id,answer|
		mturk_response = answer
	end
	puts mturk_response
	
	@@twilio.account.sms.messages.create(
		:from => @@twillo_number,
		:to => question[0].phoneNumber,
		:body => mturk_response
	)
	question = Questions.find(question[0].id)
	question.response = mturk_response
	question.workerid = assignments[0][:WorkerId]
	question.timeFinished =  assignments[0][:SubmitTime]
	question.save
	""
end
