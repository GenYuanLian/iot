--[[
ģ�����ƣ�GPS����
ģ�鹦�ܣ�GPS����رա�GPS NEMA���ݽ�����GPS��γ�ȸ߶��ٶȵȹ��ܽӿ�
ģ������޸�ʱ�䣺2017.02.21
]]

--����ģ��,����������
local base = _G
local table = require"table"
local uart = require"uart"
local rtos = require"rtos"
local sys = require"sys"
local pio = require"pio"
local pm = require"pm"
local pmd = require"pmd"
local string = require"string"
local common = require"common"
local misc = require"misc"
local os = require"os"
local pack = require"pack"
module(...,package.seeall)

--���س��õ�ȫ�ֺ���������
local print,tonumber,tostring,pairs = base.print,base.tonumber,base.tostring,base.pairs
local smatch,sfind,slen,ssub,sbyte,sformat,srep = string.match,string.find,string.len,string.sub,string.byte,string.format,string.rep

--gpsȫ����Ϣ��
local gps = {}
--���ƹ���ȫ����Ϣ��
local c = {}

--�������Ϣ���¼����Ǳ�����ģ������ڲ���Ϣʱʹ�õĲ������ⲿӦ�ù���ģ���ע����Ϣ��������ʶ��������Ϣ���¼�
--GPS�ڲ���ϢID
GPS_STATE_IND = "GPS_STATE_IND"
--GPS�ر��¼�
GPS_CLOSE_EVT = 0
--GPS���¼�
GPS_OPEN_EVT = 1
--GPS��λ�ɹ��¼���������ǰ��ʱ������ݣ�
GPS_LOCATION_SUC_EVT = 2
--GPS��λʧ���¼�
GPS_LOCATION_FAIL_EVT = 3
--û��GPSоƬ�¼�
GPS_NO_CHIP_EVT = 4
--��GPSоƬ�¼�
GPS_HAS_CHIP_EVT = 5
--GPS��λ�ɹ��¼�����û�й���ǰ��ʱ������ݣ�
GPS_LOCATION_UNFILTER_SUC_EVT = 6

--��γ��Ϊ�ȵĸ�ʽ
GPS_DEGREES = 0
--��γ��Ϊ�ȷֵĸ�ʽ
GPS_DEGREES_MINUTES = 1

--��������ʱ��
GPS_GREENWICH_TIME = 0
--����ʱ��
GPS_BEIJING_TIME = 1
--Խ��ʱ��
GPS_VIETNAM_TIME = 2

--�ٶȵ�λΪ����ÿСʱ
GPS_KNOT_SPD = 0
--�ٶȵ�λΪ����ÿСʱ
GPS_KILOMETER_SPD = 1

--[[
��������abs
����  ����������֮��ľ���ֵ
����  ��
		v1����һ����
		v2���ڶ�����
����ֵ����ľ���ֵ
]]
local function abs(v1,v2)
	return ((v1>v2) and (v1-v2) or (v2-v1))
end

local function getmilli(v,vr)
	local L,ov1,v1,v2,R,T,OT = slen(v)
	if (L ~= 4 and L ~= 5) or slen(vr) ~= 5 then
		print("gps data not right", v, vr)
		return
	end
	v2 = ssub(v,1,L-2)
	v1 = tostring(tonumber(ssub(v,L-1,L) .. vr)*10/6)
	ov1 = ssub(v,L-1,L) .. vr
	L = slen(v1)
	if L > 7 then
		v1 = ssub(v1,1,7)
	elseif L < 7 then
		v1 = srep("0", 7-L) .. v1
	end
	L = slen(ov1)
	if L > 7 then
		ov1 = ssub(ov1,1,7)
	elseif L < 7 then
		ov1 = ov1 .. string.rep("0", 7-L)
	end

	T = v2 .. "." .. v1
	OT = v2 .. "." .. ov1
	R = tonumber(v2..ssub(v1,1,5)) * 36 + tonumber(ssub(v1,6,7))*36/100
	return OT,T,R
end

--[[
��������getstrength
����  ������GSV����
����  ��
		sg��NEMA�е�һ��GSV����
����ֵ����
]]
local function getstrength(sg)
	local d1,d2,curnum,lineno,total,sgv_str = sfind(sg,"GSV,(%d),(%d),(%d+),(.*)%*.*")
	if not curnum or not lineno or not total or not sgv_str then
		return
	end
	if tonumber(lineno)== 1  then
		gps.sates = ""
		gps.sn = 0
		--gps.gsv = ""
	end

	local tmpstr,i = sgv_str
	for i=1,4 do
		local d1,d2,id,elevation,azimuth,strength = sfind(tmpstr,"(%d+),(%d*),(%d*),(%d*)")
		if id == nil then
			return
		end
		if strength == "" or not strength then
			strength = "00"
		end
		strength = tonumber(strength)
		if strength and strength < 60 then
			gps.sates = gps.sates .. id .. string.format("%02d",strength) .. " "
			if strength > gps.sn then
				gps.sn = strength
			end
		end
		local idx,cur,fnd,tmpid = 0,id..","..elevation..","..azimuth..","..strength..",",false
		for tmpid in string.gmatch(gps.gsv,"(%d+),%d*,%d*,%d*,") do
			idx = idx + 1
			if tmpid == id then fnd = true break end
		end
		if fnd then
			local pattern,i = ""
			for i=1,idx do
				pattern = pattern.."%d+,%d*,%d*,%d*,"
			end
			local m1,m2 = sfind(gps.gsv,"^"..pattern)
			if m1 and m2 then
				local front = ssub(gps.gsv,1,m2)
				local n1,n2 = sfind(front,"%d+,%d*,%d*,%d*,$")
				if n1 and n2 then
					gps.gsv = ssub(gps.gsv,1,n1-1)..cur..ssub(gps.gsv,n2+1,-1)
				end
			end
		else
			gps.gsv = gps.gsv..cur
		end
		
		tmpstr = ssub(tmpstr,d2+1,-1)
	end
end

local function getvg(A,L)
	local A1,A2,L1,L2,t1
	t1 = slen(L)
	A1 = ssub(A,1,4)
	A2 = ssub(A,5,8).."0"
	L1 = ssub(L,1,t1-4)
	L2 = ssub(L,t1-3,t1).."0"
	return A1,A2,L1,L2
end

local function push(A,L)	
	return getvg(A,L)
end

local function filter(LA,RA,LL,RL)
	if slen(LA) ~= 4 or (slen(LL) ~= 5 and slen(LL) ~= 4) then
		print("err LA or LL", LA, LL)
		return
	end

	if slen(RA) < 4 then
		RA = RA .. srep("0", 4 - slen(RA))
	end
	if slen(RL) < 4 then
		RL = RL .. srep("0", 4 - slen(RL))
	end
	local A = LA .. ssub(RA,1,4)
	local L = LL .. ssub(RL,1,4)
	A = tonumber(A) or 0
	L = tonumber(L) or 0

	return push(A, L)
end

--[[
��������rtctolocal
����  ��GPSʱ��ת��Ϊ��ģ�������õ�ʱ��ʱ��
����  ��
		y,m,d,hh,mm,ss��GPSʱ���е�������ʱ����
����ֵ����ģ�������õ�ʱ��ʱ��(table���ͣ�t.year,t.month,t.day,t.hour,t.min,t.sec)
]]
local function rtctolocal(y,m,d,hh,mm,ss)
	--print("rtctolocal",y,m,d,hh,mm,ss)
	local flg
	if not y or not m or not d or not hh or not mm or not ss then
		return
	end
	if gps.timezone == GPS_BEIJING_TIME then
		hh = hh + 8
		flg = true
	elseif gps.timezone == GPS_VIETNAM_TIME then
		hh = hh + 7
		flg = true
	end
	if flg then
		if hh >= 24 then
			hh = hh - 24
			d = d + 1
			if m == 4 or m == 6 or m == 9 or m == 11 then
				if d > 30 then
					d = 1
					m = m + 1
				end
			elseif m == 1 or m == 3 or m == 5 or m == 7 or m == 8 or m == 10 then
				if d > 31 then
					d = 1
					m = m + 1
				end
			elseif m == 12 then
				if d > 31 then
					d = 1
					m = 1
					y = y + 1
				end
			elseif m == 2 then
				if (((y+2000)%400) == 0) or (((y+2000)%4 == 0) and ((y+2000)%100 ~=0)) then
					if d > 29 then
						d = 1
						m = 3
					end
				else
					if d > 28 then
						d = 1
						m = 3
					end
				end
			end
		end
	end
	local t = {}
	t.year,t.month,t.day,t.hour,t.min,t.sec = 2000 + y,m,d,hh,mm,ss
	return t
end

--[[
��������needupdatetime
����  ���Ƿ���Ҫ����ϵͳʱ��Ϊ��ʱ��
����  ��
		newtime����ʱ��
����ֵ��true��Ҫ���£�false����Ҫ����
]]
function needupdatetime(newtime)
	if newtime and os.time(newtime) and os.date("*t") and os.time(os.date("*t")) then
		local secdif = os.difftime(os.time(os.date("*t")),os.time(newtime))
		if secdif and secdif >= 60 or secdif <= -60 then
			print("needupdatetime",secdif)
			return true
		end
	end
	return false
end

--[[
��������proc
����  ������ÿ��NEMA����
����  ��
		s��һ��NEMA����
����ֵ����
]]
local function proc(s)
	local latti,lattir,longti,longtir,spd1,cog1,gpsfind,gpstime,gpsdate,numofsate,numoflocationsate,hdp,latyp,longtyp

	if s == "" or s == nil then
		return
	end

	gps.find = ""

	--GGA����
	if smatch(s, "GGA") then
		local hh
		latti,lattir,latyp,longti,longtir,longtyp,gpsfind,numoflocationsate,hdp,hh = smatch(s,"GGA,%d+%.%d+,(%d+)%.(%d+),([NS]),(%d+)%.(%d+),([EW]),(%d),(%d+),([%d%.]*),(.*),M,.*,M")
		if (gpsfind == "1" or gpsfind == "2" or gpsfind == "4") and longti ~= nil and longtir ~= nil and latti ~= nil and lattir ~= nil then
			gps.find = "S"
			if hh ~= nil then
				gps.haiba = hh
			end
			if latyp=="N" or latyp=="S" then
				gps.latyp = latyp
			end
			if longtyp=="E" or longtyp=="W" then
				gps.longtyp = longtyp
			end
		end
	--RMC����
	elseif smatch(s, "RMC") then
		gpstime,gpsfind,latti,lattir,latyp,longti,longtir,longtyp,spd1,cog1,gpsdate = smatch(s,"RMC,(%d%d%d%d%d%d)%.%d+,(%w),(%d*)%.*(%d*),([NS]*),(%d*)%.*(%d*),([EW]*),(.-),(.-),(%d%d%d%d%d%d),")
		if gpsfind == "A" and longti ~= nil and longtir ~= nil and latti ~= nil and lattir ~= nil and longti ~= "" and longtir ~= "" and latti ~= "" and lattir ~= "" then
			gps.find = "S"
			if latyp=="N" or latyp=="S" then
				gps.latyp = latyp
			end
			if longtyp=="E" or longtyp=="W" then
				gps.longtyp = longtyp
			end
		end
		if gpstime and gpsdate and gpstime ~= "" and gpsdate ~= "" then
			local yy,mm,dd,h,m,s = tonumber(ssub(gpsdate,5,6)),tonumber(ssub(gpsdate,3,4)),tonumber(ssub(gpsdate,1,2)),tonumber(ssub(gpstime,1,2)),tonumber(ssub(gpstime,3,4)),tonumber(ssub(gpstime,5,6))
			gps.utctime = {year=2000+yy,month=mm,day=dd,hour=h,min=m,sec=s}
			if gps.timezone and yy>=17 then
				local newtime = rtctolocal(yy,mm,dd,h,m,s)
				if needupdatetime(newtime) then
					misc.setclock(newtime)
				end
			end
		end
	--GSV����
	elseif smatch(s,"GSV") and not smatch(s,"GLGSV") then
		numofsate = smatch(s,"GSV,%d+,%d+,(%d+)")
		getstrength(s)
	--GSA����
	elseif smatch(s,"GSA") then
		local satesn = smatch(s,"GSA,%w*,%d*,(%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,%d*,)") or ""
		if slen(satesn) > 0 and smatch(satesn,"%d+,") then
			gps.satesn = satesn
		end
	end

	--��λ�ɹ�
	if gps.find == "S" then
		if gps.filterbgn == nil and gps.filtertime > 0 then
			gps.filterbgn = c.gps
			gps.find = ""
			print("filter gps " .. gps.filtertime .. " secs begin")
			sys.dispatch(GPS_STATE_IND,GPS_LOCATION_UNFILTER_SUC_EVT)
			return
		elseif gps.filterbgn and c.gps - gps.filterbgn < gps.filtertime then
			gps.find = ""
			return
		end
	end

	--�ɼ����Ǹ���
	numofsate = tonumber(numofsate or "0")
	if numofsate > 12 then
		numofsate = 12
	end
	if numofsate > 0 then
		gps.satenum = numofsate
	end

	--��λʹ�õ����Ǹ���
	numoflocationsate = tonumber(numoflocationsate or "0")
	if numoflocationsate > 12 then
		numoflocationsate = 12
	end
	if numoflocationsate > 0 then
		gps.locationsatenum = numoflocationsate
	end

	--�ٶ�
	if spd1 and spd1 ~= "" then
		local r1,r2 = smatch(spd1, "(%d+)%.*(%d*)")
		if r1 then
			if gps.spdtyp == GPS_KILOMETER_SPD then
				gps.spd = (tonumber(r1)*1852/1000)
			else
				gps.spd = tonumber(r1)
			end
		end
	end
	
	--�����
	if cog1 and cog1 ~= "" then
		local r1,r2 = smatch(cog1, "(%d+)%.*(%d*)")
		if r1 then
			gps.cog = tonumber(r1)
		end
	end

	if gps.find ~= "S" then
		return
	end

	--��γ��
	local LA, RA, LL, RL = filter(latti,lattir,longti,longtir)
	--print("filterg", LA, RA, LL, RL)
	if not LA or not RA or not LL or not RL then
		return
	end

	gps.olati, gps.lati = getmilli(LA, RA)
	gps.olong, gps.long = getmilli(LL, RL)
	gps.long = gps.long or 0
	gps.lati = gps.lati or 0
	gps.olong = gps.olong or 0
	gps.olati = gps.olati or 0
end

--[[
��������diffofloc
����  ���������Ծ�γ��֮���ֱ�߾��루����ֵ��
����  ��
		latti1��γ��1���ȸ�ʽ������31.12345�ȣ�
		longti1������1���ȸ�ʽ��
		latti2��γ��2���ȸ�ʽ��
		longti2������2���ȸ�ʽ��
		typ����������
����ֵ��typ���Ϊtrue�����ص���ֱ�߾���(��λ��)��ƽ���ͣ����򷵻ص���ֱ�߾���(��λ��)
]]
function diffofloc(latti1, longti1, latti2, longti2,typ) --typ=true:����a+b ; ������ƽ����
	local I1,I2,R1,R2,diff,d
	I1,R1=smatch(latti1,"(%d+)%.(%d+)")
	I2,R2=smatch(latti2,"(%d+)%.(%d+)")
	if not I1 or not I2 or not R1 or not R2 then
		return 0
	end

	R1 = I1 .. ssub(R1,1,5)
	R2 = I2 .. ssub(R2,1,5)
	d = tonumber(R1)-tonumber(R2)
	d = d*111/100
	if typ == true then
		diff =  (d>0 and d or (-d))
	else
		diff = d * d
	end
		
	I1,R1=smatch(longti1,"(%d+)%.(%d+)")
	I2,R2=smatch(longti2,"(%d+)%.(%d+)")
	if not I1 or not I2 or not R1 or not R2 then
		return 0
	end

	R1 = I1 .. ssub(R1,1,5)
	R2 = I2 .. ssub(R2,1,5)
	d = tonumber(R1)-tonumber(R2)
	if typ == true then
		diff =  diff + (d>0 and d or (-d))
	else
		diff =  diff + d*d
	end
	--diff =  diff + d*d
	print("all diff:", diff)
	return diff
end


--[[
��������setmnea
����  �����á��Ƿ�NEMA�����׳����ṩ���ⲿӦ�ô�����־
����  ��
		flg��trueΪ�׳�NEMA���ݣ�false����nil���׳�������������׳����ⲿӦ��ע���ڲ���Ϣ"GPS_NMEA_DATA"�Ĵ��������ɽ���NEMA����
����ֵ����
]]
function setmnea(flg)
	nmea_route = flg
end

--[[
��������read
����  ���������ݽ��մ�����
����  ����
����ֵ����
]]
local function read(str)
	c.gps = c.gps + 1
	proc(str)
	--�����Ҫ�׳�NEMA���ݸ��ⲿӦ��ʹ��
	if nmea_route then
		sys.dispatch('GPS_NMEA_DATA',str)
	end
	if c.gpsprt ~= c.gps then
		c.gpsprt = c.gps
		print("gps rlt", gps.longtyp,gps.olong,gps.long,gps.latyp,gps.olati,gps.lati,gps.locationsatenum,gps.sn,gps.satenum)
	end
	--��λ�ɹ�
	if gps.find == "S" then
		c.gpsfind = c.gps
		local oldstat = gps.state
		gps.state = 1
		if oldstat ~= 1 then
			sys.dispatch(GPS_STATE_IND,GPS_LOCATION_SUC_EVT)
			print("dispatch GPS_LOCATION_SUC_EVT")
		end
		--��λʧ��
	elseif ((c.gps - c.gpsfind) > 20) and gps.state == 1 then
		print("location fail")
		sys.dispatch(GPS_STATE_IND,GPS_LOCATION_FAIL_EVT)
		print("dispatch GPS_LOCATION_FAIL_EVT")				
		gps.state = 2
		gps.satenum = 0
		gps.locationsatenum = 0
		gps.filterbgn = nil
		gps.spd = 0			
	end
end

--[[
��������opengps
����  ����GPS
����  ��
		tag���򿪱�ǣ�������ʾ��һ��Ӧ�ô���GPS
����ֵ����
]]
function opengps(tag)
	print("opengps",tag)
	gps.opentags[tag] = 1
	if gps.open then
		print("gps has open")
		return
	end
	pm.wake("gps")
	gps.open = true
	gps.filterbgn = nil
	gpscore.open(gpscore.WORK_RAW_MODE)

	print("gps open")
	sys.dispatch(GPS_STATE_IND,GPS_OPEN_EVT)
end

--[[
��������closegps
����  ���ر�GPS
����  ��
		tag���رձ�ǣ�������ʾ��һ��Ӧ�ùر���GPS
����ֵ����
]]
function closegps(tag)
	print("closegps",tag)
	gps.opentags[tag] = 0
	for k,v in pairs(gps.opentags) do
		if v > 0 then
			print("gps close using",k)
			return
		end
	end

	if not gps.open then
		print("gps has close")
		return
	end

	gpscore.close()	
	pm.sleep("gps")	
	gps.open = false
	if gps.state == 1 then
		gps.state = 2
	end	
	gps.spd = 0
	gps.cog = 0
	gps.haiba = 0
	gps.satesn = ""
	gps.find = ""
	gps.satenum = 0
	gps.locationsatenum = 0
	gps.sn = 0
	gps.sates = ""
	gps.gsv = ""
	print("gps close")
	sys.dispatch(GPS_STATE_IND,GPS_CLOSE_EVT)
end

--[[
��������getgpslocation
����  ����ȡGPS��γ����Ϣ
����  ��
		format����γ�ȸ�ʽ��Ĭ��Ϊ�ȸ�ʽGPS_DEGREES��֧��GPS_DEGREES��GPS_DEGREES_MINUTES
����ֵ����γ����Ϣ�ַ����������ʽΪ��"E,121.12345,N,31.23456"�����û�о�γ�ȸ�ʽΪ"E,,N,"
]]
function getgpslocation(format)
	local rstr = (gps.longtyp and gps.longtyp or "E") .. ","
	local lo,la
	if format == nil or format == GPS_DEGREES then
		lo,la = gps.long,gps.lati
	elseif format == GPS_DEGREES_MINUTES then
		lo,la = gps.olong,gps.olati
	end
	if lo and lo ~= 0 and lo ~= "0" and lo ~= "" then
		rstr = rstr .. lo
	end
	rstr = rstr .. "," .. (gps.latyp and gps.latyp or "N") .. ","
	if la and la ~= 0 and la ~= "0" and la ~= "" then
		rstr = rstr .. la
	end
	return rstr
end

--[[
��������getgpssatenum
����  ����ȡGPS�ɼ����Ǹ���
����  ����
����ֵ��GPS�ɼ����Ǹ���
]]
function getgpssatenum()
	return gps.satenum or 0
end

--[[
��������getgpslocationsatenum
����  ����ȡGPS��λʹ�õ����Ǹ���
����  ����
����ֵ��GPS��λʹ�õ����Ǹ���
]]
function getgpslocationsatenum()
	return gps.locationsatenum or 0
end

--[[
��������getgpsspd
����  ����ȡ�ٶ�
����  ����
����ֵ���ٶ�
]]
function getgpsspd()
	return gps.spd or 0
end

--[[
��������getgpscog
����  ����ȡ�����
����  ����
����ֵ�������
]]
function getgpscog()
	return gps.cog or 0
end

--[[
��������getgpssn
����  ����ȡ��ǿ���ǵ������
����  ����
����ֵ����ǿ���ǵ������
]]
function getgpssn()
	return gps.sn or 0
end

--[[
��������isfix
����  �����GPS�Ƿ�λ�ɹ�
����  ����
����ֵ��trueΪ��λ�ɹ���falseΪʧ��
]]
function isfix()
	return gps.state == 1
end

--[[
��������isopen
����  �����GPS�Ƿ��
����  ����
����ֵ��trueΪ�򿪣�falseΪ�ر�
]]
function isopen()
	return gps.open
end

--[[
��������getaltitude
����  ����ȡ�߶�
����  ����
����ֵ���߶�
]]
function getaltitude()
	return gps.haiba or 0
end

function getsatesn()
	return gps.satesn or ""
end

function getgsv()
	return gps.gsv or ""
end

function getsatesinfo()
	local tmp = gps.sates
	print("getsatesinfo",tmp)
	local ret = ""
	if string.len(tmp) > 0 then
		tmp = string.sub(tmp,1,-2)
	end
	local sate = ""
	for sate in string.gmatch(tmp, "(%d+)") do
		local id,strength = string.sub(sate,1,2),string.sub(sate,3,4)
		if id and strength and id <= "32" and strength > "00" then
			if ret == "" then
				ret = sate .. " "
			else
				local d1,d2,sn = string.find(ret,id .. "(%d+)")
				if d1 and d2 and sn then
					if strength > sn then
						ret = string.sub(ret,1,d1+1) .. strength .. string.sub(ret,d2+1,-1)
					end
				else
					ret = ret .. sate .. " "
				end
			end
		end
	end
	if string.len(ret) > 0 then
		return string.sub(ret,1,-2)
	else
		return ret
	end
end

--[[
��������init
����  ����ʼ��GPS
����  ����
����ֵ����
]]
function init()
	gps.open = false
	gps.lati = 0
	gps.long = 0
	gps.olati = 0
	gps.olong = 0
	gps.latyp = "N"
	gps.longtyp = "E"
	gps.spd = 0
	gps.cog = 0
	gps.haiba = 0
	gps.satesn = ""
	gps.gsv = ""
	gps.state = 0
	gps.find = ""
	gps.satenum = 0
	gps.locationsatenum = 0
	gps.sn = 0
	gps.sates = ""
	gps.filterbgn = nil
	gps.filtertime = 2
	gps.timezone = nil
	gps.spdtyp = GPS_KILOMETER_SPD	
	gps.opentags = {}
	gps.isagpspwronupd = true

	c.gps = 0
	c.gpsfind = 0

	sys.regmsg(gpscore.MSG_GPS_DATA_IND,gpsdataind)
	sys.regmsg(gpscore.MSG_GPS_OPEN_IND,gpsopenind)
end

--[[
��������setgpsfilter
����  ������GPS��λ�ɹ�����ʱ��
����  ��
		secs�����˵�����������5����ʾGPS��λ�ɹ����ӵ�ǰ5��Ķ�λ��Ϣ
����ֵ����
]]
function setgpsfilter(secs)
	if secs >= 0 then
		gps.filtertime = secs
	end
end

--[[
��������settimezone
����  ���������ϵͳ��ʱ�������ô˽ӿں�GPS��ȡ��ʱ��󣬻����ö�Ӧʱ����ϵͳʱ��
����  ��
		zone��Ŀǰ֧��GPS_GREENWICH_TIME��GPS_BEIJING_TIME��GPS_VIETNAM_TIME
����ֵ����
]]
function settimezone(zone)
	gps.timezone = zone
end

--[[
��������setspdtyp
����  �������ٶ�����
����  ��
		typ��Ŀǰ֧��GPS_KNOT_SPD��GPS_KILOMETER_SPD
����ֵ����
]]
function setspdtyp(typ)
	gps.spdtyp = typ
end

--[[
��������setfixmode
����  �����ö�λģʽ
����  ��
		md����λģʽ
			0��GPS+BD
			1����GPS
			2����BD
����ֵ����
]]
function setfixmode(md)
	gps.fixmode = md or 0
	if isopen() then
		print("setfixmode",gps.fixmode)
		if gps.fixmode==0 then
			gpscore.write("$PMTK353,1,0,0,0,1*2B")
		elseif gps.fixmode==1 then
			gpscore.write("$PMTK353,1,0,0,0,0*2A")
		elseif gps.fixmode==2 then
			gpscore.write("$PMTK353,0,0,0,0,1*2A")
		end
	end
end

--[[
��������setnemamode
����  ������NEMA���ݵĴ���ģʽ
����  ��
		md������ģʽ
			0����gps.lua�ڲ�����
			1��gps.lua�ڲ���������nema����ͨ���ص�����cb�ṩ���ⲿ������
			2��gps.lua���ⲿ���򶼴���
		cb���ⲿ������NEMA���ݵĻص�����
����ֵ����
]]
function setnemamode(md,cb)
	gps.nemamode = md or 0
	gps.nemacb = cb	
end

function getutctime()
	return gps.utctime
end

function isagpspwronupd()
	return (gps.isagpspwronupd == nil) and true or gps.isagpspwronupd
end

function gpsopenind(success)
	print("gpsopenind", success)
	--gpscore.cmd(gpscore.CMD_COLD_START)
end

function gpsdataind(ty,lens)
	--print("gpsdataind",ty,lens,isopen())
	if isopen() then
		local strgps = ""	
		strgps = gpscore.read(lens)	
		--print(strgps)
		if smatch(strgps,"PMTK010,002*2") then
			print("syy gpsdataind",strgps)
			sys.dispatch("AGPS_WRDATE")
			setfixmode(gps.fixmode)
			setnemamode(gps.nemamode,gps.nemacb)
		end
		if strgps ~= "" and strgps ~= nil then
			if gps.nemamode==0 or gps.nemamode==2 then
				read(strgps)
			end
			if (gps.nemamode==1 or gps.nemamode==2) and gps.nemacb then
				gps.nemacb(strgps)
			end
		end
	end	
end


--��GPSӦ�á���ָ����ʹ��GPS���ܵ�һ��Ӧ��
--���磬����������3������Ҫ��GPS����һ����3����GPSӦ�á���
--��GPSӦ��1����ÿ��1���Ӵ�һ��GPS
--��GPSӦ��2�����豸������ʱ��GPS
--��GPSӦ��3�����յ�һ���������ʱ��GPS
--ֻ�����С�GPSӦ�á����ر��ˣ��Ż�ȥ�����ر�GPS

--[[
ÿ����GPSӦ�á��򿪻��߹ر�GPSʱ�������4������������ GPS����ģʽ�͡�GPSӦ�á���� ��ͬ������һ��Ψһ�ġ�GPSӦ�á���
1��GPS����ģʽ(��ѡ)
2����GPSӦ�á����(��ѡ)
3��GPS�������ʱ��[��ѡ]
4���ص�����[��ѡ]
����gps.open(gps.TIMERORSUC,{cause="TEST",val=120,cb=testgpscb})
gps.TIMERORSUCΪGPS����ģʽ��"TEST"Ϊ��GPSӦ�á���ǣ�120��ΪGPS�������ʱ����testgpscbΪ�ص�����
]]


--[[
GPS����ģʽ����������3��
1��DEFAULT
   (1)���򿪺�GPS��λ�ɹ�ʱ������лص�����������ûص�����
   (2)��ʹ�ô˹���ģʽ����gps.open�򿪵ġ�GPSӦ�á����������gps.close���ܹر�
2��TIMERORSUC
   (1)���򿪺������GPS�������ʱ������ʱ��û�ж�λ�ɹ�������лص�����������ûص�������Ȼ���Զ��رմˡ�GPSӦ�á�
   (2)���򿪺������GPS�������ʱ���ڣ���λ�ɹ�������лص�����������ûص�������Ȼ���Զ��رմˡ�GPSӦ�á�
   (3)���򿪺����Զ��رմˡ�GPSӦ�á�ǰ�����Ե���gps.close�����رմˡ�GPSӦ�á��������ر�ʱ����ʹ�лص�������Ҳ������ûص�����
3��TIMER
   (1)���򿪺���GPS�������ʱ��ʱ�䵽��ʱ�������Ƿ�λ�ɹ�������лص�����������ûص�������Ȼ���Զ��رմˡ�GPSӦ�á�
   (2)���򿪺����Զ��رմˡ�GPSӦ�á�ǰ�����Ե���gps.close�����رմˡ�GPSӦ�á��������ر�ʱ����ʹ�лص�������Ҳ������ûص�����
]]
DEFAULT,TIMERORSUC,TIMER = 0,1,2

--��GPSӦ�á���
local tlist = {}

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������gpsǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("gps",...)
end

--[[
��������delitem
����  ���ӡ�GPSӦ�á�����ɾ��һ�GPSӦ�á���������������ɾ����ֻ������һ����Ч��־
����  ��
		mode��GPS����ģʽ
		para��
			para.cause����GPSӦ�á����
			para.val��GPS�������ʱ��
			para.cb���ص�����
����ֵ����
]]
local function delitem(mode,para)
	local i
	for i=1,#tlist do
		--��־��Ч ���� GPS����ģʽ��ͬ ���� ��GPSӦ�á������ͬ
		if tlist[i].flag and tlist[i].mode == mode and tlist[i].para.cause == para.cause then
			--������Ч��־
			tlist[i].flag,tlist[i].delay = false
			break
		end
	end
end

--[[
��������additem
����  ������һ�GPSӦ�á�����GPSӦ�á���
����  ��
		mode��GPS����ģʽ
		para��
			para.cause����GPSӦ�á����
			para.val��GPS�������ʱ��
			para.cb���ص�����
����ֵ����
]]
local function additem(mode,para)
	--ɾ����ͬ�ġ�GPSӦ�á�
	delitem(mode,para)
	local item,i,fnd = {flag = true, mode = mode, para = para}
	--�����TIMERORSUC����TIMERģʽ����ʼ��GPS����ʣ��ʱ��
	if mode == TIMERORSUC or mode == TIMER then item.para.remain = para.val end
	for i=1,#tlist do
		--���������Ч�ġ�GPSӦ�á��ֱ��ʹ�ô�λ��
		if not tlist[i].flag then
			tlist[i] = item
			fnd = true
			break
		end
	end
	--����һ��
	if not fnd then table.insert(tlist,item) end
end

local function isexisttimeritem()
	local i
	for i=1,#tlist do
		if tlist[i].flag and (tlist[i].mode == TIMERORSUC or tlist[i].mode == TIMER or tlist[i].para.delay) then return true end
	end
end

local function timerfunc()
	local i
	for i=1,#tlist do
		print("timerfunc@"..i,tlist[i].flag,tlist[i].mode,tlist[i].para.cause,tlist[i].para.val,tlist[i].para.remain,tlist[i].para.delay)
		if tlist[i].flag then
			local rmn,dly,md,cb = tlist[i].para.remain,tlist[i].para.delay,tlist[i].mode,tlist[i].para.cb
			if rmn and rmn > 0 then
				tlist[i].para.remain = rmn - 1
			end
			if dly and dly > 0 then
				tlist[i].para.delay = dly - 1
			end
			
			rmn = tlist[i].para.remain
			if isfix() and md == TIMER and rmn == 0 and not tlist[i].para.delay then
				tlist[i].para.delay = 1
			end
			
			dly = tlist[i].para.delay
			if isfix() then
				if dly and dly == 0 then
					if cb then cb(tlist[i].para.cause) end
					if md == DEFAULT then
						tlist[i].para.delay = nil
					else
						close(md,tlist[i].para)
					end
				end
			else
				if rmn and rmn == 0 then
					if cb then cb(tlist[i].para.cause) end
					close(md,tlist[i].para)
				end
			end			
		end
	end
	if isexisttimeritem() then sys.timer_start(timerfunc,1000) end
end

--[[
��������gpsstatind
����  ������GPS��λ�ɹ�����Ϣ
����  ��
		id��GPS��Ϣid
		evt��GPS��Ϣ����
����ֵ����
]]
local function gpsstatind(id,evt)
	--��λ�ɹ�����Ϣ
	if evt == GPS_LOCATION_SUC_EVT then
		local i
		for i=1,#tlist do
			print("gpsstatind@"..i,tlist[i].flag,tlist[i].mode,tlist[i].para.cause,tlist[i].para.val,tlist[i].para.remain,tlist[i].para.delay,tlist[i].para.cb)
			if tlist[i].flag then
				if tlist[i].mode ~= TIMER then
					tlist[i].para.delay = 1
					if tlist[i].mode == DEFAULT then
						if isexisttimeritem() then sys.timer_start(timerfunc,1000) end
					end
				end				
			end			
		end
	end
	return true
end

--[[
��������forceclose
����  ��ǿ�ƹر����С�GPSӦ�á�
����  ����
����ֵ����
]]
function forceclose()
	local i
	for i=1,#tlist do
		if tlist[i].flag and tlist[i].para.cb then tlist[i].para.cb(tlist[i].para.cause) end
		close(tlist[i].mode,tlist[i].para)
	end
end

--[[
��������close
����  ���ر�һ����GPSӦ�á�
����  ��
		mode��GPS����ģʽ
		para��
			para.cause����GPSӦ�á����
			para.val��GPS�������ʱ��
			para.cb���ص�����
����ֵ����
]]
function close(mode,para)
	assert((para and type(para) == "table" and para.cause and type(para.cause) == "string"),"gps.close para invalid")
	print("ctl close",mode,para.cause,para.val,para.cb)
	--ɾ���ˡ�GPSӦ�á�
	delitem(mode,para)
	local valid,i
	for i=1,#tlist do
		if tlist[i].flag then
			valid = true
		end		
	end
	--���û��һ����GPSӦ�á���Ч����ر�GPS
	if not valid then closegps("gps") end
end

--[[
��������open
����  ����һ����GPSӦ�á�
����  ��
		mode��GPS����ģʽ
		para��
			para.cause����GPSӦ�á����
			para.val��GPS�������ʱ��
			para.cb���ص�����
����ֵ����
]]
function open(mode,para)
	assert((para and type(para) == "table" and para.cause and type(para.cause) == "string"),"gps.open para invalid")
	print("ctl open",mode,para.cause,para.val,para.cb)
	--���GPS��λ�ɹ�
	if isfix() then
		if mode ~= TIMER then
			--ִ�лص�����
			if para.cb then para.cb(para.cause) end
			if mode == TIMERORSUC then return end			
		end
	end
	additem(mode,para)
	--����ȥ��GPS
	opengps("gps")
	--����1��Ķ�ʱ��
	if isexisttimeritem() and not sys.timer_is_active(timerfunc) then
		sys.timer_start(timerfunc,1000)
	end
end

--[[
��������isactive
����  ���ж�һ����GPSӦ�á��Ƿ��ڼ���״̬
����  ��
		mode��GPS����ģʽ
		para��
			para.cause����GPSӦ�á����
			para.val��GPS�������ʱ��
			para.cb���ص�����
����ֵ�������true�����򷵻�nil
]]
function isactive(mode,para)
	assert((para and type(para) == "table" and para.cause and type(para.cause) == "string"),"gps.isactive para invalid")
	local i
	for i=1,#tlist do
		if tlist[i].flag and tlist[i].mode == mode and tlist[i].para.cause == para.cause then
			return true
		end
	end
end

sys.regapp(gpsstatind,GPS_STATE_IND)
