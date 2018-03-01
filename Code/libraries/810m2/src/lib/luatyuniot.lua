--����ģ��,����������
local base = _G
local sys  = require"sys"
local mqtt = require"mqtt"
local misc = require"misc"
local lpack = require"pack"
require"aliyuniotauth"
module(...,package.seeall)

local slen = string.len

--�������ϴ�����key��secret���û���Ҫ�޸�������ֵ�������޷�������Luat���ƺ�̨
local PRODUCT_KEY,PRODUCT_SECRET = "1000163201","4K8nYcT4Wiannoev"
--mqtt�ͻ��˶���,���ݷ�������ַ,���ݷ������˿ڱ�
local mqttclient,gaddr,gports,gclientid,gusername
--Ŀǰʹ�õ�gport���е�index
local gportidx = 1
local gconnectedcb,gconnecterrcb,grcvmessagecb

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������luatyuniotǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("luatyuniot",...)
end

--[[
��������subackcb
����  ��MQTT SUBSCRIBE֮���յ�SUBACK�Ļص�����
����  ��
		usertag������mqttclient:subscribeʱ�����usertag
		result��true��ʾ���ĳɹ���false����nil��ʾʧ��
����ֵ����
]]
local function subackcb(usertag,result)
	print("subackcb",usertag,result)
end

--[[
��������sckerrcb
����  ��SOCKETʧ�ܻص�����
����  ��
		r��string���ͣ�ʧ��ԭ��ֵ
			CONNECT��mqtt�ڲ���socketһֱ����ʧ�ܣ����ٳ����Զ�����
����ֵ����
]]
local function sckerrcb(r)
	print("sckerrcb",r,gportidx,#gports)
	if r=="CONNECT" then
		if gportidx<#gports then
			gportidx = gportidx+1
			connect(true)
		else
			sys.restart("luatyuniot sck connect err")
		end
	end
end

function bcd(d,n)
	local l = slen(d or "")
	local num
	local t = {}

	for i=1,l,2 do
		num = tonumber(string.sub(d,i,i+1),16)

		if i == l then
			num = 0xf0+num
		else
			num = (num%0x10)*0x10 + num/0x10
		end

		table.insert(t,num)
	end

	local s = string.char(_G.unpack(t))

	l = slen(s)

	if l < n then
		s = s .. string.rep("\255",n-l)
	elseif l > n then
		s = string.sub(s,1,n)
	end

	return s
end

local base64bcdimei
local function getbase64bcdimei()
	if not base64bcdimei then
		local imei = misc.getimei()
		local imei1,imei2 = string.sub(imei,1,7),string.sub(imei,8,14)
		imei1,imei2 = string.format("%06X",tonumber(imei1)),string.format("%06X",tonumber(imei2))
		imei = common.hexstobins(imei1..imei2)
		base64bcdimei = crypto.base64_encode(imei,6)
		if string.sub(base64bcdimei,-1,-1)=="=" then base64bcdimei = string.sub(base64bcdimei,1,-2) end
		base64bcdimei = string.gsub(base64bcdimei,"+","-")
		base64bcdimei = string.gsub(base64bcdimei,"/","_")
		base64bcdimei = string.gsub(base64bcdimei,"=","@")
	end
	return base64bcdimei
end

--[[
��������connectedcb
����  ��MQTT CONNECT�ɹ��ص�����
����  ����		
����ֵ����
]]
local function connectedcb()
	print("connectedcb")
	--��������
	mqttclient:subscribe({{topic="/"..PRODUCT_KEY.."/"..getbase64bcdimei().."/g",qos=0}, {topic="/"..PRODUCT_KEY.."/"..getbase64bcdimei().."/g",qos=1}}, subackcb, "subscribegetopic")
	assert(_G.PRODUCT_KEY and _G.PROJECT and _G.VERSION,"undefine PRODUCT_KEY or PROJECT or VERSION in main.lua")
	local payload = lpack.pack("bbpbpbpbpbpbp",
								0,
								0,_G.PRODUCT_KEY,
								1,_G.PROJECT.."_"..sys.getcorever(),
								2,bcd(string.gsub(_G.VERSION,"%.","")),
								3,misc.getsn(),
								4,sim.geticcid(),
								5,sim.getimsi()
								)
	mqttclient:publish("/"..PRODUCT_KEY.."/"..getbase64bcdimei().."/1/0",payload,1)
	--ע���¼��Ļص�������MESSAGE�¼���ʾ�յ���PUBLISH��Ϣ
	mqttclient:regevtcb({MESSAGE=grcvmessagecb})
	if gconnectedcb then gconnectedcb() end
end

--[[
��������connecterrcb
����  ��MQTT CONNECTʧ�ܻص�����
����  ��
		r��ʧ��ԭ��ֵ
			1��Connection Refused: unacceptable protocol version
			2��Connection Refused: identifier rejected
			3��Connection Refused: server unavailable
			4��Connection Refused: bad user name or password
			5��Connection Refused: not authorized
����ֵ����
]]
local function connecterrcb(r)
	print("connecterrcb",r)
	if gconnecterrcb then gconnecterrcb(r) end
end


function connect(change)
	if change then
		mqttclient:change("TCP",gaddr,gports[gportidx])
	else
		--����һ��mqtt client
		mqttclient = mqtt.create("TCP",gaddr,gports[gportidx])
	end
	--������������,�������Ҫ��������һ�д��룬���Ҹ����Լ����������will����
	--mqttclient:configwill(1,0,0,"/willtopic","will payload")
	--����mqtt������
	mqttclient:connect(gclientid,600,gusername,"",connectedcb,connecterrcb,sckerrcb)
end

--[[
��������databgn
����  ����Ȩ��������֤�ɹ��������豸�������ݷ�����
����  ����		
����ֵ����
]]
local function databgn(host,ports,clientid,username)
	gaddr,gports,gclientid,gusername = host or gaddr,ports or gports,clientid,username
	gportidx = 1
	connect()
end

local procer =
{
	ALIYUN_DATA_BGN = databgn,
}

sys.regapp(procer)


--[[
��������config
����  �����ð�������������Ʒ��Ϣ���豸��Ϣ
����  ��
		productkey��string���ͣ���Ʒ��ʶ����ѡ����
		productsecret��string���ͣ���Ʒ��Կ����ѡ����
		devicename��string���ͣ��豸��
����ֵ����
]]
local function config(productkey,productsecret,devicename)
	sys.dispatch("ALIYUN_AUTH_BGN",productkey,productsecret,devicename)
end

function regcb(connectedcb,rcvmessagecb,connecterrcb)
	gconnectedcb,grcvmessagecb,gconnecterrcb = connectedcb,rcvmessagecb,connecterrcb
end

function publish(payload,qos,ackcb,usertag)
	mqttclient:publish("/"..PRODUCT_KEY.."/"..getbase64bcdimei().."/u",payload,qos,ackcb,usertag)
end

local function imeirdy()
	getbase64bcdimei()
	config(PRODUCT_KEY,PRODUCT_SECRET,getbase64bcdimei())
	return true
end

sys.regapp(imeirdy,"IMEI_READY")
