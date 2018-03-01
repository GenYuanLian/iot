--[[
ģ�����ƣ����Ź���
ģ�鹦�ܣ����ŷ��ͣ����գ���ȡ��ɾ��
ģ������޸�ʱ�䣺2017.02.13
]]

--����ģ��,����������
local base = _G
local string = require "string"
local table = require "table"
local sys = require "sys"
local ril = require "ril"
local common = require "common"
local rtos = require "rtos"
local bit = require"bit"
module("sms")

--���س��õ�ȫ�ֺ���������
local print = base.print
local tonumber = base.tonumber
local dispatch = sys.dispatch
local req = ril.request

--ready���ײ���Ź����Ƿ�׼������
local ready,isn,tlongsms = false,255,{}
local ssub,slen,sformat,smatch = string.sub,string.len,string.format,string.match
local tsend={}
--[[
  smsreadycb: ���ž������û�������
  newlongsmscb: �³����ŵ��û�������
]]
local smsreadycb,newlongsmscb

--[[
��������_send
����  �����Ͷ���(�ڲ��ӿ�)
����  ��num,����
        data:��������
����ֵ��true�����ͳɹ���false����ʧ��
]]
local function _send(num,data)
	local numlen,datalen,pducnt,pdu,pdulen,udhi = sformat("%02X",slen(num)),slen(data)/2,1,"","",""
	if not ready then return false end
	
    --������͵����ݴ���140�ֽ���Ϊ������
	if datalen > 140 then
        --����������Ų�ֺ���������������ŵ�ÿ��������ʵ��ֻ��134��ʵ��Ҫ���͵Ķ������ݣ����ݵ�ǰ6�ֽ�ΪЭ��ͷ
		pducnt = sformat("%d",(datalen+133)/134)
		pducnt = tonumber(pducnt)
        --����һ�����кţ���ΧΪ0-255
		isn = isn==255 and 0 or isn+1
	end

    table.insert(tsend,{sval=pducnt,rval=0,flg=true})--sval���͵İ�����rval�յ��İ���
	
	if ssub(num,1,1) == "+" then
		numlen = sformat("%02X",slen(num)-1)
	end
	
	for i=1, pducnt do
        --����ǳ�����
		if pducnt > 1 then
			local len_mul
			len_mul = (i==pducnt and sformat("%02X",datalen-(pducnt-1)*134+6) or "8C")
            --udhi��6λЭ��ͷ��ʽ
			udhi = "050003" .. sformat("%02X",isn) .. sformat("%02X",pducnt) .. sformat("%02X",i)
			print(datalen, udhi)
			pdu = "005110" .. numlen .. common.numtobcdnum(num) .. "000800" .. len_mul .. udhi .. ssub(data, (i-1)*134*2+1,i*134*2)
        --���Ͷ̶���    
		else
			datalen = sformat("%02X",datalen)
			pdu = "001110" .. numlen .. common.numtobcdnum(num) .. "000800" .. datalen .. data
		end
		pdulen = slen(pdu)/2-1
		req(sformat("%s%s","AT+CMGS=",pdulen),pdu)
	end
	return true
end

--[[
��������read
����  ��������
����  ��pos����λ��
����ֵ��true�����ɹ���false��ʧ��
]]
function read(pos)
	if not ready or pos==ni or pos==0 then return false end
	
	req("AT+CMGR="..pos)
	return true
end

--[[
��������delete
����  ��ɾ������
����  ��pos����λ��
����ֵ��true��ɾ���ɹ���falseɾ��ʧ��
]]
function delete(pos)
	if not ready or pos==ni or pos==0 then return false end
	req("AT+CMGD="..pos)
	return true
end

Charmap = {[0]=0x40,0xa3,0x24,0xa5,0xe8,0xE9,0xF9,0xEC,0xF2,0xC7,0x0A,0xD8,0xF8,0x0D,0xC5,0xE5
  ,0x0394,0x5F,0x03A6,0x0393,0x039B,0x03A9,0x03A0,0x03A8,0x03A3,0x0398,0x039E,0x1B,0xC6,0xE5,0xDF,0xA9
  ,0x20,0x21,0x22,0x23,0xA4,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0x2F
  ,0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F
  ,0xA1,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F
  ,0X50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0xC4,0xD6,0xD1,0xDC,0xA7
  ,0xBF,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F
  ,0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0xE4,0xF6,0xF1,0xFC,0xE0}

Charmapctl = {[10]=0x0C,[20]=0x5E,[40]=0x7B,[41]=0x7D,[47]=0x5C,[60]=0x5B,[61]=0x7E
			 ,[62]=0x5D,[64]=0x7C,[101]=0xA4}

--[[
��������gsm7bitdecode
����  ��7λ����, ��PDUģʽ�У���ʹ��7λ����ʱ�����ɷ�160���ַ�
����  ��data
        longsms
����ֵ��
]]
function gsm7bitdecode(data,longsms)
	local ucsdata,lpcnt,tmpdata,resdata,nbyte,nleft,ucslen,olddat = "",slen(data)/2,0,0,0,0,0
  
	if longsms then
		tmpdata = tonumber("0x" .. ssub(data,1,2))   
		resdata = bit.rshift(tmpdata,1)
		if olddat==27 then
			if Charmapctl[resdata] then--�����ַ�
				olddat,resdata = resdata,Charmapctl[resdata]
				ucsdata = ssub(ucsdata,1,-5)
			else
				olddat,resdata = resdata,Charmap[resdata]
			end
		else
			olddat,resdata = resdata,Charmap[resdata]
		end
		ucsdata = ucsdata .. sformat("%04X",resdata)
	else
		tmpdata = tonumber("0x" .. ssub(data,1,2))    
		resdata = bit.band(bit.bor(bit.lshift(tmpdata,nbyte),nleft),0x7f)
		if olddat==27 then
			if Charmapctl[resdata] then--�����ַ�
				olddat,resdata = resdata,Charmapctl[resdata]
				ucsdata = ssub(ucsdata,1,-5)
			else
				olddat,resdata = resdata,Charmap[resdata]
			end
		else
			olddat,resdata = resdata,Charmap[resdata]
		end
		ucsdata = ucsdata .. sformat("%04X",resdata)
   
		nleft = bit.rshift(tmpdata, 7-nbyte)
		nbyte = nbyte+1
		ucslen = ucslen+1
	end
  
	for i=2, lpcnt do
		tmpdata = tonumber("0x" .. ssub(data,(i-1)*2+1,i*2))   
		if tmpdata == nil then break end 
		resdata = bit.band(bit.bor(bit.lshift(tmpdata,nbyte),nleft),0x7f)
		if olddat==27 then
			if Charmapctl[resdata] then--�����ַ�
				olddat,resdata = resdata,Charmapctl[resdata]
				ucsdata = ssub(ucsdata,1,-5)
			else
				olddat,resdata = resdata,Charmap[resdata]
			end
		else
			olddat,resdata = resdata,Charmap[resdata]
		end
		ucsdata = ucsdata .. sformat("%04X",resdata)
   
		nleft = bit.rshift(tmpdata, 7-nbyte)
		nbyte = nbyte+1
		ucslen = ucslen+1

		if nbyte == 7 then
			if olddat==27 then
				if Charmapctl[nleft] then--�����ַ�
					olddat,nleft = nleft,Charmapctl[nleft]
					ucsdata = ssub(ucsdata,1,-5)
				else
					olddat,nleft = nleft,Charmap[nleft]
				end
			else
				olddat,nleft = nleft,Charmap[nleft]
			end
			ucsdata = ucsdata .. sformat("%04X",nleft)
			nbyte,nleft = 0,0
			ucslen = ucslen+1
		end
	end
  
	return ucsdata,ucslen
end

--[[
��������gsm8bitdecode
����  ��8λ����
����  ��data
        longsms
����ֵ��
]]
function gsm8bitdecode(data)
	local ucsdata,lpcnt = "",slen(data)/2
   
	for i=1, lpcnt do
		ucsdata = ucsdata .. "00" .. ssub(data,(i-1)*2+1,i*2)
	end
   
	return ucsdata,lpcnt
end

--[[
��������rsp
����  ��ATӦ��
����  ��cmd,success,response,intermediate
����ֵ����
]]
local function rsp(cmd,success,response,intermediate)
	local prefix = smatch(cmd,"AT(%+%u+)")
	print("lib_sms rsp",prefix,cmd,success,response,intermediate)

    --�����ųɹ�
	if prefix == "+CMGR" and success then
		local convnum,t,stat,alpha,len,pdu,data,longsms,total,isn,idx = "",""
		if intermediate then
			stat,alpha,len,pdu = smatch(intermediate,"+CMGR:%s*(%d),(.*),%s*(%d+)\r\n(%x+)")
			len = tonumber(len)--PDU���ݳ��ȣ�����������Ϣ���ĺ���
		end
    
        --�յ���PDU����Ϊ�������PDU��
		if pdu and pdu ~= "" then
			local offset,addlen,addnum,flag,dcs,tz,txtlen,fo=5     
			pdu = ssub(pdu,(slen(pdu)/2-len)*2+1,-1)--PDU���ݣ�����������Ϣ���ĺ���
			fo = tonumber("0x" .. ssub(pdu,1,1))--PDU�������ֽڵĸ�4λ,��6λΪ���ݱ�ͷ��־λ
			if bit.band(fo, 0x4) ~= 0 then
				longsms = true
			end
			addlen = tonumber(sformat("%d","0x"..ssub(pdu,3,4)))--�ظ���ַ���ָ��� 
      
			addlen = addlen%2 == 0 and addlen+2 or addlen+3 --���Ϻ�������2λ��5��6��or ���Ϻ�������2λ��5��6����1λF
      
			offset = offset+addlen
      
			addnum = ssub(pdu,5,5+addlen-1)
			convnum = common.bcdnumtonum(addnum)
  	  
			flag = tonumber(sformat("%d","0x"..ssub(pdu,offset,offset+1)))--Э���ʶ (TP-PID) 
			offset = offset+2
			dcs = tonumber(sformat("%d","0x"..ssub(pdu,offset,offset+1)))--�û���Ϣ���뷽ʽ Dcs=8����ʾ���Ŵ�ŵĸ�ʽΪUCS2����
			offset = offset+2
			tz = ssub(pdu,offset,offset+13)--ʱ��7���ֽ�
			offset = offset+14
			txtlen = tonumber(sformat("%d","0x"..ssub(pdu,offset,offset+1)))--�����ı����� 
			offset = offset+2
			data = ssub(pdu,offset,offset+txtlen*2-1)--�����ı�
			if longsms then
				isn,total,idx = tonumber("0x" .. ssub(data, 7,8)),tonumber("0x" .. ssub(data, 9,10)),tonumber("0x" .. ssub(data, 11,12))
				data = ssub(data, 13,-1)--ȥ����ͷ6���ֽ�
			end
  	  
			print("TP-PID : ",flag, "dcs: ", dcs, "tz: ",tz, "data: ",data,"txtlen",txtlen)
  	  
			if dcs == 0x00 then--7bit encode
				local newlen
				data,newlen = gsm7bitdecode(data, longsms)
				if newlen > txtlen then
					data = ssub(data,1,txtlen*4)
				end
				print("7bit to ucs2 data: ",data,"txtlen",txtlen,"newlen",newlen)
			elseif dcs == 0x04 then --8bit encode
				data,txtlen = gsm8bitdecode(data)
				print("8bit to ucs2 data: ",data,"txtlen",txtlen)
			end
  
			for i=1, 7  do
				t = t .. ssub(tz, i*2,i*2) .. ssub(tz, i*2-1,i*2-1)
	  
				if i<=3 then
					t = i<3 and (t .. "/") or (t .. ",")
				elseif i <= 6 then
					t = i<6 and (t .. ":") or (t .. "+")
				end
			end
		end

		local pos = tonumber(smatch(cmd,"AT%+CMGR=(%d+)"))
		data = data or ""
		alpha = alpha or ""
		dispatch("SMS_READ_CNF",success,convnum,data,pos,t,alpha,total,idx,isn)
	elseif prefix == "+CMGD" then
		dispatch("SMS_DELETE_CNF",success)
	elseif prefix == "+CMGS" then
        --����Ƕ̶��ţ�ֱ�ӷ��Ͷ���ȷ����Ϣ
        if tsend[1].sval == 1 then--{sval=pducnt,rval=0,flg=true}
            table.remove(tsend,1)
            dispatch("SMS_SEND_CNF",success)
        --����ǳ����ţ�����cmgs֮�󣬲��׳�SMS_SEND_CNF,����cmgs���ɹ�����true�����඼��false
        else
            tsend[1].rval=tsend[1].rval+1
            --ֻҪ�����з���ʧ�ܵĶ��ţ������������Ž����Ϊ����ʧ��
            if not success then tsend[1].flg=false end
            if tsend[1].sval == tsend[1].rval then
                dispatch("SMS_SEND_CNF",tsend[1].flg)
                table.remove(tsend,1)
            end
        end
	end
end
--ʹ��PDUģʽ����
local readyqrycnt,readyqrymax = 0,30
local function smsisready()
	--print('smsisready',rtos.sms_is_ready(),readyqrycnt,readyqrymax)
	if rtos.sms_is_ready()==1 or (readyqrymax and readyqrycnt>=readyqrymax) then
		ready = true
		print('smsisready2',rtos.sms_is_ready(),readyqrymax,readyqrycnt)
		req("AT+CMGF=0",nil,nil,nil,{skip=true})
		req("AT+CSMP=17,167,0,8")
		req("AT+CSCS=\"UCS2\"")
		req("AT+CPMS=\"SM\"")
		req('AT+CNMI=2,1')
		if smsreadycb then smsreadycb() end
		dispatch("SMS_READY")
	else
		sys.timer_start(smsisready,1000)
		readyqrycnt = readyqrycnt+1
	end
end

function setreadyqrymax(v)
	readyqrymax = v
end

--�յ���PDU��ʽ�Ķ������ݳ���,��������
local rcvlen,pdulen,rcvdata = 0,0,""

--[[
��������rcvdfilter
����  ����ATͨ����ȡ�¶�������
����  ��
		data���������Ķ�������
����ֵ����������ֵ����һ������ֵ��ʾδ��������ݣ��ڶ�������ֵ��ʾATͨ�������ݹ���������
]]
local function rcvdfilter(data)
	--����ܳ���Ϊ0���򱾺����������յ������ݣ�ֱ�ӷ���
	if not rcvlen or rcvlen==0 then
		return data
	end
	if rcvdata=="" then
		rcvlen = rcvlen+(tonumber(ssub(data,1,2))+1)*2
	end
	--ʣ��δ�յ������ݳ���
	local restlen = rcvlen-slen(rcvdata)
	if  slen(data) > restlen then -- atͨ�������ݱ�ʣ��δ�յ������ݶ�
		-- ��ȡ���緢��������
		rcvdata = rcvdata .. ssub(data,1,restlen)
		-- ʣ�µ������԰�at���к�������
		data = ssub(data,restlen+1,-1)
	else
		rcvdata = rcvdata .. data
		data = ""
	end

	if rcvlen == slen(rcvdata) then
		--֪ͨ��������
		rsp("AT+CMGR=65535",true,"CMT","+CMGR: 9,,"..(pdulen/2).."\r\n"..ssub(rcvdata,-pdulen,-1))
		rcvlen,pdulen,rcvdata = 0,0,""
		return data
	else
		return data, rcvdfilter
	end
end

--[[
��������urc
����  �������ϱ���Ϣ������
����  ��data,prefix
����ֵ����
]]
local function urc(data,prefix)
	print('sms.urc',data,prefix)
	if prefix == "+CMTI" then
        --��ȡ����λ��
		local pos = smatch(data,"(%d+)",slen(prefix)+1)
        --�ַ��յ��¶�����Ϣ
		dispatch("SMS_NEW_MSG_IND",pos)
	elseif prefix == "+CMT" then
        rcvlen = tonumber(smatch(data,",(%d+)"))*2
		pdulen = rcvlen
		return rcvdfilter
	end
end

--[[
��������getsmsstate
����  ����ȡ����Ϣ�Ƿ�׼���õ�״̬
����  ����
����ֵ��true׼���ã�����ֵ��δ׼����
]]
function getsmsstate()
	return ready
end

--[[
��������mergelongsms
����  ���ϲ�������
����  ����
����ֵ����
]]
local function mergelongsms()
	local data,num,t,alpha=""
    --�����е�˳��һ��ƴ�Ӷ���Ϣ����
	for i=1, #tlongsms do
		if tlongsms[i] and tlongsms[i].dat and tlongsms[i].dat~="" then
			data,num,t,alpha = data .. tlongsms[i].dat,tlongsms[i].num,tlongsms[i].t,tlongsms[i].nam 
		end
	end
    --ɾ�����еĶ���Ϣ���ȷ���´γ����źϲ�����ȷ
	for i=1, #tlongsms do
		table.remove(tlongsms)
	end
    --�ַ������źϲ�ȷ����Ϣ
	sys.dispatch("LONG_SMS_MERGR_CNF",true,num,data,t,alpha)
	print("mergelongsms", "num:",num, "data", data)
end

--[[
��������longsmsind
����  �������ű��������Ϣ���ϱ�
����  ��id,num, data,datetime,name,total,idx,isn
����ֵ����
]]
local function longsmsind(id,num, data,datetime,name,total,idx,isn)
	print("longsmsind", "total:",total, "idx:",idx,"data", data)
    --����ǳ����ŵĵ�һ����ֱ�Ӳ���tlongsms����
	if #tlongsms==0 then
		tlongsms[idx] = {dat=data,udhi=total .. isn,num=num,t=datetime,nam=name}
	else
		local oldudhi = ""
        --��ȡ֮ǰ�յ��İ��е�udhiֵ�����ڼ�������յ��Ķ����Ƿ�������յ��Ķ���������ͬһ��������
		for i=1,#tlongsms do
			if tlongsms[i] and tlongsms[i].udhi and tlongsms[i].udhi~="" then
				oldudhi = tlongsms[i].udhi
				break
			end
		end
        --����յ��Ķ����Ƿ�������յ��Ķ���������ͬһ�������ţ��������������
        --�����Ⱥϲ����еĳ����ţ��ٽ��������Ų���tlongsms����
		if oldudhi==total .. isn then
			tlongsms[idx] = {dat=data,udhi=total .. isn,num=num,t=datetime,nam=name}
		else
			sys.timer_stop(mergelongsms)
			mergelongsms()
			tlongsms[idx] = {dat=data,udhi=total .. isn,num=num,t=datetime,nam=name}
		end
	end
  
    --�����ŵ�������������ϣ���ʼ�ϲ�������
	if total==#tlongsms then
		sys.timer_stop(mergelongsms)
		mergelongsms()
	else
        --���2���Ӻ󳤶��Ż�û��������2���Ӻ��Զ��ϲ����յ��ĳ�����
		sys.timer_start(mergelongsms,120000)
	end
end

--ע�᳤���źϲ�������
sys.regapp(longsmsind,"LONG_SMS_MERGE")
smsisready()
ril.regurc("SMS READY",urc)
ril.regurc("+CMT",urc)
ril.regurc("+CMTI",urc)

ril.regrsp("+CMGR",rsp)
ril.regrsp("+CMGD",rsp)
ril.regrsp("+CMGS",rsp)

--���ŷ��ͻ����������
local SMS_SEND_BUF_MAX_CNT = 10
--���ŷ��ͼ������λ����
local SMS_SEND_INTERVAL = 3000
--���ŷ��ͻ����
local tsmsnd = {}

--[[
��������regsmsreadycb
����  ��ע����ž������û�������
����  ��
   cb���û�������������
����ֵ����
]]
function regsmsreadycb(cb)
  smsreadycb = cb
end

--[[
��������sndnxt
����  �����Ͷ��ŷ��ͻ�����еĵ�һ������
����  ����
����ֵ����
]]
local function sndnxt()
	if #tsmsnd>0 then
		_send(tsmsnd[1].num,tsmsnd[1].data)
	end
end

--[[
��������sendcnf
����  ��SMS_SEND_CNF��Ϣ�Ĵ��������첽֪ͨ���ŷ��ͽ��
����  ��
        result�����ŷ��ͽ����trueΪ�ɹ���false����nilΪʧ��
����ֵ����
]]
local function sendcnf(result)
	print("sendcnf",result)
  local num,data,cb = nil
  if base.type(tsmsnd[1]) == "table" then
    num,data,cb=tsmsnd[1].num,tsmsnd[1].data,tsmsnd[1].cb
    --�Ӷ��ŷ��ͻ�������Ƴ���ǰ����
    table.remove(tsmsnd,1)
  end
	--����з��ͻص�������ִ�лص�
	if cb then cb(result,num,data) end
	--������ŷ��ͻ�����л��ж��ţ���SMS_SEND_INTERVAL����󣬼���������������
	if #tsmsnd>0 then sys.timer_start(sndnxt,SMS_SEND_INTERVAL) end
end

--[[
��������send
����  �����Ͷ���
����  ��
    num�����Ž��շ����룬ASCII���ַ�����ʽ
		data���������ݣ�GB2312������ַ���
		cb�����ŷ��ͽ���첽����ʱʹ�õĻص���������ѡ
		idx��������ŷ��ͻ�����λ�ã���ѡ��Ĭ���ǲ���ĩβ
����ֵ������true����ʾ���ýӿڳɹ��������Ƕ��ŷ��ͳɹ������ŷ��ͽ����ͨ��sendcnf���أ������cb����֪ͨcb������������false����ʾ���ýӿ�ʧ��
]]
function send(num,data,cb,idx)
	--����������ݷǷ�
	if not num or num=="" or not data or data=="" then return end
	--���ŷ��ͻ��������
	if #tsmsnd>=SMS_SEND_BUF_MAX_CNT then return end
	local dat = common.binstohexs(common.gb2312toucs2be(data))
	--���ָ���˲���λ��
	if idx then
		table.insert(tsmsnd,idx,{num=num,data=dat,cb=cb})
	--û��ָ������λ�ã����뵽ĩβ
	else
		table.insert(tsmsnd,{num=num,data=dat,cb=cb})
	end
	--������ŷ��ͻ������ֻ��һ�����ţ������������ŷ��Ͷ���
	if #tsmsnd==1 then _send(num,dat) return true end
end


--���Ž���λ�ñ�
local tnewsms = {}

--[[
��������readsms
����  ����ȡ���Ž���λ�ñ��еĵ�һ������
����  ����
����ֵ����
]]
local function readsms()
	if #tnewsms ~= 0 then
		read(tnewsms[1])
	end
end

--[[
��������newsms
����  ��SMS_NEW_MSG_IND��δ�����Ż����¶��������ϱ�����Ϣ����Ϣ�Ĵ�����
����  ��
        pos�����Ŵ洢λ��
����ֵ����
]]
local function newsms(pos)
	--�洢λ�ò��뵽���Ž���λ�ñ���
	table.insert(tnewsms,pos)
	--���ֻ��һ�����ţ���������ȡ
	if #tnewsms == 1 then
		readsms()
	end
end

--�¶��ŵ��û�������
local newsmscb
--[[
��������regnewsmscb
����  ��ע���¶��ŵ��û�������
����  ��
        cb���û���������
����ֵ����
]]
function regnewsmscb(cb)
	newsmscb = cb
end

--[[
��������readcnf
����  ��SMS_READ_CNF��Ϣ�Ĵ��������첽���ض�ȡ�Ķ�������
����  ��
        result�����Ŷ�ȡ�����trueΪ�ɹ���false����nilΪʧ��
		num�����ź��룬ASCII���ַ�����ʽ
		data���������ݣ�UCS2��˸�ʽ��16�����ַ���
		pos�����ŵĴ洢λ�ã���ʱû��
		datetime���������ں�ʱ�䣬ASCII���ַ�����ʽ
		name�����ź����Ӧ����ϵ����������ʱû��
����ֵ����
]]
local function readcnf(result,num,data,pos,datetime,name)
	--���˺����е�86��+86
	local d1,d2 = string.find(num,"^([%+]*86)")
	if d1 and d2 then
		num = string.sub(num,d2+1,-1)
	end
	if pos~=65535 then
		--ɾ������
		delete(tnewsms[1])
		--�Ӷ��Ž���λ�ñ���ɾ���˶��ŵ�λ��
		table.remove(tnewsms,1)
	end
    
    --[[if total and total >1 then
        sys.dispatch("LONG_SMS_MERGE",num, data,datetime,name,total,idx,isn)  
        readsms()--��ȡ��һ���¶���
        return
    end
    
    sys.dispatch("SMS_RPT_REQ",num, data,datetime)]]  
    
	if data then
		--��������ת��ΪGB2312�ַ�����ʽ
		data = common.ucs2betogb2312(common.hexstobins(data))
		--�û�Ӧ�ó��������
		if newsmscb then newsmscb(num,data,datetime) end
	end
	if pos~=65535 then
		--������ȡ��һ������
		readsms()
	end
end

--[[
��������regnewlongsmscb
����  ��ע���³����ŵ��û�������
����  ��
        cb���û���������
����ֵ����
]]
function regnewlongsmscb(cb)
  newlongsmscb = cb
end

--[[
��������mergercnf
����  ��LONG_SMS_MERGR_CNF��Ϣ�Ĵ��������첽���ض�ȡ�Ķ�������
����  ��
    res�����Ŷ�ȡ�����trueΪ�ɹ���false����nilΪʧ��
    num�����ź��룬ASCII���ַ�����ʽ
    data���������ݣ�UCS2��˸�ʽ��16�����ַ���
    t���������ں�ʱ�䣬ASCII���ַ�����ʽ
    alpha����ʱû��
����ֵ����
]]
local function mergercnf(res,num,data,t,alpha)
    print("sms mergercnf num",num,data,t)
    sys.dispatch("SMS_RPT_REQ",num,data,t)
    if data then
        data = common.ucs2betogb2312(common.hexstobins(data))
        if newlongsmscb then newlongsmscb(res,num,data,t,alpha) end
    end
end

--����ģ����ڲ���Ϣ�����
local smsapp =
{
	SMS_NEW_MSG_IND = newsms, --�յ��¶��ţ�sms.lua���׳�SMS_NEW_MSG_IND��Ϣ
	SMS_READ_CNF = readcnf, --����sms.read��ȡ����֮��sms.lua���׳�SMS_READ_CNF��Ϣ
	LONG_SMS_MERGR_CNF = mergercnf, --����sms.read��ȡ����֮��sms.lua���׳�LONG_SMS_MERGR_CNF��Ϣ
	SMS_SEND_CNF = sendcnf, --����sms.send���Ͷ���֮��sms.lua���׳�SMS_SEND_CNF��Ϣ
	SMS_READY = sndnxt, --�ײ����ģ��׼������
}

--ע����Ϣ������
sys.regapp(smsapp)