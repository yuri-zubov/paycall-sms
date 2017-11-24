module PayCallSms
  class IncomingMessageParser
    attr_reader :logger

    # Create new sms sender with given +gateway+
    def initialize(options={})
      @options = options
      @logger = Logging.logger[self.class]
    end

    # params will look something like the following:
    # msgId - uniq id of the message
    # sender - the phone that have sent the message
    # recipient - the virtual phone number that received the message (at gateway operator)
    # segments - number of segments
    # content - text of the message
    def from_http_push_params(params)
      %w(msgId  sender  recipient  content).each do |p|
        raise ArgumentError.new("Missing http parameter #{p}. Parameters were: #{params.inspect}") if params[p].blank?
      end

      logger.debug "Parsing http push reply xml: \n#{params['IncomingXML']}"
      parse_reply_values_hash(
        phone: params['sender'],
        reply_to_phone: params['recipient'],
        text: params['content'],
        message_id: params['msgId']
      )
    end

    # This method receives sms reply +values+ Hash and tries to type cast it's values
    # @raises Smsim::GatewayError when values hash is missing attributes or when one of attributes fails to be type casted
    #
    # Method returns object with the following attributes:
    # * +phone+ - the phone that sent the sms (from which sms reply was received)
    # * +text+ - contents of the message that were received
    # * +reply_to_phone+ - the phone to sms which reply was sent (gateway phone number)
    # * +received_at+ - when the sms was received (as reported by gateway server)
    # * +message_id+ - uniq message id generated from phone,reply_to_phone and received_at timestamp
    def parse_reply_values_hash(values)
      logger.debug "Parsing reply_values_hash: #{values.inspect}"
      [:message_id, :phone, :text, :reply_to_phone].each do |key|
        raise ArgumentError.new("Missing sms reply values key #{key}. Values were: #{values.inspect}") if values[key].blank?
      end

      values[:phone] = PhoneNumberUtils.ensure_country_code(values[:phone])
      values[:reply_to_phone] = PhoneNumberUtils.ensure_country_code(values[:reply_to_phone])

      if values[:received_at].is_a?(String)
        begin
          Time.use_zone(@options[:time_zone] || Time.zone || 'Jerusalem') do
            values[:received_at] = DateTime.strptime(values[:received_at], '%Y-%m-%d %H:%M:%S')
            values[:received_at] = Time.zone.parse(values[:received_at].strftime('%Y-%m-%d %H:%M:%S')) #convert to ActiveSupport::TimeWithZone
          end
        rescue Exception => e
          raise ArgumentError.new("received_at could not be converted to date. received_at was: #{values[:received_at]}")
        end
      else
        values[:received_at] = Time.now
      end
      OpenStruct.new(values)
    end

  end
end
