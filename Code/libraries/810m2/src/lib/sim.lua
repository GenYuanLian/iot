--[[
ģ�����ƣ�sim������
ģ�鹦�ܣ���ѯsim��״̬��iccid��imsi��mcc��mnc
ģ������޸�ʱ�䣺2017.02.13
]]

--����ģ��,����������
local string = require"string"
local ril = require"ril"
local sys = require"sys"
local base = _G
local os = require"os"
module(...)

--���س��õ�ȫ�ֺ���������
local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request

--sim����imsi
local imsi
--sim����iccid
local iccid,cpinsta
local smatch = string.match

--[[
��������geticcid
����  ����ȡsim����iccid
����  ����
����ֵ��iccid�������û�ж�ȡ�������򷵻�nil
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯiccid��������Ҫһ��ʱ����ܻ�ȡ��iccid���������������ô˽ӿڣ������Ϸ���nil
]]
function geticcid()
	return iccid or ""
end

--[[
��������getimsi
����  ����ȡsim����imsi
����  ����
����ֵ��imsi�������û�ж�ȡ�������򷵻�nil
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯimsi��������Ҫһ��ʱ����ܻ�ȡ��imsi���������������ô˽ӿڣ������Ϸ���nil
]]
function getimsi()
	return imsi or ""
end

--[[
��������getmcc
����  ����ȡsim����mcc
����  ����
����ֵ��mcc�������û�ж�ȡ�������򷵻�""
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯimsi��������Ҫһ��ʱ����ܻ�ȡ��imsi���������������ô˽ӿڣ������Ϸ���""
]]
function getmcc()
	return (imsi ~= nil and imsi ~= "") and string.sub(imsi,1,3) or ""
end

--[[
��������getmnc
����  ����ȡsim����getmnc
����  ����
����ֵ��mnc�������û�ж�ȡ�������򷵻�""
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯimsi��������Ҫһ��ʱ����ܻ�ȡ��imsi���������������ô˽ӿڣ������Ϸ���""
]]
function getmnc()
	return (imsi ~= nil and imsi ~= "") and string.sub(imsi,4,5) or ""
end

--[[
��������getstatus
����  ����ȡsim����״̬
����  ����
����ֵ��true��ʾsim��������false����nil��ʾδ��⵽�����߿��쳣
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯ״̬��������Ҫһ��ʱ����ܻ�ȡ��״̬���������������ô˽ӿڣ������Ϸ���nil
]]
function getstatus()
	return cpinsta=="RDY"
end

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
	if cmd == "AT+ICCID" then
		iccid = smatch(intermediate,"+ICCID:%s*(%w+)") or ""
	elseif cmd == "AT+CIMI" then
		imsi = intermediate
		--����һ���ڲ���ϢIMSI_READY��֪ͨ�Ѿ���ȡimsi
		sys.dispatch("IMSI_READY")
	elseif cmd=="AT+CPIN?" then
		--base.print("sim.rsp",cmd,success,response,intermediate)
		if not success or intermediate==nil then
			urc("+CPIN:NOT INSERTED","+CPIN")
		else
			urc(intermediate,smatch(intermediate,"((%+%w+))"))
		end
		ril.regurc("+CPIN",urc)
	end
end

local function setcpinsta(newsta,data)
	if cpinsta~=newsta then
		base.print('setcpinsta',data)
		if newsta=="RDY" then
			req("AT+ICCID")
			req("AT+CIMI")
		end
		cpinsta = newsta
	end
end

--[[
��������urc
����  ��������ģ���ڡ�ע��ĵײ�coreͨ�����⴮�������ϱ���֪ͨ���Ĵ���
����  ��
		data��֪ͨ�������ַ�����Ϣ
		prefix��֪ͨ��ǰ׺
����ֵ����
]]
function urc(data,prefix)
	--base.print('simurc',data,prefix)
	
	if prefix == "+CPIN" then
		--sim������
		if smatch(data,"+CPIN:%s*READY") then
			setcpinsta("RDY",data)
			sys.dispatch("SIM_IND","RDY")
		--δ��⵽sim��
		elseif smatch(data,"+CPIN:%s*NOT INSERTED") then
			setcpinsta("NIST",data)
			sys.dispatch("SIM_IND","NIST")
		else
			setcpinsta("NORDY",data)
			if data == "+CPIN: SIM PIN" then
				sys.dispatch("SIM_IND_SIM_PIN")	
			end
			sys.dispatch("SIM_IND","NORDY")
		end
	elseif prefix == '+ESIMS' then	
		base.print('testetst',data)
		if data == '+ESIMS: 1' then
			setcpinsta("RDY",data)
			sys.dispatch("SIM_IND","RDY")
		else
			setcpinsta("NIST",data)
			sys.dispatch("SIM_IND","NIST")
		end	
	end
end

local function cpinqry()
	ril.regrsp("+CPIN",rsp)
	ril.deregurc("+CPIN")
	req("AT+CPIN?",nil,nil,nil,{skip=true})
end

local function netind(e,v)
	if v=="REGISTERED" then
		cpinqry()
	end	
	return true
end

--ע��AT+ICCID�����Ӧ������
ril.regrsp("+ICCID",rsp)
--ע��AT+CIMI�����Ӧ������
ril.regrsp("+CIMI",rsp)
--ע��+CPIN֪ͨ�Ĵ�����
ril.regurc("+CPIN",urc)
sys.regapp(netind,"NET_STATE_CHANGED")
sys.timer_loop_start(cpinqry,60000)
