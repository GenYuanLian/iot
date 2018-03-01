--[[
ģ�����ƣ��������п��
ģ�鹦�ܣ���ʼ�����������п�ܡ���Ϣ�ַ�������ʱ���ӿ�
ģ������޸�ʱ�䣺2017.02.17
]]

--����ģ��,����������
require"patch"

local base = _G
local table = require"table"
local rtos = require"rtos"
local pmd = require"pmd"
local uart = require"uart"
local io = require"io"
local os = require"os"
local watchdog = require"watchdog"
local bit = require"bit"
local pm = require"pm"
local string = require"string"
module(...,package.seeall)

--���س��õ�ȫ�ֺ���������
local print = base.print
local unpack = base.unpack
local ipairs = base.ipairs
local type = base.type
local pairs = base.pairs
local assert = base.assert
local tonumber = base.tonumber
local isn = 65535
local hasPwrKey = false

--lib�ű��汾�ţ�ֻҪlib�е��κ�һ���ű������޸ģ�����Ҫ���´˰汾��
SCRIPT_LIB_VER = "1.0.8"
--�ű�����ʱ������core����汾��
CORE_MIN_VER = "Luat_V0008_AIR810"

--���Ƿ���Ҫˢ�½��桱�ı�־����GUI����Ŀ�Ż��õ��˱�־
local refreshflag = false
--[[
��������refresh
����  �����ý���ˢ�±�־����GUI����Ŀ�Ż��õ��˽ӿ�
����  ����
����ֵ����
]]
function refresh()
	refreshflag = true
end

--��ʱ��֧�ֵĵ������ʱ������λ����
local MAXMS = 0x7fffffff/17
--��ʱ��id
local uniquetid = 0
--��ʱ��id��
local tpool = {}
--��ʱ��������
local para = {}
--��ʱ���Ƿ�ѭ����
local loop = {}
--lprfun���û��Զ���ġ��͵�ػ��������
--lpring���Ƿ��Ѿ������Զ��ػ���ʱ��
local lprfun,lpring
--������Ϣ�ļ��Լ�������Ϣ����
local LIB_ERR_FILE,liberr,extliberr = "/lib_err.txt",""
--����ģʽ
--SIMPLE_MODE����ģʽ��Ĭ�ϲ��Ὺ����ÿһ���Ӳ���һ���ڲ���Ϣ��������ʱ��ѯcsq��������ʱ��ѯceng���Ĺ���
--FULL_MODE������ģʽ��Ĭ�ϻῪ����ÿһ���Ӳ���һ���ڲ���Ϣ��������ʱ��ѯcsq��������ʱ��ѯceng���Ĺ���
SIMPLE_MODE,FULL_MODE = 0,1
--Ĭ��Ϊ����ģʽ
local workmode = FULL_MODE

--[[
��������timerfnc
����  ������ײ�core�ϱ����ⲿ��ʱ����Ϣ
����  ��
		utid����ʱ��id
����ֵ����
]]
local function timerfnc(utid)
  local tid,sn= bit.band(utid, 0xffff),bit.band((bit.rshift(utid,16)), 0xffff)

	if tpool[tid] ~= nil then
		--�˶�ʱ���Ļص�����
		local cb = tpool[tid].cb
		
		if tpool[tid].sn ~= sn or not cb then
		  print("invalid timerfnc tid:",tid,"sn:",sn,"realsn:",tpool[tid].sn)
		  return
		end

		local tval = tpool[tid]
		if tval.times and tval.total and tval.step then
			tval.times = tval.times+1
			--��ֵļ�����ʱ����δִ����ϣ�����ִ����һ��
			if tval.times < tval.total then
				rtos.timer_start(tid,tval.step)
				return
			end
		end
		--�������ѭ����ʱ�����Ӷ�ʱ��id��������˶�ʱ��idλ�õ�����
		if not loop[tid] then tpool[tid] = nil end
		--�����Զ���ɱ����
		if para[tid] ~= nil then
			local pval = para[tid]
			--�������ѭ����ʱ�����Ӷ�ʱ��������������˶�ʱ��idλ�õ�����
			if not loop[tid] then para[tid] = nil end
			--ִ�ж�ʱ���ص�����
			cb(unpack(pval))
		--�������Զ���ɱ����
		else
			--ִ�ж�ʱ���ص�����
			cb()
		end

		--�����ѭ����ʱ�������������˶�ʱ��
		if loop[tid] then 
		  isn = isn==65535 and 0 or isn+1
		  tpool[tid].sn = isn
		  local lptid = bit.bor(bit.lshift(isn,16),tid)
		  rtos.timer_start(lptid,loop[tid]) 
		end
	end
end

--[[
��������comp_table
����  ���Ƚ�����table�������Ƿ���ͬ��ע�⣺table�в����ٰ���table
����  ��
		t1����һ��table
		t2���ڶ���table
����ֵ����ͬ����true������false
]]
local function comp_table(t1,t2)
	if not t2 then
	  if not t1 then return #t1 == 0 end
	  return true
	end
	if #t1 == #t2 then
		for i=1,#t1 do
			if unpack(t1,i,i) ~= unpack(t2,i,i) then
				return false
			end
		end
		return true
	end
	return false
end

--[[
��������timer_start
����  ������һ����ʱ��
����  ��
		fnc����ʱ���Ļص�����
		ms����ʱ��ʱ������λΪ����
		...���Զ���ɱ���������ûص�����ʱ������Զ���Ŀɱ�����ش����û�
		ע�⣺fnc�Ϳɱ����...��ͬ���Ψһ��һ����ʱ��
����ֵ����ʱ����ID�����ʧ�ܷ���nil
]]
function timer_start(fnc,ms,...)
	--�ص�������ʱ��������Ч��������������
	assert(fnc~=nil,"timer_start:callback function==nil")
	assert(ms>0,"timer_start:ms==0")
	--�ر���ȫ��ͬ�Ķ�ʱ��
	if arg.n == 0 then
		timer_stop(fnc)
	else
		timer_stop(fnc,unpack(arg))
	end
	isn = isn==65535 and 0 or isn+1
	
	--���ʱ����������֧�ֵ����ʱ��������Ϊ������ʱ��
	if ms > MAXMS then
		local count = ms/MAXMS + (ms%MAXMS == 0 and 0 or 1)
		local step = ms/count
		tval = {cb = fnc, step = step, total = count, times = 0,sn = isn}
		ms = step
	--ʱ��δ��������֧�ֵ����ʱ��
	else
		tval = {cb = fnc,sn = isn}
	end
	uniquetid = 1

	--�Ӷ�ʱ��id�����ҵ�һ��δʹ�õ�idʹ��
	while true do
		if tpool[uniquetid] == nil then
			tpool[uniquetid] = tval
			break
		end
		uniquetid = uniquetid + 1
	end
	local tid = bit.bor(bit.lshift(isn,16),uniquetid)
	--���õײ�ӿ�������ʱ��
	if rtos.timer_start(tid,ms) ~= 1 then print("rtos.timer_start error") return end
	--������ڿɱ�������ڶ�ʱ���������б������
	if arg.n ~= 0 then
		para[uniquetid] = arg
	end
	--���ض�ʱ��id,����id,sn
	return tid,uniquetid,tpool[uniquetid].sn
end

--[[
��������timer_loop_start
����  ������һ��ѭ����ʱ��
����  ��
		fnc����ʱ���Ļص�����
		ms����ʱ��ʱ������λΪ����
		...���Զ���ɱ���������ûص�����ʱ������Զ���Ŀɱ�����ش����û�
		ע�⣺fnc�Ϳɱ����...��ͬ���Ψһ��һ����ʱ��
����ֵ����ʱ����ID�����ʧ�ܷ���nil
]]
function timer_loop_start(fnc,ms,...)
	local tid,utid,sn = timer_start(fnc,ms,unpack(arg))
	if utid then loop[utid] = ms end
	return tid
end

--[[
��������timer_stop
����  ���ر�һ����ʱ��
����  ��
		val����������ʽ��
		     һ���ǿ�����ʱ��ʱ���صĶ�ʱ��id������ʽʱ����Ҫ�ٴ���ɱ����...����Ψһ���һ����ʱ��
			 ��һ���ǿ�����ʱ��ʱ�Ļص�����������ʽʱ�����ٴ���ɱ����...����Ψһ���һ����ʱ��
		...���Զ���ɱ��������timer_start��timer_loop_start�еĿɱ����������ͬ
����ֵ����
]]
function timer_stop(val,...)
	--valΪ��ʱ��id
	if type(val) == "number" then
		tpool[val],para[val],loop[val] = nil
		rtos.timer_stop(val)
	else
		for k,v in pairs(tpool) do
			--�ص�������ͬ
			if type(v) == "table" and v.cb == val or v == val then
				--�Զ���ɱ������ͬ
				if comp_table(arg,para[k])then
					rtos.timer_stop(k)
					tpool[k],para[k],loop[k] = nil
					break
				end
			end
		end
	end
end

--[[
��������timer_stop_all
����  ���ر�ĳ���ص�������ǵ����ж�ʱ�������ۿ�����ʱ��ʱ��û�д����Զ���ɱ����
����  ��
		fnc��������ʱ��ʱ�Ļص�����
����ֵ����
]]
function timer_stop_all(fnc)
	for k,v in pairs(tpool) do
		if type(v) == "table" and v.cb == fnc or v == fnc then
			rtos.timer_stop(k)
			tpool[k],para[k],loop[k] = nil
		end
	end
end

--[[
��������timer_is_active
����  ���ж�ĳ����ʱ���Ƿ��ڿ���״̬
����  ��
		val����������ʽ��
		     һ���ǿ�����ʱ��ʱ���صĶ�ʱ��id������ʽʱ����Ҫ�ٴ���ɱ����...����Ψһ���һ����ʱ��
			 ��һ���ǿ�����ʱ��ʱ�Ļص�����������ʽʱ�����ٴ���ɱ����...����Ψһ���һ����ʱ��
		...���Զ���ɱ��������timer_start��timer_loop_start�еĿɱ����������ͬ
����ֵ����������true������false
]]
function timer_is_active(val,...)
	if type(val) == "number" then
		return tpool[val] ~= nil
	else
		for k,v in pairs(tpool) do
			if type(v) == "table" and v.cb == val or v == val then
				if comp_table(arg,para[k]) then
					return true
				end
			end
		end
		return false
	end
end

--[[
��������readtxt
����  ����ȡ�ı��ļ��е�ȫ������
����  ��
		f���ļ�·��
����ֵ���ı��ļ��е�ȫ�����ݣ���ȡʧ��Ϊ���ַ�������nil
]]
local function readtxt(f)
	local file,rt = io.open(f,"r")
	if not file then print("sys.readtxt no open",f) return "" end
	rt = file:read("*a")
	file:close()
	return rt
end

--[[
��������writetxt
����  ��д�ı��ļ�
����  ��
		f���ļ�·��
		v��Ҫд����ı�����
����ֵ����
]]
local function writetxt(f,v)
	local file = io.open(f,"w")
	if not file then print("sys.writetxt no open",f) return end	
	file:write(v)
	file:close()
end

--[[
��������appenderr
����  ��׷�Ӵ�����Ϣ��LIB_ERR_FILE�ļ���
����  ��
		s��������Ϣ���û��Զ��壬һ����string���ͣ��������trace�л��ӡ���˴�����Ϣ
����ֵ����
]]
local function appenderr(s)
	print("appenderr",s)
	liberr = liberr..s
	writetxt(LIB_ERR_FILE,liberr)	
end

--[[
��������initerr
����  ����ӡLIB_ERR_FILE�ļ��еĴ�����Ϣ
����  ����
����ֵ����
]]
local function initerr()
	extliberr = readtxt(LIB_ERR_FILE) or ""
	print("sys.initerr",extliberr)
	--ɾ��LIB_ERR_FILE�ļ�
	os.remove(LIB_ERR_FILE)
end

--[[
��������getextliberr
����  ����ȡLIB_ERR_FILE�ļ��еĴ�����Ϣ�����ⲿģ��ʹ��
����  ����
����ֵ��LIB_ERR_FILE�ļ��еĴ�����Ϣ
]]
function getextliberr()
	return extliberr or (readtxt(LIB_ERR_FILE) or "")
end

--[[
��������restart
����  ���������
����  ��
		r������ԭ���û��Զ��壬һ����string���ͣ��������trace�л��ӡ��������ԭ��
����ֵ����
]]
function restart(r)
	base.print("sys restart:",r)
	assert(r and r ~= "","sys.restart cause null")
	appenderr("restart["..r.."];")
	if poweroffcb then poweroffcb() end
	rtos.restart()	
end

--[[
��������getcorever
����  ����ȡ�ײ�����汾��
����  ����
����ֵ���汾���ַ���
]]
function getcorever()
	return rtos.get_version()
end

--[[
��������checkcorever
����  �����ײ�����汾�ź�lib�ű���Ҫ����С�ײ�����汾���Ƿ�ƥ��
����  ����
����ֵ����
]]
local function checkcorever()
	local realver = getcorever()
	--���û�л�ȡ���ײ�����汾��
	if not realver or realver=="" then
		appenderr("checkcorever[no core ver error];")
		return
	end
	
	local buildver = string.match(realver,"Luat_V(%d+)_AIR810")
	--����ײ�����汾�Ÿ�ʽ����
	if not buildver then
		appenderr("checkcorever[core ver format error]"..realver..";")
		return
	end
	
	--lib�ű���Ҫ�ĵײ�����汾�Ŵ��ڵײ������ʵ�ʰ汾��
	if tonumber(string.match(CORE_MIN_VER,"Luat_V(%d+)_AIR810"))>tonumber(buildver) then
		appenderr("checkcorever[core ver match warn]"..realver..","..CORE_MIN_VER..";")
	end
end

--[[
��������repwron
����  ��������ٿ����ӿ�
����  ����
����ֵ����
]]
function repwron()
  return rtos.repoweron()
end

--[[
��������poweroff
����  ���ػ��ӿ�
����  ��
    r���ػ�ԭ��
����ֵ����
]]
function poweroff(r)
	base.print("sys poweroff:",r)
	if r then appenderr("poweroff["..r.."];") end
	rtos.poweroff()
end

--[[
��������isPwronCharger
����  ���ж��Ƿ�Ϊ���������
����  ����
����ֵ��true,�����������false,�ǳ����������
]]
function isPwronCharger()
  return rtos.poweron_reason() == rtos.POWERON_CHARGER
end

--[[
��������setPwronCharger
����  �����ÿ�����ʶ
����  ��
  has ��ʶ
����ֵ����
]]
function setPwrFlag(has)
  hasPwrKey = has
end

--[[
��������getPwrFlag
����  ����ÿ�����ʶ
����  ����
����ֵ��true,����������false,�ǰ���������
]]
function getPwrFlag()
  return hasPwrKey
end

--[[
��������init
����  ��luaӦ�ó����ʼ��
����  ��
		mode����翪���Ƿ�����GSMЭ��ջ
		lprfnc���û�Ӧ�ýű��ж���ġ��͵�ػ���������������к���������͵�ʱ�����ļ��е�run�ӿڲ���ִ���κζ��������򣬻���ʱ1�����Զ��ػ�
����ֵ����
]]
function init(mode,lprfnc)
	--�û�Ӧ�ýű��б��붨��PROJECT��VERSION����ȫ�ֱ����������������������ζ�����ο�����demo�е�main.lua
	assert(base.PROJECT and base.PROJECT ~= "" and base.VERSION and base.VERSION ~= "","Undefine PROJECT or VERSION")
	require"net"
	require"keypad"
	--����AT��������⴮��
	uart.setup(uart.ATC,0,0,uart.PAR_NONE,uart.STOP_1)
	--��LDO_VIB����Դ���߹���
	pmd.ldoset(1,pmd.LDO_VIB)
	print("init mode :",mode,lprfnc)
	print("poweron reason:",rtos.poweron_reason(),base.PROJECT,base.VERSION,SCRIPT_LIB_VER,CORE_MIN_VER,getcorever())

	-- ģʽ0 ����������ӿ�������ע������
	if mode==0 then setPwrFlag(rtos.poweron_reason() ~= rtos.POWERON_CHARGER) end
	
	-- ģʽ1 ����������ӿ�����ע������
	if mode == 1 then
		if rtos.poweron_reason() == rtos.POWERON_CHARGER 
			or rtos.poweron_reason() == rtos.POWERON_ALARM  then
			rtos.repoweron()
		end
	--ģʽ2 ���������ע�����磬���ӿ�����ע������
	elseif  mode == 2 then
		if rtos.poweron_reason() == rtos.POWERON_CHARGER then
			rtos.repoweron()
		end
	--ģʽ2 ���ӿ���ע�����磬�����������ע������
	elseif  mode == 3 then
		if rtos.poweron_reason() == rtos.POWERON_ALARM  then
			rtos.repoweron()
		end
	end
	--������ڽű����д����ļ������ļ�����ӡ������Ϣ
	local f = io.open("/luaerrinfo.txt","r")
	if f then
		print(f:read("*a") or "")
		f:close()
	end
	--�����û�Ӧ�ýű��ж���ġ��͵�ػ���������
	lprfun = lprfnc
	initerr()
	checkcorever()
	pm.wake("sys.lua.daemon")
	pm.sleep("sys.lua.daemon")
end

--[[
��������poweron
����  ������GSMЭ��ջ�������ڳ�翪��δ����GSMЭ��ջ״̬�£�����û�������������������ʱ���ô˽ӿ�����GSMЭ��ջ����
����  ����
����ֵ����
]]
function poweron()
	rtos.poweron(1)
end

--[[
��������setworkmode
����  �����ù���ģʽ
����  ��
		v������ģʽ
����ֵ���ɹ�����true�����򷵻�nil
]]
function setworkmode(v)
	if workmode~=v and (v==SIMPLE_MODE or v==FULL_MODE) then
		workmode = v
		--����һ������ģʽ�仯���ڲ���Ϣ"SYS_WORKMODE_IND"
		dispatch("SYS_WORKMODE_IND")
		return true
	end
end

--[[
��������getworkmode
����  ����ȡ����ģʽ
����  ����
����ֵ����ǰ����ģʽ
]]
function getworkmode()
	return workmode
end

--[[
��������opntrace
����  ���������߹ر�print�Ĵ�ӡ�������
����  ��
		v��false��nilΪ�رգ�����Ϊ����
		uartid�����Luatrace�Ķ˿ڣ�nil��ʾhost�ڣ�1��ʾuart1,2��ʾuart2
		baudrate��number���ͣ�uartid��Ϊnilʱ���˲����������壬��ʾ�����ʣ�Ĭ��115200
				  ��֧��1200,2400,4800,9600,14400,19200,28800,38400,57600,76800,115200,230400,460800,576000,921600,1152000,4000000
����ֵ����
]]
function opntrace(v,uartid,baudrate)
	if uartid then
		if v then
			uart.setup(uartid,baudrate or 115200,8,uart.PAR_NONE,uart.STOP_1)
		else
			uart.close(uartid)
		end
	end
	rtos.set_trace(v and 1 or 0,uartid)
end

--app�洢��
local apps = {}

--[[
��������regapp
����  ��ע��app
����  ���ɱ������app�Ĳ�����������������ʽ��
		�Ժ�����ʽע���app������regapp(fncname,"MSG1","MSG2","MSG3")
		��table��ʽע���app������regapp({MSG1=fnc1,MSG2=fnc2,MSG3=fnc3})
����ֵ����
]]
function regapp(...)
	local app = arg[1]
	--table��ʽ
	if type(app) == "table" then
	--������ʽ
	elseif type(app) == "function" then
		app = {procer = arg[1],unpack(arg,2,arg.n)}
	else
		error("unknown app type "..type(app),2)
	end
	--����һ������app���ڲ���Ϣ
	dispatch("SYS_ADD_APP",app)
	return app
end

--[[
��������deregapp
����  ����ע��app
����  ��
		id��app��id��id�������ַ�ʽ��һ���Ǻ���������һ����table��
����ֵ����
]]
function deregapp(id)
	--����һ���Ƴ�app���ڲ���Ϣ
	dispatch("SYS_REMOVE_APP",id)
end


--[[
��������addapp
����  ������app
����  ��
		app��ĳ��app��������������ʽ��
		     ������Ժ�����ʽע���app������regapp(fncname,"MSG1","MSG2","MSG3"),����ʽΪ��{procer=arg[1],"MSG1","MSG2","MSG3"}
			 �������table��ʽע���app������regapp({MSG1=fnc1,MSG2=fnc2,MSG3=fnc3}),����ʽΪ{MSG1=fnc1,MSG2=fnc2,MSG3=fnc3}
����ֵ����
]] 
local function addapp(app)
	-- ����β��
	table.insert(apps,#apps+1,app)
end

--[[
��������removeapp
����  ���Ƴ�app
����  ��
		id��app��id��id�������ַ�ʽ��һ���Ǻ���������һ����table��
����ֵ����
]] 
local function removeapp(id)
	--����app��
	for k,v in ipairs(apps) do
		--app��id����Ǻ�����
		if type(id) == "function" then
			if v.procer == id then
				table.remove(apps,k)
				return
			end
		--app��id�����table��
		elseif v == id then
			table.remove(apps,k)
			return
		end
	end
end

--[[
��������callapp
����  �������ڲ���Ϣ
		ͨ������ÿ��app���д���
����  ��
		msg����Ϣ
����ֵ����
]] 
local function callapp(msg)
	local id = msg[1]
	--����app��Ϣ
	if id == "SYS_ADD_APP" then
		addapp(unpack(msg,2,#msg))
	--�Ƴ�app��Ϣ
	elseif id == "SYS_REMOVE_APP" then
		removeapp(unpack(msg,2,#msg))
	else
		local app
		--����app��
		for i=#apps,1,-1 do
			app = apps[i]
			--����ע�᷽ʽ��app,����Ϣid֪ͨ
			if app.procer then 
				for _,v in ipairs(app) do
					if v == id then
						--�����Ϣ�Ĵ�����û�з���true�������Ϣ�������ڽ���������һֱ����app
						if app.procer(unpack(msg)) ~= true then
							return
						end
					end
				end
			--tableע�᷽ʽ��app,������Ϣid֪ͨ
			elseif app[id] then 
				--�����Ϣ�Ĵ�����û�з���true�������Ϣ�������ڽ���������һֱ����app
				if app[id](unpack(msg,2,#msg)) ~= true then
					return
				end
			end
		end
	end
end

--�ڲ���Ϣ����
local qmsg = {}

--[[
��������dispatch
����  �������ڲ���Ϣ���洢���ڲ���Ϣ������
����  ���ɱ�������û��Զ���
����ֵ����
]] 
function dispatch(...)
	table.insert(qmsg,arg)
end

--[[
��������getmsg
����  ����ȡ�ڲ���Ϣ
����  ����
����ֵ���ڲ���Ϣ�����еĵ�һ����Ϣ���������򷵻�nil
]] 
local function getmsg()
	if #qmsg == 0 then
		return nil
	end

	return table.remove(qmsg,1)
end

--[[
��������runqmsg
����  �������ڲ���Ϣ
����  ����
����ֵ����
]] 
local function runqmsg()
	local inmsg
	while true do
		--��ȡ�ڲ���Ϣ
		inmsg = getmsg()
		--�ڲ���ϢΪ��
		if  inmsg == nil then 
			--��Ҫˢ�½���
			if refreshflag == true then
				refreshflag=false
				--����һ������ˢ���ڲ���Ϣ
				inmsg={"UIWND_UPDATE"}
			else
				break
			end
		end
		--�����ڲ���Ϣ
		callapp(inmsg)
	end
end

--������ʱ����Ϣ����������Ϣ��������ⲿ��Ϣ������AT��������⴮�����ݽ�����Ϣ����Ƶ��Ϣ����������Ϣ��������Ϣ�ȣ����Ĵ�������
local handlers = {}
base.setmetatable(handlers,{__index = function() return function() end end,})

--[[
��������regmsg
����  ��ע�ᡰ����ʱ����Ϣ����������Ϣ��������ⲿ��Ϣ������AT��������⴮�����ݽ�����Ϣ����Ƶ��Ϣ����������Ϣ��������Ϣ�ȣ����Ĵ�����
����  ��
		id����Ϣ����id
		handler����Ϣ������
����ֵ����
]] 
function regmsg(id,handler)
	if not id then return end
	handlers[id] = handler
end

--���������ڵ����ݽ��մ�������
local uartprocs = {}

--[[
��������reguart
����  ��ע�������ڵ����ݽ��մ�����
����  ��
		id�������ںţ�1��ʾUART1��2��ʾUART2
		fnc�����ݽ��մ�������
����ֵ����
]] 
function reguart(id,fnc)
	uartprocs[id-1] = fnc
end

--[[
��������run
����  ��luaӦ�ó������п�����
����  ����
����ֵ����

���п�ܻ�����Ϣ������ƣ�Ŀǰһ��������Ϣ���ڲ���Ϣ���ⲿ��Ϣ
�ڲ���Ϣ��lua�ű����ñ��ļ�dispatch�ӿڲ�������Ϣ����Ϣ�洢��qmsg����
�ⲿ��Ϣ���ײ�core�����������Ϣ��lua�ű�ͨ��rtos.receive�ӿڶ�ȡ��Щ�ⲿ��Ϣ
]] 
function run()
	local msg,v1,v2,v3,v4

	while true do
		--�����ڲ���Ϣ
		runqmsg()
		--������ȡ�ⲿ��Ϣ
		msg,v1,v2,v3,v4 = rtos.receive(rtos.INF_TIMEOUT)
		if msg then watchdog.kick() end

		--��ص���Ϊ0%���û�Ӧ�ýű���û�ж��塰�͵�ػ�������򡱣�����û�������Զ��ػ���ʱ��		
		if not lprfun and not lpring and type(msg) == "table" and msg.id == rtos.MSG_PMD and msg.level == 0 then
			--�����Զ��ػ���ʱ����60���ػ�
			lpring = true
			timer_start(poweroff,60000,"r1")
		end
		
		--�ⲿ��ϢΪtable����
		if type(msg) == "table" then
			--��ʱ��������Ϣ
			if msg.id == rtos.MSG_TIMER then
				timerfnc(msg.timer_id)
			--AT��������⴮�����ݽ�����Ϣ
			elseif msg.id == rtos.MSG_UART_RXDATA and msg.uart_id == uart.ATC then
				handlers.atc()
			else
				--���������ݽ�����Ϣ
				if msg.id == rtos.MSG_UART_RXDATA then
					if uartprocs[msg.uart_id] ~= nil then
						uartprocs[msg.uart_id]()
					else
						handlers[msg.id](msg)
					end
				--������Ϣ����Ƶ��Ϣ����������Ϣ��������Ϣ�ȣ�
				else
					handlers[msg.id](msg)
				end
			end
		--�ⲿ��Ϣ��table����
		elseif type(msg) == "number" then
			--��ʱ��������Ϣ
			if msg == rtos.MSG_TIMER then
				timerfnc(v1)
			elseif msg == rtos.MSG_ALARM then
				--print("ZHY rtos.MSG_ALARM",msg,rtos.MSG_ALARM,type(msg))
				handlers[msg](msg)
			elseif msg == rtos.MSG_UART_RXDATA then
				--AT��������⴮��
				if v1 == uart.ATC then
					handlers.atc()
				--������
				else
					if uartprocs[v1] ~= nil then
						uartprocs[v1]()
					else
						handlers[msg](msg,v1)
					end
				end
			elseif msg >= rtos.MSG_PDP_ACT_CNF and msg <= rtos.MSG_SOCK_CLOSE_IND then
				handlers.sock(msg,v1,v2,v3,v4)
			else
				if handlers[msg] then
					handlers[msg](v1,v2,v3,v4)
				end
			end
		end
		--��ӡlua�ű�����ռ�õ��ڴ棬��λ��K�ֽ�
		--print("mem:",base.collectgarbage("count"))
	end
end

local DIR,DIR2 = "/EPO_GR_3_","/QG_R_"
function removegpsdat()
	--timer_stop(removegpsdat)
	--timer_start(removegpsdat,3600*1000)
	for i = 0,10 do
		--print("removegpsdat",i,DIR..i..".DAT")
		os.remove(DIR..i..".DAT")
	end
	for i = 0,4 do
		os.remove(DIR2..i..".DAT")		
	end
end

