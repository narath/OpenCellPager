#!/usr/local/bin/ruby 

require "serialport.so"
require "socket"

class SMSController
  
  def initialize(bluetoothDevice,phoneNum,smsText)
    @@bluetoothDevice = bluetoothDevice
    @@phoneNum = phoneNum
    @@smsText = smsText
  end
  
  @@t_bin =  
    {
    "0000" => "0", 
    '0001' => '1', 
    '0010' => '2',
    '0011' => '3', 
    '0100' => '4', 
    '0101' => '5', 
    '0110' => '6', 
    '0111' => '7', 
    '1000' => '8', 
    '1001' => '9', 
    '1010' => 'A', 
    '1011' => 'B', 
    '1100' => 'C',  
    '1101' => 'D', 
    '1110' => 'E', 
    '1111' => 'F' 
    }
    
  @@bit7 = 
    {
      "0000000" => "@",
      "0000001" => "£",
      "0000010" => "$",
      "0000011" => "¥",
      "0000100" => "è",
      "0000101" => "é",
      "0000110" => "ù",
      "0000111" => "ì",
      "0001000" => "ò",
      "0001001" => "Ç",
      "0001010" => "\r",
      "0001011" => "Ø",
      "0001100" => "ø",
      "0001101" => "\n\r",
      "0001110" => "Å",
      "0001111" => "å",
      "0010000" => "∆",
      "0010001" => "_",
      "0010010" => "ﬁ",
      "0010011" => "GAMMA",
      "0010100" => "LAMBDA",
      "0010101" => "Ω",
      "0010110" => "π",
      "0010111" => "PSI",
      "0011000" => "∑",
      "0011001" => "THETA",
      "0011010" => "XI",
      "0011011" => "\n",
      "0011100" => "Æ",
      "0011101" => "æ",
      "0011110" => "ß",
      "0011111" => "É",
      "0100000" => " ",
      "0100001" => "!",
      "0100010" => "\"",
      "0100011" => "#",
      "0100100" => "¢",
      "0100101" => "%",
      "0100110" => "&",
      "0100111" => "\'",
      "0101000" => "(",
      "0101001" => ")",
      "0101010" => "*",
      "0101011" => "+",
      "0101100" => ",",
      "0101101" => "-",
      "0101110" => ".",
      "0101111" => "/",
      "0110000" => "0",
      "0110001" => "1",
      "0110010" => "2",
      "0110011" => "3",
      "0110100" => "4",
      "0110101" => "5",
      "0110110" => "6",
      "0110111" => "7",
      "0111000" => "8",
      "0111001" => "9",
      "0111010" => ":",
      "0111011" => ",",
      "0111100" => "<",
      "0111101" => "=",
      "0111110" => ">",
      "0111111" => "?",
      "1000000" => "¡",
      "1000001" => "A",
      "1000010" => "B",
      "1000011" => "C",
      "1000100" => "D",
      "1000101" => "E",
      "1000110" => "F",
      "1000111" => "G",
      "1001000" => "H",
      "1001001" => "I",
      "1001010" => "J",
      "1001011" => "K",
      "1001100" => "L",
      "1001101" => "M",
      "1001110" => "N",
      "1001111" => "O",
      "1010000" => "P",
      "1010001" => "Q",
      "1010010" => "R",
      "1010011" => "S",
      "1010100" => "T",
      "1010101" => "U",
      "1010110" => "V",
      "1010111" => "W",
      "1011000" => "X",
      "1011001" => "Y",
      "1011010" => "Z",
      "1011011" => "Ä",
      "1011100" => "Ö",
      "1011101" => "N",
      "1011110" => "Ü",
      "1011111" => "§",
      "1100000" => "?",
      "1100001" => "a",
      "1100010" => "b",
      "1100011" => "c",
      "1100100" => "d",
      "1100101" => "e",
      "1100110" => "f",
      "1100111" => "g",
      "1101000" => "h",
      "1101001" => "i",
      "1101010" => "j",
      "1101011" => "k",
      "1101100" => "l",
      "1101101" => "m",
      "1101110" => "n",
      "1101111" => "o",
      "1110000" => "p",
      "1110001" => "q",
      "1110010" => "r",
      "1110011" => "s",
      "1110100" => "t",
      "1110101" => "u",
      "1110110" => "v",
      "1110111" => "w",
      "1111000" => "x",
      "1111001" => "y",
      "1111010" => "Z",
      "1111011" => "ä",
      "1111100" => "ö",
      "1111101" => "ñ",
      "1111110" => "ü",
      "1111111" => "à",
      }
      
   def sendSMS()
    	createSMS(@@phoneNum,@@smsText)
   end
   

   def nibble_swap(str)
       strLen = str.length
       swap_str = ""
       if strLen%2 != 0 then        
           str = str + "f"
       end
       i = 0
       while i < strLen
           swap_str = swap_str + str.slice(i..(i+1)).reverse
           i += 2
       end
       return swap_str
   end  
   
  def ascii2bin7bit(str)
      strLen = str.length
      binStr = ""
      i = 0
      while i < strLen
          char = str.slice(i..i)
          @@bit7.each do |k,v|
              if v == char then
                  binStr = binStr + k
              end
          end
          i += 1
      end
      return binStr
  end
  
  def code7bin2octet(septets)

      spLen = septets.length - 6
      octets = ""
      octets_n = ""
      oct = {}
      n = 0
      i = 0
      while i < spLen
          if (n <= 6) then
              sep = septets.slice((i)..(i+6))
              sep_n = septets.slice((i+7)..(i+13))
              if !(sep_n.length == 0) then
                  oct[n] = sep_n.slice((6-n)..6) + sep.slice(0..(6-n))
                  octets_n = octets_n + oct[n]
              else
                  oct[n] = sep.slice(0..(6-n))
                  while oct[n].length < 8
                      oct[n] = "0" + oct[n]
                  end
                  octets_n = octets_n + oct[n]
              end
              n += 1
          else
              n = 0
          end
          i += 7
      end
      hex = []
      j = 0   
      while j < octets_n.length
          bin = octets_n.slice(j..j+3)
          hex.insert(-1,@@t_bin["#{bin}"])
          j += 4
      end
      return hex.to_s
  end
  
  def createSMS(phoneNum,smsText)
    
      @sms_praefix = "001100"

      @phone_num = phoneNum
      @sms_msg = smsText
      @pn_len = @phone_num.length
      @pn_len = sprintf('%02X',@pn_len)
      @trp = "91"
      @phone_num = nibble_swap(@phone_num)
      @sms_infix = "0000FF"
      @msg_len = @sms_msg.length
      @msg_len = sprintf('%02X',@msg_len)
      @sms_msg = ascii2bin7bit(@sms_msg)
      @sms_msg = code7bin2octet(@sms_msg)
      @sms = @sms_praefix + @pn_len + @trp + @phone_num + @sms_infix + @msg_len + @sms_msg
      @sms_len = @sms.length/2 -1

      sp = SerialPort.new(@@bluetoothDevice, 9600,8,1,SerialPort::NONE)
      open(@@bluetoothDevice)

      sp.write( "at+cmgs=#{@sms_len}" + "\n\r")

      sleep 2

      sp.write( "#{@sms}" + "\032")

      sleep 2

      sp.close
  end  

end

#mySMS = SMSController.new("/dev/cu.Your_Paired_Bluetooth_Device","Number_Of_SMS_Receiver,"SMS_Message")
mySMS = SMSController.new("/dev/cu.W900i-SerialPort-1","43676844256222","hallo world!")

mySMS.sendSMS

