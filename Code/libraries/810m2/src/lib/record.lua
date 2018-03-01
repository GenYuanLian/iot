--[[
ģ�����ƣ�¼������
ģ�鹦�ܣ�¼�����Ҷ�ȡ¼������
ģ������޸�ʱ�䣺2017.04.05
]]

--����ģ��,����������
local base = _G
local string = require"string"
local io = require"io"
local os = require"os"
local rtos = require"rtos"
local audio = require"audio"
local sys = require"sys"
local ril = require"ril"
module(...)

--���س��õ�ȫ�ֺ���������
local smatch = string.match
local print = base.print
local dispatch = sys.dispatch
local tonumber = base.tonumber
local assert = base.assert

--RCD_ID ¼���ļ����
--RCD_FILE¼���ļ���
--local RCD_ID,RCD_FILE = 1,"/RecDir/rec001"
local RCD_ID,RCD_FILE = 1
--rcding���Ƿ�����¼��
--rcdcb��¼���ص�����
--reading���Ƿ����ڶ�ȡ¼��
--duration��¼��ʱ�������룩
local rcding,rcdcb,reading,duration

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������recordǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("record",...)
end

--[[
��������getdata
����  ����ȡ¼���ļ�ָ��λ�����ָ����������
����  ��
		offset��number���ͣ�ָ��λ�ã�ȡֵ��Χ�ǡ�0 �� �ļ�����-1��
        len��number���ͣ�ָ�����ȣ�������õĳ��ȴ����ļ�ʣ��ĳ��ȣ���ֻ�ܶ�ȡʣ��ĳ�������
����ֵ��ָ����¼�����ݣ������ȡʧ�ܣ����ؿ��ַ���""
]]
function getdata(offset,len)
	local f,rt = io.open(audio.getfilepath(RCD_ID),"rb")
    --������ļ�ʧ�ܣ���������Ϊ�ա���
	if not f then print("getdata err��open") return "" end
	if not f:seek("set",offset) then print("getdata err��seek") return "" end
    --��ȡָ�����ȵ�����
	rt = f:read(len)
	f:close()
	print("getdata",string.len(rt or ""))
	return rt or ""
end

--[[
��������getsize
����  ����ȡ��ǰ¼���ļ����ܳ���
����  ����
����ֵ����ǰ¼���ļ����ܳ��ȣ���λ���ֽ�
]]
local function getsize()
	local f = io.open(audio.getfilepath(RCD_ID),"rb")
	if not f then print("getsize err��open") return 0 end
	local size = f:seek("end")
	if not size or size == 0 then print("getsize err��seek") return 0 end
	f:close()
    return size
end


--[[
��������rcdcnf
����  ��AUDIO_RECORD_CNF��Ϣ������
����  ��suc��sucΪtrue��ʾ��ʼ¼������¼��ʧ��
����ֵ����
]]
local function rcdcnf(suc)
	print("rcdcnf",suc)
	if suc then
		rcding = true
	else
		if rcdcb then rcdcb() end
	end
end


--[[
��������rcdind
����  ��¼������������
����  ��suc��true¼���ɹ���false¼��ʧ��
����ֵ��true
]]
local function rcdind(suc,dur)
	print("rcdind",suc,dur,rcding)	
    --¼��ʧ�� ���� ��Ӧ�ò���¼����������Ϣ
	if not suc or not rcding then	
        --ɾ��¼���ļ�
		delete()
	end
	duration = dur
	if rcdcb then rcdcb(suc and rcding,getsize()) end
	rcding=false
end


--[[
��������start
����  ����ʼ¼��
����  ��seconds��number���ͣ�¼��ʱ������λ�룩
        cb��function���ͣ�¼���ص�������¼�����������۳ɹ�����ʧ�ܣ��������cb����
			���÷�ʽΪcb(result,size)��resultΪtrue��ʾ�ɹ���false����nilΪʧ��,size��ʾ¼���ļ��Ĵ�С����λ���ֽڣ�
����ֵ����
]]
function start(seconds,cb)
	print("start",seconds,cb,rcding,reading)
	if seconds<=0 or seconds>50 then
		print("start err��seconds")
		if cb then cb() end
		return
	end
    --�������¼���������ڶ�ȡ¼������ֱ�ӷ���ʧ��
	if rcding or reading then
		print("start err��ing")
		if cb then cb() end
		return
	end
	
	--��������¼����־
	rcding = true
	rcdcb = cb
    --ɾ����ǰ��¼���ļ�
	delete()
    --��ʼ¼��
	audio.beginrecord(RCD_ID,seconds)
end

--[[
��������delete
����  ��ɾ��¼���ļ�
����  ����
����ֵ����
]]
function delete()
	os.remove(audio.getfilepath(RCD_ID))
end

--[[
��������getfilepath
����  ����ȡ¼���ļ���·��
����  ����
����ֵ��¼���ļ���·��
]]
function getfilepath()
	return audio.getfilepath(RCD_ID)
end

local procer = {
	AUDIO_RECORD_CNF = rcdcnf,
	AUDIO_RECORD_IND = rcdind,
}
--ע�᱾����ģ���ע����Ϣ������
sys.regapp(procer)
