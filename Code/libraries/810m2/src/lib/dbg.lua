--[[
ģ�����ƣ��������
ģ�鹦�ܣ��ϱ�����ʱ�﷨���󡢽ű����Ƶ�����ԭ��
ģ������޸�ʱ�䣺2017.02.20
]]

--����ģ��,����������
module(...,package.seeall)
local link = require"link"
local misc = require"misc"

--FREQ���ϱ��������λ���룬���������Ϣ�ϱ���û���յ�OK�ظ�����ÿ���˼�������ϱ�һ��
--prot,addr,port�������Э��(TCP����UDP)����̨��ַ�Ͷ˿�
--lid��socket id
--linksta������״̬��trueΪ���ӳɹ���falseΪʧ��
local FREQ,prot,addr,port,lid,linksta = 1800000
--DBG_FILE�������ļ�·��
--inf��DBG_FILE�еĴ�����Ϣ��sys.lua��LIB_ERR_FILE�еĴ�����Ϣ
--luaerr��"/luaerrinfo.txt"�еĴ�����Ϣ
local DBG_FILE,inf,luaerr,d1,d2 = "/dbg.txt",""

--[[
��������readtxt
����  ����ȡ�ı��ļ��е�ȫ������
����  ��
		f���ļ�·��
����ֵ���ı��ļ��е�ȫ�����ݣ���ȡʧ��Ϊ���ַ�������nil
]]
local function readtxt(f)
	local file,rt = io.open(f,"r")
	if file == nil then
		print("dbg can not open file",f)
		return ""
	end
	rt = file:read("*a")
	file:close()
	return rt or ""
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
	if file == nil then
		print("dbg open file to write err",f)
		return
	end
	file:write(v)
	file:close()
end

--[[
��������writerr
����  ��д��Ϣ�������ļ�
����  ��
		append���Ƿ�׷�ӵ�ĩβ
		s��������Ϣ
����ֵ����
˵���������ļ�����ౣ�������900�ֽ�����
]]
local function writerr(append,s)	
	print("dbg_w",append,s)
	if s then
		local str = (append and (readtxt(DBG_FILE)..s) or s)
		if string.len(str)>900 then
			str = string.sub(str,-900,-1)
		end
		writetxt(DBG_FILE,str)
	end
end

--[[
��������initerr
����  ���Ӵ����ļ��ж�ȡ������Ϣ����
����  ����
����ֵ����
]]
local function initerr()
	inf = (sys.getextliberr() or "")..(readtxt(DBG_FILE) or "")
	print("dbg inf",inf)
end

--[[
��������getlasterr
����  ����ȡlua����ʱ���﷨����
����  ����
����ֵ����
]]
local function getlasterr()
	luaerr = readtxt("/luaerrinfo.txt") or ""
end

--[[
��������valid
����  ���Ƿ��д������Ϣ��Ҫ�ϱ�
����  ����
����ֵ��true��Ҫ�ϱ���false����Ҫ�ϱ�
]]
local function valid()
	return ((string.len(luaerr) > 0) or (string.len(inf) > 0)) and _G.PROJECT
end

--[[
��������rcvtimeout
����  �����ʹ�����Ϣ����̨�󣬳�ʱû���յ�OK�Ļظ�����ʱ������
����  ����
����ֵ����
]]
local function rcvtimeout()
	endntfy()
	link.close(lid)
end

--[[
��������snd
����  �����ʹ�����Ϣ����̨
����  ����
����ֵ����
]]
local function snd()
	local data = (luaerr or "") .. (inf or "")
	if string.len(data) > 0 then
		link.send(lid,_G.PROJECT .."_"..sys.getcorever() .. "," .. (_G.VERSION and (_G.VERSION .. ",") or "") .. misc.getimei() .. "," .. data)
		sys.timer_start(snd,FREQ)
		sys.timer_start(rcvtimeout,20000)
	end
end

--���Ӻ�̨ʧ�ܺ����������
local reconntimes = 0
--[[
��������reconn
����  �����Ӻ�̨ʧ�ܺ���������
����  ����
����ֵ����
]]
local function reconn()
	if reconntimes < 3 then
		reconntimes = reconntimes+1
		link.connect(lid,prot,addr,port)
	else
		endntfy()
	end
end

--[[
��������endntfy
����  ��һ��dbg�������ڽ���
����  ����
����ֵ����
]]
function endntfy()
	sys.dispatch("DBG_END_IND")
	sys.timer_stop(sys.dispatch,"DBG_END_IND")
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
local function notify(id,evt,val)
	print("dbg notify",id,evt,val)
	if id ~= lid then return end
	if evt == "CONNECT" then
		if val == "CONNECT OK" then
			linksta = true
			sys.timer_stop(reconn)
			reconntimes = 0
			snd()
		else
			sys.timer_start(reconn,5000)
		end
	elseif evt=="DISCONNECT" or evt=="CLOSE" then
		linksta = false
	elseif evt == "STATE" and val == "CLOSED" then
		link.close(lid)
	end
end

--[[
��������recv
����  ��socket�������ݵĴ�����
����  ��
        id ��socket id��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
local function recv(id,data)
	if string.upper(data) == "OK" then
		sys.timer_stop(snd)
		link.close(lid)
		inf = ""
		writerr(false,"")
		luaerr = ""
		os.remove("/luaerrinfo.txt")
		endntfy()
		sys.timer_stop(rcvtimeout)
	end
end

--[[
��������init
����  ����ʼ��
����  ��
        id ��socket id��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
local function init()
	--��ȡ�����ļ�����
	initerr()
	--��ȡlua����ʱ�﷨����
	getlasterr()
	if valid() then
		if linksta then
			snd()
		else
			lid = link.open(notify,recv,"dbg")
			link.connect(lid,prot,addr,port)
		end
		sys.dispatch("DBG_BEGIN_IND")
		sys.timer_start(sys.dispatch,120000,"DBG_END_IND")
	end
end

--[[
��������restart
����  ������
����  ��
        r������ԭ��
����ֵ����
]]
function restart(r)
	writerr(true,"dbg.restart:" .. (r or "") .. ";")
	rtos.restart()
end

--[[
��������saverr
����  �����������Ϣ
����  ��
        s��������Ϣ
����ֵ����
]]
function saverr(s)
	writerr(true,s)
	init()
end

--[[
��������setup
����  �����ô���Э�顢��̨��ַ�Ͷ˿�
����  ��
        inProt �������Э�飬��֧��TCP��UDP
		inAddr����̨��ַ
		inPort����̨�˿�
����ֵ����
]]
function setup(inProt,inAddr,inPort)
	if inProt and inAddr and inPort then
		prot,addr,port = inProt,inAddr,inPort
		init()
	end
end
