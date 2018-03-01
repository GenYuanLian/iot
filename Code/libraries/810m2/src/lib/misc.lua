--[[
ģ�����ƣ��������
ģ�鹦�ܣ����кš�IMEI���ײ�����汾�š�ʱ�ӡ��Ƿ�У׼������ģʽ����ѯ��ص����ȹ���
ģ������޸�ʱ�䣺2017.02.14
]]

--����ģ��,����������
local string = require"string"
local ril = require"ril"
local sys = require"sys"
local base = _G
local os = require"os"
local io = require"io"
local rtos = require"rtos"
local pmd = require"pmd"
module(...)

--���س��õ�ȫ�ֺ���������
local tonumber,tostring,print,req,smatch = base.tonumber,base.tostring,base.print,ril.request,string.match

--sn�����к�
--snrdy���Ƿ��Ѿ��ɹ���ȡ�����к�
--imei��IMEI
--imeirdy���Ƿ��Ѿ��ɹ���ȡ��IMEI
--ver���ײ�����汾��
--clkswitch������ʱ��֪ͨ����
--updating���Ƿ�����ִ��Զ����������(update.lua)
--dbging���Ƿ�����ִ��dbg����(dbg.lua)
--ntping���Ƿ�����ִ��NTPʱ��ͬ������(ntp.lua)
--flypending���Ƿ��еȴ�����Ľ������ģʽ����
local sn,snrdy,imeirdy,--[[ver,]]imei,clkswitch,updating,dbging,ntping,flypending

--calib��У׼��־��trueΪ��У׼������δУ׼
--setclkcb��ִ��AT+CCLK���Ӧ�����û��Զ���ص�����
--wimeicb��ִ��AT+WIMEI���Ӧ�����û��Զ���ص�����
--wsncb��ִ��AT+WISN���Ӧ�����û��Զ���ص�����
local calib,setclkcb,wimeicb,wsncb,audflg

--[[
��������rsp
����  ��������ģ���ڡ�ͨ�����⴮�ڷ��͵��ײ�core�����AT�����Ӧ����
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function rsp(cmd,success,response,intermediate)
	local prefix = smatch(cmd,"AT(%+%u+)")
	--��ѯ���к�
	if cmd == "AT+WISN?" then
		if intermediate then sn = smatch(intermediate,"+WISN:%s*(.+)") end
		--���û�гɹ���ȡ�����кţ������һ���ڲ���ϢSN_READY����ʾ�Ѿ���ȡ�����к�
		if not snrdy then sys.dispatch("SN_READY") snrdy = true end
	--��ѯ�ײ�����汾��
	--[[elseif cmd == "AT+VER" then
		ver = intermediate]]
	--��ѯIMEI
	elseif cmd == "AT+CGSN" then
		imei = intermediate
		--���û�гɹ���ȡ��IMEI�������һ���ڲ���ϢIMEI_READY����ʾ�Ѿ���ȡ��IMEI
		if not imeirdy then sys.dispatch("IMEI_READY") imeirdy = true end
	--дIMEI
	elseif smatch(cmd,"AT%+EGMR=") then
		if smatch(cmd,"AT%+EGMR=%d,(%d)")=="7" then
			if wimeicb then
				wimeicb(success)
			else
				if success then sys.restart("write imei") end
			end
		end
	elseif smatch(cmd,"AT%+CSDS=") then
	elseif smatch(cmd,"AT%+WISN=") then
		if wsncb then
			wsncb(success)
		else
			if success then sys.restart("write sn") end
		end
	--����ϵͳʱ��
	elseif prefix == "+CCLK" then
		startclktimer()
		--AT����Ӧ�������������лص�����
		if setclkcb then
			setclkcb(cmd,success,response,intermediate)
		end
	--��ѯ�Ƿ�У׼
	elseif cmd == "AT+ATWMFT=99" then
		print('ATWMFT',intermediate)
		if intermediate == "SUCC" then
			calib = true
		else
			calib = false
		end
	--������˳�����ģʽ
	elseif smatch(cmd,"AT%+CFUN=[01]") then
		--����һ���ڲ���ϢFLYMODE_IND����ʾ����ģʽ״̬�����仯
		sys.dispatch("FLYMODE_IND",smatch(cmd,"AT%+CFUN=(%d)")=="0")

	elseif cmd == "AT+AUD?" then
		print('AT+AUD?',intermediate)
		if intermediate then
			audflg = smatch(intermediate,"+AUD=1")
		end
	end
	
end

--[[
��������setclock
����  ������ϵͳʱ��
����  ��
		t��ϵͳʱ�����ʽ�ο���{year=2017,month=2,day=14,hour=14,min=2,sec=58}
		rspfunc������ϵͳʱ�����û��Զ���ص�����
����ֵ����
]]
function setclock(t,rspfunc)
	if t.year - 2000 > 38 then
		if rspfunc then rspfunc() end
		return
	end
	setclkcb = rspfunc
	req(string.format("AT+CCLK=\"%02d/%02d/%02d,%02d:%02d:%02d\"",string.sub(t.year,3,4),t.month,t.day,t.hour,t.min,t.sec),nil,rsp)
end

--[[
��������getclockstr
����  ����ȡϵͳʱ���ַ���
����  ����
����ֵ��ϵͳʱ���ַ�������ʽΪYYMMDDhhmmss������170214141602��17��2��14��14ʱ16��02��
]]
function getclockstr()
	local clk = os.date("*t")
	clk.year = string.sub(clk.year,3,4)
	return string.format("%02d%02d%02d%02d%02d%02d",clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec)
end

--[[
��������getweek
����  ����ȡ����
����  ����
����ֵ�����ڣ�number���ͣ�1-7�ֱ��Ӧ��һ������
]]
function getweek()
	local clk = os.date("*t")
	return ((clk.wday == 1) and 7 or (clk.wday - 1))
end

--[[
��������getclock
����  ����ȡϵͳʱ���
����  ����
����ֵ��table���͵�ʱ�䣬����{year=2017,month=2,day=14,hour=14,min=19,sec=23}
]]
function getclock()
	return os.date("*t")
end

--[[
��������startclktimer
����  ��ѡ���Ե���������ʱ��֪ͨ��ʱ��
����  ����
����ֵ����
]]
function startclktimer()
	--���ؿ��� ���� ����ģʽΪ����ģʽ
	if clkswitch or sys.getworkmode()==sys.FULL_MODE then
		--����һ���ڲ���ϢCLOCK_IND����ʾ���������֣�����12��13��00�롢14��34��00��
		sys.dispatch("CLOCK_IND")
		print('CLOCK_IND',os.date("*t").sec)
		--�����´�֪ͨ�Ķ�ʱ��
		sys.timer_start(startclktimer,(60-os.date("*t").sec)*1000)
	end
end

function chingeclktimer()
	sys.timer_start(startclktimer,(60-os.date("*t").sec)*1000)
end

--[[
��������getsn
����  ����ȡ���к�
����  ����
����ֵ�����кţ����δ��ȡ������""
]]
function getsn()
	return sn or ""
end

--[[
��������isnvalid
����  ���ж�sn�Ƿ���Ч
����  ����
����ֵ����Ч����true�����򷵻�false
]]
function isnvalid()
	local snstr,sninvalid = getsn(),""
	local len,i = string.len(snstr)
	for i=1,len do
		sninvalid = sninvalid.."0"
	end
	return snstr~=sninvalid
end

--[[
��������getimei
����  ����ȡIMEI
����  ����
����ֵ��IMEI�ţ����δ��ȡ������""
]]
function getimei()
	return imei or ""
end

--[[
��������setimei
����  ������IMEI
		���������cb��������IMEI�󲻻��Զ��������û������Լ���֤���óɹ��󣬵���sys.restart����dbg.restart�ӿڽ���������;
		���û�д���cb�������óɹ���������Զ�����
����  ��
		s����IMEI
		cb�����ú�Ļص�����������ʱ�Ὣ���ý������ȥ��true��ʾ���óɹ���false����nil��ʾʧ�ܣ�
����ֵ����
]]
function setimei(s,cb)
	if s==imei then
		if cb then cb(true) end
	else
		req("AT+EGMR=1,7,\""..s.."\"")
		wimeicb = cb
	end
end



--[[
��������setsn
����  ������SN
		���������cb��������SN�󲻻��Զ��������û������Լ���֤���óɹ��󣬵���sys.restart����dbg.restart�ӿڽ���������;
		���û�д���cb�������óɹ���������Զ�����
����  ��
		s����SN
		cb�����ú�Ļص�����������ʱ�Ὣ���ý������ȥ��true��ʾ���óɹ���false����nil��ʾʧ�ܣ�
����ֵ����
]]
function setsn(s,cb)
	if s==sn then
		if cb then cb(true) end
	else
		req("AT+AMFAC="..(cb and "0" or "1"))
		req("AT+WISN=\""..s.."\"")
		wsncb = cb
	end
end


--[[
��������setflymode
����  �����Ʒ���ģʽ
����  ��
		val��trueΪ�������ģʽ��falseΪ�˳�����ģʽ
����ֵ����
]]
function setflymode(val)
	--����ǽ������ģʽ
	if val then
		--�������ִ��Զ���������ܻ���dbg���ܻ���ntp���ܣ����ӳٽ������ģʽ
		if updating or dbging or ntping then flypending = true return end
	end
	--����AT�����������˳�����ģʽ
	req("AT+CFUN="..(val and 0 or 1))
	flypending = false
end

--[[
��������set
����  ������֮ǰд�ľɳ���ĿǰΪ�պ���
����  ����
����ֵ����
]]
function set() end

--[[
��������getcalib
����  ����ȡ�Ƿ�У׼��־
����  ����
����ֵ��trueΪУ׼������ΪûУ׼
]]
function getcalib()
	return calib
end

--[[
��������getaudflg
����  ����ȡ�Ƿ���д��Ƶ������־
����  ����
����ֵ��trueΪ��д������Ϊû��д
]]
function getaudflg()
	return audflg
end

--[[
��������getvbatvolt
����  ����ȡVBAT�ĵ�ص�ѹ
����  ����
����ֵ����ѹ��number���ͣ���λ����
]]
function getvbatvolt()
	local v1,v2,v3,v4,v5 = pmd.param_get()
	return v2
end

--[[
��������getcharger
����  ����ȡ�������λ״̬
����  ����
����ֵ��true��ʾ��ӳ������false��ʾδ�ӳ����
]]
function getcharger()
	local v1,v2,v3,v4,v5 = pmd.param_get()
	return v4
end

local function pmdinit()
	local param = 
	{
		ccLevel = 4050,--�������� ������4.15�������������ѹ
		cvLevel = 4200,-- ������ѹ��
		ovLevel = 4250,-- ������Ƶ�ѹ
		pvLevel = 4100,---�س��
		poweroffLevel = 3400,--%0��ѹ��
		ccCurrent = 300,--���� �׶ε���
		fullCurrent = 50,--����ֹͣ����
	}
	pmd.init(param)
end

--[[
��������ind
����  ����ģ��ע����ڲ���Ϣ�Ĵ�����
����  ��
		id���ڲ���Ϣid
		para���ڲ���Ϣ����
����ֵ��true
]]
local function ind(id,para)
	--����ģʽ�����仯
	if id=="SYS_WORKMODE_IND" then
		startclktimer()
	--Զ��������ʼ
	elseif id=="UPDATE_BEGIN_IND" then
		updating = true
	--Զ����������
	elseif id=="UPDATE_END_IND" then
		updating = false
		if flypending then setflymode(true) end
	--dbg���ܿ�ʼ
	elseif id=="DBG_BEGIN_IND" then
		dbging = true
	--dbg���ܽ���
	elseif id=="DBG_END_IND" then
		dbging = false
		if flypending then setflymode(true) end
	--NTPͬ����ʼ
	elseif id=="NTP_BEGIN_IND" then
		ntping = true
	--NTPͬ������
	elseif id=="NTP_END_IND" then
		ntping = false
		if flypending then setflymode(true) end
	end

	return true
end

--ע������AT�����Ӧ������
ril.regrsp("+ATWMFT",rsp)
ril.regrsp("+WISN",rsp)
ril.regrsp("+CGSN",rsp)
ril.regrsp("+EGMR",rsp)
ril.regrsp("+AMFAC",rsp)
ril.regrsp("+CFUN",rsp)
ril.regrsp("+AUD",rsp)
--��ѯ�Ƿ�У׼
--req("AT+ATWMFT=99")
--��ѯ���к�
req("AT+WISN?")
--��ѯIMEI
req("AT+CGSN")
req("AT+AUD?")
--��������ʱ��֪ͨ��ʱ��
startclktimer()
--ע�᱾ģ���ע���ڲ���Ϣ�Ĵ�����
sys.regapp(ind,"SYS_WORKMODE_IND","UPDATE_BEGIN_IND","UPDATE_END_IND","DBG_BEGIN_IND","DBG_END_IND","NTP_BEGIN_IND","NTP_END_IND")
pmdinit()
