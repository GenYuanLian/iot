--[[
ģ�����ƣ��������
ģ�鹦�ܣ��źŲ�ѯ��GSM����״̬��ѯ������ָʾ�ƿ��ơ��ٽ�С����Ϣ��ѯ
ģ������޸�ʱ�䣺2017.02.17
]]

--����ģ��,����������
local base = _G
local string = require"string"
local sys = require "sys"
local ril = require "ril"
local pio = require"pio"
require"sim"
module("net")

--���س��õ�ȫ�ֺ���������
local dispatch = sys.dispatch
local req = ril.request
local smatch = string.match
local tonumber,tostring,print = base.tonumber,base.tostring,base.print

--GSM����״̬��
--INIT��������ʼ���е�״̬
--REGISTERED��ע����GSM����
--UNREGISTER��δע����GSM����
local state,cengset = "INIT"
--SIM��״̬��trueΪ�쳣��false����nilΪ����
local simerrsta

--lac��λ����ID
--ci��С��ID
--rssi���ź�ǿ��
local lac,ci,rssi = "","",0

--csqqrypriod���ź�ǿ�ȶ�ʱ��ѯ���
local csqqrypriod = 60*1000

--cellinfo����ǰС�����ٽ�С����Ϣ��
--flymode���Ƿ��ڷ���ģʽ
--pwrkeymode���Ƿ�Ϊ��Դ������
--csqswitch����ʱ��ѯ�ź�ǿ�ȿ���
--multicellcb����ȡ��С���Ļص�����
local cellinfo,flymode,pwrkeymode,csqswitch,multicellcb = {}

--ledstate������ָʾ��״̬INIT,FLYMODE,SIMERR,IDLE,CREG,CGATT,SCK
--INIT�����ܹر�״̬
--FLYMODE������ģʽ
--SIMERR��δ��⵽SIM������SIM����pin����쳣
--IDLE��δע��GSM����
--CREG����ע��GSM����
--CGATT���Ѹ���GPRS��������
--SCK���û�socket�������Ϻ�̨
--ledontime��ָʾ�Ƶ���ʱ��(����)
--ledofftime��ָʾ��Ϩ��ʱ��(����)
--usersckconnect���û�socket�Ƿ������Ϻ�̨
local ledstate,ledontime,ledofftime,usersckconnect = "INIT",0,0
--[[
ledflg������ָʾ�ƿ���
ledpin������ָʾ�ƿ�������
ledvalid������������ֵ�ƽ�����ָʾ�ƣ�1Ϊ�ߣ�0Ϊ��
]]
local ledflg,ledpin,ledvalid=false,pio.P1_3,1
--[[
1) �������������δ������Դ��������
2) ����ģʽ������
ledflymodeon,ledflymodeoff
3) δ��⵽SIM������0.3�룬��5.7��
ledsimerron,ledsimerroff
4) ��⵽SIM����δע����GSM���磺��0.3�룬��3.7��
ledidleon,ledidleoff   IDLE״̬��ָʾ�Ƶĵ�����Ϩ��ʱ��(����)
5) ע����GSM���磬δ������GPRS���磺��0.3�룬��0.7��
ledcregon,ledcregoff   CREG״̬��ָʾ�Ƶĵ�����Ϩ��ʱ��(����)
6) ������GPRS���磬δ�����Ϸ���������0.3�룬��1.7��
ledcgatton,ledcgattoff CGATT״̬��ָʾ�Ƶĵ�����Ϩ��ʱ��(����)
7) �����Ϸ���������0.1�룬��0.1��
ledsckon,ledsckoff     SCK״̬��ָʾ�Ƶĵ�����Ϩ��ʱ��(����)
]]
local ledflymodeon,ledflymodeoff,ledsimerron,ledsimerroff,ledidleon,ledidleoff,ledcregon,ledcregoff,ledcgatton,ledcgattoff,ledsckon,ledsckoff = 0,0xFFFF,300,5700,300,3700,300,1700,300,700,100,100

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������testǰ׺
����  ����
����ֵ����
]]
local function print(...)
  base.print("net",...)
end

--[[
��������ledblinkflush
����  ����������ָʾ�ƿ�/��
����  ��
  on trueָʾ�Ƶ�����falseָʾ��Ϩ��
����ֵ����
]]
local function ledblinkflush(on)
  pio.pin.setdir(pio.OUTPUT,ledpin)
  if on then
    --���������ƽ����ָʾ�Ƶ���
    pio.pin.setval(ledvalid==1 and 1 or 0,ledpin)
  else
    --���������ƽ����ָʾ��Ϩ��
    pio.pin.setval(ledvalid==1 and 0 or 1,ledpin)
  end
end

--[[
��������creg
����  ������CREG��Ϣ
����  ��
		data��CREG��Ϣ�ַ���������+CREG: 2��+CREG: 1,"18be","93e1"��+CREG: 5,"18a7","cb51"
����ֵ����
]]
local function creg(data)
	local p1,s
	--��ȡע��״̬
	_,_,p1 = string.find(data,"%d,%s*(%d)")
	if p1 == nil then
		_,_,p1 = string.find(data,"(%d)")
		if p1 == nil then
			return
		end
	end
	--��ע��
	if p1 == "1" or p1 == "5" then
		s = "REGISTERED"
	--δע��
	else
		s = "UNREGISTER"
	end
	--ע��״̬�����˸ı�
	if s ~= state then
		state = s
		--����һ���ڲ���ϢNET_STATE_CHANGED����ʾGSM����ע��״̬�����仯
		dispatch("NET_STATE_CHANGED",s)
		--ָʾ�ƿ���
		procled()
	end
	--��ע�Ტ��lac��ci�����˱仯
	if state == "REGISTERED" then
		local p2,p3 = string.match(data,"\"(%x+)\",%s*\"(%x+)\"")
		if lac ~= p2 or ci ~= p3 then
			lac = p2
			ci = p3
			--����һ���ڲ���ϢNET_CELL_CHANGED����ʾlac��ci�����˱仯
			dispatch("NET_CELL_CHANGED")
		end
		if not cengset then
			cengset = true
			req("AT+CENG=1")
		end
	end
end

--[[
��������resetcellinfo
����  �����õ�ǰС�����ٽ�С����Ϣ��
����  ����
����ֵ����
]]
local function resetcellinfo()
	local i
	cellinfo.cnt = 11 --������
	for i=1,cellinfo.cnt do
		cellinfo[i] = {}
		cellinfo[i].mcc,cellinfo[i].mnc = nil
		cellinfo[i].lac = 0
		cellinfo[i].ci = 0
		cellinfo[i].rssi = 0
		cellinfo[i].ta = 0
	end
end

--[[
��������ceng
����  ��������ǰС�����ٽ�С����Ϣ
����  ��
		data����ǰС�����ٽ�С����Ϣ�ַ��������������е�ÿһ�У�
		+CENG:1,1
		+CENG:0,"573,24,99,460,0,13,49234,10,0,6311,255"
		+CENG:1,"579,16,460,0,5,49233,6311"
		+CENG:2,"568,14,460,0,26,0,6311"
		+CENG:3,"584,13,460,0,10,0,6213"
		+CENG:4,"582,13,460,0,51,50146,6213"
		+CENG:5,"11,26,460,0,3,52049,6311"
		+CENG:6,"29,26,460,0,32,0,6311"
����ֵ����
]]
local function ceng(data)
	--ֻ������Ч��CENG��Ϣ
	if string.find(data,"%+CENG:%d+,.+") then
		local id,rssi,lac,ci,ta,mcc,mnc
		id = string.match(data,"%+CENG:(%d)")
		id = tonumber(id)
		mcc,mnc,lac,ci,rssi=string.match(data, "%+CENG:%d,(%w+),(%d+),(%d+),(%d+),%d+,(%d+)")

		--������ȷ
		if rssi and ci and lac and mcc and mnc then
			--����ǵ�һ���������Ϣ��
			if id == 0 then
				resetcellinfo()
			end
			--����mcc��mnc��lac��ci��rssi��ta
			cellinfo[id+1].mcc = tostring(tonumber(mcc,16))
			cellinfo[id+1].mnc = mnc
			cellinfo[id+1].lac = tonumber(lac)
			cellinfo[id+1].ci = tonumber(ci)
			cellinfo[id+1].rssi = ((tonumber(rssi) == 99) and 0 or tonumber(rssi))/2
			cellinfo[id+1].ta = tonumber(ta or "0")
			--����һ���ڲ���ϢCELL_INFO_IND����ʾ��ȡ�����µĵ�ǰС�����ٽ�С����Ϣ
			if id == 0 then
				dispatch("CELL_INFO_IND",cellinfo)
			end
		end
	end
end

--[[
��������neturc
����  ��������ģ���ڡ�ע��ĵײ�coreͨ�����⴮�������ϱ���֪ͨ���Ĵ���
����  ��
		data��֪ͨ�������ַ�����Ϣ
		prefix��֪ͨ��ǰ׺
����ֵ����
]]
local function neturc(data,prefix)
	if prefix == "+CREG" then
		--�յ�����״̬�仯ʱ,����һ���ź�ֵ
		csqquery()
		--����creg��Ϣ
		creg(data)
	elseif prefix == "+CENG" then
		--����ceng��Ϣ
		ceng(data)
	end
end

--[[
��������getstate
����  ����ȡGSM����ע��״̬
����  ����
����ֵ��GSM����ע��״̬(INIT��REGISTERED��UNREGISTER)
]]
function getstate()
	return state
end

--[[
��������getmcc
����  ����ȡ��ǰС����mcc
����  ����
����ֵ����ǰС����mcc�������û��ע��GSM���磬�򷵻�sim����mcc
]]
function getmcc()
	return cellinfo[1].mcc or sim.getmcc()
end

--[[
��������getmnc
����  ����ȡ��ǰС����mnc
����  ����
����ֵ����ǰС����mnc�������û��ע��GSM���磬�򷵻�sim����mnc
]]
function getmnc()
	return cellinfo[1].mnc or sim.getmnc()
end

--[[
��������getlac
����  ����ȡ��ǰλ����ID
����  ����
����ֵ����ǰλ����ID(16�����ַ���������"18be")�������û��ע��GSM���磬�򷵻�""
]]
function getlac()
	return lac
end

--[[
��������getci
����  ����ȡ��ǰС��ID
����  ����
����ֵ����ǰС��ID(16�����ַ���������"93e1")�������û��ע��GSM���磬�򷵻�""
]]
function getci()
	return string.sub(ci,-4)
end

--[[
��������getrssi
����  ����ȡ�ź�ǿ��
����  ����
����ֵ����ǰ�ź�ǿ��(ȡֵ��Χ0-31)
]]
function getrssi()
	return rssi
end

--[[
��������getcell
����  ����ȡ��ǰ���ٽ�С���Լ��ź�ǿ�ȵ�ƴ���ַ���
����  ����
����ֵ����ǰ���ٽ�С���Լ��ź�ǿ�ȵ�ƴ���ַ��������磺49234.30.49233.23.49232.18.
]]
function getcell()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].ci.."."..cellinfo[i].rssi.."."
		end
	end
	return ret
end

--[[
��������getcellinfo
����  ����ȡ��ǰ���ٽ�λ������С���Լ��ź�ǿ�ȵ�ƴ���ַ���
����  ����
����ֵ����ǰ���ٽ�λ������С���Լ��ź�ǿ�ȵ�ƴ���ַ��������磺6311.49234.30;6311.49233.23;6322.49232.18;
]]
function getcellinfo()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].lac.."."..cellinfo[i].ci.."."..cellinfo[i].rssi..";"
		end
	end
	return ret
end

--[[
��������getcellinfoext
����  ����ȡ��ǰ���ٽ�λ������С����mcc��mnc���Լ��ź�ǿ�ȵ�ƴ���ַ���
����  ����
����ֵ����ǰ���ٽ�λ������С����mcc��mnc���Լ��ź�ǿ�ȵ�ƴ���ַ��������磺460.01.6311.49234.30;460.01.6311.49233.23;460.02.6322.49232.18;
]]
function getcellinfoext()
	local i,ret = 1,""
	for i=1,cellinfo.cnt do
		if cellinfo[i] and cellinfo[i].mcc and cellinfo[i].mnc and cellinfo[i].lac and cellinfo[i].lac ~= 0 and cellinfo[i].ci and cellinfo[i].ci ~= 0 then
			ret = ret..cellinfo[i].mcc.."."..cellinfo[i].mnc.."."..cellinfo[i].lac.."."..cellinfo[i].ci.."."..cellinfo[i].rssi..";"
		end
	end
	return ret
end

--[[
��������getta
����  ����ȡTAֵ
����  ����
����ֵ��TAֵ
]]
function getta()
	return cellinfo[1].ta
end

--[[
��������startquerytimer
����  ���պ������޹��ܣ�ֻ��Ϊ�˼���֮ǰд��Ӧ�ýű�
����  ����
����ֵ����
]]
function startquerytimer() end

--[[
��������simind
����  ���ڲ���ϢSIM_IND�Ĵ�����
����  ��
		para����������ʾSIM��״̬
����ֵ����
]]
local function simind(para)
	print("simind",simerrsta,para)
	if simerrsta ~= (para~="RDY") then
		simerrsta = (para~="RDY")
		procled()
	end
	--sim������������
	if para ~= "RDY" then
		--����GSM����״̬
		state = "UNREGISTER"
		--�����ڲ���ϢNET_STATE_CHANGED����ʾ����״̬�����仯
		dispatch("NET_STATE_CHANGED",state)
	end
	if para == "NIST" then
		sys.timer_stop(queryfun)
	end

	return true
end

--[[
��������flyind
����  ���ڲ���ϢFLYMODE_IND�Ĵ�����
����  ��
		para����������ʾ����ģʽ״̬��true��ʾ�������ģʽ��false��ʾ�˳�����ģʽ
����ֵ����
]]
local function flyind(para)
	--����ģʽ״̬�����仯
	if flymode~=para then
		flymode = para
		--��������ָʾ��
		procled()
	end
	--�˳�����ģʽ
	if not para then
		----�����ѯ��ʱ��
		startcsqtimer()
		startcengtimer()
		--��λGSM����״̬
		neturc("2","+CREG")
	end
	return true
end

--[[
��������pwrkeyind
����  ���ڲ���ϢPWRKEY_IND�Ĵ�����
����  ��
    para����������ʾ��Դ��״̬��true��ʾ��Դ��������false��ʾ�ǵ�Դ������
����ֵ����
]]
local function pwrkeyind(para,pressed)
  --������״̬�����仯
  if pwrkeymode~=para then
    pwrkeymode = para
    --��������ָʾ��
    setled(sys.getPwrFlag())
    ledblinkflush(true)
  end
end

--[[
��������workmodeind
����  ���ڲ���ϢSYS_WORKMODE_IND�Ĵ�����
����  ��
		para����������ʾϵͳ����ģʽ
����ֵ����
]]
local function workmodeind(para)
	--�����ѯ��ʱ��
	startcengtimer()
	startcsqtimer()
	return true
end

--[[
��������startcsqtimer
����  ����ѡ���Ե��������ź�ǿ�Ȳ�ѯ����ʱ��
����  ����
����ֵ����
]]
function startcsqtimer()
	--���Ƿ���ģʽ ���� (���˲�ѯ���� ���� ����ģʽΪ����ģʽ)
	if not flymode and (csqswitch or sys.getworkmode()==sys.FULL_MODE) then
		--����AT+CSQ��ѯ
		csqquery()
		--������ʱ��
		sys.timer_start(startcsqtimer,csqqrypriod)
	end
end

--[[
��������startcengtimer
����  ����ѡ���Ե���������ǰ���ٽ�С����Ϣ��ѯ����ʱ��
����  ����
����ֵ����
]]
function startcengtimer()
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
	local prefix = string.match(cmd,"AT(%+%u+)")

	if intermediate ~= nil then
		if prefix == "+CSQ" then
			local s = smatch(intermediate,"+CSQ:%s*(%d+)")
			if s ~= nil then
				rssi = tonumber(s)
				rssi = rssi == 99 and 0 or rssi
				--����һ���ڲ���ϢGSM_SIGNAL_REPORT_IND����ʾ��ȡ�����ź�ǿ��
				dispatch("GSM_SIGNAL_REPORT_IND",success,rssi)
			end
		elseif prefix == "+CENG" then
		end
	end
end

--[[
��������setcsqqueryperiod
����  �����á��ź�ǿ�ȡ���ѯ���
����  ��
		period����ѯ�������λ����
����ֵ����
]]
function setcsqqueryperiod(period)
	csqqrypriod = period
	startcsqtimer()
end

--[[
��������setcengqueryperiod
����  �����á���ǰ���ٽ�С����Ϣ����ѯ���
����  ��
		period����ѯ�������λ���롣���С�ڵ���0����ʾֹͣ��ѯ����
����ֵ����
]]
function setcengqueryperiod(period)
end

--[[
��������cengquery
����  ����ѯ����ǰ���ٽ�С����Ϣ��
����  ����
����ֵ����
]]
function cengquery()
end

--[[
��������setcengswitch
����  �����á���ǰ���ٽ�С����Ϣ����ѯ����
����  ��
		v��trueΪ����������Ϊ�ر�
����ֵ����
]]
function setcengswitch(v)
end

--[[
��������cellinfoind
����  ��CELL_INFO_IND��Ϣ�Ĵ�����
����  ����
����ֵ��������û��Զ���Ļ�ȡ���վ��Ϣ�Ļص��������򷵻�nil�����򷵻�true
]]
local function cellinfoind()
	if multicellcb then
		local cb = multicellcb
		multicellcb = nil
		cb(getcellinfoext())
	else
		return true
	end
end

--[[
��������getmulticell
����  ����ȡ����ǰ���ٽ�С����Ϣ��
����  ��
		cb���ص�����������ȡ��С����Ϣ�󣬻���ô˻ص�������������ʽΪcb(cells)������cellsΪstring���ͣ���ʽΪ��
		    ��ǰ���ٽ�λ������С����mcc��mnc���Լ��ź�ǿ�ȵ�ƴ���ַ��������磺460.01.6311.49234.30;460.01.6311.49233.23;460.02.6322.49232.18;
����ֵ���� 
]]
function getmulticell(cb)
	multicellcb = cb
	cengquery()
end

--[[
��������csqquery
����  ����ѯ���ź�ǿ�ȡ�
����  ����
����ֵ����
]]
function csqquery()
	--���Ƿ���ģʽ������AT+CSQ
	if not flymode then req("AT+CSQ",nil,nil,nil,{skip=true}) end
end

--[[
��������setcsqswitch
����  �����á��ź�ǿ�ȡ���ѯ����
����  ��
		v��trueΪ����������Ϊ�ر�
����ֵ����
]]
function setcsqswitch(v)
	csqswitch = v
	--�������Ҳ��Ƿ���ģʽ
	if v and not flymode then startcsqtimer() end
end

--[[
��������ledblinkon
����  ����������ָʾ��
����  ����
����ֵ����
]]
local function ledblinkon()
	--print("ledblinkon",ledstate,ledontime,ledofftime)
	--���������ƽ����ָʾ�Ƶ���
	pio.pin.setval(ledvalid==1 and 1 or 0,ledpin)
	--����
	if ledontime==0 and ledofftime==0xFFFF then
		ledblinkoff()
	--����
	elseif ledontime==0xFFFF and ledofftime==0 then
		--�رյ���ʱ����ʱ����Ϩ��ʱ����ʱ��
		sys.timer_stop(ledblinkon)
		sys.timer_stop(ledblinkoff)
	--��˸
	else
		--��������ʱ����ʱ������ʱ����֮��Ϩ��ָʾ��
		sys.timer_start(ledblinkoff,ledontime)
	end	
end

--[[
��������ledblinkoff
����  ��Ϩ������ָʾ��
����  ����
����ֵ����
]]
function ledblinkoff()
	--print("ledblinkoff",ledstate,ledontime,ledofftime)
	--���������ƽ����ָʾ��Ϩ��
	pio.pin.setval(ledvalid==1 and 0 or 1,ledpin)
	--����
	if ledontime==0 and ledofftime==0xFFFF then
		--�رյ���ʱ����ʱ����Ϩ��ʱ����ʱ��
		sys.timer_stop(ledblinkon)
		sys.timer_stop(ledblinkoff)
	--����
	elseif ledontime==0xFFFF and ledofftime==0 then
		ledblinkon()
	--��˸
	else
		--����Ϩ��ʱ����ʱ������ʱ����֮�󣬵���ָʾ��
		sys.timer_start(ledblinkon,ledofftime)
	end	
end

--[[
��������procled
����  ����������ָʾ��״̬�Լ�������Ϩ��ʱ��
����  ����
����ֵ����
]]
function procled()
  ledflg = sys.getPwrFlag()
	print("procled",ledflg,ledstate,flymode,usersckconnect,cgatt,state)
	--�������������ָʾ�ƹ���
	if ledflg then
		local newstate,newontime,newofftime = "IDLE",ledidleon,ledidleoff
		--����ģʽ
		if flymode then
			newstate,newontime,newofftime = "FLYMODE",ledflymodeon,ledflymodeoff
		elseif simerrsta then
			newstate,newontime,newofftime = "SIMERR",ledsimerron,ledsimerroff
		--�û�socket���ӵ��˺�̨
		elseif usersckconnect then
			newstate,newontime,newofftime = "SCK",ledsckon,ledsckoff
		--������GPRS��������
		elseif cgatt then
			newstate,newontime,newofftime = "CGATT",ledcgatton,ledcgattoff
		--ע����GSM����
		elseif state=="REGISTERED" then
			newstate,newontime,newofftime = "CREG",ledcregon,ledcregoff		
		end
		--ָʾ��״̬�����仯
		if newstate~=ledstate then
			ledstate,ledontime,ledofftime = newstate,newontime,newofftime
			ledblinkoff()
		end
	end
end

--[[
��������usersckind
����  ���ڲ���ϢUSER_SOCKET_CONNECT�Ĵ�����
����  ��
		v����������ʾ�û�socket�Ƿ������Ϻ�̨
����ֵ����
]]
local function usersckind(v)
	print("usersckind",v)
	if usersckconnect~=v then
		usersckconnect = v
		procled()
	end
end

--[[
��������cgattind
����  ���ڲ���ϢNET_GPRS_READY�Ĵ�����
����  ��
		v����������ʾ�Ƿ�����GPRS��������
����ֵ����
]]
local function cgattind(v)
	print("cgattind",v)
	if cgatt~=v then
		cgatt = v
		procled()
	end
end

--[[
��������setled
����  ����������ָʾ�ƹ���
����  ��
		v��ָʾ�ƿ��أ�trueΪ����������Ϊ�ر�
		pin��ָʾ�ƿ������ţ���ѡ
		valid������������ֵ�ƽ�����ָʾ�ƣ�1Ϊ�ߣ�0Ϊ�ͣ���ѡ
		flymodeon,flymodeoff,simerron,simerroff,idleon,idleoff,cregon,cregoff,cgatton,cgattoff,sckon,sckoff��FLYMODE,SIMERR,IDLE,CREG,CGATT,SCK״̬��ָʾ�Ƶĵ�����Ϩ��ʱ��(����)����ѡ
����ֵ����
]]
function setled(v,pin,valid,flymodeon,flymodeoff,simerron,simerroff,idleon,idleoff,cregon,cregoff,cgatton,cgattoff,sckon,sckoff)
	local c1 = (ledflg~=v or ledpin~=(pin or ledpin) or ledvalid~=(valid or ledvalid))
	local c2 = (ledidleon~=(idleon or ledidleon) or ledidleoff~=(idleoff or ledidleoff) or flymodeon~=(flymodeon or ledflymodeon) or flymodeoff~=(flymodeoff or ledflymodeoff))
	local c3 = (ledcregon~=(cregon or ledcregon) or ledcregoff~=(cregoff or ledcregoff) or ledcgatton~=(cgatton or ledcgatton) or simerron~=(simerron or ledsimerron))
	local c4 = (ledcgattoff~=(cgattoff or ledcgattoff) or ledsckon~=(sckon or ledsckon) or ledsckoff~=(sckoff or ledsckoff) or simerroff~=(simerroff or ledsimerroff))
	--����ֵ�����仯 �����������������仯
	if c1 or c2 or c3 or c4 then
		local oldledflg = ledflg
		ledflg = v
		--����
		if v then
			ledpin,ledvalid,ledidleon,ledidleoff,ledcregon,ledcregoff = pin or ledpin,valid or ledvalid,idleon or ledidleon,idleoff or ledidleoff,cregon or ledcregon,cregoff or ledcregoff
			ledcgatton,ledcgattoff,ledsckon,ledsckoff = cgatton or ledcgatton,cgattoff or ledcgattoff,sckon or ledsckon,sckoff or ledsckoff
			ledflymodeon,ledflymodeoff,ledsimerron,ledsimerroff = flymodeon or ledflymodeon,flymodeoff or ledflymodeoff,simerron or ledsimerron,simerroff or ledsimerroff
			if not oldledflg then pio.pin.setdir(pio.OUTPUT,ledpin) end
			procled()
		--�ر�
		else
			sys.timer_stop(ledblinkon)
			sys.timer_stop(ledblinkoff)
			if oldledflg then
				pio.pin.setval(ledvalid==1 and 0 or 1,ledpin)
				pio.pin.close(ledpin)
			end
			ledstate = "INIT"
		end		
	end
end

--��ģ���ע���ڲ���Ϣ��������
local procer =
{
	SIM_IND = simind,
	FLYMODE_IND = flyind,
	PWRKEY_IND = pwrkeyind,
	SYS_WORKMODE_IND = workmodeind,
	USER_SOCKET_CONNECT = usersckind,
	NET_GPRS_READY = cgattind,
	CELL_INFO_IND = cellinfoind,
}
--ע����Ϣ��������
sys.regapp(procer)
--ע��+CREG��+CENG֪ͨ�Ĵ�����
ril.regurc("+CREG",neturc)
ril.regurc("+CENG",neturc)
ril.regurc("+CPIN",neturc)
--ע��AT+CCSQ�����Ӧ������
ril.regrsp("+CSQ",rsp)
--����AT����
req("AT+CREG=2")
req("AT+CREG?")
--req("AT+CENG=1")
-- 8����ѯ��һ��csq
sys.timer_start(startcsqtimer,8*1000)
resetcellinfo()
setled(sys.getPwrFlag())
