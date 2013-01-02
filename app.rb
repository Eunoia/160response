require "rubygems"
require 'sinatra'
require 'pg'
require "uri"
require "haml"
require 'active_record'
require "ruby-aws"
require 'amazon/webservices/mturk/question_generator'
require "digest/sha1"
require "twilio-ruby"
require "bcrypt"
include Amazon::WebServices::MTurk

use Rack::Session::Cookie, :secret => 'A1 sauce 1s so good you should use 1t on a11 yr st34ksssss'
enable :sessions

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
	# :Host => "Sandbox",
	:AWSAccessKeyId => ENV["AWS_KEY"],
	:AWSAccessKey => ENV["AWS_SECRET"]
})
@@twilio = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_TOKEN'])
# @@phoneNum = ENV["VALID_NUMBER"]
@@twillo_number = ENV["TWILIO_NUM"]

get '/' do
	haml :index
end

get '/styles.css' do
	less 'styles.less'
end
get '/questions' do
	@questions = Questions.find(:all)
	haml :questions
end
get '/price' do
	erb :price
end
# get '/#:id/' do
# 	@questions = Questions.where(:questionText => "#{params}" )
# 	haml :questions
# end

# get '/question/:id' do
# 	@question = Questions.find(params[:id])
# 	haml :question
# end

post '/receiveSMS' do
	#parse options
	phoneNum = params[:From][/\d+/]
	body = params[:Body]
	timeRecived = Time.now
	puts "Message from: #{phoneNum}, #{body}"
	#return if phoneNum != env[phoneNum]
	# return if(@@phoneNum.to_i!=phoneNum.to_i)
	#return if insufficientFunds
	#possible commands: bonus, redo, funds?, 
	return if @@mturk.availableFunds<0.55
	#create question
	title = body[/^..+\??/]
	desc = "Research a question, but keep your response below 160 charactors."
	keywords = "research, creative, 160"
	numAssignments = 1
	rewardAmount = 0.75 + rand(100)/100 #priced between .75 and $1.75
	qualReq = { :QualificationTypeId => Amazon::WebServices::MechanicalTurkRequester::LOCALE_QUALIFICATION_TYPE_ID,
				:Comparator => 'EqualTo',
				:LocaleValue => {:Country => 'US'}, }
	qualReqs = [qualReq]
	puts "Building Question"
	question = QuestionGenerator.build(:Basic) do |q|
		q.ask "Research this question, use bit.ly to shorten urls, keep your response under 160 chars\nQuestion: #{body}"
	end
	puts "Created Question"
	#send to mTurk
	hit = @@mturk.createHIT(    :Title => title,
								:Description => desc,
								:MaxAssignments => numAssignments,
								:Reward => { :Amount => rewardAmount, :CurrencyCode => 'USD' },
								:Question => question,
								:QualificationRequirement => qualReqs,
								:Keywords => keywords )
	puts "Posted Question to mTurk"
	if(hit[:Request][:IsValid]!="True")
		@@twilio.account.sms.messages.create(
			:from => @@twillo_number,
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
	q.phoneNumber = phoneNum
	q.timeRecived = timeRecived
	q.save
	puts "Saved question to DB"
	@@twilio.account.sms.messages.create(
			:from => @@twillo_number,
			:to => phoneNum,
			:body => "Your question is live :)"
	)
	puts "Notified Asker"
	#regester notifier
	#not yet, see example in notes
end

get '/pollTurk' do
	#get list of answered questions 
	hitids = @@mturk.getReviewableHITs(:Status => "Reviewable", :PageSize => 100)[:HIT]
	return if hitids.nil?
	hitids.map do |hit|
		hitId = hit[1]||hit[:HITId]
		puts hitId
		question = Questions.where(:hitid => hitId)
		#dont send message if hit doesnt belong to question.
		next if(question==[])
		#ask mturk for response
		assignments = @@mturk.getAssignmentsForHITAll( :HITId => hitId)
		#send alert if question expired w/o answer
		if(assignments[0].nil?)
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
		next if gets.chomp[/^n.+/i]
		#if response send text
		
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
											:Destination => 'http://requestb.in/18zmm1r1',
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
:HITTypeId => hitid,
"Notification.1.Destination" => 'http://requestb.in/18zmm1r1',
"Notification.1.Transport" => "REST",
"Notification.1.Active" => "true",
"Notification.1.EventType" => eventType,
"Notification.1.Version" => "2006-05-05",
:Active => "true",
}).do_op.to_s; hash
end
=end

#users/login stuff
helpers do
	def login?
		if session[:phoneNumber].nil?
			return false
		else
			return true
		end
	end
	def phoneNumber
		return session[:phoneNumber]
	end
end

get "/" do
	if(login?)
		@myPatents = patentTable.select{ |p| p[:owner]==phoneNumber }
	end
	haml :questions
end

get "/signup" do
  haml :signup
end
get '/login' do
	@phoneNumber = session[:phoneNumber]
	haml :login
end
post "/signup" do
	password_salt = BCrypt::Engine.generate_salt
	password_hash = BCrypt::Engine.hash_secret(params[:password], password_salt)
	user = Users.where(:phoneNumber => params[:phoneNumber])
	if(user.length==0)
  		Users.new({
  			:phoneNumber => params[:phoneNumber],
  			:salt => password_salt,
  			:passwordhash => password_hash,
  			:created => Time.now,
  			:plan => 0,
  			:active => false
		}).save
  else
	haml :error
  end
  session[:phoneNumber] = params[:phoneNumber]
  redirect "/questions"
end

post "/login" do
	user = Users.where(:phoneNumber => params[:phoneNumber]).first
	if(user.phoneNumber!=nil)
		if user.passwordhash == BCrypt::Engine.hash_secret(params[:password], user.salt)
			session[:phoneNumber] = params[:phoneNumber]
			redirect "/questions"
		end
	end
	haml :error
end

get "/logout" do
	session[:phoneNumber] = nil
	redirect "/"
end

get '/session' do
	session
end

get '/me' do
	if(login?)
		@s = session
		@user = Users.where(:phoneNumber => session[:phoneNumber]).first
		@questions = Questions.where(:phoneNumber => session[:phoneNumber])
		haml :questions
	else
		redirect '/login'
	end
end
