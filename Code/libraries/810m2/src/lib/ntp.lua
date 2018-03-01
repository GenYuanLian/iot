--[[
ģ�����ƣ�����ʱ�����
ģ�鹦�ܣ�ֻ��ÿ�ο�����������ʱ������NTP������������ϵͳʱ��
�������аٶ�ѧϰNTPЭ��
Ȼ�����Ķ���ģ��
ģ������޸�ʱ�䣺2017.03.22
]]

--����ģ��,����������
local base = _G
local string = require"string"
local os = require"os"
local sys  = require"sys"
local link = require"link"
local misc = require"misc"
local common = require"common"
local pack = require"pack"
module(...)

--���س��õ�ȫ�ֺ���������
local print = base.print
local send = link.send
local dispatch = sys.dispatch
local sbyte,ssub = string.byte,string.sub


--���õ�NTP�������������ϣ�����˳��ȥ���ӷ�����ͬ��ʱ�䣬ͬ���ɹ��󣬾��˳������ټ�������
local tserver =
{	
	"ntp1.aliyun.com",
	"ntp2.aliyun.com",
	"ntp3.aliyun.com",
	"ntp4.aliyun.com",
	"ntp5.aliyun.com",
	"ntp7.aliyun.com",
	"ntp6.aliyun.com",	
	"s2c.time.edu.cn",
	"194.109.22.18",
	"210.72.145.44",
	--[["ntp.sjtu.edu.cn",
	"s1a.time.edu.cn",
	"s1b.time.edu.cn",
	"s1c.time.edu.cn",
	"s1d.time.edu.cn",
	"s2a.time.edu.cn",	
	"s2d.time.edu.cn",
	"s2e.time.edu.cn",
	"s2g.time.edu.cn",
	"s2h.time.edu.cn",
	"s2m.time.edu.cn",]]
}
--��ǰ���ӵķ�������tserver�е�����
local tserveridx = 1

--REQUEST����ȴ�ʱ��
local REQUEST_TIMEOUT = 8000
--ÿ��REQUEST�������Դ���
local REQUEST_RETRY_TIMES = 3
--socket id
local lid
--�뵱ǰ��NTP������ʱ��ͬ���Ѿ����ԵĴ���
local retries = 0


--[[
��������retry
����  ��ʱ��ͬ�������е����Զ���
����  ����
����ֵ����
]]
local function retry()
	sys.timer_stop(retry)
	--���Դ�����1
	retries = retries + 1
	--δ�����Դ���,��������ͬ������
	if retries < REQUEST_RETRY_TIMES then
		request()
	else
		--�������Դ���,�뵱ǰ������ͬ��ʧ��
		upend(false)
	end
end


--[[
��������upend
����  ���뵱ǰ��NTP������ʱ��ͬ���������
����  ��
		suc��ʱ��ͬ�������trueΪ�ɹ�������Ϊʧ��
����ֵ����
]]
function upend(suc)
	print("ntp.upend",suc)
	--ֹͣ���Զ�ʱ��
	sys.timer_stop(retry)
	retries = 0
	--�Ͽ�����
	link.close(lid)
	--ͬ��ʱ��ɹ� ���� NTP�������Ѿ���������
	if suc or tserveridx>=#tserver then
		--����һ���ڲ���ϢUPDATE_END_IND��Ŀǰ�����ģʽ���ʹ��
		dispatch("NTP_END_IND",suc)
	else
		tserveridx = tserveridx+1
		connect()
	end	
end

--[[
��������request
����  �����͡�ͬ��ʱ�䡱�������ݵ�������
����  ����
����ֵ����
]]
function request()
	send(lid,common.hexstobins("E30006EC0000000000000000314E31340000000000000000000000000000000000000000000000000000000000000000"))
	sys.timer_start(retry,REQUEST_TIMEOUT)
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
		--����һ���ڲ���ϢNTP_BEGIN_IND��Ŀǰ�����ģʽ���ʹ��
		dispatch("NTP_BEGIN_IND")
		--���ӳɹ�
		if val == "CONNECT OK" then
			request()
		--����ʧ��
		else
			upend(false)
		end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and val == "CLOSED" then		 
		upend(false)
	end
end

--[[
��������setclkcb
����  ������misc.setclock�ӿ�����ʱ���Ļص�����
����  ��
        cmd ��������Ժ��Բ�����
        suc�����óɹ�����ʧ�ܣ�true�ɹ�������ʧ��
����ֵ����
]]
local function setclkcb(cmd,suc)
	upend(suc)
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
	--���ݸ�ʽ����
	if string.len(data)~=48 then
		upend(false)
		return
	end
	print("ntp recv:",common.binstohexs(ssub(data,41,44)))
	misc.setclock(os.date("*t",(sbyte(ssub(data,41,41))-0x83)*2^24+(sbyte(ssub(data,42,42))-0xAA)*2^16+(sbyte(ssub(data,43,43))-0x7E)*2^8+(sbyte(ssub(data,44,44))-0x80)+1),setclkcb)
end

--[[
��������connect
����  ������socket���������ӵ�tserveridx��NTP������
����  ����
����ֵ����
]]
function connect()
	lid = link.open(nofity,recv,"ntp")
	link.connect(lid,"UDP",tserver[tserveridx],123)
end

connect()
