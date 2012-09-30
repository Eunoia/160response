require "rubygems"
require 'sinatra'
require 'pg'
require "uri"
require "haml"
require 'activeRecord'
require "ruby-aws"
#require "twilio-ruby"
include Amazon::WebServices::MTurk

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

@mturk = Amazon::WebServices::MechanicalTurkRequester.new(:Config => File.join( File.dirname(__FILE__), 'mturk.yml' ),:Host => "Sandbox")
@twilio = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_TOKEN'])
@phoneNum = ENV["VALID_NUMBER"]
@twillo_number = ENV["TWILIO_NUM"]
get '/' do
	haml :index
end

get '/questions' do
	@questions = Questions.find(:all)
	haml :questions
end

get '/question/:id' do
	@question = Questions.find(params[:id])
	haml :question
end

post '/receiveSMS' do
	#parse options
	phoneNum = params[:From][/\d+/]
	body = params[:Body]
	timeRecived = Time.now
	#return if phoneNum != env[phoneNum]
	return if(@phoneNum.to_i!=phoneNum.to_i)
	#return if insufficientFunds
	return if @mturk.availableFunds<0.55
	#create question
	title = body[/^..+\?/]
	desc = "Research a question, but keep your response below 160 charactors."
	keywords = "research, creative, 160"
	numAssignments = 1
	rewardAmount = 0.30 # 30 cents
	qualReq = { :QualificationTypeId => Amazon::WebServices::MechanicalTurkRequester::LOCALE_QUALIFICATION_TYPE_ID,
				:Comparator => 'EqualTo',
				:LocaleValue => {:Country => 'US'}, }
	qualReqs = [qualReq]
	question = QuestionGenerator.build(:Basic) do |q|
		q.ask "Research this question, use bit.ly to shorten urls, keep your response under 160 chars\nQuestion: #{body}"
	end
	#send to mTurk
	hit = @mturk.createHIT(  :Title => title,
								:Description => desc,
								:MaxAssignments => numAssignments,
								:Reward => { :Amount => rewardAmount, :CurrencyCode => 'USD' },
								:Question => question,
								:QualificationRequirement => qualReqs,
								:Keywords => keywords )
	if(hit[:Request][:IsValid]!=="True")
		@twilio.account.sms.messages.create(
			:from => @twillo_number,
			:to => phoneNum,
			:body => "Your question couldn't be asked right now :("
		)
		return;
	end
	#save question to DB
	q = Questions.new
	q.hitid = hit[:HITId]
	q.hittypeid = hit[:HITTypeId]
	q.value = 0.3
	q.questionText = body
	q.phoneNumber = phoneNumber
	q.timeRecived = timeRecived
	q.save
	#regester notifier
	#not yet, see example in notes
end

get '/pollTurk' do
	#get list of answered questions 
	@mturk.getReviewableHITs(:Status => "Reviewable").map do |hit|
		hitId = hit.hit 
		#ask mturk for response
		assignments = @mturk.getAssignmentsForHITAll( :HITId => hitId)
		answers = @mturk.simplifyAnswer( assignments[0][:Answer])
		answers.each do |id,answer|
			response = answer
		end
		#if response send text
		phoneNum = Questions.where(:hitid => hit).phoneNum
		@twilio.account.sms.messages.create(
			:from => @twillo_number,
			:to => phoneNum,
			:body => response
		)
		@mturk.setHITAsReviewing( :HITId => hitId )
		question = Questions.find(params[:id])
		question.response = response
		question.workerid = assignments[0][:WorkerId]
		question.timeFinished =  resp[:SubmitTime]
		question.save
	end
end
get '/receiveNotice' do
	#parse options
	#get response from Mturk
	#save response to DB
	#send sms 
end

=begin 
#notes
#for polling
@mturk.getAssignmentsForHITAll( :HITId => "2K80JG5TYMNCEDS1ZH0SVSHX7GVLHP", :AssignmentStatus => 'Submitted')

 def create_notification(hit_type_id, email)
		result = @@mturk.SetHITTypeNotification(
										:HITTypeId => hit_type_id,
										:Notification => {
											:Destination => email,
											:Transport => "Email",
											:EventType => "AssignmentSubmitted",
											:Version => "2006-05-05"
										},
										:Active => true
										)
	end
@mturk = Amazon::WebServices::MechanicalTurkRequester.new(:Config => File.join( File.dirname(__FILE__), 'mturk.yml' ))#,:Host => "Production")
validEvents = "AssignmentAccepted | AssignmentAbandoned | AssignmentReturned | AssignmentSubmitted | HITReviewable | HITExpired".split(" | ") #ping
resp = validEvents.inject({}) do |hash,eventType|
	hash[eventType.to_sym] = @mturk.setHITTypeNotification(
										:HITTypeId => '2KGW3K4F0OHOF5ROE6BO5LA2HMI01O',
										:Active => "true",
										:Notification => {
											:Destination => 'http://requestb.in/17f36621',
											:Transport => "REST",
											:Active => "true",
											:EventType => eventType,
											:Version => "2006-05-05"
										}
										); hash
end

										{

validEvents = "AssignmentAccepted | AssignmentAbandoned | AssignmentReturned | AssignmentSubmitted | HITReviewable | HITExpired".split(" | ") #ping
resp = validEvents.inject({}) do |hash,eventType|
		hash[eventType.to_sym] = TurkOperation.new("SetHITTypeNotification",{
												:HITTypeId => '2KGW3K4F0OHOF5ROE6BO5LA2HMI01O',
												"Notification.1.Destination" => 'http://requestb.in/17f36621',
												"Notification.1.Transport" => "REST",
												"Notification.1.Active" => "true",
												"Notification.1.EventType" => eventType,
												"Notification.1.Version" => "2006-05-05",
												:Active => "true",
												}).do_op.to_s; hash
end
=end

