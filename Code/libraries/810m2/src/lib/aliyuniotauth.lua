--����ģ��,����������
local base = _G
local string = require"string"
local io = require"io"
local os = require"os"
local sys  = require"sys"
local misc = require"misc"
local link = require"link"
local socket = require"socket"
local crypto = require"crypto"
module(...,package.seeall)


local ssub,schar,smatch,sbyte,slen,sfind = string.sub,string.char,string.match,string.byte,string.len,string.find
local tonumber = base.tonumber


--�����Ƽ�Ȩ������
local SCK_IDX,PROT,ADDR,PORT = 3,"TCP","iot-auth.aliyun.com",80
--�밢���Ƽ�Ȩ��������socket����״̬
local linksta
--һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
--���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
--�������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20
--reconncnt:��ǰ���������ڣ��Ѿ������Ĵ���
--reconncyclecnt:�������ٸ��������ڣ���û�����ӳɹ�
--һ�����ӳɹ������Ḵλ���������
--conning:�Ƿ��ڳ�������
local reconncnt,reconncyclecnt,conning = 0,0
--��Ʒ��ʶ����Ʒ��Կ���豸�����豸��Կ
local productkey,productsecret,devicename,devicesecret
--��Ȩ��Ϣ
local gauthinfo = 
{
	truststorepath = "/aliyuniot_publicKey.crt",
	otherinfopath = "/aliyuniot_otherInfo.info"
}
--ȫ����ȡ����ȡ�����������ȡ֤�����
local ALL_SERVER_PARAM,NETWORK_SERVER_PARAM,CERT_SERVER_PARAM = 0,1,2
local gsvrpara
--�Ӽ�Ȩ�������յ����������ģ��������е���Ч����
local rcvbuf,rcvalidbody = "",""

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������aliyuniotauthǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("aliyuniotauth",...)
end

local function getdevice(s)
	if s=="name" then
		return devicename or misc.getimei()
	elseif s=="secret" then
		return devicesecret or misc.getsn()
	end
end

--[[
��������filexist
����  ���ж��ļ��Ƿ����
����  ��
		path���ļ�·��
����ֵ�����ڷ���true�����򷵻�nil
]]
local function filexist(path)
	local f = io.open(path,"rb")
	if f then
		f:close()
		return true
	end
end

--[[
��������snd
����  �����÷��ͽӿڷ�������
����  ��
        data�����͵����ݣ��ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.data��
		para�����͵Ĳ������ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.para�� 
����ֵ�����÷��ͽӿڵĽ�������������ݷ����Ƿ�ɹ��Ľ�������ݷ����Ƿ�ɹ��Ľ����ntfy�е�SEND�¼���֪ͨ����trueΪ�ɹ�������Ϊʧ��
]]
function snd(data,para)
	return socket.send(SCK_IDX,data,para)
end

--[[
��������makesign
����  ������ǩ����Ϣ
����  ��
		typ����������
����ֵ��ǩ����Ϣ
]]
local function makesign(typ)
	local temp = ""
	if typ==NETWORK_SERVER_PARAM then
		temp = "resFlagip"
	elseif typ==CERT_SERVER_PARAM then
		temp = "resFlagcert"
	end
	local data = "deviceName"..getdevice("name").."productKey"..productkey.."protocolmqtt"..temp.."sdkVersion1.0.0signMethodHmacMD5"
	local signkey = productsecret..getdevice("secret")
	return crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
end

--[[
��������postsnd
����  ������POST���ĵ���Ȩ������
����  ��
		typ����������
����ֵ����
]]
local function postsnd(typ)
	local postbody = "/iot/auth?&sign="..makesign(typ).."&productKey="..productkey.."&deviceName="..getdevice("name").."&protocol=mqtt&sdkVersion=1.0.0&signMethod=HmacMD5"
	if typ==NETWORK_SERVER_PARAM then
		postbody = postbody.."&resFlag=ip"
	elseif typ==CERT_SERVER_PARAM then
		postbody = postbody.."&resFlag=cert"
	end
	local posthead = "POST "..postbody.." HTTP/1.1\r\n" .. "Host: "..ADDR.."\r\n\r\n"
	snd(posthead,"POSTSND")
	gsvrpara = typ
end

--[[
��������readauthinfo
����  �����ļ��ж�ȡ��Ȩ��Ϣ
����  ����
����ֵ�����ɹ�����true�����򷵻�nil
]]
local function readauthinfo()
	local f = io.open(gauthinfo.truststorepath,"rb")
	if not f then print("readauthinfo open truststorepath error") return end
	gauthinfo.pubkey = f:read("*a")
	if not gauthinfo.pubkey then f:close() print("readauthinfo read truststorepath error") return end	
	f:close()
	
	f = io.open(gauthinfo.otherinfopath,"rb")
	if not f then print("readauthinfo open otherinfopath error") return end
	local alldata = f:read("*a")
	if not alldata then f:close() print("readauthinfo read otherinfopath error") return end
	
	gauthinfo.pkVersion,gauthinfo.sign,gauthinfo.deviceId = smatch(alldata,"(%w+)\n(%w+)\n(%w+)")
	f:close()
	if not gauthinfo.pkVersion or not gauthinfo.sign or not gauthinfo.deviceId then		
		print("readauthinfo read otherinfopath parse error")
		return
	end
	gauthinfo.pkVersion = tonumber(gauthinfo.pkVersion)
	
	return true
end

--[[
��������writeauthinfo
����  ��д��Ȩ��Ϣ���ļ���
����  ����
����ֵ��д�ɹ�����true�����򷵻�nil
]]
local function writeauthinfo()
	os.remove(gauthinfo.truststorepath)
	os.remove(gauthinfo.otherinfopath)
	
	local f = io.open(gauthinfo.truststorepath,"wb")
	if not f then print("writeauthinfo open truststorepath error") return end
	if not f:write(gauthinfo.pubkey) then f:close() print("writeauthinfo write truststorepath error") return end
	f:close()
	
	f = io.open(gauthinfo.otherinfopath,"wb")
	if not f then print("writeauthinfo open otherinfopath error") return end
	if not f:write(gauthinfo.pkVersion.."\n") then f:close() print("writeauthinfo write otherinfopath pkVersion error") return end
	if not f:write(gauthinfo.certsign.."\n") then f:close() print("writeauthinfo write otherinfopath certsign error") return end	
	if not f:write(gauthinfo.deviceId) then f:close() print("writeauthinfo write otherinfopath deviceId error") return end
	f:close()
	
	return true
end

--[[
��������verifycert
����  ����֤֤��ĺϷ���
����  ��
		typ����������
����ֵ���Ϸ�����true�����򷵻�nil
]]
local function verifycert(typ)
	local ptype = typ or gsvrpara
	local data,sign,signkey,pubkeyencode
	if ptype==ALL_SERVER_PARAM then
		pubkeyencode = crypto.base64_encode(gauthinfo.pubkey,slen(gauthinfo.pubkey))
		signkey = productsecret..getdevice("secret")
		data = "deviceId"..gauthinfo.deviceId.."pkVersion"..gauthinfo.pkVersion.."pubkey"..pubkeyencode.."servers"..gauthinfo.servers
		sign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
		data = "deviceId"..gauthinfo.deviceId.."pkVersion"..gauthinfo.pkVersion.."pubkey"..pubkeyencode
		gauthinfo.certsign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
	elseif ptype==CERT_SERVER_PARAM then
		pubkeyencode = crypto.base64_encode(gauthinfo.pubkey,slen(gauthinfo.pubkey))
		signkey = productsecret..getdevice("secret")
		data = "deviceId"..gauthinfo.deviceId.."pkVersion"..gauthinfo.pkVersion.."pubkey"..pubkeyencode
		sign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
	elseif ptype==NETWORK_SERVER_PARAM then
		signkey = productsecret..getdevice("secret")
		data = "deviceId"..gauthinfo.deviceId.."servers"..gauthinfo.servers
		sign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
	end
	
	if ptype==ALL_SERVER_PARAM and sign==gauthinfo.sign then
		if not writeauthinfo() then print("verifycert writeauthinfo error") return end
	end
	
	print("verifycert",ptype,sign==gauthinfo.sign,sign,gauthinfo.sign)
	return sign==gauthinfo.sign
end

--[[
��������parsedatasvr
����  ���������ݷ���������(host��port��clientid��username)
����  ��
����ֵ���ɹ�����true�����򷵻�nil
]]
local function parsedatasvr()
	local clientid = productkey..":"..gauthinfo.deviceId
	local temp = productkey..productsecret..gauthinfo.deviceId..getdevice("secret")
	local username = crypto.md5(temp,slen(temp))
	local host,port = smatch(gauthinfo.servers,"([%w%.]+):([%d|]+)")
	local ports = {}
	if port then
		local h,t,p = sfind(port,"(%d+)")
		while p do
			table.insert(ports,tonumber(p))
			port = ssub(port,t+1,-1)
			h,t,p = sfind(port,"(%d+)")
		end
	end
	
	print("parsedatasvr",host,#ports,clientid,username)
	if host and #ports>0 and clientid and username then
		sys.dispatch("ALIYUN_DATA_BGN",host,ports,clientid,username)
	end
	
	return host and #ports>0 and clientid and username
end

--[[
��������preproc
����  ����ȨԤ����
����  ����
����ֵ����
]]
function preproc()
	print("preproc",linksta)
	if linksta then
		if filexist(gauthinfo.truststorepath) and filexist(gauthinfo.otherinfopath) then
			if readauthinfo() then
				if verifycert(CERT_SERVER_PARAM) then
					postsnd(NETWORK_SERVER_PARAM)
					return
				end
			end
		end
		postsnd(ALL_SERVER_PARAM)
	end
end

--[[
��������sndcb
����  �����ݷ��ͽ������
����  ��          
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ��������socket.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
		result�� bool���ͣ����ͽ����trueΪ�ɹ�������Ϊʧ��
����ֵ����
]]
local function sndcb(item,result)
	print("sndcb",item.para,result)
	if not item.para then return end
	if item.para=="POSTSND" then
		sys.timer_start(reconn,RECONN_PERIOD*1000)
	end
end


--[[
��������reconn
����  ��������̨����
        һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
        ���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
        �������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
����  ����
����ֵ����
]]
function reconn()
	print("reconn",reconncnt,conning,reconncyclecnt)
	--conning��ʾ���ڳ������Ӻ�̨��һ��Ҫ�жϴ˱����������п��ܷ��𲻱�Ҫ������������reconncnt���ӣ�ʵ�ʵ�������������
	if conning then return end
	--һ�����������ڵ�����
	if reconncnt < RECONN_MAX_CNT then		
		reconncnt = reconncnt+1
		link.shut()
		connect()
	--һ���������ڵ�������ʧ��
	else
		reconncnt,reconncyclecnt = 0,reconncyclecnt+1
		if reconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			sys.restart("connect fail")
		end
		sys.timer_start(reconn,RECONN_CYCLE_PERIOD*1000)
	end
end

--[[
��������ntfy
����  ��socket״̬�Ĵ�����
����  ��
        idx��number���ͣ�socket.lua��ά����socket idx��������socket.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        evt��string���ͣ���Ϣ�¼�����
		result�� bool���ͣ���Ϣ�¼������trueΪ�ɹ�������Ϊʧ��
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ�Ŀǰֻ����SEND���͵��¼����õ��˴˲������������socket.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
����ֵ����
]]
function ntfy(idx,evt,result,item)
	print("ntfy",evt,result,item)
	--���ӽ��������socket.connect����첽�¼���
	if evt == "CONNECT" then
		conning = false
		--���ӳɹ�
		if result then
			reconncnt,reconncyclecnt,linksta,rcvbuf,rcvbody = 0,0,true,"",""
			--ֹͣ������ʱ��
			sys.timer_stop(reconn)
			preproc()
		--����ʧ��
		else
			--RECONN_PERIOD�������
			sys.timer_start(reconn,RECONN_PERIOD*1000)
		end	
	--���ݷ��ͽ��������socket.send����첽�¼���
	elseif evt == "SEND" then
		if item then
			sndcb(item,result)
		end
		--����ʧ�ܣ�RECONN_PERIOD���������̨����Ҫ����reconn����ʱsocket״̬��Ȼ��CONNECTED���ᵼ��һֱ�����Ϸ�����
		--if not result then sys.timer_start(reconn,RECONN_PERIOD*1000) end
		if not result then link.shut() end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and result == "CLOSED" then
		linksta = false
		socket.close(SCK_IDX)
		--reconn()
	--���������Ͽ�������link.shut����첽�¼���
	elseif evt == "STATE" and result == "SHUTED" then
		linksta = false
		reconn()
	--���������Ͽ�������socket.disconnect����첽�¼���
	elseif evt == "DISCONNECT" then
		linksta = false
		--reconn()
	end
	--�����������Ͽ�������·����������
	if smatch((base.type(result)=="string") and result or "","ERROR") then
		--RECONN_PERIOD�����������Ҫ����reconn����ʱsocket״̬��Ȼ��CONNECTED���ᵼ��һֱ�����Ϸ�����
		--sys.timer_start(reconn,RECONN_PERIOD*1000)
		link.shut()
	end
end

--[[
��������parsevalidbody
����  ��������Ȩ���������ص���Ч������
����  ����
����ֵ����
]]
local function parsevalidbody()
	print("parsevalidbody")
	local tjsondata = json.decode(rcvalidbody)
	print("deviceId",tjsondata["deviceId"])
	print("pkVersion",tjsondata["pkVersion"])
	print("pubkey",tjsondata["pubkey"])
	print("servers",tjsondata["servers"])
	print("sign",tjsondata["sign"])
	print("success",tjsondata["success"])
	if tjsondata["success"]~="true" and tjsondata["success"]~=true then print("parsevalidbody success err",tjsondata["success"]) return end
	if tjsondata["deviceId"] then gauthinfo.deviceId = tjsondata["deviceId"] end
	if tjsondata["pkVersion"] then gauthinfo.pkVersion = tonumber(tjsondata["pkVersion"]) end
	if tjsondata["pubkey"] then gauthinfo.pubkey = crypto.base64_decode(tjsondata["pubkey"],slen(tjsondata["pubkey"])) end
	if tjsondata["servers"] then gauthinfo.servers = tjsondata["servers"] end
	if tjsondata["sign"] then gauthinfo.sign = tjsondata["sign"] end
	--��������ɹ�
	if verifycert() and parsedatasvr() then
		sys.timer_stop(reconn)
	end
end

--[[
��������parse
����  ��������Ȩ���������ص�����
����  ����
����ֵ����
]]
local function parse()
	local headend = sfind(rcvbuf,"\r\n\r\n")
	if not headend then print("parse wait head end") return end
	
	local headstr = ssub(rcvbuf,1,headend+3)
	if not smatch(headstr,"200 OK") then print("parse no 200 OK") return end
	
	local contentflg
	if smatch(headstr,"Transfer%-Encoding: chunked") or smatch(headstr,"Transfer%-Encoding: Chunked") then
		contentflg = "chunk"
	elseif smatch(headstr,"Content%-Length: %d+") then
		contentflg = tonumber(smatch(headstr,"Content%-Length: (%d+)"))
	end
	if not contentflg then print("parse contentflg error") return end
	
	local rcvbody = ssub(rcvbuf,headend+4,-1)
	if contentflg=="chunk" then	
		rcvalidbody = ""
		if not smatch(rcvbody,"0\r\n\r\n") then print("parse wait chunk end") return end
		local h,t,len
		while true do
			h,t,len = sfind(rcvbody,"(%w+)\r\n")
			if len then
				len = tonumber(len,16)
				if len==0 then break end
				rcvalidbody = rcvalidbody..ssub(rcvbody,t+1,t+len)
				rcvbody = ssub(rcvbody,t+len+1,-1)
			else
				print("parse chunk len err ")
				return
			end
		end
	else
		if slen(rcvbody)~=contentflg then print("parse wait content len end") return end
		rcvalidbody = rcvbody
	end
	
	rcvbuf = ""
	parsevalidbody()
	socket.close(SCK_IDX)
end

--[[
��������rcv
����  ��socket�������ݵĴ�����
����  ��
        idx ��socket.lua��ά����socket idx��������socket.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
function rcv(idx,data)
	print("rcv",data)
	rcvbuf = rcvbuf..data
	parse()
end

--[[
��������connect
����  �������������Ƽ�Ȩ�����������ӣ�
        ������������Ѿ�׼���ã����������Ӻ�̨��������������ᱻ���𣬵���������׼���������Զ�ȥ���Ӻ�̨
		ntfy��socket״̬�Ĵ�����
		rcv��socket�������ݵĴ�����
����  ����
����ֵ����
]]
function connect()
	socket.connect(SCK_IDX,PROT,ADDR,PORT,ntfy,rcv)
	conning = true
end

--[[
��������authbgn
����  �������Ȩ
����  ����
����ֵ����
]]
local function authbgn(pkey,psecret,dname,dsecret)
	productkey,productsecret,devicename,devicesecret = pkey,psecret,dname,dsecret
	connect()
end

local procer =
{
	ALIYUN_AUTH_BGN = authbgn,
}

sys.regapp(procer)

