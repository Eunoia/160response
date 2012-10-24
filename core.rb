#http://cutehackergirl.wordpress.com/files-for-tutorials/mechanical-turkey-wrap/
# Require libraries
require 'digest/sha1'
require 'base64'
require 'cgi'
require 'net/http'
require 'net/https'
require 'rexml/document'

class TurkOperation
	# Define constants
	AWS_ACCESS_KEY_ID = ENV['AWS_KEY']
	AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET']
	SERVICE_NAME = 'AWSMechanicalTurkRequester'
	SERVICE_VERSION = '2012-03-25'
        REST_URL = "https://mechanicalturk.sandbox.amazonaws.com"

	def initialize(op_name, params)
		set_operation(op_name)
		set_parameters(params)
	end

	# Define authentication routines
	def generate_timestamp(time)
	  return time.gmtime.strftime('%Y-%m-%dT%H:%M:%SZ')
	end

	def hmac_sha1(key, s)
	  ipad = [].fill(0x36, 0, 64)
	  opad = [].fill(0x5C, 0, 64)
	  key = key.unpack("C*")
	  key += [].fill(0, 0, 64-key.length) if key.length < 64
	  
	  inner = []
	  64.times { |i| inner.push(key[i] ^ ipad[i]) }
	  inner += s.unpack("C*")
	  
	  outer = []
	  64.times { |i| outer.push(key[i] ^ opad[i]) }
	  outer = outer.pack("c*")
	  outer += Digest::SHA1.digest(inner.pack("c*"))
	  
	  return Digest::SHA1.digest(outer)
	end

	def generate_signature(service, operation, timestamp, secret_access_key)
	  msg = "#{service}#{operation}#{timestamp}"
	  hmac = hmac_sha1( secret_access_key, msg )
	  b64_hmac = Base64::encode64(hmac).chomp
	  return b64_hmac
	end

	def set_operation(op)
		@operation = op
	end
	
	def set_parameters(params)
		@parameters = params
	end

	def do_op
		# Calculate the request authentication parameters
		operation = @operation 
		timestamp = generate_timestamp(Time.now)
		signature = generate_signature('AWSMechanicalTurkRequester', operation, timestamp, AWS_SECRET_ACCESS_KEY)

		# Construct the request
		parameters = @parameters

		parameters[:Operation] = operation
		parameters[:Service] = SERVICE_NAME
		parameters[:Version] = SERVICE_VERSION
		parameters[:AWSAccessKeyId] = AWS_ACCESS_KEY_ID
		parameters[:Signature] = signature
		parameters[:Timestamp] = timestamp

		# Make the request
		param_string = (parameters.collect { |key,value| "#{key}=#{CGI::escape(value)}" }).join('&')
		url = URI.parse( REST_URL + '/onca/xml?' + param_string )

		http = Net::HTTP.new(url.host, url.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE

		request = Net::HTTP::Get.new(url.request_uri)
		response = http.request(request)

		xml = REXML::Document.new( response.body )

		if error_nodes = xml.root.elements['OperationRequest/Errors']
		  print_errors(error_nodes)
		end

		return xml
	end

	# Check for and print results and errors
	def print_errors(errors_node)
	  puts 'There was an error processing your request:'
	  errors_node.each { |error_node|
	    puts "  Error code:    #{error_node.elements['Code'].text}"
	    puts "  Error message: #{error_node.elements['Message'].text}"
	  }
	end

end
