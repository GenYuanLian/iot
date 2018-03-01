--[[
ģ�����ƣ�ͨ������
ģ�鹦�ܣ����롢�������������Ҷ�
ģ������޸�ʱ�䣺2017.02.20
]]

--����ģ��,����������
local base = _G
local string = require"string"
local table = require"table"
local sys = require"sys"
local ril = require"ril"
local net = require"net"
local pm = require"pm"
module(...)

--���س��õ�ȫ�ֺ���������
local ipairs,pairs,print,unpack,type = base.ipairs,base.pairs,base.print,base.unpack,base.type
local req = ril.request

--�ײ�ͨ��ģ���Ƿ�׼��������true������false����nilδ����
local ccready = true

--��¼������뱣֤ͬһ�绰�������ֻ��ʾһ��
local incoming_num = nil
--���������
local emergency_num = {"112", "911", "000", "08", "110", "119", "118", "999"}
--ͨ���б�
local clcc,clccold,disc,chupflag = {},{},{},0
--״̬�仯֪ͨ�ص�
local usercbs = {}


--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������ccǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("cc",...)
end

--[[
��������dispatch
����  ��ִ��ÿ���ڲ���Ϣ��Ӧ���û��ص�
����  ��
		evt����Ϣ����
		para����Ϣ����
����ֵ����
]]
local function dispatch(evt,para)
	local tag = string.match(evt,"CALL_(.+)")
	if usercbs[tag] then usercbs[tag](para) end
end

--[[
��������regcb
����  ��ע��һ�����߶����Ϣ���û��ص�����
����  ��
		evt1����Ϣ���ͣ�Ŀǰ��֧��"READY","INCOMING","CONNECTED","DISCONNECTED"
		cb1����Ϣ��Ӧ���û��ص�����
		...��evt��cb�ɶԳ���
����ֵ����
]]
function regcb(evt1,cb1,...)
	usercbs[evt1] = cb1
	local i
	for i=1,arg.n,2 do
		usercbs[unpack(arg,i,i)] = unpack(arg,i+1,i+1)
	end
end

--[[
��������deregcb
����  ������ע��һ�����߶����Ϣ���û��ص�����
����  ��
		evt1����Ϣ���ͣ�Ŀǰ��֧��"READY","INCOMING","CONNECTED","DISCONNECTED"
		...��0�����߶��evt
����ֵ����
]]
function deregcb(evt1,...)
	usercbs[evt1] = nil
	local i
	for i=1,arg.n do
		usercbs[unpack(arg,i,i)] = nil
	end
end

--[[
��������isemergencynum
����  ���������Ƿ�Ϊ��������
����  ��
		num����������
����ֵ��trueΪ�������룬false��Ϊ��������
]]
local function isemergencynum(num)
	for k,v in ipairs(emergency_num) do
		if v == num then
			return true
		end
	end
	return false
end

--[[
��������clearincomingflag
����  ������������
����  ����
����ֵ����
]]
local function clearincomingflag()
	print("clearincomingflag")
	incoming_num = nil
end

--[[
��������clearchupflag
����  ����������־
����  ����
����ֵ����
]]
local function clearchupflag()
    print("clearchupflag")
    chupflag = 0
end

--[[
��������qrylist
����  ����ѯͨ���б�
����  ����
����ֵ����
]]
local function qrylist()
	print("qrylist")
    clcc = {}
    req("AT+CLCC")
end

--[[
��������FindCcById
����  ��ͨ��id��ѯͨ��
����  ��
    id: ͨ��idֵ
    cctb: ͨ���б�
����ֵ��ͨ��
]]
function FindCcById(id,cctb)  
	print("FindCcById")
    for k,v in pairs(cctb) do
		print(v.id,id,cctb[k])
	    if v.id == id then
	        return cctb[k]
	    end
    end
  
    return nil
end

local checkclcc=true
local function proclist()
    print("proclist",#clccold,#clcc)
    local k,v,isactive,cc,res,hasincoming

    if #clccold == 0 then
	    clccold = clcc
	    res = true--return
    end
    for k,v in pairs(clcc) do
		print("clcc",v.dir,v.sta,incoming_num,v.num)
	    if v.dir == "1" and (v.sta == "4" or v.sta == "5") and ((incoming_num and incoming_num ==v.num) or incoming_num==nil) then
            if incoming_num==nil then incoming_num=v.num end
            cc = FindCcById(v.id,clccold)
	        if not res and cc and cc.num ==v.num and (cc.sta == "4" or cc.sta == "5") then
                print("ljdcc proclist invalid CALL_INCOMING:",incoming_num,cc.sta,v.sta)
	        else
		        print("ljdcc proclist CALL_INCOMING:",incoming_num,#clccold,v.id)
		        if res then
                    dispatch("CALL_INCOMING",incoming_num,clccold,v.id)
                else
                    hasincoming={incoming_num,clccold,v.id}
                end
	        end
	    end
    end
    if res then return end
    for k,v in pairs(clccold) do
		print("clccold",v.id)
	    cc = FindCcById(v.id,clcc)
	    if cc == nil then
	        if #clccold>0 then
	            if #clccold>1 and checkclcc then
	                qrylist()
	                checkclcc = false
	                if hasincoming then--������һ��������պ�����ͬʱ�к��룬����ʧ�ܣ���һ��clcc��idΪ1��ͨ���Ǻ������ڶ���clcc��idΪ1���Ǻ��룬�ڶ���clcc��������м�Ҫ����disc��Ϣ��ҲҪ����incoming��Ϣ�����ȴ���disc��Ϣ
                        print("ljdcc real dispatch incom ",hasincoming[1],hasincoming[2],hasincoming[3])
                        dispatch("CALL_INCOMING",hasincoming[1],hasincoming[2],hasincoming[3])
                    end
	                return
	            else
    		        print("ljdcc proclist CALL_DISCONNECTED",disc[1] or "invalid reason")
    		        dispatch("CALL_DISCONNECTED",disc[1] or "invalid reason",clccold,v.id)
    		        chupflag,disc,checkclcc,incoming_num = 1,{},true
    		        sys.timer_start(clearchupflag,2000)
		        end
	        end
	  
	    else
	        if cc.dir == v.dir and cc.num ==v.num and cc.mode ==v.mode then
                print("ljdcc proclist CALL_CONNECTED = ",(cc.sta =="0" and v.sta ~="0"),cc.sta,v.sta)
			    if cc.sta =="0" and v.sta ~="0" then
			        dispatch("CALL_CONNECTED",clccold,v.id)
			    end
	        else
	            dispatch("CALL_DISCONNECTED",disc[1] or "invalid reason",clccold,v.id)
	            chupflag,disc,checkclcc,incoming_num = 1,{},true
                sys.timer_start(clearchupflag,2000)
		        print("ljdcc maybe someting err , cc.dir:",cc.dir,"v.dir:",v.dir,"cc.num:",cc.num,"v.num:",v.num,"cc.mode:",cc.mode,"v.mode:",v.mode) 	    
	        end
	    end
    end
    
    --������һ��������պ�����ͬʱ�к��룬����ʧ�ܣ���һ��clcc��idΪ1��ͨ���Ǻ������ڶ���clcc��idΪ1���Ǻ��룬�ڶ���clcc��������м�Ҫ����disc��Ϣ��ҲҪ����incoming��Ϣ�����ȴ���disc��Ϣ
    if hasincoming then
        print("ljdcc real dispatch incom ",hasincoming[1],hasincoming[2],hasincoming[3])
        dispatch("CALL_INCOMING",hasincoming[1],hasincoming[2],hasincoming[3])
    end
  
    clccold = clcc
end

local function discevt(reason)
	pm.sleep("cc")
	table.insert(disc,reason)
	print("ljdcc discevt reason:",reason,#clccold,#clcc)
	--dispatch("CALL_DISCONNECTED",reason)
	qrylist()
end

function anycallexist()
	return #clccold>0
end

--[[
��������dial
����  ������һ������
����  ��
		number������
		delay����ʱdelay����󣬲ŷ���at������У�Ĭ�ϲ���ʱ
����ֵ����
]]
function dial(number,delay)
	if number == "" or number == nil then
		return false
	end

	if (ccready == false or net.getstate() ~= "REGISTERED") and not isemergencynum(number) then
		return false
	end

	pm.wake("cc")
	req(string.format("%s%s;","ATD",number),nil,nil,delay)
	qrylist()

	return true
end

function dropcallbyarg(statb,dir)
    if type(statb) ~= "table" or #statb==0 then
	    print("ljdcc dropcallbyarg err statb ind")
	    return
    end
    print("ljdcc dropcallbyarg ",#statb,dir,#clccold)
    for k,v in pairs(clccold) do
		print(dir,v.dir)
	    if v.dir==dir then
	        for i=1,#statb do
		        print("ljdcc dropcallbyarg ",statb[i],v.sta)
		        if v.sta == statb[i] then
		            req("AT+CHLD=1"..v.id)
		            print("ljdcc hangup:",v.num) 
					return true
		        end
	        end
	    end 
    end
end

--[[
��������hangup
����  �������Ҷ�����ͨ��
����  ����
����ֵ����
]]
function hangup()
	--aud.stop()
	if #clccold==1 then
	    req("AT+CHUP")
	else
	    for k,v in pairs(clccold) do
	        if v.sta == "0" then 
		        req("AT+CHLD=1"..v.id)
		        print("ljdcc hangup:",v.num) 
		        break 
	        end
	    end
	end
end

--[[
��������accept
����  ����������
����  ����
����ֵ����
]]
function accept()
	--aud.stop()
	req("ATA")
	pm.wake("cc")
end

--[[
��������transvoice
����  ��ͨ���з����������Զ�,������12.2K AMR��ʽ
����  ��
����ֵ��trueΪ�ɹ���falseΪʧ��
]]
function transvoice(data,loop,loop2)
	local f = io.open("/RecDir/rec000","wb")

	if f == nil then
		print("transvoice:open file error")
		return false
	end

	-- ���ļ�ͷ������12.2K֡
	if string.sub(data,1,7) == "#!AMR\010\060" then
	-- ���ļ�ͷ����12.2K֡
	elseif string.byte(data,1) == 0x3C then
		f:write("#!AMR\010")
	else
		print("transvoice:must be 12.2K AMR")
		return false
	end

	f:write(data)
	f:close()

	req(string.format("AT+AUDREC=%d,%d,2,0,50000",loop2 == true and 1 or 0,loop == true and 1 or 0))

	return true
end

--[[
��������dtmfdetect
����  ������dtmf����Ƿ�ʹ���Լ�������
����  ��
		enable��trueʹ�ܣ�false����nilΪ��ʹ��
		sens�������ȣ�Ĭ��3��������Ϊ1
����ֵ����
]]
function dtmfdetect(enable,sens)
	if enable == true then
		if sens then
			req("AT+DTMFDET=2,1," .. sens)
		else
			req("AT+DTMFDET=2,1,3")
		end
	end

	req("AT+DTMFDET="..(enable and 1 or 0))
end

--[[
��������senddtmf
����  ������dtmf���Զ�
����  ��
		str��dtmf�ַ���
		playtime��ÿ��dtmf����ʱ�䣬��λ���룬Ĭ��100
		intvl������dtmf�������λ���룬Ĭ��100
����ֵ����
]]
function senddtmf(str,playtime,intvl)
	if string.match(str,"([%dABCD%*#]+)") ~= str then
		print("senddtmf: illegal string "..str)
		return false
	end

	playtime = playtime and playtime or 100
	intvl = intvl and intvl or 100

	req("AT+SENDSOUND="..string.format("\"%s\",%d,%d",str,playtime,intvl))
end

local dtmfnum = {[71] = "Hz1000",[69] = "Hz1400",[70] = "Hz2300"}

--[[
��������parsedtmfnum
����  ��dtmf���룬����󣬻����һ���ڲ���ϢAUDIO_DTMF_DETECT��Я��������DTMF�ַ�
����  ��
		data��dtmf�ַ�������
����ֵ����
]]
local function parsedtmfnum(data)
	local n = base.tonumber(string.match(data,"(%d+)"))
	local dtmf

	if (n >= 48 and n <= 57) or (n >=65 and n <= 68) or n == 42 or n == 35 then
		dtmf = string.char(n)
	else
		dtmf = dtmfnum[n]
	end

	if dtmf then
		dispatch("CALL_DTMF",dtmf)
	end
end

--[[
��������ccurc
����  ��������ģ���ڡ�ע��ĵײ�coreͨ�����⴮�������ϱ���֪ͨ���Ĵ���
����  ��
		data��֪ͨ�������ַ�����Ϣ
		prefix��֪ͨ��ǰ׺
����ֵ����
]]
local function ccurc(data,prefix)
	--�ײ�ͨ��ģ��׼������
	if data == "CALL READY" then
		ccready = true
		dispatch("CALL_READY")
	--ͨ������֪ͨ
	elseif data == "CONNECT" then
		qrylist()		
		dispatch("CALL_CONNECTED")
	--ͨ���Ҷ�֪ͨ
	elseif data == "NO CARRIER" or data == "BUSY" or data == "NO ANSWER" then
	    print("ljdcc ",data,chupflag,#clccold,#clcc)
	    if #clccold==0 and #clcc==0 then
	        return
	    end
		discevt(data)
	--��������
	elseif prefix == "+CLIP" then
	    print("ljdcc CLIP CALL_INCOMING",incoming_num,"chupflag:",chupflag)
		local number = string.match(data,"\"(%+*%d*)\"",string.len(prefix)+1)
		if incoming_num ~= number then
			incoming_num = number
			if chupflag==1 then
			  sys.timer_start(qrylist,1500)
			else
			  qrylist()
			end
			--dispatch("CALL_INCOMING",number)
		end
	--ͨ���б���Ϣ
	elseif prefix == "+CLCC" then
		local id,dir,sta,mode,mpty,num = string.match(data,"%+CLCC:%s*(%d+),(%d),(%d),(%d),(%d),\"(%+*%d*)\"")
		if id then
		    local cc=FindCcById(id,clcc)
		    if cc== nil then
			    table.insert(clcc,{id=id,dir=dir,sta=sta,mode=mode,mpty=mpty,num=num})
			else
			    cc.dir,cc.sta,cc.mode,cc.mpty,cc.num = dir,sta,mode,mpty,num
			end		
		end
	--DTMF���ռ��
	elseif prefix == "+DTMFDET" then
		parsedtmfnum(data)
	end
end

--[[
��������ccrsp
����  ��������ģ���ڡ�ͨ�����⴮�ڷ��͵��ײ�core�����AT�����Ӧ����
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function ccrsp(cmd,success,response,intermediate)
	local prefix = string.match(cmd,"AT(%+*%u+)")
	print("ljdcc ccrsp",prefix,cmd,success,response,intermediate)
	--����Ӧ��
	if prefix == "D" then
		if not success then
			discevt("CALL_FAILED")
		else
			if usercbs["ALERTING"] then sys.timer_loop_start(qrylist,1000,"MO") end
		end
	--�Ҷ�����ͨ��Ӧ��
	elseif prefix == "+CHUP" then
		discevt("LOCAL_HANG_UP")
	elseif prefix == "+CLCC" then
	    proclist()
    elseif prefix=='+CHLD' and (response=='ERROR' or response=='NO ANSWER') then
    	qrylist()
	--��������Ӧ��
	elseif prefix == "A" then
		incoming_num = nil
		qrylist()
		--dispatch("CALL_CONNECTED")
	end
end

--ע������֪ͨ�Ĵ�����
ril.regurc("CALL READY",ccurc)
ril.regurc("CONNECT",ccurc)
ril.regurc("NO CARRIER",ccurc)
ril.regurc("NO ANSWER",ccurc)
ril.regurc("BUSY",ccurc)
ril.regurc("+CLIP",ccurc)
ril.regurc("+CLCC",ccurc)

ril.regurc("+DTMFDET",ccurc)
--ע������AT�����Ӧ������
ril.regrsp("D",ccrsp)
ril.regrsp("A",ccrsp)
ril.regrsp("+CHUP",ccrsp)
ril.regrsp("+CLCC",ccrsp)
ril.regrsp("+CHLD",ccrsp)
--����������,æ�����
req("ATX4")
--��������urc�ϱ�
req("AT+CLIP=1")
dtmfdetect(true)
