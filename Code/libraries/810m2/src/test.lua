module(...,package.seeall)
require"misc"
require"http"
require"common"
require"pm"
require"agps"
require"gps"
--[[
���ܽ��ܣ�http�����ӣ�������Ҫ�ṩADDR��PORT�������ݾ��ǿͻ�����Ҫ���ӵĿͻ���
1.��Ҫ���ú�����������url�����ͷ�������ʵ�壬����ע������ײ�Hostʱ����ǰ���ADDR��PORTһ��,���õ���socket�ĳ�����
2.����request�������ú����Ƿ��ͱ�����������Ҫ���õ�
3.rcvcb�����ǽ��ջص��������᷵�ؽ����״̬�룬�ײ���һ�������ʵ�壬�ú������Զ��庯�����ͻ����Ը����Լ��������Լ�����
4.�������ݺ����������û���ٴ���������������������
]]
local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len
--����ʱ����д��IP��ַ�Ͷ˿ڣ�������д���ײ�Ҫ�������hostһ�£������ֵ����Ĭ�ϵ�ֵ
local ADDR,PORT ="139.220.193.149",80
--����POST����ʱ���õ�ַ
--local ADDR,PORT ="www.luam2m.com",80
local httpclient
local UART_ID = 3
--���ڶ��������ݻ�����
local rdbuf = ""
local wd=""
local sd=""
--�Ƿ�֧��gps
local gpsupport = true
--���֧��gps�����gps
if gpsupport then
  gps.init()
  gps.open(gps.TIMERORSUC,{cause="linkair",val=120,cb=test2cb})
end

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������testǰ׺
����  ����
����ֵ����
]]
local function print(...)
  _G.print("test",...)
end



local function parse(data)
  if not data then return end 
  
  local tail = string.find(data,string.char(0x2A))
  local stt= string.find(data,string.char(0x23))
  if not tail or not stt then return false,data end  
  
  local cmdtyp = string.byte(data,1)
  local body,result = string.sub(data,stt+1,tail-1)
  
 -- print("parse",body)
  
  wd=string.sub(body,1,2)
  sd=string.sub(body,3,4)
  print("wd:"..wd.."sd:"..sd)
  
  return true,string.sub(data,tail+1,-1)  
end

--[[
��������proc
����  ������Ӵ��ڶ���������
����  ��
    data����ǰһ�δӴ��ڶ���������
����ֵ����
]]
local function proc(data)
  if not data or string.len(data) == 0 then return end
  --׷�ӵ�������
  rdbuf = rdbuf..data 
  
  local result,unproc
  unproc = rdbuf
  --����֡�ṹѭ������δ�����������
  while true do
    result,unproc = parse(unproc)
    if not unproc or unproc == "" or not result then
      break
    end
  end

  rdbuf = unproc or ""
end

--[[
��������read
����  ����ȡ���ڽ��յ�������
����  ����
����ֵ����
]]
local function read()
  local data = ""
  --�ײ�core�У������յ�����ʱ��
  --������ջ�����Ϊ�գ�������жϷ�ʽ֪ͨLua�ű��յ��������ݣ�
  --������ջ�������Ϊ�գ��򲻻�֪ͨLua�ű�
  --����Lua�ű����յ��ж϶���������ʱ��ÿ�ζ�Ҫ�ѽ��ջ������е�����ȫ���������������ܱ�֤�ײ�core�е��������ж���������read�����е�while����оͱ�֤����һ��
  while true do   
    data = uart.read(UART_ID,"*l",0)
    if not data or string.len(data) == 0 then break end
    --������Ĵ�ӡ���ʱ
    --print("read",data,common.binstohexs(data))
    proc(data)
  end
end


local function loadUart()
--����ϵͳ���ڻ���״̬���˴�ֻ��Ϊ�˲�����Ҫ�����Դ�ģ��û�еط�����pm.sleep("test")���ߣ��������͹�������״̬
--�ڿ�����Ҫ�󹦺ĵ͡�����Ŀʱ��һ��Ҫ��취��֤pm.wake("test")���ڲ���Ҫ����ʱ����pm.sleep("test")
 -- pm.wake("test")
--ע�ᴮ�ڵ����ݽ��պ����������յ����ݺ󣬻����жϷ�ʽ������read�ӿڶ�ȡ����
  sys.reguart(UART_ID,read)
--���ò��Ҵ򿪴���
  uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)
end
local function test2cb(cause)
  print("test2cb",cause,gps.isfix(),gps.getgpslocation())
end
--[[
��������rcvcb
���ܣ����ջص��������û��Զ���Խ��ղ������в���
������result��0����ʾ ����ʵ�峤����ʵ����ͬ����ȷ��� 1����ʾû��ʵ��  2����ʾʵ�峬��ʵ��ʵ�壬���󣬲����ʵ������ 3�����ճ�ʱ  4:��ʾ���������е��Ƿֿ鴫��ģʽ
����ֵ��
]]
local function rcvcb(result,statuscode,head,body)
  print("resultrcvcb: ",result)  
  print("statuscodercvcb: ",statuscode)
  if  head==nil then  print("headrcvcb: nil")
  else
    print("headrcvcb:")
    --������ӡ������ͷ������Ϊ�ײ����֣�������Ӧ��ֵΪ�ײ����ֶ�ֵ
    for k,v in pairs(head) do   
      print(k..": "..v)
    end
  end
  print("bodyrcvcb:",body)
  httpclient:disconnect(discb)
end

local function getgps()
  local t = {}
  if gpsupport then
    print("getgps:",gps.getgpslocation(),gps.getgpscog(),gps.getgpsspd())
    t.fix = gps.isfix()
    t.lng,t.lat = smatch(gps.getgpslocation(),"[EW]*,(%d+%.%d+),[NS]*,(%d+%.%d+)")
    t.lng,t.lat = t.lng or "",t.lat or ""
    t.cog = gps.getgpscog()
    t.spd = gps.getgpsspd()
  end
  return t
end

--[[
��������connectedcb
����  ��SOCKET connected �ɹ��ص�����
����  ��
����ֵ��
]]
local function connectedcb()
 local info,ret,t,mcc,mnc,lac,ci,rssi,k,v,m,n,cntrssi = net.getcellinfoext(),"",{}
--local t1=misc.getclock()
--misc.setclock(t1)
--print("time:",misc.getclock())
 local time=misc.getclockstr()
 local id=misc.getimei()
-- print("time",misc.getclockstr)
 local location=gps.getgpslocation()
 --local t=getgps()
  --GETĬ�Ϸ���
  --����URL
 -- httpclient:seturl("/tpage.html?".."location="..location.."&enode="..info.."&wd="..wd.."&sd="..sd)
  --httpclient:seturl("http://www.genyuanlian.org/data/uploadSensorData?param=".."id="..id..";".."location="..location..";".."wd="..wd..";".."sd="..sd..";".."time="..time)
  httpclient:seturl("http://www.genyuanlian.org/data/uploadSensorData?param="..id..";"..location..";".."wd="..wd..";".."sd="..sd..";".."time="..time)
  --����ײ���ע��Host�ײ���ֵ�������addr��portһ��
  httpclient:addhead("Host","139.220.193.149")
  httpclient:addhead("Connection","keep-alive")
  --���ʵ������

 -- httpclient:setbody("encellinfoext:"..info.."location:"..location)
 --httpclient:setbody("1234567890"..location.."1234567890")
  --���ô˺����Żᷢ�ͱ���,��Ҫʹ��POST��ʽʱ����GET��ΪPOST
    httpclient:request("GET",rcvcb)
end 

--[[
��������sckerrcb
����  ��SOCKETʧ�ܻص�����
����  ��
    r��string���ͣ�ʧ��ԭ��ֵ
    CONNECT: socketһֱ����ʧ�ܣ����ٳ����Զ�����
����ֵ����
]]
local function sckerrcb(r)
  print("sckerrcb",r)
end
--[[
��������connect
���ܣ����ӷ�����
������
   connectedcb:���ӳɹ��ص�����
   sckerrcb��http lib��socketһֱ����ʧ��ʱ�������Զ�������������ǵ���sckerrcb����
���أ�
]]
local function connect()
  --pm.wake("test")
 -- misc.setflymode(false)
  --gps.init()
  print("vbat:",misc.getvbatvolt())
  gps.open(gps.TIMERORSUC,{cause="linkair",val=120,cb=test2cb})
  uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)
  httpclient:connect(connectedcb,sckerrcb)
end


--[[
��������locrptcb
����  ��λ�ð����ͽ����������ͳɹ����߳�ʱ������������ģʽ�����5���ӵġ��˳�����ģʽ�����Ӻ�̨����ʱ��
����  ��  
        result�� bool���ͣ����ͽ�������Ƿ�ʱ��trueΪ�ɹ����߳�ʱ������Ϊʧ��
    item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ��������socket.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
����ֵ����

function locrptcb(result,item)
  print("locrptcb",result)
  if result then
    misc.setflymode(true)
    sys.timer_start(connect,60000)
    --gps.close(gps.DEFAULT,{cause="linkair"})
    uart.close(UART_ID)
    pm.sleep("test")
  else
   -- sys.timer_start(reconn,RECONN_PERIOD*1000)
  end
end
]]

--[[
��������discb
����  ��HTTP���ӶϿ���Ļص�
����  ����    
����ֵ����
]]
function discb()
  print("http discb")
  --20������½���HTTP����
  sys.timer_start(connect,60000)
 -- pw.wake("AA")
--  misc.setflymode(false)
 -- locrptcb(true)
end

--[[
��������http_run
����  ������http�ͻ��ˣ�����������
����  ����    
����ֵ����
]]
function http_run()
  --��ΪhttpЭ�������ڡ�TCP��Э�飬���Բ��ش���PROT����
  httpclient=http.create(ADDR,PORT) 
  --����http����
  connect() 
end





http_run()
loadUart()



