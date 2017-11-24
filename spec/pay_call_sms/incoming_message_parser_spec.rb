require 'spec_helper'

describe PayCallSms::IncomingMessageParser do
  let(:parser){ PayCallSms::IncomingMessageParser.new }

  describe '#from_http_push_params' do
    let(:http_params) { {'msgId' => 'a1234', 'sender' => '0541234567', 'recipient' => '972529992090', 'content' => 'kak dila'} }
    let(:reply) { parser.from_http_push_params(http_params) }

    it 'should raise ArgumentError if parameters are missing or not of expected type' do
      %w(msgId  sender  recipient  content).each do |p|
        params = http_params.clone.tap{|h| h.delete(p) }
        lambda{ parser.from_http_push_params(params) }.should raise_error(ArgumentError)
      end
    end

    it 'should return incoming message object with all fields initialized' do
      Time.stub(:now).and_return(Time.utc(2011, 8, 1, 11, 15, 00))

      reply.should be_present
      reply.message_id.should == 'a1234'
      reply.phone.should == '972541234567'
      reply.text.should == 'kak dila'
      reply.reply_to_phone.should == '972529992090'
      reply.received_at.strftime('%d/%m/%Y %H:%M:%S').should == '01/08/2011 11:15:00'
    end
  end

end
