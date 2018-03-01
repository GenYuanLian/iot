--[[
ģ�����ƣ�AGPS��ȫ��Assisted Global Positioning System��GPS������λ����(��������u-blox��GPSģ��)
ģ�鹦�ܣ�����AGPS��̨������GPS�������ݣ�д��GPSģ�飬����GPS��λ
ģ������޸�ʱ�䣺2017.02.20
]]

--[[
�����Ϻ�̨��Ӧ�ò�Э�飺
1������AGPS����̨
2����̨�ظ�AGPSUPDATE,total,last,sum1,sum2,sum3,......,sumn
   total�������ܸ���
   last�����һ�������ֽ���
   sum1����һ�������ݵ�У���
   sum2���ڶ��������ݵ�У���
   sum3�������������ݵ�У���
   ......
   sumn����n�������ݵ�У���
3������Getidx
   idx�ǰ�����������Χ��1---total
   ���磺���������ļ�Ϊ4000�ֽڣ�
   Get1
   Get2
   Get3
   Get4
4����̨�ظ�ÿ����������
   ��һ���ֽں͵ڶ����ֽڣ�Ϊ�������������
   ��������Ϊ��������
]]

--����ģ��,����������
local base = _G
local table = require"table"
local lpack = require"pack"
local rtos = require"rtos"
local sys = require"sys"
local string = require"string"
local link = require"link"
local misc = require"misc"
local net = require"net"
local gps = require"gps"
local bit = require"bit"
module(...,package.seeall)

--���س��õ�ȫ�ֺ���������
local print,tonumber,fly = base.print,base.tonumber,base.fly
local sfind,slen,ssub,sbyte,sformat,smatch,sgsub,schar,srep = string.find,string.len,string.sub,string.byte,string.format,string.match,string.gsub,string.char,string.rep
local send,dispatch = link.send,sys.dispatch

--[[
lid��socket id
isfix��GPS�Ƿ�λ�ɹ�
agpsop: �Ƿ��agps
]]
local lid,isfix,agpsop
--[[
ispt���Ƿ���AGPS����
itv������AGPS��̨�������λ�룬Ĭ��2Сʱ����ָ2Сʱ����һ��AGPS��̨������һ����������
PROT,SVR,PORT��AGPS��̨�����Э�顢��ַ���˿�
WRITE_INTERVAL��ÿ���������ݰ�д��GPSģ��ļ������λ����
]]
local ispt,itv,PROT,SVR,PORT,WRITE_INTERVAL = true,(2*3600),"UDP","bs.openluat.com",12412,100
--[[
mode��AGPS���ܹ���ģʽ�����������֣�Ĭ��Ϊ0��
  0���Զ����Ӻ�̨�������������ݡ�д��GPSģ��
  1����Ҫ���Ӻ�̨ʱ�������ڲ���ϢAGPS_EVT���û������������Ϣ�����Ƿ���Ҫ���ӣ������������ݣ�д��GPSģ��󣬽���������ڲ���ϢAGPS_EVT��֪ͨ�û����ؽ����д����
pwrcb:�����ص�����
]]
local mode,pwrcb = 0
--[[
gpssupport���Ƿ���GPSģ��
eph����AGPS��̨���ص���������
]]
local gpssupport,eph = true,""
--[[
GET_TIMEOUT��GET����ȴ�ʱ�䣬��λ����
ERROR_PACK_TIMEOUT�������(��ID���߳��Ȳ�ƥ��) ��һ��ʱ���������»�ȡ
GET_RETRY_TIMES��GET���ʱ���ߴ����ʱ����ǰ���������Ե�������
PACKET_LEN��ÿ����������ݳ��ȣ���λ�ֽ�
RETRY_TIMES�����Ӻ�̨���������ݹ��̽����󣬻�Ͽ����ӣ�����˴����ع���ʧ�ܣ�����������Ӻ�̨�����´�ͷ��ʼ���ء��������ָ���������������Ӻ�̨���ص�������
]]
local GET_TIMEOUT,ERROR_PACK_TIMEOUT,GET_RETRY_TIMES,PACKET_LEN,RETRY_TIMES = 10000,5000,3,1024,3
--[[
state��״̬��״̬
IDLE������״̬
CHECK������ѯ�������������ݡ�״̬
UPDATE�����������������С�״̬
total�������ܸ�����������������Ϊ10221�ֽڣ���total=(int)((10221+1021)/1022)=11;�����ļ�Ϊ10220�ֽڣ���total=(int)((10220+1021)/1022)=10
last�����һ�������ֽ��������������ļ�Ϊ10225�ֽڣ���last=10225%1022=5;�����ļ�Ϊ10220�ֽڣ���last=1022
checksum��ÿ�����������ݵ�У��ʹ洢��
packid����ǰ��������
getretries����ȡÿ�����Ѿ����ԵĴ���
retries���������Ӻ�̨���أ��Ѿ����ԵĴ���
reconnect���Ƿ���Ҫ������̨
]]
local state,total,last,checksum,packid,getretries,retries,reconnect = "IDLE",0,0,{},0,0,1,false

--[[
��������startupdatetimer
����  �����������Ӻ�̨�������������ݡ���ʱ��
����  ����
����ֵ����
]]
local function startupdatetimer()
	--֧��GPS����֧��AGPS
	if gpssupport and ispt then
		sys.timer_start(connect,itv*1000)
	end
end

--[[
��������gpsstateind
����  ������GPSģ����ڲ���Ϣ
����  ��
		id��gps.GPS_STATE_IND�����ô���
		data����Ϣ��������
����ֵ��true
]]
local function gpsstateind(id,data)
	--GPS��λ�ɹ�
	if data == gps.GPS_LOCATION_SUC_EVT or data == gps.GPS_LOCATION_UNFILTER_SUC_EVT then
		sys.dispatch("AGPS_UPDATE_SUC")
		startupdatetimer()
		isfix = true
		setsucstr()
	--GPS��λʧ�ܻ���GPS�ر�
	elseif data == gps.GPS_LOCATION_FAIL_EVT or data == gps.GPS_CLOSE_EVT then
		isfix = false
	--û��GPSоƬ
	elseif data == gps.GPS_NO_CHIP_EVT then
		gpssupport = false
	end
	return true
end

--[[
��������calsum
����  ������У���
����  ��
		str��Ҫ����У��͵�����
����ֵ��У���
]]
local function calsum(str)
	local sum,i = 0
	for i=1,slen(str) do
		sum = sum + sbyte(str,i)
	end
	return sum
end

--[[
��������errpack
����  �����������
����  ��
		str��Ҫ����У��͵�����
����ֵ��У���
]]
local function errpack()
	print("errpack")
	upend(false)
end

--[[
��������retry
����  �����Զ���
����  ��
		para�����ΪSTOP����ֹͣ���ԣ�����ִ������
����ֵ����
]]
function retry(para)
	if state ~= "UPDATE" and state ~= "CHECK" then
		return
	end

	if para == "STOP" then
		getretries = 0
		sys.timer_stop(errpack)
		sys.timer_stop(retry)
		return
	end

	if para == "ERROR_PACK" then
		sys.timer_start(errpack,ERROR_PACK_TIMEOUT)
		return
	end

	getretries = getretries + 1
	if getretries < GET_RETRY_TIMES then
		if state == "UPDATE" then
			-- δ�����Դ���,�������Ի�ȡ������
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
function reqget(idx)
	send(lid,sformat("Get%d",idx))
	sys.timer_start(retry,GET_TIMEOUT)
end

--[[
��������getpack
����  �������ӷ������յ���һ������
����  ��
		data��������
����ֵ����
]]
local function getpack(data)
	-- �жϰ������Ƿ���ȷ
	local len = slen(data)
	if (packid < total and len ~= PACKET_LEN) or (packid >= total and len ~= (last+2)) then
		print("getpack:len not match",packid,len,last)
		retry("ERROR_PACK")
		return
	end

	-- �жϰ�����Ƿ���ȷ
	local id = sbyte(data,1)*256 + sbyte(data,2)%256
	if id ~= packid then
		print("getpack:packid not match",id,packid)
		retry("ERROR_PACK")
		return
	end

	--�ж�У����Ƿ���ȷ
	local sum = calsum(ssub(data,3,-1))
	if checksum[id] ~= sum then
		print("getpack:checksum not match",checksum[id],sum)
		retry("ERROR_PACK")
		return
	end

	-- ֹͣ����
	retry("STOP")

	-- ����������
	eph = eph .. ssub(data,3,-1)

	-- ��ȡ��һ������
	if packid == total then
		sum = calsum(eph)
		if checksum[total+1] ~= sum then
			print("getpack:total checksum not match",checksum[total+1],sum)
			upend(false)
		else
			upend(true)
		end
	else
		packid = packid + 1
		reqget(packid)
	end
end

--[[
��������upbegin
����  �������������·�����������Ϣ
����  ��
		data����������Ϣ
����ֵ����
]]
local function upbegin(data)
	--���ĸ��������һ�����ֽ���
	local d1,d2,p1,p2 = sfind(data,"AGPSUPDATE,(%d+),(%d+)")
	local i
	if d1 and d2 and p1 and p2 then
		p1,p2 = tonumber(p1),tonumber(p2)
		total,last = p1,p2
		local tmpdata = data
		--ÿ���������ݵ�У���
		for i=1,total+1 do
			if d2+2 > slen(tmpdata) then
				upend(false)
				return false
			end
			tmpdata = ssub(tmpdata,d2+2,-1)
			d1,d2,p1 = sfind(tmpdata,"(%d+)")
			if d1 == nil or d2 == nil or p1 == nil then
				upend(false)
				return false
			end
			checksum[i] = tonumber(p1)
		end

		getretries,state,packid,eph = 0,"UPDATE",1,""
		--�����1��
		reqget(packid)
		return true
	end

	upend(false)
	return false
end

function writeapgs(str)
	print("writeapgs",str,slen(str))
	local A,tmp,s1,s2 = 65,0
	for i = 2,slen(str)-1 do
		tmp = bit.bxor(tmp,sbyte(str,i))
	end
	if bit.rshift(tmp,4) > 9 then
		s1 = schar(bit.rshift(tmp,4) - 10 + A)
	else
		s1 = bit.rshift(tmp,4) + '0'
	end

	if bit.band(tmp,0x0f) > 9 then
		s2 = schar(bit.band(tmp,0x0f) - 10 + A)
	else
		s2 = bit.band(tmp,0x0f) + '0'
	end
	str = str..s1..s2..'\13'..'\10'..'\0'
	print("writeapgs str",str,slen(str))
	gpscore.write(str)
end

local function agpswr()
	print("agpswr")
	local clkstr,s,i = os.date("*t")
	local clk = common.transftimezone(clkstr.year,clkstr.month,clkstr.day,clkstr.hour,clkstr.min,clkstr.sec,8,0)
	s = string.format("%0d,%02d,%02d,%02d,%02d,%02d",clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec)
	local str = getagpstr()
	if str then
		str = str..s..'*'
		writeapgs(str)
		gps.closegps("AGPS")
		sys.dispatch("AGPS_WRDATE_SUC")
	end
	return true
end

local function bcd(d,n)
	local l = slen(d or "")
	local num
	local t = {}

	for i=1,l,2 do
		num = tonumber(ssub(d,i,i+1),16)

		if i == l then
			num = 0xf0+num
		else
			num = (num%0x10)*0x10 + num/0x10
		end

		table.insert(t,num)
	end

	local s = string.char(base.unpack(t))

	l = slen(s)

	if l < n then
		s = s .. string.rep("\255",n-l)
	elseif l > n then
		s = ssub(s,1,n)
	end

	return s
end

local function encellinfo(s)
	local ret,t,mcc,mnc,lac,ci,rssi,k,v,m,n,cntrssi = "",{}
	print("syy encellinfo",s)
	for mcc,mnc,lac,ci,rssi in string.gmatch(s,"(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+);") do
		mcc,mnc,lac,ci,rssi = tonumber(mcc),tonumber(mnc),tonumber(lac),tonumber(ci),(tonumber(rssi) > 31) and 31 or tonumber(rssi)
		local handle = nil
		for k,v in pairs(t) do
			print("syy v.lac",v.lac,lac,v.mcc,mcc,v.mnc,mnc,#v.rssici)
			if v.lac == lac and v.mcc == mcc and v.mnc == mnc then
				if #v.rssici < 8 then
					table.insert(v.rssici,{rssi=rssi,ci=ci})
				end
				--handle = true
				break
			end
		end
		print("syy handle",handle)
		if not handle then
			table.insert(t,{mcc=mcc,mnc=mnc,lac=lac,rssici={{rssi=rssi,ci=ci}}})
		end
	end
	for k,v in pairs(t) do
		ret = ret .. lpack.pack(">HHb",v.lac,v.mcc,v.mnc)
		for m,n in pairs(v.rssici) do
			cntrssi = bit.bor(bit.lshift(((m == 1) and (#v.rssici-1) or 0),5),n.rssi)
			ret = ret .. lpack.pack(">bH",cntrssi,n.ci)
		end
	end

	return #t,string.char(#t)..ret
end

--[[
��������reqcheck
����  �����͡�����������Ϣ�����ݵ�������
����  ����
����ֵ����
]]
function reqcheck()
	state = "CHECK"
	local num,sr = encellinfo(net.getcellinfoext())
	link.send(lid,lpack.pack("bAbAA",1,string.char(0),0,bcd(misc.getimei(),8),sr))
	sys.timer_start(retry,GET_TIMEOUT)
end

--[[
��������upend
����  �����ؽ���
����  ��
		succ�������trueΪ�ɹ�������Ϊʧ��
����ֵ����
]]
function upend(succ)
	state = "IDLE"
	-- ֹͣ��ʵ��ʱ��
	sys.timer_stop(retry)
	sys.timer_stop(errpack)
	-- �Ͽ�����
	link.close(lid)
	getretries = 0
	if succ then
		reconnect = false
		retries = 0
		--д������Ϣ��GPSоƬ
		print("eph rcv",slen(eph))
		--startwrite()
		startupdatetimer()
		if mode==1 then dispatch("AGPS_EVT","END_IND",true) end
	else
		if retries >= RETRY_TIMES then
			reconnect = false
			retries = 0
			startupdatetimer()
			if mode==1 then dispatch("AGPS_EVT","END_IND",false) end
		else
			reconnect = true
			retries = retries + 1
		end
	end
end

local agpsstr

local function setagpstr(str)
	agpsstr = str
end

function getagpstr(str)
	return agpsstr
end

function setsucstr()
	local lng,lat = smatch(gps.getgpslocation(),"[EW]*,(%d+%.%d+),[NS]*,(%d+%.%d+)")
	print("setsucstr,lng",lng,lat)
	if lng and lat then
		local str = '$PMTK741,'..lat..','..lng..',0,'
		setagpstr(str)
	end
end

local function unbcd(d)
	local byte,v1,v2
	local t = {}

	for i=1,slen(d) do
		byte = sbyte(d,i)
		v1,v2 = bit.band(byte,0x0f),bit.band(bit.rshift(byte,4),0x0f)

		if v1 == 0x0f then break end
		table.insert(t,v1)

		if v2 == 0x0f then break end
		table.insert(t,v2)
	end

	return table.concat(t)
end

local function trans(lat,lng)
	local la,ln = lat,lng
	if slen(lat)>10 then
		la = ssub(lat,1,10)
	elseif slen(lat)<10 then
		la = lat..srep("0",10-slen(lat))
	end
	if slen(lng)>10 then
		ln = ssub(lng,1,10)
	elseif slen(lng)<10 then
		ln = lng..srep("0",10-slen(lng))
	end
	
	local la1,ln1 = sgsub(ssub(la,1,3),"0",""),sgsub(ssub(ln,1,3),"0","")
	
	return la1.."."..ssub(la,4,-1),ln1.."."..ssub(ln,4,-1)
end


--[[
��������rcv
����  ��socket�������ݵĴ�����
����  ��
        id ��socket id��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
local function rcv(id,data)
	base.collectgarbage()
	--ֹͣ���Զ�ʱ��
	sys.timer_stop(retry)
	print("syy rcv",slen(data),(slen(data)<270) and common.binstohexs(data) or "")
	if slen(data) >=11 then
		local lat,lng,latdm,lngdm = trans(unbcd(ssub(data,2,6)),unbcd(ssub(data,7,11)))
		print("syy rcv",lat,lng)
		if not lat or not lng then return end
		local str = '$PMTK741,'..lat..','..lng..',0,'
		print("syy rcv str",str)
		setagpstr(str)
		if gps.isopen() then
			agpswr()	
		elseif not agpsop then
			gps.opengps("AGPS")
			agpsop = true
		end
		upend(true)
		return		
	end		
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if state == "CHECK" then
		--����������������Ϣ
		if sfind(data,"AGPSUPDATE") == 1 then
			upbegin(data)
			return
		end
	elseif state == "UPDATE" then
		if data ~= "ERR" then
			getpack(data)
			return
		end
	end

	upend(false)
	return
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
	print("agps notify",lid,id,evt,val,reconnect)
	if id ~= lid then return end
	--�����λ�ɹ����߲�֧��GPSģ��
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if evt == "CONNECT" then
		--���ӳɹ�
		if val == "CONNECT OK" then
			reqcheck()
		--����ʧ��
		else
			upend(false)
		end
	elseif evt == "CLOSE" and reconnect then
		--����
		connect()
	elseif evt == "STATE" and val == "CLOSED" then
		upend(false)
	end
end

local function flycb()
	retries = RETRY_TIMES
	upend(false)
end

--[[
��������connectcb
����  �����ӷ�����
����  ����
����ֵ����
]]
local function connectcb()
	lid = link.open(nofity,rcv,"agps")
	link.connect(lid,PROT,SVR,PORT)
end

--[[
��������connect
����  �����ӷ���������
����  ����
����ֵ����
]]
function connect()
	if ispt then
		--�Զ�ģʽ
		if mode==0 then
			connectcb()
		--�û�����ģʽ
		else
			dispatch("AGPS_EVT","BEGIN_IND",connectcb)
		end
	end
end

--[[
��������init
����  ���������ӷ����������������ݼ���ʹ�ģ�鹤��ģʽ
����  ��
		inv�����¼������λ��
		md������ģʽ
����ֵ����
]]
function init(inv,md)
	itv = inv or itv
	mode = md or 0
	startupdatetimer()
end

--[[
��������setspt
����  �������Ƿ���AGPS����
����  ��
		spt��trueΪ������false����nilΪ�ر�
����ֵ����
]]
function setspt(spt)
	if spt ~= nil and ispt ~= spt then
		ispt = spt
		if spt then
			startupdatetimer()
		end
	end
end

--[[
��������load
����  �����д˹���ģ��
����  ����
����ֵ����
]]
local function load(force)
	local pwrstat = pwrcb and pwrcb()
	if (gps.isagpspwronupd() or force) then
		connect()
	else
		startupdatetimer()
	end
end

function setpwrcb(cb)
	pwrcb = cb
	load(true)
end

local procer =
{
	AGPS_WRDATE = agpswr
}

--ע��GPS��Ϣ������
sys.regapp(gpsstateind,gps.GPS_STATE_IND)
sys.regapp(procer)
load()
if fly then fly.setcb(flycb) end
