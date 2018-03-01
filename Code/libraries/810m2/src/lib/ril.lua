--[[
ģ�����ƣ����⴮��AT���������
ģ�鹦�ܣ�AT����
ģ������޸�ʱ�䣺2017.02.13
]]

-- ����ģ��,����������
local base = _G
local table = require"table"
local string = require"string"
local uart = require"uart"
local rtos = require"rtos"
local sys = require"sys"
module("ril")

--���س��õ�ȫ�ֺ���������
local setmetatable = base.setmetatable
local print = base.print
local type = base.type
local smatch = string.match
local sfind = string.find
local vwrite = uart.write
local vread = uart.read

--�Ƿ�Ϊ͸��ģʽ��trueΪ͸��ģʽ��false����nilΪ��͸��ģʽ
--Ĭ�Ϸ�͸��ģʽ
local transparentmode
--͸��ģʽ�£����⴮�����ݽ��յĴ�����
local rcvfunc

--ִ��AT�����1�����޷������ж�at����ִ��ʧ�ܣ����������
local TIMEOUT,RETRYTIMEOUT,RETRY_MAX = 60000,1000,5 --1�����޷��� �ж�at����ִ��ʧ��

--[[
AT�����Ӧ������:
  NORESULT: �յ���Ӧ�����ݵ���urc֪ͨ����������͵�AT�������Ӧ�����û���������ͣ�Ĭ��Ϊ������
  NUMBERIC: ���������ͣ����緢��AT+CGSN���Ӧ�������Ϊ��862991527986589\r\nOK��������ָ����862991527986589��һ����Ϊ����������
  SLINE: ��ǰ׺�ĵ����ַ������ͣ����緢��AT+CSQ���Ӧ�������Ϊ��+CSQ: 23,99\r\nOK��������ָ����+CSQ: 23,99��һ����Ϊ�����ַ�������
  MLINE: ��ǰ׺�Ķ����ַ������ͣ����緢��AT+CMGR=5���Ӧ�������Ϊ��+CMGR: 0,,84\r\n0891683108200105F76409A001560889F800087120315123842342050003590404590D003A59\r\nOK��������ָ����OK֮ǰΪ�����ַ�������
  STRING: ��ǰ׺���ַ������ͣ����緢��AT+ATWMFT=99���Ӧ�������Ϊ��SUCC\r\nOK��������ָ����SUCC
]]
local NORESULT,NUMBERIC,SLINE,MLINE,STRING = 0,1,2,3,4

--AT�����Ӧ�����ͱ�Ԥ�������¼���
local RILCMD = {
	["+CSQ"] = 2,
	["+CGSN"] = 1,
	["+WISN"] = 2,
	["+AUD"] = 2,
	["+VER"] = 2,
	["+BLVER"] = 2,
	["+CIMI"] = 1,
	["+ICCID"] = 2,
	["+CGATT"] = 2,
	["+CCLK"] = 2,
	["+CPIN"] = 2,
	["+ATWMFT"] = 4,
	["+CMGR"] = 3,
	["+CMGS"] = 2,
	["+CPBF"] = 3,
	["+CPBR"] = 3, 	
}

--radioready��AT����ͨ���Ƿ�׼������
--delaying��ִ����ĳЩAT����ǰ����Ҫ��ʱһ��ʱ�䣬������ִ����ЩAT����˱�־��ʾ�Ƿ�����ʱ״̬
local radioready,delaying = false

--AT�������
local cmdqueue = {
	{cmd = "ATE0",retry = {max=25,timeout=2000}},
	"AT+CMEE=0",
	"AT+VER",
	"AT+BLVER"
}
-- ��ǰ����ִ�е�AT����,����,�����ص�,�ӳ�ִ��ʱ��,����,����ͷ,����,������ʽ
local currcmd,currarg,currsp,curdelay,curetry,cmdhead,cmdtype,rspformt
-- �������,�м���Ϣ,�����Ϣ
local result,interdata,respdata

--ril������������: 
--����AT����յ�Ӧ��
--����AT������ʱû��Ӧ��
--�ײ���������ϱ���֪ͨ���������Ǽ��Ϊurc

--[[
��������atimeout
����  ������AT������ʱû��Ӧ��Ĵ���
����  ����
����ֵ����
]]
local function atimeout()
	--������Ӧ��ʱ�Զ�����ϵͳ
	sys.restart("ril.atimeout_"..(currcmd or ""))
end

local function retrytimeout()
	print("retrytimeout",currcmd,curetry)
	if curetry and currcmd then
		if not curetry.cnt then curetry.cnt=0 end
		if curetry.cnt<=(curetry.max or RETRY_MAX) then
			sys.timer_start(retrytimeout,curetry.timeout or RETRYTIMEOUT)
			print("sendat retry:",currcmd)
			vwrite(uart.ATC,currcmd .. "\r")
			curetry.cnt = curetry.cnt+1
		else
			if curetry.skip then rsp() end
		end
	end
end

--[[
��������defrsp
����  ��AT�����Ĭ��Ӧ�������û�ж���ĳ��AT��Ӧ������������ߵ�������
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function defrsp(cmd,success,response,intermediate)
	print("default response:",cmd,success,response,intermediate)
end

--AT�����Ӧ�����
local rsptable = {}
setmetatable(rsptable,{__index = function() return defrsp end})

--�Զ����AT����Ӧ���ʽ����AT����Ӧ��ΪSTRING��ʽʱ���û����Խ�һ������������ĸ�ʽ
local formtab = {}

--[[
��������regrsp
����  ��ע��ĳ��AT����Ӧ��Ĵ�����
����  ��
		head����Ӧ���Ӧ��AT����ͷ��ȥ������ǰ���AT�����ַ�
		fnc��AT����Ӧ��Ĵ�����
		typ��AT�����Ӧ�����ͣ�ȡֵ��ΧNORESULT,NUMBERIC,SLINE,MLINE,STRING,SPECIAL
		formt��typΪSTRINGʱ����һ������STRING�е���ϸ��ʽ
����ֵ���ɹ�����true��ʧ��false
]]
function regrsp(head,fnc,typ,formt)
	--û�ж���Ӧ������
	if typ == nil then
		rsptable[head] = fnc
		return true
	end
	--�����˺Ϸ�Ӧ������
	if typ == 0 or typ == 1 or typ == 2 or typ == 3 or typ == 4 then
		--���AT�����Ӧ�������Ѵ��ڣ������������õĲ�һ��
		if RILCMD[head] and RILCMD[head] ~= typ then
			return false
		end
		--����
		RILCMD[head] = typ
		rsptable[head] = fnc
		formtab[head] = formt
		return true
	else
		return false
	end
end

--[[
��������rsp
����  ��AT�����Ӧ����
����  ����
����ֵ����
]]
function rsp()
	--ֹͣӦ��ʱ��ʱ��
	sys.timer_stop(atimeout)
	sys.timer_stop(retrytimeout)

	--�������AT����ʱ�Ѿ�ͬ��ָ����Ӧ������
	if currsp then
		currsp(currcmd,result,respdata,interdata)
	--�û�ע���Ӧ�����������ҵ�������
	else
		rsptable[cmdhead](currcmd,result,respdata,interdata)
	end
	--����ȫ�ֱ���
	currcmd,currarg,currsp,curdelay,curetry,cmdhead,cmdtype,rspformt = nil
	result,interdata,respdata = nil
end

--[[
��������defurc
����  ��urc��Ĭ�ϴ������û�ж���ĳ��urc��Ӧ������������ߵ�������
����  ��
		data��urc����
����ֵ����
]]
local function defurc(data)
	print("defurc:",data)
end

--urc�Ĵ����
local urctable = {}
setmetatable(urctable,{__index = function() return defurc end})

--[[
��������regurc
����  ��ע��ĳ��urc�Ĵ�����
����  ��
		prefix��urcǰ׺����ǰ��������ַ���������+����д�ַ������ֵ����
		handler��urc�Ĵ�����
����ֵ����
]]
function regurc(prefix,handler)
	urctable[prefix] = handler
end

--[[
��������deregurc
����  ����ע��ĳ��urc�Ĵ�����
����  ��
		prefix��urcǰ׺����ǰ��������ַ���������+����д�ַ������ֵ����
����ֵ����
]]
function deregurc(prefix)
	urctable[prefix] = nil
end

--�����ݹ������������⴮���յ�������ʱ��������Ҫ���ô˺������˴���һ��
local urcfilter

local function kickoff()
	radioready = true
	sendat()
end

--[[
��������urc
����  ��urc����
����  ��
		data��urc����
����ֵ����
]]
local function urc(data)
	--ATͨ��׼������
	if data == "RDY" then
		radioready = true
	else
		local prefix = smatch(data,"(%+*[%u%d& ]+)")
		--ִ��prefix��urc���������������ݹ�����
		urcfilter = urctable[prefix](data,prefix)
	end
end

local function printrcv(data)
	if data=="\r\n" then return end
	if smatch(data,"^%+CENG:.+\r\n$") then return end
	if sys.getworkmode()==sys.SIMPLE_MODE then
		if --[[smatch(data,"^%+CENG:.+\r\n$") or ]]smatch(data,"^%+CPIN:.+\r\n$") then return end
		if data=="OK\r\n" and currcmd=="AT+CPIN?" then return end
	end
	
	return true
end

--[[
��������procatc
����  ���������⴮���յ�������
����  ��
		data���յ�������
����ֵ����
]]
local function procatc(data)
	if printrcv(data) then print("atc:",data) end
	
  -- �������ն��з���ֱ������OKΪֹ
	if interdata and cmdtype == MLINE then
		-- ���з���������������յ��м�����˵��ִ�гɹ���,�ж�֮������ݽ�������OK
		if data ~= "OK\r\n" then
    -- ȥ�����Ļ��з�
			if sfind(data,"\r\n",-2) then
				data = string.sub(data,1,-3)
			end
			--ƴ�ӵ��м�����
			interdata = interdata .. "\r\n" .. data
			return
		end
	end
	--������ڡ����ݹ�������
	if urcfilter then
		data,urcfilter = urcfilter(data)
	end
  -- ����������ֽ���\r\n��ɾ��
	if sfind(data,"\r\n",-2) then
		data = string.sub(data,1,-3)
	end
	--����Ϊ��
	if data == "" then
		return
	end

  -- ��ǰ��������ִ�����ж�Ϊurc
	if currcmd == nil then
		urc(data)
		return
	end

	local isurc = false

	--һЩ����Ĵ�����Ϣ��ת��ΪERRORͳһ����
	if sfind(data,"^%+CMS ERROR:") or sfind(data,"^%+CME ERROR:") then
		data = "ERROR"
	end
	--ִ�гɹ���Ӧ��
	if data == "OK" then
		result = true
		respdata = data
	--ִ��ʧ�ܵ�Ӧ��
	elseif data == "ERROR" or data == "NO ANSWER" or data == "NO DIALTONE" then
		result = false
		respdata = data
	elseif data == "NO CARRIER" and currcmd=="ATA" then
    result = false
    respdata = data
  --��Ҫ�������������AT����Ӧ��
	elseif data == "> " then
		if cmdhead == "+CMGS" then -- ������ʾ�����Ͷ��Ż�������
			print("send:",currarg)
			vwrite(uart.ATC,currarg,"\026")		
		else
			print("error promot cmd:",currcmd)
		end
	else
		--���������������ж��յ���������urc���߷�������
		if cmdtype == NORESULT then -- �޽������ ��ʱ�յ�������ֻ��URC
			isurc = true
		elseif cmdtype == NUMBERIC then -- ȫ����
			local numstr = smatch(data,"(%x+)")
			if numstr == data then
				interdata = data
			else
				isurc = true
			end
		elseif cmdtype == STRING then -- �ַ���
			if smatch(data,rspformt or "^%w+$") then
				interdata = data
			else
				isurc = true
			end
		elseif cmdtype == SLINE or cmdtype == MLINE then
			if interdata == nil and sfind(data, cmdhead) == 1 then
				interdata = data
			else
				isurc = true
			end		
		else
			isurc = true
		end
	end

	if isurc then
		urc(data)
	elseif result ~= nil then
		rsp()
	end
end

--�Ƿ��ڶ�ȡ���⴮������
local readat = false

--[[
��������getcmd
����  ������һ��AT����
����  ��
		item��AT����
����ֵ����ǰAT���������
]]
local function getcmd(item)
	local cmd,arg,rsp,delay,retry
	--������string����
	if type(item) == "string" then
		--��������
		cmd = item
	--������table����
	elseif type(item) == "table" then
		--��������
		cmd = item.cmd
		--�������
		arg = item.arg
		--����Ӧ������
		rsp = item.rsp
		--������ʱִ��ʱ��
		delay = item.delay
		retry = item.retry
	else
		print("getpack unknown item")
		return
	end
	--����ǰ׺
	head = smatch(cmd,"AT([%+%*]*%u+)")

	if head == nil then
		print("request error cmd:",cmd)
		return
	end

	if head == "+CMGS" then -- �����в���
		if arg == nil or arg == "" then
			print("request error no arg",head)
			return
		end
	end

	--��ֵȫ�ֱ���
	currcmd = cmd
	currarg = arg
	currsp = rsp
	curdelay = delay
	curetry = retry
	cmdhead = head
	cmdtype = RILCMD[head] or NORESULT
	rspformt = formtab[head]

	return currcmd
end

--[[
��������sendat
����  ������AT����
����  ����
����ֵ����
]]
function sendat()
	--print("sendat",radioready,readat,currcmd,delaying)
	if not radioready or readat or currcmd ~= nil or delaying then
		-- δ��ʼ��/���ڶ�ȡatc���ݡ���������ִ�С����������� ֱ���˳�
		return
	end

	local item

	while true do
		--������AT����
		if #cmdqueue == 0 then
			return
		end
		--��ȡ��һ������
		item = table.remove(cmdqueue,1)
		--��������
		getcmd(item)
		--��Ҫ�ӳٷ���
		if curdelay then
			--�����ӳٷ��Ͷ�ʱ��
			sys.timer_start(delayfunc,curdelay)
			--���ȫ�ֱ���
			currcmd,currarg,currsp,curdelay,cmdhead,cmdtype,rspformt = nil
			item.delay = nil
			--�����ӳٷ��ͱ�־
			delaying = true
			--���������²���������еĶ���
			table.insert(cmdqueue,1,item)
			return
		end

		if currcmd ~= nil then
			break
		end
	end
	--����AT����Ӧ��ʱ��ʱ��
	sys.timer_start(atimeout,TIMEOUT)
	if curetry then sys.timer_start(retrytimeout,curetry.timeout or RETRYTIMEOUT) end

	if not (sys.getworkmode()==sys.SIMPLE_MODE and currcmd=="AT+CPIN?") then
		print("sendat:",currcmd)
	end
	--�����⴮���з���AT����
	vwrite(uart.ATC,currcmd .. "\r")
end

--[[
��������delayfunc
����  ����ʱִ��ĳ��AT����Ķ�ʱ���ص�
����  ����
����ֵ����
]]
function delayfunc()
	--�����ʱ��־
	delaying = nil
	--ִ��AT�����
	sendat()
end

--[[
��������atcreader
����  ����AT��������⴮�����ݽ�����Ϣ���Ĵ������������⴮���յ�����ʱ�����ߵ��˺�����
����  ����
����ֵ����
]]
local function atcreader()
	local s

	if not transparentmode then readat = true end
	--ѭ����ȡ���⴮���յ�������
	while true do
		--ÿ�ζ�ȡһ��
		s = vread(uart.ATC,"*l",0)

		if string.len(s) ~= 0 then
			if transparentmode then
				--͸��ģʽ��ֱ��ת������
				rcvfunc(s)
			else
                        --��͸��ģʽ�´����յ�������
			procatc(s)
			end
		else
			break
		end
	end
  if not transparentmode then
    readat = false
    --atc�ϱ����ݴ������Ժ��ִ�з���AT����
    sendat()
  end
end

--ע�ᡰAT��������⴮�����ݽ�����Ϣ���Ĵ�����
sys.regmsg("atc",atcreader)

--[[
��������request
����  ������AT����ײ����
����  ��
		cmd��AT��������
		arg��AT�������������AT+CMGS=12����ִ�к󣬽������ᷢ�ʹ˲�����AT+CIPSEND=14����ִ�к󣬽������ᷢ�ʹ˲���
		onrsp��AT����Ӧ��Ĵ�������ֻ�ǵ�ǰ���͵�AT����Ӧ����Ч������֮���ʧЧ��
		delay����ʱdelay����󣬲ŷ��ʹ�AT����
		retry: ����
����ֵ����
]]
function request(cmd,arg,onrsp,delay,retry)
	if transparentmode then return end
	--���뻺�����
	if arg or onrsp or delay or retry then
		table.insert(cmdqueue,{cmd = cmd,arg = arg,rsp = onrsp,delay = delay,retry = retry})
	else
		table.insert(cmdqueue,cmd)
	end
	--ִ��AT�����
	sendat()
end

sys.timer_start(kickoff,3000)

--[[
��������setransparentmode
����  ��AT����ͨ������Ϊ͸��ģʽ
����  ��
		fnc��͸��ģʽ�£����⴮�����ݽ��յĴ�����
����ֵ����
ע�⣺͸��ģʽ�ͷ�͸��ģʽ��ֻ֧�ֿ����ĵ�һ�����ã���֧����;�л�
]]
function setransparentmode(fnc)
	transparentmode,rcvfunc = true,fnc
end

--[[
��������sendtransparentdata
����  ��͸��ģʽ�·�������
����  ��
		data������
����ֵ���ɹ�����true��ʧ�ܷ���nil
]]
function sendtransparentdata(data)
	if not transparentmode then return end
	vwrite(uart.ATC,data)
	return true
end

