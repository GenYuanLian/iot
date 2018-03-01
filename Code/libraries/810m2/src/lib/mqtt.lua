--[[
ģ�����ƣ�mqttЭ�����
ģ�鹦�ܣ�ʵ��Э�������ͽ�����������Ķ�http://public.dhe.ibm.com/software/dw/webservices/ws-mqtt/mqtt-v3r1.html�˽�mqttЭ��
ģ������޸�ʱ�䣺2017.02.24
]]

--[[
Ŀǰֻ֧��QoS=0��QoS=1����֧��QoS=2
]]

module(...,package.seeall)

local lpack = require"pack"
require"common"
require"socket"
require"mqttdup"

local slen,sbyte,ssub,sgsub,schar,srep,smatch,sgmatch = string.len,string.byte,string.sub,string.gsub,string.char,string.rep,string.match,string.gmatch
--��������
CONNECT,CONNACK,PUBLISH,PUBACK,PUBREC,PUBREL,PUBCOMP,SUBSCRIBE,SUBACK,UNSUBSCRIBE,UNSUBACK,PINGREQ,PINGRSP,DISCONNECT = 1,2,3,4,5,6,7,8,9,10,11,12,13,14
--�������к�
local seq = 1

local function print(...)
	_G.print("mqtt",...)
end

local function encutf8(s)
	if not s then return "" end
	local utf8s = common.gb2312toutf8(s)
	return lpack.pack(">HA",slen(utf8s),utf8s)
end

local function enclen(s)
	if not s or slen(s) == 0 then return schar(0) end
	local ret,len,digit = "",slen(s)
	repeat
		digit = len % 128
		len = len / 128
		if len > 0 then
			digit = bit.bor(digit,0x80)
		end
		ret = ret..schar(digit)
	until (len <= 0)
	return ret
end

local function declen(s)
	local i,value,multiplier,digit = 1,0,1 
	repeat
		if i > slen(s) then return end
		digit = sbyte(s,i) 
		value = value + bit.band(digit,127)*multiplier
		multiplier = multiplier * 128
		i = i + 1
	until (bit.band(digit,128) == 0)
	return true,value,i-1
end

local function getseq()
	local s = seq
	seq = (seq+1)%0xFFFF
	if seq == 0 then seq = 1 end
	return lpack.pack(">H",s)
end

local function iscomplete(s)
	local i,typ,flg,len,cnt
	for i=1,slen(s) do
		typ = bit.band(bit.rshift(sbyte(s,i),4),0x0f)
		--print("typ",typ)
		if typ >= CONNECT and typ <= DISCONNECT then
			flg,len,cnt = declen(ssub(s,i+1,-1))
			--print("f",flg,len,cnt,(slen(ssub(s,i+1,-1))-cnt))
			if flg and cnt <= 4 and len <= (slen(ssub(s,i+1,-1))-cnt) then
				return true,i,i+cnt+len,typ,len
			else
				return
			end
		end		
	end
end

--[[
��������pack
����  ��MQTT���
����  ��
		mqttver��mqttЭ��汾��
		typ����������
		...���ɱ����
����ֵ����һ������ֵ�Ǳ������ݣ��ڶ�������ֵ��ÿ�ֱ����Զ���Ĳ���
]]
local function pack(mqttver,typ,...)
	local para = {}
	local function connect(alive,id,twill,user,pwd,cleansess)
		local ret = lpack.pack(">bAbbHA",
						CONNECT*16,
						encutf8(mqttver=="3.1.1" and "MQTT" or "MQIsdp"),
						mqttver=="3.1.1" and 4 or 3,
						(user and 1 or 0)*128+(pwd and 1 or 0)*64+twill.retain*32+twill.qos*8+twill.flg*4+(cleansess or 1)*2,
						alive,
						encutf8(id))
		if twill.flg==1 then
			ret = ret..encutf8(twill.topic)..encutf8(twill.payload)
		end
		ret = ret..encutf8(user)..encutf8(pwd)
		return ret
	end
	
	local function subscribe(p)
		para.dup,para.topic = true,p.topic
		para.seq = p.seq or getseq()
		print("subscribe",p.dup,para.dup,common.binstohexs(para.seq))
		
		local s = lpack.pack("bA",SUBSCRIBE*16+(p.dup and 1 or 0)*8+2,para.seq)
		for i=1,#p.topic do
			s = s..encutf8(p.topic[i].topic)..schar(p.topic[i].qos or 0)
		end
		return s
	end
	
	local function publish(p)
		para.dup,para.topic,para.payload,para.qos,para.retain = true,p.topic,p.payload,p.qos,p.retain
		para.seq = p.seq or getseq()
		--print("publish",p.dup,para.dup,common.binstohexs(para.seq))
		local s1 = lpack.pack("bAA",PUBLISH*16+(p.dup and 1 or 0)*8+(p.qos or 0)*2+p.retain or 0,encutf8(p.topic),((p.qos or 0)>0 and para.seq or ""))
		local s2 = s1..p.payload
		return s2
	end
	
	local function puback(seq)
		return schar(PUBACK*16)..seq
	end
	
	local function pingreq()
		return schar(PINGREQ*16)
	end
	
	local function disconnect()
		return schar(DISCONNECT*16)
	end
	
	local function unsubscribe(p)
		para.dup,para.topic = true,p.topic
		para.seq = p.seq or getseq()
		print("unsubscribe",p.dup,para.dup,common.binstohexs(para.seq))
		
		local s = lpack.pack("bA",UNSUBSCRIBE*16+(p.dup and 1 or 0)*8+2,para.seq)
		for i=1,#p.topic do
			s = s..encutf8(p.topic[i])
		end
		return s
	end

	local procer =
	{
		[CONNECT] = connect,
		[SUBSCRIBE] = subscribe,
		[PUBLISH] = publish,
		[PUBACK] = puback,
		[PINGREQ] = pingreq,
		[DISCONNECT] = disconnect,
		[UNSUBSCRIBE] = unsubscribe,
	}

	local s = procer[typ](...)
	local s1,s2,s3 = ssub(s,1,1),enclen(ssub(s,2,-1)),ssub(s,2,-1)
	s = s1..s2..s3
	print("pack",typ,(slen(s) > 200) and "" or common.binstohexs(s))
	return s,para
end

local rcvpacket = {}

--[[
��������unpack
����  ��MQTT���
����  ��
		mqttver��mqttЭ��汾��
		s��һ�������ı���
����ֵ���������ɹ�������һ��table�������ݣ�����Ԫ���ɱ������;�����������ʧ�ܣ�����nil
]]
local function unpack(mqttver,s)
	rcvpacket = {}

	local function connack(d)
		print("connack",common.binstohexs(d))
		rcvpacket.suc = (sbyte(d,2)==0)
		rcvpacket.reason = sbyte(d,2)
		return true
	end
	
	local function suback(d)
		print("suback or unsuback",common.binstohexs(d))
		if slen(d) < 2 then return end
		rcvpacket.seq = ssub(d,1,2)
		return true
	end
	
	local function puback(d)
		print("puback",common.binstohexs(d))
		if slen(d) < 2 then return end
		rcvpacket.seq = ssub(d,1,2)
		return true
	end
	
	local function publish(d)
		print("publish",common.binstohexs(d)) --������̫��ʱ���ܴ򿪣��ڴ治��
		if slen(d) < 4 then return end
		local _,tplen = lpack.unpack(ssub(d,1,2),">H")		
		local pay = (rcvpacket.qos > 0 and 5 or 3)
		if slen(d) < tplen+pay-1 then return end
		rcvpacket.topic = ssub(d,3,2+tplen)
		
		if rcvpacket.qos > 0 then
			rcvpacket.seq = ssub(d,tplen+3,tplen+4)
			pay = 5
		end
		rcvpacket.payload = ssub(d,tplen+pay,-1)
		return true
	end
	
	local function empty()
		return true
	end

	local procer =
	{
		[CONNACK] = connack,
		[SUBACK] = suback,
		[PUBACK] = puback,
		[PUBLISH] = publish,
		[PINGRSP] = empty,
		[UNSUBACK] = suback,
	}
	local d1,d2,d3,typ,len = iscomplete(s)	
	if not procer[typ] then print("unpack unknwon typ",typ) return end
	rcvpacket.typ = typ
	rcvpacket.qos = bit.rshift(bit.band(sbyte(s,1),0x06),1)
	rcvpacket.dup = bit.rshift(bit.band(sbyte(s,1),0x08),3)==1
	print("unpack",typ,rcvpacket.qos,(slen(s) > 200) and "" or common.binstohexs(s))
	return procer[typ](ssub(s,slen(s)-len+1,-1)) and rcvpacket or nil
end


--һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
--���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
--�������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20

--mqtt clients�洢��
local tclients = {}

--[[
��������getclient
����  ������һ��mqtt client��tclients�е�����
����  ��
		sckidx��mqtt client��Ӧ��socket����
����ֵ��sckidx��Ӧ��mqtt client��tclients�е�����
]]
local function getclient(sckidx)
	for k,v in pairs(tclients) do
		if v.sckidx==sckidx then return k end
	end
end

--[[
��������mqttconncb
����  ������MQTT CONNECT���ĺ���첽�ص�����
����  ��		
		sckidx��socket idx
		result�� bool���ͣ����ͽ����trueΪ�ɹ�������Ϊʧ��
		tpara��table���ͣ�{key="MQTTCONN",val=CONNECT��������}
����ֵ����
]]
function mqttconncb(sckidx,result,tpara)
	--��MQTT CONNECT�������ݱ��������������ʱDUP_TIME����û���յ�CONNACK����CONNACK����ʧ�ܣ�����Զ��ط�CONNECT����
	--�ط��Ĵ���������mqttdup.lua��
	mqttdup.ins(sckidx,tmqttpack["MQTTCONN"].mqttduptyp,tpara.val)
end

--[[
��������mqttconndata
����  �����MQTT CONNECT��������
����  ��
		sckidx��socket idx
����ֵ��CONNECT�������ݺͱ��Ĳ���
]]
function mqttconndata(sckidx)
	local mqttclientidx = getclient(sckidx)
	return pack(tclients[mqttclientidx].mqttver,
				CONNECT,
				tclients[mqttclientidx].keepalive,
				tclients[mqttclientidx].clientid,
				{
					flg=tclients[mqttclientidx].willflg or 0,
					qos=tclients[mqttclientidx].willqos or 0,
					retain=tclients[mqttclientidx].willretain or 0,
					topic=tclients[mqttclientidx].willtopic or "",
					payload=tclients[mqttclientidx].willpayload or "",
				},
				tclients[mqttclientidx].user,
				tclients[mqttclientidx].password,
				tclients[mqttclientidx].cleansession or 1)
end

--[[
��������mqttsubcb
����  ������SUBSCRIBE���ĺ���첽�ص�����
����  ��		
		sckidx��socket idx
		result�� bool���ͣ����ͽ����trueΪ�ɹ�������Ϊʧ��
		tpara��table���ͣ�{key="MQTTSUB", val=para, usertag=usertag, ackcb=ackcb}
����ֵ����
]]
local function mqttsubcb(sckidx,result,tpara)	
	--���·�װMQTT SUBSCRIBE���ģ��ظ���־��Ϊtrue�����кź�topic������ԭʼֵ�����ݱ��������������ʱDUP_TIME����û���յ�SUBACK������Զ��ط�SUBSCRIBE����
	--�ط��Ĵ���������mqttdup.lua��
	mqttdup.ins(sckidx,tpara.key,pack(tclients[getclient(sckidx)].mqttver,SUBSCRIBE,tpara.val),tpara.val.seq,tpara.ackcb,tpara.usertag)
end

--[[
��������mqttpubcb
����  ������PUBLISH���ĺ���첽�ص�����
����  ��		
		sckidx��socket idx
		result�� bool���ͣ����ͽ����trueΪ�ɹ�������Ϊʧ��
		tpara��table���ͣ�{key="MQTTPUB", val=para, qos=qos, usertag=usertag, ackcb=ackcb}
����ֵ����
]]
local function mqttpubcb(sckidx,result,tpara)	
	if tpara.qos==0 then
		if tpara.ackcb then tpara.ackcb(tpara.usertag,result) end
	elseif tpara.qos==1 then
		--���·�װMQTT PUBLISH���ģ��ظ���־��Ϊtrue�����кš�topic��payload������ԭʼֵ�����ݱ��������������ʱDUP_TIME����û���յ�PUBACK������Զ��ط�PUBLISH����
		--�ط��Ĵ���������mqttdup.lua��
		mqttdup.ins(sckidx,tpara.key,pack(tclients[getclient(sckidx)].mqttver,PUBLISH,tpara.val),tpara.val.seq,tpara.ackcb,tpara.usertag)
	end	
end

--[[
��������mqttdiscb
����  ������MQTT DICONNECT���ĺ���첽�ص�����
����  ��		
		sckidx��socket idx
		result�� bool���ͣ����ͽ����trueΪ�ɹ�������Ϊʧ��
		tpara��table���ͣ�{key="MQTTDISC", val=data, usertag=usrtag}
����ֵ����
]]
function mqttdiscb(sckidx,result,tpara)
	--�ر�socket����
	tclients[getclient(sckidx)].discing = true
	socket.disconnect(sckidx,tpara.usertag)
end

--[[
��������mqttdiscdata
����  �����MQTT DISCONNECT��������
����  ��
		sckidx��socket idx
����ֵ��DISCONNECT�������ݺͱ��Ĳ���
]]
function mqttdiscdata(sckidx)
	return pack(tclients[getclient(sckidx)].mqttver,DISCONNECT)
end

--[[
��������disconnect
����  ������MQTT DISCONNECT����
����  ��
		sckidx��socket idx
		usrtag���û��Զ�����
����ֵ��true��ʾ�����˶�����nil��ʾû�з���
]]
local function disconnect(sckidx,usrtag)
	return mqttsnd(sckidx,"MQTTDISC",usrtag)
end

--[[
��������mqttpingreqdata
����  �����MQTT PINGREQ��������
����  ��
		sckidx��socket idx
����ֵ��PINGREQ�������ݺͱ��Ĳ���
]]
function mqttpingreqdata(sckidx)
	return pack(tclients[getclient(sckidx)].mqttver,PINGREQ)
end

--[[
��������pingreq
����  ������MQTT PINGREQ����
����  ��
		sckidx��socket idx
����ֵ����
]]
local function pingreq(sckidx)
	local mqttclientidx = getclient(sckidx)
	mqttsnd(sckidx,"MQTTPINGREQ")
	if not sys.timer_is_active(disconnect,sckidx) then
		--������ʱ�����������ʱ��+30���ڣ�û���յ�pingrsp������MQTT DISCONNECT����
		sys.timer_start(disconnect,(tclients[mqttclientidx].keepalive+30)*1000,sckidx)
	end
end

--[[
��������snd
����  �����÷��ͽӿڷ�������
����  ��
		sckidx��socket idx
        data�����͵����ݣ��ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.data��
		para�����͵Ĳ������ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.para�� 
����ֵ�����÷��ͽӿڵĽ�������������ݷ����Ƿ�ɹ��Ľ�������ݷ����Ƿ�ɹ��Ľ����ntfy�е�SEND�¼���֪ͨ����trueΪ�ɹ�������Ϊʧ��
]]
function snd(sckidx,data,para)
	return socket.send(sckidx,data,para)
end

--mqttӦ�ñ��ı�
tmqttpack =
{
	MQTTCONN = {sndpara="MQTTCONN",mqttyp=CONNECT,mqttduptyp="CONN",mqttdatafnc=mqttconndata,sndcb=mqttconncb},
	MQTTPINGREQ = {sndpara="MQTTPINGREQ",mqttyp=PINGREQ,mqttdatafnc=mqttpingreqdata},
	MQTTDISC = {sndpara="MQTTDISC",mqttyp=DISCONNECT,mqttdatafnc=mqttdiscdata,sndcb=mqttdiscb},
}

local function getidbysndpara(para)
	for k,v in pairs(tmqttpack) do
		if v.sndpara==para then return k end
	end
end

--[[
��������mqttsnd
����  ��MQTT���ķ����ܽӿڣ����ݱ������ͣ���mqttӦ�ñ��ı����ҵ����������Ȼ��������
����  ��
		sckidx��socket idx
        typ����������
		usrtag���û��Զ�����
����ֵ��true��ʾ�����˶�����nil��ʾû�з���
]]
function mqttsnd(sckidx,typ,usrtag)
	if not tmqttpack[typ] then print("mqttsnd typ error",typ) return end
	local mqttyp = tmqttpack[typ].mqttyp
	local dat,para = tmqttpack[typ].mqttdatafnc(sckidx)
	
	if mqttyp==CONNECT then
		if tmqttpack[typ].mqttduptyp then mqttdup.rmv(sckidx,tmqttpack[typ].mqttduptyp) end
		if not snd(sckidx,dat,{key=tmqttpack[typ].sndpara,val=dat}) and tmqttpack[typ].sndcb then
			tmqttpack[typ].sndcb(sckidx,false,{key=tmqttpack[typ].sndpara,val=dat})
		end
	elseif mqttyp==PINGREQ then
		snd(sckidx,dat,{key=tmqttpack[typ].sndpara})
	elseif mqttyp==DISCONNECT then
		if not snd(sckidx,dat,{key=tmqttpack[typ].sndpara,usertag=usrtag}) and tmqttpack[typ].sndcb then
			tmqttpack[typ].sndcb(sckidx,false,{key=tmqttpack[typ].sndpara,usertag=usrtag})
		end		
	end	
	
	return true
end

--[[
��������reconn
����  ��socket������̨����
        һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
        ���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
        �������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
����  ��
		sckidx��socket idx
����ֵ����
]]
local function reconn(sckidx)
	local mqttclientidx = getclient(sckidx)
	print("reconn",mqttclientidx,tclients[mqttclientidx].sckreconncnt,tclients[mqttclientidx].sckconning,tclients[mqttclientidx].sckreconncyclecnt)
	--sckconning��ʾ���ڳ������Ӻ�̨��һ��Ҫ�жϴ˱����������п��ܷ��𲻱�Ҫ������������sckreconncnt���ӣ�ʵ�ʵ�������������
	if tclients[mqttclientidx].sckconning then return end
	--һ�����������ڵ�����
	if tclients[mqttclientidx].sckreconncnt < RECONN_MAX_CNT then		
		tclients[mqttclientidx].sckreconncnt = tclients[mqttclientidx].sckreconncnt+1
		link.shut()
		for k,v in pairs(tclients) do
			connect(v.sckidx,v.prot,v.host,v.port)
		end
		
	--һ���������ڵ�������ʧ��
	else
		tclients[mqttclientidx].sckreconncnt,tclients[mqttclientidx].sckreconncyclecnt = 0,tclients[mqttclientidx].sckreconncyclecnt+1
		if tclients[mqttclientidx].sckreconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			if tclients[mqttclientidx].sckerrcb then
				tclients[mqttclientidx].sckreconncnt=0
				tclients[mqttclientidx].sckreconncyclecnt=0
				tclients[mqttclientidx].sckerrcb("CONNECT")
			else
				sys.restart("connect fail")
			end
		else
			sys.timer_start(reconn,RECONN_CYCLE_PERIOD*1000,sckidx)
		end		
	end
end

--[[
��������ntfy
����  ��socket״̬�Ĵ�����
����  ��
        idx��number���ͣ�socket��ά����socket idx��������socket.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        evt��string���ͣ���Ϣ�¼�����
		result�� bool���ͣ���Ϣ�¼������trueΪ�ɹ�������Ϊʧ��
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ�Ŀǰֻ����SEND���͵��¼����õ��˴˲������������socket.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
����ֵ����
]]
function ntfy(idx,evt,result,item)
	local mqttclientidx = getclient(idx)
	print("ntfy",evt,result,item)
	--���ӽ��������socket.connect����첽�¼���
	if evt == "CONNECT" then
		tclients[mqttclientidx].sckconning = false
		--���ӳɹ�
		if result then
			tclients[mqttclientidx].sckconnected=true
			tclients[mqttclientidx].sckreconncnt=0
			tclients[mqttclientidx].sckreconncyclecnt=0
			tclients[mqttclientidx].sckrcvs=""
			--ֹͣ������ʱ��
			sys.timer_stop(reconn,idx)
			--����mqtt connect����
			mqttsnd(idx,"MQTTCONN")
		--����ʧ��
		else
			--RECONN_PERIOD�������
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end	
	--���ݷ��ͽ��������socket.send����첽�¼���
	elseif evt == "SEND" then
		if not result then
			link.shut()
		else
			if item.para then
				if item.para.key=="MQTTPUB" then
					mqttpubcb(idx,result,item.para)
				elseif item.para.key=="MQTTSUB" then
					mqttsubcb(idx,result,item.para)
				elseif item.para.key=="MQTTDUP" then
					mqttdupcb(idx,result,item.data)
				else
					local id = getidbysndpara(item.para.key)
					print("item.para",type(item.para) == "table",type(item.para) == "table" and item.para.typ or item.para,id)
					if id and tmqttpack[id].sndcb then tmqttpack[id].sndcb(idx,result,item.para) end
				end
			end
		end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and result == "CLOSED" then
		sys.timer_stop(pingreq,idx)
		mqttdup.rmvall(idx)
		tclients[mqttclientidx].sckconnected=false
		tclients[mqttclientidx].mqttconnected=false
		tclients[mqttclientidx].sckrcvs=""
		if tclients[mqttclientidx].discing then
			if tclients[mqttclientidx].discb then tclients[mqttclientidx].discb() end
			tclients[mqttclientidx].discing = false
		else
			reconn(idx)
		end
	--���������Ͽ�������link.shut����첽�¼���
	elseif evt == "STATE" and result == "SHUTED" then
		sys.timer_stop(pingreq,idx)
		mqttdup.rmvall(idx)
		tclients[mqttclientidx].sckconnected=false
		tclients[mqttclientidx].mqttconnected=false
		tclients[mqttclientidx].sckrcvs=""
		reconn(idx)
	--���������Ͽ�������socket.disconnect����첽�¼���
	elseif evt == "DISCONNECT" then
		sys.timer_stop(pingreq,idx)
		mqttdup.rmvall(idx)
		tclients[mqttclientidx].sckconnected=false
		tclients[mqttclientidx].mqttconnected=false
		tclients[mqttclientidx].sckrcvs=""
		if item=="USER" then
			if tclients[mqttclientidx].discb then tclients[mqttclientidx].discb() end
			tclients[mqttclientidx].discing = false
		else
			reconn(idx)
		end
	--���������Ͽ��������٣�����socket.close����첽�¼���
	elseif evt == "CLOSE" then
		sys.timer_stop(pingreq,idx)
		mqttdup.rmvall(idx)
		local cb = tclients[mqttclientidx].destroycb
		table.remove(tclients,mqttclientidx)
		if cb then cb() end
	end
	--�����������Ͽ�������·����������
	if smatch((type(result)=="string") and result or "","ERROR") then
		link.shut()
	end
end

--[[
��������connack
����  ������������·���MQTT CONNACK����
����  ��
        sckidx��socket idx
		packet��������ı��ĸ�ʽ��table����{suc=�Ƿ����ӳɹ�}
����ֵ����
]]
local function connack(sckidx,packet)
	local mqttclientidx = getclient(sckidx)
	print("connack",packet.suc)
	if packet.suc then
		tclients[mqttclientidx].mqttconnected = true
		mqttdup.rmv(sckidx,tmqttpack["MQTTCONN"].mqttduptyp)
		if tclients[mqttclientidx].connectedcb then tclients[mqttclientidx].connectedcb() end
	else
		if tclients[mqttclientidx].connecterrcb then tclients[mqttclientidx].connecterrcb(packet.reason) end
	end
end

--[[
��������suback
����  ������������·���MQTT SUBACK����
����  ��
        sckidx��socket idx
		packet��������ı��ĸ�ʽ��table����{seq=��Ӧ��SUBSCRIBE�������к�}
����ֵ����
]]
local function suback(sckidx,packet)
	local mqttclientidx = getclient(sckidx)
	local typ,cb,cbtag = mqttdup.getyp(sckidx,packet.seq)
	print("suback",common.binstohexs(packet.seq))
	mqttdup.rmv(sckidx,nil,nil,packet.seq)
	if cb then cb(cbtag,true) end
end

--[[
��������puback
����  ������������·���MQTT PUBACK����
����  ��
        sckidx��socket idx
		packet��������ı��ĸ�ʽ��table����{seq=��Ӧ��PUBLISH�������к�}
����ֵ����
]]
local function puback(sckidx,packet)
	local mqttclientidx = getclient(sckidx)
	local typ,cb,cbtag = mqttdup.getyp(sckidx,packet.seq)
	print("puback",common.binstohexs(packet.seq),typ)
	mqttdup.rmv(sckidx,nil,nil,packet.seq)
	if cb then cb(cbtag,true) end
end

--[[
��������svrpublish
����  ������������·���MQTT PUBLISH����
����  ��
        sckidx��socket idx
		mqttpacket��������ı��ĸ�ʽ��table����{qos=,topic,seq,payload}
����ֵ����
]]
local function svrpublish(sckidx,mqttpacket)
	local mqttclientidx = getclient(sckidx)
	print("svrpublish",mqttpacket.topic,mqttpacket.seq,mqttpacket.payload)	
	if mqttpacket.qos == 1 then snd(sckidx,pack(tclients[mqttclientidx].mqttver,PUBACK,mqttpacket.seq)) end
	if tclients[mqttclientidx].evtcbs then
		if tclients[mqttclientidx].evtcbs["MESSAGE"] then tclients[mqttclientidx].evtcbs["MESSAGE"](common.utf8togb2312(mqttpacket.topic),mqttpacket.payload,mqttpacket.qos) end
	end
end

--[[
��������pingrsp
����  ������������·���MQTT PINGRSP����
����  ��
		sckidx��socket idx
����ֵ����
]]
local function pingrsp(sckidx)
	sys.timer_stop(disconnect,sckidx)
end

--�������·����Ĵ����
mqttcmds = {
	[CONNACK] = connack,
	[SUBACK] = suback,
	[PUBACK] = puback,
	[PUBLISH] = svrpublish,
	[PINGRSP] = pingrsp,
}

--[[
��������datinactive
����  ������ͨ���쳣����
����  ��
		sckidx��socket idx
����ֵ����
]]
local function datinactive(sckidx)
    sys.restart("SVRNODATA")
end

--[[
��������checkdatactive
����  �����¿�ʼ��⡰����ͨ���Ƿ��쳣��
����  ��
		sckidx��socket idx
����ֵ����
]]
local function checkdatactive(sckidx)
	local mqttclientidx = getclient(sckidx)
	sys.timer_start(datinactive,tclients[mqttclientidx].keepalive*1000*3+30000,sckidx) --3������ʱ��+�����
end

--[[
��������rcv
����  ��socket�������ݵĴ�����
����  ��
        idx ��socket��ά����socket idx��������socket.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
function rcv(idx,data)
	local mqttclientidx = getclient(idx)
	print("rcv",slen(data)>200 and slen(data) or common.binstohexs(data))
	sys.timer_start(pingreq,tclients[mqttclientidx].keepalive*1000/2,idx)	
	tclients[mqttclientidx].sckrcvs = tclients[mqttclientidx].sckrcvs..data

	local f,h,t = iscomplete(tclients[mqttclientidx].sckrcvs)

	while f do
		data = ssub(tclients[mqttclientidx].sckrcvs,h,t)
		tclients[mqttclientidx].sckrcvs = ssub(tclients[mqttclientidx].sckrcvs,t+1,-1)
		local packet = unpack(tclients[mqttclientidx].mqttver,data)
		if packet and packet.typ and mqttcmds[packet.typ] then
			mqttcmds[packet.typ](idx,packet)
			if packet.typ ~= CONNACK and packet.typ ~= SUBACK then
				checkdatactive(idx)
			end
		end
		f,h,t = iscomplete(tclients[mqttclientidx].sckrcvs)
	end
end


--[[
��������connect
����  ����������̨��������socket���ӣ�
        ������������Ѿ�׼���ã���������Ӻ�̨��������������ᱻ���𣬵���������׼���������Զ�ȥ���Ӻ�̨
		ntfy��socket״̬�Ĵ�����
		rcv��socket�������ݵĴ�����
����  ��
		sckidx��socket idx
		prot��string���ͣ������Э�飬��֧��"TCP"��"UDP"[��ѡ]
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
����ֵ����
]]
function connect(sckidx,prot,host,port)
	socket.connect(sckidx,prot,host,port,ntfy,rcv)
	tclients[getclient(sckidx)].sckconning=true
end

--[[
��������mqttdupcb
����  ��mqttdup�д������ط����ķ��ͺ���첽�ص�
����  ��
		sckidx��socket idx
		result�� bool���ͣ����ͽ����trueΪ�ɹ�������Ϊʧ��
		v����������
����ֵ����
]]
function mqttdupcb(sckidx,result,v)
	mqttdup.rsm(sckidx,v)
end

--[[
��������mqttdupind
����  ��mqttdup�д������ط����Ĵ���
����  ��
		sckidx��socket idx
		s����������
����ֵ����
]]
local function mqttdupind(sckidx,s)
	if not snd(sckidx,s,{key="MQTTDUP"}) then mqttdupcb(sckidx,false,s) end
end

--[[
��������mqttdupfail
����  ��mqttdup�д������ط����ģ�������ط������ڣ�������ʧ�ܵ�֪ͨ��Ϣ����
����  ��
		sckidx��socket idx
		t�����ĵ��û��Զ�������
		s����������
		cb���û��ص�����
		cbtag���û��ص������ĵ�һ������
����ֵ����
]]
local function mqttdupfail(sckidx,t,s,cb,cbtag)
    print("mqttdupfail",t)
	if cb then cb(cbtag,false) end
end

--mqttdup�ط���Ϣ��������
local procer =
{
	MQTT_DUP_IND = mqttdupind,
	MQTT_DUP_FAIL = mqttdupfail,
}
--ע����Ϣ�Ĵ�����
sys.regapp(procer)


local tmqtt = {}
tmqtt.__index = tmqtt


--[[
��������create
����  ������һ��mqtt client
����  ��
		prot��string���ͣ������Э�飬��֧��"TCP"��"UDP"[��ѡ]
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
		ver��string���ͣ�MQTTЭ��汾�ţ���֧��"3.1"��"3.1.1"��Ĭ��"3.1"
����ֵ����
]]
function create(prot,host,port,ver)
	if #tclients>=2 then assert(false,"tclients maxcnt error") return end
	local mqtt_client =
	{
		prot=prot,
		host=host,
		port=port,		
		sckidx=socket.SCK_MAX_CNT-#tclients,
		sckconning=false,
		sckconnected=false,
		sckreconncnt=0,
		sckreconncyclecnt=0,
		sckrcvs="",
		mqttconnected=false,
		mqttver = ver or "3.1",
	}
	setmetatable(mqtt_client,tmqtt)
	table.insert(tclients,mqtt_client)
	return(mqtt_client)
end

--[[
��������change
����  ���ı�һ��mqtt client��socket����
����  ��
		prot��string���ͣ������Э�飬��֧��"TCP"��"UDP"[��ѡ]
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
����ֵ����
]]
function tmqtt:change(prot,host,port)
	self.prot,self.host,self.port=prot or self.prot,host or self.host,port or self.port
end

--[[
��������destroy
����  ������һ��mqtt client
����  ��
		destroycb��function���ͣ�mqtt client���ٺ�Ļص�����[��ѡ]
����ֵ����
]]
function tmqtt:destroy(destroycb)
	local k,v
	self.destroycb = destroycb
	for k,v in pairs(tclients) do
		if v.sckidx==self.sckidx then
			socket.close(v.sckidx)
		end
	end
end

--[[
��������disconnect
����  ���Ͽ�һ��mqtt client�����ҶϿ�socket
����  ��
		discb��function���ͣ��Ͽ���Ļص�����[��ѡ]
����ֵ����
]]
function tmqtt:disconnect(discb)
	print("tmqtt:disconnect",self.discing,self.mqttconnected,self.sckconnected)
	sys.timer_stop(datinactive,self.sckidx)
	if self.discing or not self.mqttconnected or not self.sckconnected then
		if discb then discb() end
		return
	end
	self.discb = discb
	if not disconnect(self.sckidx,"USER") and discb then discb() end
end

--[[
��������configwill
����  ��������������
����  ��
		flg��number���ͣ�������־����֧��0��1
		qos��number���ͣ��������˷���������Ϣ�ķ��������ȼ�����֧��0,1,2
		retain��number���ͣ�����������־����֧��0��1
		topic��string���ͣ��������˷���������Ϣ�����⣬gb2312����	
		payload��string���ͣ��������˷���������Ϣ���غɣ�gb2312����
����ֵ����
]]
function tmqtt:configwill(flg,qos,retain,topic,payload)
	self.willflg=flg or 0
	self.willqos=qos or 0
	self.willretain=retain or 0
	self.willtopic=topic or ""
	self.willpayload=payload or ""
end

--[[
��������setcleansession
����  ������clean session��־
����  ��
		flg��number���ͣ�clean session��־����֧��0��1��Ĭ��Ϊ1
����ֵ����
]]
function tmqtt:setcleansession(flg)
	self.cleansession=flg or 1
end

--[[
��������connect
����  ������mqtt������
����  ��
		clientid��string���ͣ�client identifier��gb2312����[��ѡ]
		keepalive��number���ͣ�����ʱ�䣬��λ��[��ѡ��Ĭ��600]
		user��string���ͣ��û�����gb2312����[��ѡ��Ĭ��""]
		password��string���ͣ����룬gb2312����[��ѡ��Ĭ��""]		
		connectedcb��function���ͣ�mqtt���ӳɹ��Ļص�����[��ѡ]
		connecterrcb��function���ͣ�mqtt����ʧ�ܵĻص�����[��ѡ]
		sckerrcb��function���ͣ�socket����ʧ�ܵĻص�����[��ѡ]
����ֵ����
]]
function tmqtt:connect(clientid,keepalive,user,password,connectedcb,connecterrcb,sckerrcb)
	self.clientid=clientid
	self.keepalive=keepalive or 600
	self.user=user or ""
	self.password=password or ""
	--if autoreconnect==nil then autoreconnect=true end
	--self.autoreconnect=autoreconnect
	self.connectedcb=connectedcb
	self.connecterrcb=connecterrcb
	self.sckerrcb=sckerrcb
	
	tclients[getclient(self.sckidx)]=self
	
	if self.mqttconnected then print("tmqtt:connect already connected") return end
	if not self.sckconnected then
		connect(self.sckidx,self.prot,self.host,self.port)
		checkdatactive(self.sckidx)
	elseif not self.mqttconnected then
		mqttsnd(self.sckidx,"MQTTCONN")
	else
		if connectedcb then connectedcb() end
	end
end

--[[
��������publish
����  ������һ����Ϣ
����  ��
		topic��string���ͣ���Ϣ���⣬gb2312����[��ѡ]
		payload�����������ݣ���Ϣ���أ��û��Զ�����룬���ļ�������������κα���ת������[��ѡ]
		flags��number���ͣ�qos��retain��־����֧��0��1��4��5[��ѡ��Ĭ��0]
				0��ʾ��qos=0��retain=0
				1��ʾ��qos=1��retain=0
				4��ʾ��qos=0��retain=1
				5��ʾ��qos=1��retain=1
		ackcb��function���ͣ�qosΪ1ʱ��ʾ�յ�PUBACK�Ļص�����,qosΪ0ʱ��Ϣ���ͽ���Ļص�����[��ѡ]
		usertag��string���ͣ��û��ص�����ackcb�õ��ĵ�һ������[��ѡ]
����ֵ����
]]
function tmqtt:publish(topic,payload,flags,ackcb,usertag)
	--���mqtt����״̬
	if not self.mqttconnected then
		print("tmqtt:publish not connected")
		if ackcb then ackcb(usertag,false) end
		return
	end
	
	if flags and flags~=0 and flags~=1 and flags~=4 and flags~=5 then assert(false,"tmqtt:publish not support flags "..flags) return end
	local qos,retain = flags and (bit.band(flags,0x03)) or 0,flags and (bit.isset(flags,2) and 1 or 0) or 0
	--print("tmqtt:publish",flags,qos,retain)
	--���publish����
	local dat,para = pack(self.mqttver,PUBLISH,{qos=qos,retain=retain,topic=topic,payload=payload})
	
	--����
	local tpara = {key="MQTTPUB",val=para,qos=qos,retain=retain,usertag=usertag,ackcb=ackcb}
	if not snd(self.sckidx,dat,tpara) then
		mqttpubcb(self.sckidx,false,tpara)
	end
end

--[[
��������subscribe
����  ����������
����  ��
		topics��table���ͣ�һ�����߶�����⣬������gb2312���룬�����ȼ���֧��0��1��{{topic="/topic1",qos=�����ȼ�}, {topic="/topic2",qos=�����ȼ�}, ...}[��ѡ]
		ackcb��function���ͣ���ʾ�յ�SUBACK�Ļص�����[��ѡ]
		usertag��string���ͣ��û��ص�����ackcb�õ��ĵ�һ������[��ѡ]
����ֵ����
]]
function tmqtt:subscribe(topics,ackcb,usertag)
	--���mqtt����״̬
	if not self.mqttconnected then
		print("tmqtt:subscribe not connected")
		if ackcb then ackcb(usertag,false) end
		return
	end
	
	--��֧��qos 0��1
	for k,v in pairs(topics) do
		if v.qos==2 then assert(false,"tmqtt:publish not support qos 2") return end
	end

	--���subscribe����
	local dat,para = pack(self.mqttver,SUBSCRIBE,{topic=topics})
	
	--����
	local tpara = {key="MQTTSUB", val=para, usertag=usertag, ackcb=ackcb}
	if not snd(self.sckidx,dat,tpara) then
		mqttsubcb(self.sckidx,false,tpara)
	end
end

--[[
��������regevtcb
����  ��ע���¼��Ļص�����
����  ��
		evtcbs��һ�Ի��߶��evt��cb����ʽΪ{evt=cb,...}}��evtȡֵ���£�
				"MESSAGE"����ʾ�ӷ������յ���Ϣ������cbʱ����ʽΪcb(topic,payload,qos)
����ֵ����
]]
function tmqtt:regevtcb(evtcbs)
	self.evtcbs=evtcbs	
end

--[[
��������getstatus
����  ����ȡMQTT CLIENT��״̬
����  ����
����ֵ��MQTT CLIENT��״̬��string���ͣ���4��״̬��
		DISCONNECTED��δ����״̬
		CONNECTING��������״̬
		CONNECTED������״̬
		DISCONNECTING���Ͽ�������״̬
]]
function tmqtt:getstatus()
	if self.mqttconnected then
		return self.discing and "DISCONNECTING" or "CONNECTED"
	elseif self.sckconnected or self.sckconning then
		return "CONNECTING"
	else
		return "DISCONNECTED"
	end
end
