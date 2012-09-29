require 'sinatra'
require 'pg'
require 'activeRecord'
require "ruby-aws"
require "twillio"


get '/'
    haml :index
end
get '/questions'
    @questions = Questions.find(:all)
    haml :questions
end
get '/question/:id'
    @question = Questions.find(params[:id])
    haml :question
end

get '/receiveSMS'
    #parse options
    #return if phoneNum != env[phoneNum]
    #create question
    #save question to DB
    #regester notifier
    #send to mTurk
end

get '/receiveNotice'
    #parse options
    #get response from Mturk
    #save response to DB
    #send sms 
end

=begin 
#DB schema
*questions (and HITS)
*answers
*users
=end

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

