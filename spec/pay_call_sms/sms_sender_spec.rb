require 'spec_helper'

describe PayCallSms::SmsSender do
  let(:sender){ ::PayCallSms::SmsSender.new(:username => 'user', :password => 'pass') }

  describe '#send_sms' do
    let(:message){ 'my message text' }
    let(:phone){ '972541234567' }
    let(:api_url){ sender.api_url }

    it 'should raise error if text is blank' do
      lambda{ sender.send_sms('', phone) }.should raise_error(ArgumentError)
    end

    it 'should raise error if phone is blank' do
      lambda{ sender.send_sms(message, '') }.should raise_error(ArgumentError)
    end

    it 'should raise error if phone is not valid cellular phone' do
      lambda{ sender.send_sms(message, '0541234567') }.should raise_error(ArgumentError)
      lambda{ sender.send_sms(message, '541234567') }.should raise_error(ArgumentError)
    end

    it 'should raise error if url not found' do
      stub_request(:any, api_url).to_return(:status => 404)
      lambda{ sender.send_sms('asdf', phone, sender_name: '1234') }.should raise_error(StandardError)
    end

    it 'should raise error url if response code is 200 but json Success is false' do
      stub_request(:any, api_url).to_return(:status => 200, :body => {success: false}.to_json)
      lambda{ sender.send_sms('asdf', phone, sender_name: '1234') }.should raise_error(PayCallSms::GatewayError)
    end

    it 'should raise error url if response code is 200 and json Success is true' do
      stub_request(:any, api_url).to_return(:status => 200, :body => {success: true}.to_json)
      result = sender.send_sms('asdf', phone, sender_name: '1234')
      result.class.should == OpenStruct
      result.message_id.should be_present
    end

    it 'should not raise error url if response code is 200 and but response is not a json' do
      stub_request(:any, api_url).to_return(:status => 200, :body => 'kljidf,dfdef')
      lambda{ sender.send_sms('asdf', phone, sender_name: '1234') }.should raise_error(PayCallSms::GatewayError)
    end

  end

  describe '#build_send_sms_params' do
    let(:message){ 'my message text' }
    let(:phones){ ['0541234567'] }
    let(:http_params){ sender.build_send_sms_params(message, phones, '123', :sender_number => '972501234567') }

    it 'should have username and password' do
      http_params[:user].should == 'user'
      http_params[:password].should == 'pass'
    end

    it 'should have message text' do
      http_params[:message].should == message
    end

    it 'should have recepients phone number' do
      http_params[:recipient].should == phones.first
    end

    it 'should have recepients phone numbers separated by ; without spaces' do
      phones << '0541234568' << '0541234569'
      http_params[:recipient].should == phones.join(',')
    end

    it 'should have sender number' do
      http_params[:from].should == '972501234567'
    end

    it 'should have message_id' do
      http_params[:customermessageid].should == '123'
    end

    it 'should have delivery notification url if specified' do
      http_params = sender.build_send_sms_params(message, phones, '123', :sender_number => '972501234567', :delivery_notification_url => 'http://google.com?auth=1234&alex=king')
      http_params[:deliverynotificationURL].should == "http://google.com?auth=1234&alex=king"
    end

    it 'should not have delivery notification url if not specified' do
      http_params[:deliverynotificationURL].should be_nil
    end

  end

end
