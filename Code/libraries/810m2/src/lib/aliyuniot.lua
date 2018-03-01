--����ģ��,����������
local base = _G
local string = require"string"
local sys  = require"sys"
local mqtt = require"mqtt"
require"aliyuniotauth"
module(...,package.seeall)

--mqtt�ͻ��˶���,���ݷ�������ַ,���ݷ������˿ڱ�
local mqttclient,gaddr,gports,gclientid,gusername
--Ŀǰʹ�õ�gport���е�index
local gportidx = 1
local gconnectedcb,gconnecterrcb

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������aliyuniotǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("aliyuniot",...)
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
			sys.restart("aliyuniot sck connect err")
		end
	end
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
	mqttclient:connect(gclientid,240,gusername,"",gconnectedcb,gconnecterrcb,sckerrcb)
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
����ֵ����
]]
function config(productkey,productsecret)
	sys.dispatch("ALIYUN_AUTH_BGN",productkey,productsecret)
end

function regcb(connectedcb,connecterrcb)
	gconnectedcb,gconnecterrcb = connectedcb,connecterrcb
end

function subscribe(topics,ackcb,usertag)
	mqttclient:subscribe(topics,ackcb,usertag)
end

function regevtcb(evtcbs)
	mqttclient:regevtcb(evtcbs)
end

function publish(topic,payload,qos,ackcb,usertag)
	mqttclient:publish(topic,payload,qos,ackcb,usertag)
end
