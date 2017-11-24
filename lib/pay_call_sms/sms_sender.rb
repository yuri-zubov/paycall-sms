require 'httparty'
require 'logging'

module PayCallSms

  # this class sends smses and parses responses
  class SmsSender
    attr_reader :logger

    # Create new sms sender with given +options+
    # - api_url: endpoint api url to make request to
    # - username: endpoint auth user
    # - password: endpoint auth pass
    def initialize(options = {})
      @options = {api_url: 'https://api.multisend.co.il/MultiSendAPI/sendsms'}.merge(options)
      @logger = Logging.logger[self.class]

      %w(api_url  username  password).each{|key| raise ArgumentError.new("options :#{key} must be present") if @options[key.to_sym].blank? }
    end

    def api_url
      @options[:api_url]
    end

    # send +text+ string to the +phones+ array of phone numbers
    # +options+ - is a hash of optional configuration that can be passed to sms sender:
    #  * +sender_name+ - sender name that will override gateway sender name
    #  * +sender_number+ - sender number that will override gateway sender number
    #  * +delivery_notification_url+ - url which will be invoked upon notification delivery
    # Returns response OpenStruct that contains:
    #  * +message_id+ - message id string. You must save this id if you want to receive delivery notifications via push/pull
    def send_sms(message_text, phones, options = {})
      raise ArgumentError.new("Text must be at least 1 character long") if message_text.blank?
      raise ArgumentError.new("No phones were given") if phones.blank?
      raise ArgumentError.new("Either :sender_name or :sender_number attribute required") if options[:sender_name].blank? && options[:sender_number].blank?
      raise ArgumentError.new("Sender number must be between 4 to 14 digits: #{options[:sender_number]}") if options[:sender_number].present? && !PhoneNumberUtils.valid_sender_number?(options[:sender_number])
      raise ArgumentError.new("Sender name must be between 2 and 11 latin chars") if options[:sender_name].present? && !PhoneNumberUtils.valid_sender_name?(options[:sender_name])

      phones = [phones] unless phones.is_a?(Array)
      phones.each do |p| # check that phones are in valid cellular format
        raise ArgumentError.new("Phone number '#{p}' must be cellular phone with 972 country code") unless PhoneNumberUtils.valid_cellular_phone?(p)
      end

      message_id = UUIDTools::UUID.timestamp_create.to_str
      body_params = build_send_sms_params(message_text, phones, message_id, options)
      logger.debug "#send_sms - making post to #{@options[:api_url]} with params: \n #{body_params}"
      http_response = HTTParty.post(@options[:api_url], :body => body_params, :headers => {'Accept' => 'application/json'})
      logger.debug "#send_sms - got http response: code=#{http_response.code}; body=\n#{http_response.parsed_response}"
      raise StandardError.new("Non 200 http response code: #{http_response.code} \n #{http_response.parsed_response}") if http_response.code != 200
      if http_response.parsed_response.is_a?(Hash)
        json = http_response.parsed_response
      elsif http_response.parsed_response.is_a?(String)
        begin
          json = JSON.parse(http_response.parsed_response)
        rescue JSON::ParserError => e
          raise PayCallSms::GatewayError.new("Failed to parse response to json: #{http_response.parsed_response}")
        end
        logger.debug "#send_sms - parsed response: #{json.inspect}"
      end
      if json['success'] == true
        OpenStruct.new(
           message_id: message_id,
         )
      else
        raise PayCallSms::GatewayError.new("Failed to send sms: #{json.inspect}")
      end
    end

    def build_send_sms_params(message_text, phones, message_id, options = {})
      result = {
        user: @options[:username],
        password: @options[:password],
        recipient: phones.join(','),
        message: message_text,
        customermessageid: message_id
      }
      result[:deliverynotificationURL] = options[:delivery_notification_url] if options[:delivery_notification_url].present?
      result[:from] = options[:sender_number]
      result[:from] = options[:sender_name] if options[:sender_name].present?
      result
    end

  end

end