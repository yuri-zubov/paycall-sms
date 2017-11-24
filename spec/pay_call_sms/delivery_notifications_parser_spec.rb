require 'spec_helper'

describe PayCallSms::DeliveryNotificationParser do
  let(:parser){ PayCallSms::DeliveryNotificationParser.new }

  describe '#from_http_push_params' do
    let(:http_params) { {'Status' => 'inprogress', 'CustomerMessageId' => 'a1', 'PhoneNumber' => '0545123456', 'dateTime' => "19-03-2012 23:29:12"} }
    let(:notification) { parser.from_http_push_params(http_params) }

    it 'should raise GatewayError if parameters are missing or not of expected type' do
      ['PhoneNumber', 'Status', 'CustomerMessageId', 'dateTime'].each do |p|
        params = http_params.clone
        params.delete(p)
        lambda { parser.from_http_push_params(params) }.should raise_error(ArgumentError)
      end

      lambda { parser.from_http_push_params(http_params.update('dateTime' => 'asdf')) }.should raise_error(ArgumentError)
    end

    it 'should return DeliveryNotification with all fields initialized' do
      notification.should be_present
      notification.message_id.should == 'a1'
      notification.phone.should == '972545123456'
      notification.gateway_status.should == 'inprogress'
      notification.occurred_at.should be_present
      notification.occurred_at.strftime('%d/%m/%Y %H:%M:%S').should == "19/03/2012 23:29:12"
    end

    it 'should be delivered when status is delivered' do
      http_params.update('Status' => 'delivered')
      notification.delivery_status.should == :delivered
    end

    it 'should be not delivered when status is failed' do
      http_params.update('Status' => 'failed')
      notification.delivery_status.should == :failed
    end

  end

end
