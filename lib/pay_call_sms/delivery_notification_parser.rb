module PayCallSms
  class DeliveryNotificationParser
    attr_reader :logger

    # Create new sms delivery notification parser
    # options can contain the following keys:
    # time_zone: the timezone through which the notification date would be parsed
    def initialize(options = {})
      @options = options
      @logger = Logging.logger[self.class]
    end

    # params will look something like the following:
    # {"PhoneNumber"=>"972545290862", "CustomerMessageId"=>"34", "Status"=>"inprogress", "dateTime"=>"20-11-2017 17:22:55"}
    def from_http_push_params(params)
      self.class.normalize_http_push_params(params)
      %w(PhoneNumber   Status   CustomerMessageId   dateTime).each do |p|
        raise ArgumentError.new("Missing http delivery notification push parameter #{p}. Parameters were: #{params.inspect}") if params[p].blank?
      end
      logger.debug "Parsing http push delivery notification params: #{params.inspect}"

      values = {
        :gateway_status => params['Status'],
        :phone => params['PhoneNumber'],
        :message_id => params['CustomerMessageId'],
        :occurred_at => params['dateTime'],
        :reason_not_delivered => params['ReasonNotDelivered']
      }

      parse_notification_values_hash(values)
    end

    # This method receives notification +values+ Hash and tries to type cast it's values and determine delivery status (add delivered?)
    # @raises Smsim::GatewayError when values hash is missing attributes or when one of the attributes fails to be parsed
    #
    # Method returns object with the following attributes:
    # * +gateway_status+ - gateway status: [inprogress,delivered]
    # * +delivery_status+ - :delivered, :in_progress, :failed, :unknown
    # * +occurred_at+ - when the sms became in gateway_status (as reported by gateway)
    # * +phone+ - the phone to which sms was sent
    # * +message_id+ - gateway message id of the sms that was sent
    def parse_notification_values_hash(values)
      logger.debug "Parsing delivery notification values hash: #{values.inspect}"
      [:gateway_status, :phone, :message_id, :occurred_at].each do |key|
        raise ArgumentError.new("Missing notification values key #{key}. Values were: #{values.inspect}") if values[key].blank?
      end

      values[:phone] = PhoneNumberUtils.ensure_country_code(values[:phone])
      values[:delivery_status] = self.class.gateway_delivery_status_to_delivery_status(values[:gateway_status])

      begin
        Time.use_zone(@options[:time_zone] || Time.zone || 'Jerusalem') do
          values[:occurred_at] = DateTime.strptime(values[:occurred_at], '%d-%m-%Y %H:%M:%S')
          values[:occurred_at] = Time.zone.parse(values[:occurred_at].strftime('%d-%m-%Y %H:%M:%S')) #convert to ActiveSupport::TimeWithZone
        end
      rescue Exception => e
        logger.error "occurred_at could not be converted to integer. occurred_at was: #{values[:occurred_at]}. \n\t #{e.message}: \n\t #{e.backtrace.join("\n\t")}"
        raise ArgumentError.new("occurred_at could not be converted to date. occurred_at was: #{values[:occurred_at]}")
      end
      OpenStruct.new(values)
    end

    def self.gateway_delivery_status_to_delivery_status(gateway_status)
      {inprogress: :in_progress, pending: :in_progress, delivered: :delivered, failed: :failed, kosher: :failed}.with_indifferent_access[gateway_status] || :unknown
    end

    def self.normalize_http_push_params(params)
      if params['Status'] == 'kosher'
        params['ReasonNotDelivered'] = 'kosher_number'
        params['dateTime'] = Time.now.strftime('%d-%m-%Y %H:%M:%s') # "12-12-2017 14:22:1"
      end
      params
    end

  end
end
