require 'active_support/all'

Dir[File.join(File.dirname(__FILE__), 'pay_call_sms', '*')].each do |file_name|
  require file_name
end

module PayCallSms

end
