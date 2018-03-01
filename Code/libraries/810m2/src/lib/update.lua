--[[
ģ�����ƣ�Զ������
ģ�鹦�ܣ�ֻ��ÿ�ο�����������ʱ��������������������������������°汾��lib��Ӧ�ýű�Զ������
ģ������޸�ʱ�䣺2017.02.09
]]

--����ģ��,����������
local base = _G
local string = require"string"
local io = require"io"
local os = require"os"
local rtos = require"rtos"
local sys  = require"sys"
local link = require"link"
local misc = require"misc"
local common = require"common"
module(...)

--���س��õ�ȫ�ֺ���������
local print = base.print
local send = link.send
local dispatch = sys.dispatch

--Զ������ģʽ������main.lua�У�����UPDMODE������δ���õĻ�Ĭ��Ϊ0
--0���Զ�����ģʽ���ű����º��Զ������������
--1���û��Զ���ģʽ�������̨���°汾�������һ����Ϣ�����û�Ӧ�ýű������Ƿ�����
local updmode = base.UPDMODE or 0

--PROTOCOL�������Э�飬ֻ֧��TCP��UDP
--SERVER,PORTΪ��������ַ�Ͷ˿�
local PROTOCOL,SERVER,PORT = "UDP","firmware.openluat.com",12410
--�Ƿ�ʹ���û��Զ��������������
local usersvr
--����������·��
local UPDATEPACK = "/luazip/update.bin"

-- GET����ȴ�ʱ��
local CMD_GET_TIMEOUT = 10000
-- �����(��ID���߳��Ȳ�ƥ��) ��һ��ʱ���������»�ȡ
local ERROR_PACK_TIMEOUT = 10000
-- ÿ��GET�������Դ���
local CMD_GET_RETRY_TIMES = 5
--socket id
local lid,updsuc
--���ö�ʱ������ʱ�����ڣ���λ�룬0��ʾ�رն�ʱ����
local period = 0
--״̬��״̬
--IDLE������״̬
--CHECK������ѯ�������Ƿ����°汾��״̬
--UPDATE��������״̬
local state = "IDLE"
--projectid����Ŀ��ʶ��id,�������Լ�ά��
--total�ǰ��ĸ��������������ļ�Ϊ10235�ֽڣ���total=(int)((10235+1022)/1023)=11;�����ļ�Ϊ10230�ֽڣ���total=(int)((10230+1022)/1023)=10
--last�����һ�������ֽ��������������ļ�Ϊ10235�ֽڣ���last=10235%1023=5;�����ļ�Ϊ10230�ֽڣ���last=1023
local projectid,total,last
--packid����ǰ��������
--getretries����ȡÿ�����Ѿ����ԵĴ���
local packid,getretries = 1,0

--ʱ������ģ��֧������ϵͳʱ�书�ܣ�������Ҫ���������ص�ǰʱ��
timezone = nil
BEIJING_TIME = 8
GREENWICH_TIME = 0

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������updateǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("update",...)
end

--[[
��������save
����  ���������ݰ��������ļ���
����  ��
		data�����ݰ�
����ֵ����
]]
local function save(data)
	--����ǵ�һ�������򸲸Ǳ��棻����׷�ӱ���
	local mode = packid == 1 and "wb" or "a+"
	--���ļ�
	local f = io.open(UPDATEPACK,mode)

	if f == nil then
		print("update.save:file nil")
		return
	end
	--д�ļ�
	local rt = f:write(data)
	print("update.save",rt,string.len(data))
	local len = f:seek("end")
	print("update.save current len:",len)
	if not rt then
		sys.removegpsdat()
		--����д�˶����ֽ�
		local write_len = len - 1022*(packid-1)
		
		rt = f:write(string.sub(data,write_len+1,-1))
		print("update.save2",rt,string.len(data))
		if not rt then
		  f:close()
		  return
		end
	end
	f:close()
	return true
end

--[[
��������retry
����  �����������е����Զ���
����  ��
		param�����ΪSTOP����ֹͣ���ԣ�����ִ������
����ֵ����
]]
local function retry(param)
	--����״̬�ѽ���ֱ���˳�
	if state~="CONNECT" and state~="UPDATE" and state~="CHECK" then
		return
	end
	--ֹͣ����
	if param == "STOP" then
		getretries = 0
		sys.timer_stop(retry)
		return
	end
	--�����ݴ���ERROR_PACK_TIMEOUT��������Ե�ǰ��
	if param == "ERROR_PACK" then
		sys.timer_start(retry,ERROR_PACK_TIMEOUT)
		return
	end
	--���Դ�����1
	getretries = getretries + 1
	if getretries < CMD_GET_RETRY_TIMES then
		-- δ�����Դ���,�������Ի�ȡ������
		if state == "CONNECT" then
			link.close(lid)
			lid = nil
			connect()
		elseif state == "UPDATE" then
			reqget(packid)
		else
			reqcheck()
		end
	else
		-- �������Դ���,����ʧ��
		upend(false)
	end
end

--[[
��������reqget
����  �����͡���ȡ��index�����������ݡ���������
����  ��
		index��������������1��ʼ
����ֵ����
]]
function reqget(index)
	send(lid,string.format("%sGet%d,%d",
							usersvr and "" or string.format("0,%s,%s,%s,%s,%s,",base.PRODUCT_KEY,misc.getimei(),misc.isnvalid() and misc.getsn() or "",base.PROJECT.."_"..sys.getcorever(),base.VERSION),
							index,
							projectid))
	--������CMD_GET_TIMEOUT��������ԡ���ʱ��
	sys.timer_start(retry,CMD_GET_TIMEOUT)
end

--[[
��������getpack
����  �������ӷ������յ���һ������
����  ��
		data��������
����ֵ����
]]
local function getpack(data)
	--�жϰ������Ƿ���ȷ
	local len = string.len(data)
	if (packid < total and len ~= 1024) or (packid >= total and (len - 2) ~= last) then
		print("getpack:len not match",packid,len,last)
		retry("ERROR_PACK")
		return
	end

	--�жϰ�����Ƿ���ȷ
	local id = string.byte(data,1)*256+string.byte(data,2)
	if id ~= packid then
		print("getpack:packid not match",id,packid)
		retry("ERROR_PACK")
		return
	end

	--ֹͣ����
	retry("STOP")

	--����������
	save(string.sub(data,3,-1))
	--������û��Զ���ģʽ������һ���ڲ���ϢUP_PROGRESS_IND����ʾ��������
	if updmode == 1 then
		dispatch("UP_EVT","UP_PROGRESS_IND",packid*100/total)
	end

	--��ȡ��һ������
	if packid == total then
		upend(true)
	else
		packid = packid + 1
		reqget(packid)
	end
end

--[[
��������upbegin
����  �������������·����°汾��Ϣ
����  ��
		data���°汾��Ϣ
����ֵ����
]]
function upbegin(data)
	local p1,p2,p3 = string.match(data,"LUAUPDATE,(%d+),(%d+),(%d+)")
	--��̨ά������Ŀid�����ĸ��������һ�����ֽ���
	p1,p2,p3 = base.tonumber(p1),base.tonumber(p2),base.tonumber(p3)
	--��ʽ��ȷ
	if p1 and p2 and p3 then
		projectid,total,last = p1,p2,p3
		--���Դ�����0
		getretries = 0
		--����Ϊ������״̬
		state = "UPDATE"
		--�ӵ�1����������ʼ
		packid = 1
		sys.removegpsdat()
		--�������󣬻�ȡ��1��������
		reqget(packid)
	--��ʽ������������
	else
		upend(false)
	end
end

--[[
��������upend
����  ����������
����  ��
		succ�������trueΪ�ɹ�������Ϊʧ��
����ֵ����
]]
function upend(succ)
	print("upend",succ)
	updsuc = succ
	if not succ then os.remove(UPDATEPACK) end
	local tmpsta = state
	state = "IDLE"
	--ֹͣ���Զ�ʱ��
	sys.timer_stop(retry)
	--�Ͽ�����
	link.close(lid)
	lid = nil
	getretries = 0
	--�����ɹ��������Զ�����ģʽ������
	if succ == true and updmode == 0 then
		sys.restart("update.upend")
	end
	--������Զ�������ģʽ������һ���ڲ���ϢUP_END_IND����ʾ���������Լ��������
	if updmode == 1 and tmpsta ~= "IDLE" then
		dispatch("UP_EVT","UP_END_IND",succ)
	end
	--����һ���ڲ���ϢUPDATE_END_IND��Ŀǰ�����ģʽ���ʹ��
	dispatch("UPDATE_END_IND")
	if period~=0 then sys.timer_start(connect,period*1000,"period") end
end

--[[
��������reqcheck
����  �����͡����������Ƿ����°汾���������ݵ�������
����  ����
����ֵ����
]]
function reqcheck()
	print("reqcheck",usersvr)
	state = "CHECK"
	if usersvr then
		send(lid,string.format("%s,%s,%s",misc.getimei(),base.PROJECT.."_"..sys.getcorever(),base.VERSION))
	else
		send(lid,string.format("0,%s,%s,%s,%s,%s",base.PRODUCT_KEY,misc.getimei(),misc.isnvalid() and misc.getsn() or "",base.PROJECT.."_"..sys.getcorever(),base.VERSION))
	end
	sys.timer_start(retry,CMD_GET_TIMEOUT)
end

--[[
��������nofity
����  ��socket״̬�Ĵ�����
����  ��
        id��socket id��������Ժ��Բ�����
        evt����Ϣ�¼�����
		val�� ��Ϣ�¼�����
����ֵ����
]]
local function nofity(id,evt,val)
	--���ӽ��
	if evt == "CONNECT" then
		state = "CONNECT"
		--����һ���ڲ���ϢUPDATE_BEGIN_IND��Ŀǰ�����ģʽ���ʹ��
		dispatch("UPDATE_BEGIN_IND")
		--���ӳɹ�
		if val == "CONNECT OK" then
			reqcheck()
		--����ʧ��
		else
			sys.timer_start(retry,CMD_GET_TIMEOUT)
		end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and val == "CLOSED" then		 
		upend(false)
	end
end

--�������·����°汾��Ϣ���Զ���ģʽ��ʹ��
local chkrspdat
--[[
��������upselcb
����  ���Զ���ģʽ�£��û�ѡ���Ƿ������Ļص�����
����  ��
        sel���Ƿ�����������trueΪ��������Ϊ������
����ֵ����
]]
local upselcb = function(sel)
	--��������
	if sel then
		upbegin(chkrspdat)
	--����������
	else
		link.close(lid)
		lid = nil
		dispatch("UPDATE_END_IND")
	end
end

--[[
��������recv
����  ��socket�������ݵĴ�����
����  ��
        id ��socket id��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
local function recv(id,data)
	--ֹͣ���Զ�ʱ��
	sys.timer_stop(retry)
	--����ѯ�������Ƿ����°汾��״̬
	if state == "CHECK" then
		--�����������°汾
		if string.find(data,"LUAUPDATE") == 1 then
			--�Զ�����ģʽ
			if updmode == 0 then
				upbegin(data)
			--�Զ�������ģʽ
			elseif updmode == 1 then
				chkrspdat = data
				dispatch("UP_EVT","NEW_VER_IND",upselcb)
			else
				upend(false)
			end
		--û���°汾
		else
			upend(false)
		end
		--����û�Ӧ�ýű��е�����settimezone�ӿ�
		if timezone then
			local clk,a,b = {}
			a,b,clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec = string.find(data,"(%d+)%-(%d+)%-(%d+) *(%d%d):(%d%d):(%d%d)")
			--�����������������ȷ��ʱ���ʽ
			if a and b then
				--����ϵͳʱ��
				clk = common.transftimezone(clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec,BEIJING_TIME,timezone)
				misc.setclock(clk)
			end
		end
	--�������С�״̬
	elseif state == "UPDATE" then
		if data == "ERR" then
			upend(false)
		else
			getpack(data)
		end
	else
		upend(false)
	end	
end

--[[
��������settimezone
����  ������ϵͳʱ���ʱ��
����  ��
        zone ��ʱ����Ŀǰ��֧�ָ�������ʱ��ͱ���ʱ�䣬BEIJING_TIME��GREENWICH_TIME
����ֵ����
]]
function settimezone(zone)
	timezone = zone
end

function connect()
	print("connect",lid,updsuc)
	if not lid and not updsuc then
		lid = link.open(nofity,recv,"update")
		link.connect(lid,PROTOCOL,SERVER,PORT)
	end
end

local function defaultbgn()
	print("defaultbgn",usersvr)
	if not usersvr then
		base.assert(base.PRODUCT_KEY and base.PROJECT and base.VERSION,"undefine PRODUCT_KEY or PROJECT or VERSION in main.lua")
		base.assert(not string.match(base.PROJECT,","),"PROJECT in main.lua format error")
		base.assert(string.match(base.VERSION,"%d%.%d%.%d") and string.len(base.VERSION)==5,"VERSION in main.lua format error")
		connect()
	end
end

--[[
��������setup
����  �����÷������Ĵ���Э�顢��ַ�Ͷ˿�
����  ��
        prot �������Э�飬��֧��TCP��UDP
		server����������ַ
		port���������˿�
����ֵ����
]]
function setup(prot,server,port)
	if prot and server and port then
		PROTOCOL,SERVER,PORT = prot,server,port
		usersvr = true
		base.assert(base.PROJECT and base.VERSION,"undefine PROJECT or VERSION in main.lua")		
		connect()
	end
end

--[[
��������setperiod
����  �����ö�ʱ����������
����  ��
        prd��number���ͣ���ʱ���������ڣ���λ�룻0��ʾ�رն�ʱ�������ܣ�����ֵҪ���ڵ���60��
����ֵ����
]]
function setperiod(prd)
	base.assert(prd==0 or prd>=60,"setperiod prd error")
	print("setperiod",prd)
	period = prd
	if prd==0 then
		sys.timer_stop(connect,"period")
	else
		sys.timer_start(connect,prd*1000,"period")
	end
end

--[[
��������request
����  ��ʵʱ����һ������
����  ����
����ֵ����
]]
function request()
	print("request")
	connect()
end

sys.timer_start(defaultbgn,10000)
