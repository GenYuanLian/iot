--[[
ģ�����ƣ�������·��SOCKET����
ģ�鹦�ܣ��������缤�SOCKET�Ĵ��������ӡ������շ���״̬ά��
ģ������޸�ʱ�䣺2017.02.14
]]

--����ģ��,����������
local base = _G
local string = require"string"
local table = require"table"
local sys = require"sys"
local ril = require"ril"
local net = require"net"
local rtos = require"rtos"
local sim = require"sim"
local socket = require"tcpipsock"
module(...,package.seeall)

--���س��õ�ȫ�ֺ���������
local print = base.print
local pairs = base.pairs
local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request
local extapn
--���socket id����0��ʼ������ͬʱ֧�ֵ�socket��������8��
local MAXLINKS = 7
--IP��������ʧ��ʱ���5������
local IPSTART_INTVL = 5000

--socket���ӱ�
local linklist = {}
--ipstatus��IP����״̬
--sckconning���Ƿ�������������
--shuting���Ƿ����ڹر���������
local ipstatus,sckconning,shuting = "IP INITIAL"
--GPRS�������總��״̬��"1"���ţ�����δ����
local cgatt
--apn���û���������
local apnname = "CMNET"
local username=''
local password=''
--socket������������������connectnoretinterval�����û���κ�Ӧ�����connectnoretrestartΪtrue������������
local connectnoretrestart = false
local connectnoretinterval
--apnflg��������ģ���Ƿ��Զ���ȡapn��Ϣ��true�ǣ�false�����û�Ӧ�ýű��Լ�����setapn�ӿ�����apn���û���������
--checkciicrtm��ִ��AT+CIICR�����������checkciicrtm��checkciicrtm�����û�м���ɹ����������������;ִ��AT+CIPSHUT����������
--flymode���Ƿ��ڷ���ģʽ
--updating���Ƿ�����ִ��Զ����������(update.lua)
--dbging���Ƿ�����ִ��dbg����(dbg.lua)
--ntping���Ƿ�����ִ��NTPʱ��ͬ������(ntp.lua)
--shutpending���Ƿ��еȴ�����Ľ���AT+CIPSHUT����
local apnflag,checkciicrtm,flymode,updating,dbging,ntping,shutpending,pdpdeacting=true


--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������linkǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("link",...)
end

--[[
��������setapn
����  ������apn���û���������
����  ��
		a��apn
		b���û���
		c������
����ֵ����
]]
function setapn(a,b,c)
	apnname,username,password = a,b or '',c or ''
	apnflag=false
end

--[[
��������getapn
����  ����ȡapn
����  ����
����ֵ��apn
]]
function getapn()
	return apnname
end

--[[
��������connectingtimerfunc
����  ��socket���ӳ�ʱû��Ӧ������
����  ��
		id��socket id
����ֵ����
]]
local function connectingtimerfunc(id)
	print("connectingtimerfunc",id,connectnoretrestart)
	if connectnoretrestart then
		sys.restart("link.connectingtimerfunc")
	end
end

--[[
��������stopconnectingtimer
����  ���رա�socket���ӳ�ʱû��Ӧ�𡱶�ʱ��
����  ��
		id��socket id
����ֵ����
]]
local function stopconnectingtimer(id)
	print("stopconnectingtimer",id)
	sys.timer_stop(connectingtimerfunc,id)
end

--[[
��������startconnectingtimer
����  ��������socket���ӳ�ʱû��Ӧ�𡱶�ʱ��
����  ��
		id��socket id
����ֵ����
]]
local function startconnectingtimer(id)
	print("startconnectingtimer",id,connectnoretrestart,connectnoretinterval)
	if id and connectnoretrestart and connectnoretinterval and connectnoretinterval > 0 then
		sys.timer_start(connectingtimerfunc,connectnoretinterval,id)
	end
end

--[[
��������setconnectnoretrestart
����  �����á�socket���ӳ�ʱû��Ӧ�𡱵Ŀ��Ʋ���
����  ��
		flag�����ܿ��أ�true����false
		interval����ʱʱ�䣬��λ����
����ֵ����
]]
function setconnectnoretrestart(flag,interval)
	connectnoretrestart = flag
	connectnoretinterval = interval
end

--[[
��������setupIP
����  �����ͼ���IP��������
����  ����
����ֵ����
]]
function setupIP()
	print("setupIP:",ipstatus,cgatt,flymode)
	--���������Ѽ�����ߴ��ڷ���ģʽ��ֱ�ӷ���
	if ipstatus ~= "IP INITIAL" or flymode then
		return
	end
	--gprs��������û�и�����
	if cgatt ~= "1" then
		print("setupIP: wait cgatt")
		return
	end

	socket.pdp_activate(apnname,username,password)
end

--[[
��������emptylink
����  ����ȡ���õ�socket id
����  ����
����ֵ�����õ�socket id�����û�п��õķ���nil
]]
local function emptylink()
	for i = 0,MAXLINKS do
		if linklist[i] == nil then
			return i
		end
	end

	return nil
end

--[[
��������validaction
����  �����ĳ��socket id�Ķ����Ƿ���Ч
����  ��
		id��socket id
		action������
����ֵ��true��Ч��false��Ч
]]
local function validaction(id,action)
	--socket��Ч
	if linklist[id] == nil then
		print("validaction:id nil",id)
		return false
	end

	--ͬһ��״̬���ظ�ִ��
	if action.."ING" == linklist[id].state then
		print("validaction:",action,linklist[id].state)
		return false
	end

	local ing = string.match(linklist[id].state,"(ING)",-3)

	if ing then
		--�����������ڴ���ʱ,������������,�������߹ر��ǿ��Ե�
		if action == "CONNECT" and linklist[id].state~= "SHUTING" then
			print("validaction: action running",linklist[id].state,action)
			return false
		end
	end

	-- ������������ִ��,����ִ��
	return true
end

--[[
��������openid
����  ������socket�Ĳ�����Ϣ
����  ��
		id��socket id
		notify��socket״̬������
		recv��socket���ݽ��մ�����
		tag��socket�������
����ֵ��true�ɹ���falseʧ��
]]
function openid(id,notify,recv,tag)
	--idԽ�����id��socket�Ѿ�����
	if id > MAXLINKS or linklist[id] ~= nil then
		print("error",id)
		return false
	end

	local link = {
		notify = notify,
		recv = recv,
		state = "INITIAL",
		tag = tag,
	}

	linklist[id] = link

	--����IP����
	if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" then
		setupIP()
	end

	return true
end

--[[
��������open
����  ������һ��socket
����  ��
		notify��socket״̬������
		recv��socket���ݽ��մ�����
		tag��socket�������
����ֵ��number���͵�id��ʾ�ɹ���nil��ʾʧ��
]]
function open(notify,recv,tag)
	local id = emptylink()

	if id == nil then
		return nil,"no empty link"
	end

	openid(id,notify,recv,tag)

	return id
end

--[[
��������close
����  ���ر�һ��socket�������socket�����в�����Ϣ��
����  ��
		id��socket id
����ֵ��true�ɹ���falseʧ��
]]
function close(id)
	print("close",id)
	--����Ƿ�����ر�
	if validaction(id,"CLOSE") == false then
		return false
	end
	--���ڹر�
	linklist[id].state = "CLOSING"

	socket.sock_close(id,1)

	return true
end

--[[
��������asyncLocalEvent
����  ��socket�첽֪ͨ��Ϣ�Ĵ�����
����  ��
		msg���첽֪ͨ��Ϣ"LINK_ASYNC_LOCAL_EVENT"
		cbfunc����Ϣ�ص�
		id��socket id
		val��֪ͨ��Ϣ�Ĳ���
����ֵ��true�ɹ���falseʧ��
]]
function asyncLocalEvent(msg,cbfunc,id,val)
	cbfunc(id,val)
end

--ע����ϢLINK_ASYNC_LOCAL_EVENT�Ĵ�����
sys.regapp(asyncLocalEvent,"LINK_ASYNC_LOCAL_EVENT")

--[[
��������connect
����  ��socket���ӷ���������
����  ��
		id��socket id
		protocol�������Э�飬TCP����UDP
		address����������ַ
		port���������˿�
����ֵ������ɹ�ͬ������true������false��
]]
function connect(id,protocol,address,port)
	print("connect",id,protocol,address,port,ipstatus,sckconning,shuting)
	--�����������Ӷ���
	if validaction(id,"CONNECT") == false or linklist[id].state == "CONNECTED" then
		return false
	end

	if cc and cc.anycallexist() then
		--�������ͨ������ ���ҵ�ǰ����ͨ����ʹ���첽֪ͨ����ʧ��
		print("connect:failed cause call exist")
		sys.dispatch("LINK_ASYNC_LOCAL_EVENT",statusind,id,"CONNECT FAIL")
		return true
	end

	local connstr = string.format("AT+CIPSTART=%d,\"%s\",\"%s\",%s",id,protocol,address,port)
	linklist[id].state = "CONNECTING"
	if (ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING") or sckconning or shuting then
		-- ip����δ׼�����ȼ���ȴ�
		linklist[id].pending = connstr
	else
		socket.sock_conn(id,(protocol=="TCP") and 0 or 1,tonumber(port),address)
		startconnectingtimer(id)
		sckconning = true
	end

	return true
end

--[[
��������disconnect
����  ���Ͽ�һ��socket���������socket�����в�����Ϣ��
����  ��
		id��socket id
����ֵ��true�ɹ���falseʧ��
]]
function disconnect(id)
	print("disconnect",id)
	--������Ͽ�����
	if validaction(id,"DISCONNECT") == false then
		return false
	end
	--�����socket id��Ӧ�����ӻ��ڵȴ��У���û����������
	if linklist[id].pending then
		linklist[id].pending = nil
		if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" and linklist[id].state == "CONNECTING" then
			print("disconnect: ip not ready",ipstatus)
			linklist[id].state = "DISCONNECTING"
			sys.dispatch("LINK_ASYNC_LOCAL_EVENT",closecnf,id,"DISCONNECT","OK")
			return
		end
	end

	linklist[id].state = "DISCONNECTING"
	--�Ͽ�����
	socket.sock_close(id,1)

	return true
end

--[[
��������send
����  ���������ݵ�������
����  ��
		id��socket id
		data��Ҫ���͵�����
����ֵ��true�ɹ���falseʧ��
]]
function send(id,data)
	--socket��Ч������socketδ����
	if linklist[id] == nil or linklist[id].state ~= "CONNECTED" then
		print("send:error",id)
		return false
	end

	if cc and cc.anycallexist() then
		-- �������ͨ������ ���ҵ�ǰ����ͨ����ʹ���첽֪ͨ����ʧ��
		print("send:failed cause call exist")
		return false
	end
	--ִ�����ݷ���
	print("send",id,string.len(data),(string.len(data) > 200) and "" or data)
	socket.sock_send(id,data)

	return true
end

--[[
��������getstate
����  ����ȡһ��socket������״̬
����  ��
		id��socket id
����ֵ��socket��Ч�򷵻�����״̬�����򷵻�"NIL LINK"
]]
function getstate(id)
	return linklist[id] and linklist[id].state or "NIL LINK"
end

--[[
��������recv
����  ��ĳ��socket�����ݽ��մ�����
����  ��
		id��socket id
		data�����յ�����������
����ֵ����
]]
local function recv(id,data)
	print("recv",id,string.len(data)>200 and "" or data)
	if not id or not linklist[id] then
		print("recv:error",id)
		return
	end
	--����socket id��Ӧ���û�ע������ݽ��մ�����
	if linklist[id].recv then
		linklist[id].recv(id,data)
	else
		print("recv:nil recv",id)
	end
end

--[[ ipstatus��ѯ���ص�״̬����ʾ
function linkstatus(data)
end
]]

--[[
��������usersckisactive
����  ���ж��û�������socket�����Ƿ��ڼ���״̬
����  ����
����ֵ��ֻҪ�κ�һ���û�socket��������״̬�ͷ���true�����򷵻�nil
]]
local function usersckisactive()
	for i = 0,MAXLINKS do
		--�û��Զ����socket��û��tagֵ
		if linklist[i] and not linklist[i].tag and linklist[i].state=="CONNECTED" then
			return true
		end
	end
end

--[[
��������usersckntfy
����  ���û�������socket����״̬�仯֪ͨ
����  ��
		id��socket id
����ֵ����
]]
local function usersckntfy(id)
	--����һ���ڲ���Ϣ"USER_SOCKET_CONNECT"��֪ͨ���û�������socket����״̬�����仯��
	if not linklist[id].tag then sys.dispatch("USER_SOCKET_CONNECT",usersckisactive()) end
end

--[[
��������sendcnf
����  ��socket���ݷ��ͽ��ȷ��
����  ��
		id��socket id
		result�����ͽ���ַ���
����ֵ����
]]
local function sendcnf(id,result)
	if not id or not linklist[id] then print("sendcnf:error",id) return end
	local str = string.match(result,"([%u ])")
	--����ʧ��
	if str == "TCP ERROR" or str == "UDP ERROR" or str == "ERROR" then
		linklist[id].state = result
	end
	--�����û�ע���״̬������
	linklist[id].notify(id,"SEND",result)
end

--[[
��������closecnf
����  ��socket�رս��ȷ��
����  ��
		id��socket id
		result���رս���ַ���
����ֵ����
]]
function closecnf(id,result)	
	--socket id��Ч
	if not id or not linklist[id] then
		print("closecnf:error",id)
		return
	end
	print("closecnf",id,result,linklist[id].state,shuting)
	--�����κε�close���,�������ǳɹ��Ͽ���,����ֱ�Ӱ������ӶϿ�����
	if linklist[id].state == "DISCONNECTING" then
		linklist[id].state = "CLOSED"
		linklist[id].notify(id,"DISCONNECT","OK")
		usersckntfy(id,false)
		stopconnectingtimer(id)
	--����ע��,���ά����������Ϣ,���urc��ע
	elseif linklist[id].state == "CLOSING" then		
		local tlink = linklist[id]
		usersckntfy(id,false)
		linklist[id] = nil
		tlink.notify(id,"CLOSE","OK")		
		stopconnectingtimer(id)
	elseif linklist[id].state == "SHUTING" or shuting then
		linklist[id].state = "CLOSED"
		linklist[id].notify(id,"STATE","SHUTED")
	else
		print("closecnf:error",linklist[id].state)
	end
end

--[[
��������statusind
����  ��socket״̬ת������
����  ��
		id��socket id
		state��״̬�ַ���
����ֵ����
]]
function statusind(id,state)	
	--socket��Ч
	if linklist[id] == nil then
		print("statusind:nil id",id)
		return
	end
	
	print("statusind",id,state,linklist[id].state)

    -- �췢ʧ�ܵ���ʾ����URC
	if state == "SEND FAIL" then
		if linklist[id].state == "CONNECTED" then
			linklist[id].notify(id,"SEND",state)
		else
			print("statusind:send fail state",linklist[id].state)
		end
		return
	end

	local evt
	--socket��������������ӵ�״̬�����߷��������ӳɹ���״̬֪ͨ
	if linklist[id].state == "CONNECTING" or state == "CONNECT OK" then
		--�������͵��¼�
		evt = "CONNECT"		
	else
		--״̬���͵��¼�
		evt = "STATE"
	end

	--�������ӳɹ�,����������Ȼ�����ڹر�״̬
	if state == "CONNECT OK" then
		linklist[id].state = "CONNECTED"		
	else
		linklist[id].state = "CLOSED"
	end
	--����usersckntfy�ж��Ƿ���Ҫ֪ͨ���û�socket����״̬�����仯��
	usersckntfy(id,state == "CONNECT OK")
	--�����û�ע���״̬������
	linklist[id].notify(id,evt,state)
	stopconnectingtimer(id)
end

--[[
��������connpend
����  ��ִ����IP����δ׼���ñ������socket��������
����  ����
����ֵ����
]]
local function connpend()
	for k,v in pairs(linklist) do
		print("connpend",v.pending)
		if v.pending then
			local id,protocol,address,port = string.match(v.pending,"AT%+CIPSTART=(%d+),\"(%a+)\",\"(.+)\",(%d+)")
			if id then
				id = tonumber(id)
				socket.sock_conn(id,(protocol=="TCP") and 0 or 1,tonumber(port),address)
				linklist[id].state = "CONNECTING"
				startconnectingtimer(id)
				sckconning = true
			end
			v.pending = nil
			break
		end
	end	
end

local ipstatusind
function regipstatusind()
	ipstatusind = true
end

--[[
��������setIPStatus
����  ������IP����״̬
����  ��
		status��IP����״̬
����ֵ����
]]
local function setIPStatus(status)
	print("setIPStatus:",status,ipstatus)

	if ipstatus ~= status then
		if ipstatusind then
			sys.dispatch("IP_STATUS_IND",status=="IP GPRSACT" or status=="IP PROCESSING" or status=="IP STATUS")
		end

		ipstatus = status
		if ipstatus == "IP STATUS" then
			connpend()
		elseif ipstatus == "IP INITIAL" then -- ��������
			sys.timer_start(setupIP,IPSTART_INTVL)		
		else -- �����쳣״̬�ر���IP INITIAL
			shut()
		end
	elseif status == "IP INITIAL" then
		sys.timer_start(setupIP,IPSTART_INTVL)
	end
end

--[[
��������closeall
����  ���ر�ȫ��IP����
����  ����
����ֵ����
]]
local function closeall()
	shuting = false
	if ipstatusind then sys.dispatch("IP_SHUTING_IND",false) end
	local i

	for i = 0,MAXLINKS do
		if linklist[i] then
			print("closeall",linklist[i].state,linklist[i].pending)
			if linklist[i].state == "CONNECTING" and linklist[i].pending then
				-- ������δ���й����������� ����ʾclose,IP�����������Զ�����
			elseif linklist[i].state == "INITIAL" then -- δ���ӵ�Ҳ����ʾ
			else
				linklist[i].state = "SHUTING"
				usersckntfy(i,false)
				socket.sock_close(i,0)
			end
			stopconnectingtimer(i)
		end
	end
end

local function pdpdeact()
	socket.pdp_deactivate()
	pdpdeacting = true
	sys.timer_start(pdpdeactrsp,10000,true)
end

--[[
��������shut
����  ���ر�IP����
����  ����
����ֵ����
]]
function shut()
	print("shut",updating,dbging,ntping,shutpending)
	--�������ִ��Զ���������ܻ���dbg���ܻ���ntp���ܣ����ӳٹر�
	if updating or dbging or ntping then shutpending = true return end
	closeall()
	pdpdeact()
	sckconning = false
	--���ùر��б�־
	shuting = true
	if ipstatusind then sys.dispatch("IP_SHUTING_IND",true) end
	shutpending = false
end
reset = shut

function pdpdeactrsp(tmout)
	print("pdpdeactrsp",tmout,ipstatus)
	pdpdeacting = false
	if tmout and ipstatus == "IP STATUS" then
		connpend()
	end
	sys.timer_stop(pdpdeactrsp,true)
end

local function pdpactcnf(result)
	if result == 1 then
		pdpdeactrsp()
		setIPStatus("IP STATUS")
	else
		pdpdeact()
	end
end

local function pdpdeactcnf(result)
	shuting = false
	pdpdeactrsp()
	setIPStatus("IP INITIAL")
end

local function pdpdeactind(result)
	closeall()
	setIPStatus("IP INITIAL")
end

local function sockconncnf(id,result)
	statusind(id,(result == 1) and "CONNECT OK" or "ERROR")
	sckconning = nil
	connpend()
end

local function socksendcnf(id,result)
	sendcnf(id,(result == 1) and "SEND OK" or "ERROR")
end

local function sockrecvind(id,cnt)
	if cnt > 0 then
		recv(id,socket.sock_recv(id,cnt))
	end
end

local function sockclosecnf(id,result)
	closecnf(id,(result == 1) and "CLOSE OK" or "ERROR")
end

local function sockcloseind(id,result)
	statusind(id,"CLOSED")
end

local tntfy =
{
	[rtos.MSG_PDP_ACT_CNF] = {nm="PDP_ACT_CNF",hd=pdpactcnf},
	[rtos.MSG_PDP_DEACT_CNF] = {nm="PDP_DEACT_CNF",hd=pdpdeactcnf},
	[rtos.MSG_PDP_DEACT_IND] = {nm="PDP_DEACT_IND",hd=pdpdeactind},
	[rtos.MSG_SOCK_CONN_CNF] = {nm="SOCK_CONN_CNF",hd=sockconncnf},
	[rtos.MSG_SOCK_SEND_CNF] = {nm="SOCK_SEND_CNF",hd=socksendcnf},
	[rtos.MSG_SOCK_RECV_IND] = {nm="SOCK_RECV_IND",hd=sockrecvind},
	[rtos.MSG_SOCK_CLOSE_CNF] = {nm="SOCK_CLOSE_CNF",hd=sockclosecnf},
	[rtos.MSG_SOCK_CLOSE_IND] = {nm="SOCK_CLOSE_IND",hd=sockcloseind},
}

local function ntfy(msg,v1,v2,v3)
	print("ntfy",tntfy[msg] and tntfy[msg].nm or "unknown",v1,v2,v3)
	if tntfy[msg] then		
		tntfy[msg].hd(v1,v2,v3)
	end
end

sys.regmsg("sock",ntfy)

--gprs����δ����ʱ����ʱ��ѯ����״̬�ļ��
local QUERYTIME = 2000
local querycgatt

--[[
��������cgattrsp
����  ����ѯGPRS�������總��״̬��Ӧ����
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function cgattrsp(cmd,success,response,intermediate)
	--�Ѹ���
	if intermediate == "+CGATT: 1" then
		if cgatt ~= "1" then
			cgatt = "1"
			sys.dispatch("NET_GPRS_READY",true)

			-- �����������,��ô��gprs�������Ժ��Զ���ʼ��IP����
			if base.next(linklist) then
				if ipstatus == "IP INITIAL" then
					setupIP()
				else
					setIPStatus("IP STATUS")
				end
			end
		end
		sys.timer_start(querycgatt,60000)
	elseif intermediate == "+CGATT: 0" then
		if cgatt ~= "0" then
			cgatt = "0"
			sys.dispatch("NET_GPRS_READY",false)
		end
		setcgatt(1)
		sys.timer_start(querycgatt,QUERYTIME)
	end
end

--[[
��������querycgatt
����  ����ѯGPRS�������總��״̬
����  ����
����ֵ����
]]
function querycgatt()
	--���Ƿ���ģʽ����ȥ��ѯ
	if not flymode then req("AT+CGATT?",nil,cgattrsp,nil,{skip=true}) end
end

function setquicksend() end

--[[
��������netmsg
����  ��GSM����ע��״̬�����仯�Ĵ���
����  ����
����ֵ��true
]]
local function netmsg(id,data)
	print("netmsg",data)
	if data == "REGISTERED" then
		--mtk��Ҫ����attach
		setcgatt(1)
		sys.timer_start(querycgatt,QUERYTIME)
	elseif  data == "UNREGISTER" then 
		if cgatt ~= "0" then
			cgatt = "0"
			sys.dispatch("NET_GPRS_READY",false)
		end	
	end
	return true
end

--sim����Ĭ��apn��
local apntable =
{
	["46000"] = "CMNET",
	["46002"] = "CMNET",
	["46004"] = "CMNET",
	["46007"] = "CMNET",
	["46001"] = "UNINET",
	["46006"] = "UNINET",
	["46009"] = "3GNET",
}

--[[
��������proc
����  ����ģ��ע����ڲ���Ϣ�Ĵ�����
����  ��
		id���ڲ���Ϣid
		para���ڲ���Ϣ����
����ֵ��true
]]
local function proc(id,para)
	--IMSI��ȡ�ɹ�
	if id=="IMSI_READY" then
	if not extapn then
		apnname=apntable[sim.getmcc()..sim.getmnc()] or "CMNET"
	end
	--����ģʽ״̬�仯
	elseif id=="FLYMODE_IND" then
		flymode = para
		if para then
			sys.timer_stop(req,"AT+CIPSTATUS")
		else
			req("AT+CGATT?",nil,cgattrsp)
		end
	--Զ��������ʼ
	elseif id=="UPDATE_BEGIN_IND" then
		updating = true
	--Զ����������
	elseif id=="UPDATE_END_IND" then
		updating = false
		if shutpending then shut() end
	--dbg���ܿ�ʼ
	elseif id=="DBG_BEGIN_IND" then
		dbging = true
	--dbg���ܽ���
	elseif id=="DBG_END_IND" then
		dbging = false
		if shutpending then shut() end
	--NTPͬ����ʼ
	elseif id=="NTP_BEGIN_IND" then
		ntping = true
	--NTPͬ������
	elseif id=="NTP_END_IND" then
		ntping = false
		if shutpending then shut() end
	end
	return true
end

function setcgatt(v)
	req("AT+CGATT="..v,nil,nil,nil,{skip=true})
end

function getcgatt()
	return cgatt
end

function getipstatus()
	return ipstatus
end

--ע�᱾ģ���ע���ڲ���Ϣ�Ĵ�����
sys.regapp(proc,"IMSI_READY","FLYMODE_IND","UPDATE_BEGIN_IND","UPDATE_END_IND","DBG_BEGIN_IND","DBG_END_IND","NTP_BEGIN_IND","NTP_END_IND")
sys.regapp(netmsg,"NET_STATE_CHANGED")

