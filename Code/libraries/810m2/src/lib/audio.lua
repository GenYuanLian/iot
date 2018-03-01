--[[
ģ�����ƣ���Ƶ����
ģ�鹦�ܣ�dtmf����롢��Ƶ�ļ��Ĳ��ź�ֹͣ��¼����mic��speaker�Ŀ���
ģ������޸�ʱ�䣺2017.02.20
]]

--����ģ��,����������
local base = _G
local string = require"string"
local io = require"io"
local rtos = require"rtos"
local audio = require"audiocore"
local sys = require"sys"
local ril = require"ril"
local os = require"os"
module(...)

--���س��õ�ȫ�ֺ���������
local smatch = string.match
local print = base.print
local dispatch = sys.dispatch
local req = ril.request
local tonumber,type,assert = base.tonumber,base.type,base.assert

--[[
speakervol��speaker�����ȼ���ȡֵ��ΧΪaudio.VOL0��audio.VOL7��audio.VOL0Ϊ����
audiochannel����Ƶͨ������Ӳ������йأ��û�������Ҫ����Ӳ������
microphonevol��mic�����ȼ���ȡֵ��ΧΪaudio.MIC_VOL0��audio.MIC_VOL15��audio.MIC_VOL0Ϊ����
]]
local speakervol,audiochannel,microphonevol = audio.VOL4,audio.HANDSET,audio.MIC_VOL15
-- GSMȫ����ģʽ
local gsmfr = false 
--��Ƶ�ļ�·��
local playname
--¼����־
local regrcd,recording

--[[
��������beginrecord
����  ����ʼ¼��
����  ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
		duration��¼��ʱ������λ��
����ֵ��true
]]
function beginrecord(id,duration)
	if not regrcd then
		regrcd = true
		sys.regmsg(rtos.MSG_RECORD,recordmsg)
	end
	print("beginrecord",id,duration,recording)
	if recording then dispatch("AUDIO_RECORD_CNF",false) end
	if not recording then
		local file = (type(id)=="number" and ("/rcd"..id..".amr") or id)
		recording = (audio.record(file,duration) == 1)
		dispatch("AUDIO_RECORD_CNF",recording)
		--if duration then sys.timer_start(audio.stoprecord,duration*1000,file) end
	end
	return true
end

--[[
��������endrecord
����  ������¼��
����  ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
		duration��¼��ʱ������λ����
����ֵ��true
]]
function endrecord(id,duration)
	recording = false
	sys.timer_stop(audio.stoprecord)
	audio.stoprecord(type(id)=="number" and ("/rcd"..id..".amr") or id)
	return true
end

--[[
��������delrecord
����  ��ɾ��¼���ļ�
����  ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
		duration��¼��ʱ������λ����
����ֵ��true
]]
function delrecord(id,duration)
	os.remove((type(id)=="number" and ("/rcd"..id..".amr") or id))
	return true
end

--[[
��������getfilepath
����  ����ȡ¼���ļ���·��
����  ��
    id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
����ֵ��¼���ļ���·��
]]
function getfilepath(id)
  return (type(id)=="number" and ("/rcd"..id..".amr") or id)
end

--[[
��������playrecord
����  ������¼���ļ�
����  ��
		dl��ģ�����У��������ֱ������ȣ��Ƿ��������¼�����ŵ�������true����������false����nil������
		loop���Ƿ�ѭ�����ţ�trueΪѭ����false����nilΪ��ѭ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
����ֵ��true
]]
function playrecord(dl,loop,id)
	play((type(id)=="number" and ("/rcd"..id..".amr") or id),loop)
	return true
end

--[[
��������stoprecord
����  ��ֹͣ����¼���ļ�
����  ��
����ֵ��true
]]
function stoprecord()
	stop()
	return true
end

--[[
��������_play
����  ��������Ƶ�ļ�
����  ��
		name����Ƶ�ļ�·��
		loop���Ƿ�ѭ�����ţ�trueΪѭ����false����nilΪ��ѭ��
����ֵ�����ò��Žӿ��Ƿ�ɹ���trueΪ�ɹ���falseΪʧ��
]]
local function _play(name,loop)
	if loop then playname = name end
	return audio.play(name)
end

--[[
��������_stop
����  ��ֹͣ������Ƶ�ļ�
����  ����
����ֵ������ֹͣ���Žӿ��Ƿ�ɹ���trueΪ�ɹ���falseΪʧ��
]]
local function _stop()
	playname = nil
	return audio.stop()
end

--[[
��������audiourc
����  ��������ģ���ڡ�ע��ĵײ�coreͨ�����⴮�������ϱ���֪ͨ���Ĵ���
����  ��
		data��֪ͨ�������ַ�����Ϣ
		prefix��֪ͨ��ǰ׺
����ֵ����
]]
local function audiourc(data,prefix)
end

--[[
��������audiorsp
����  ��������ģ���ڡ�ͨ�����⴮�ڷ��͵��ײ�core�����AT�����Ӧ����
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function audiorsp(cmd,success,response,intermediate)
end

--ע������֪ͨ�Ĵ�����
ril.regurc("+AUDREC",audiourc)
--ע������AT�����Ӧ������
ril.regrsp("+AUDREC",audiorsp,0)

--[[
��������setspeakervol
����  ��������Ƶͨ�����������
����  ��
		vol�������ȼ���ȡֵ��ΧΪaudio.VOL0��audio.VOL7��audio.VOL0Ϊ����
����ֵ����
]]
function setspeakervol(vol)
	audio.setvol(vol)
	speakervol = vol
end

--[[
��������setcallvol
����  ������ͨ������
����  ��
   vol�������ȼ���ȡֵ��ΧΪaudio.VOL0��audio.VOL7��audio.VOL0Ϊ����
����ֵ����
]]
function setcallvol(vol)
  print("setcallvol",vol)
  audio.setsphvol(vol)
end

--[[
��������getspeakervol
����  ����ȡ��Ƶͨ�����������
����  ����
����ֵ�������ȼ�
]]
function getspeakervol()
	return speakervol
end

--[[
��������setaudiochannel
����  ��������Ƶͨ��
����  ��
		channel����Ƶͨ������Ӳ������йأ��û�������Ҫ����Ӳ�����ã�Air810ģ��͹̶���audiocore.HANDSET
����ֵ����
]]
function setaudiochannel(channel)
	audio.setchannel(channel)
	audiochannel = channel
end

--[[
��������getaudiochannel
����  ����ȡ��Ƶͨ��
����  ����
����ֵ����Ƶͨ��
]]
local function getaudiochannel()
	return audiochannel
end

--[[
��������setloopback
����  �����ûػ�����
����  ��
		flag���Ƿ�򿪻ػ����ԣ�trueΪ�򿪣�falseΪ�ر�
		typ�����Իػ�����Ƶͨ������Ӳ������йأ��û�������Ҫ����Ӳ������
		setvol���Ƿ����������������trueΪ���ã�false������
		vol�����������
����ֵ��true���óɹ���false����ʧ��
]]
function setloopback(flag,typ,setvol,vol)
	return audio.setloopback(flag,typ,setvol,vol)
end

--[[
��������setmicrophonegain
����  ������MIC������
����  ��
		vol��mic�����ȼ���ȡֵ��ΧΪaudio.MIC_VOL0��audio.MIC_VOL15��audio.MIC_VOL0Ϊ����
����ֵ����
]]
function setmicrophonegain(vol)
	audio.setmicvol(vol)
	microphonevol = vol
end

--[[
��������getmicrophonegain
����  ����ȡMIC�������ȼ�
����  ����
����ֵ�������ȼ�
]]
function getmicrophonegain()
	return microphonevol
end

--[[
��������audiomsg
����  ������ײ��ϱ���rtos.MSG_AUDIO�ⲿ��Ϣ
����  ��
		msg��play_end_ind���Ƿ��������Ž���
		     play_error_ind���Ƿ񲥷Ŵ���
����ֵ����
]]
local function audiomsg(msg)
	if msg.play_end_ind == true then
		if playname then audio.play(playname) return end
		playend()
	elseif msg.play_error_ind == true then
		if playname then playname = nil end
		playerr()
	end
end

--[[
��������recordmsg
����  ������ײ��ϱ���rtos.MSG_RECORD�ⲿ��Ϣ
����  ��
		msg��record_end_ind��¼���Ƿ���������
		     record_error_ind��¼���Ƿ�������
����ֵ����
]]
function recordmsg(msg)
	print("recordmsg",msg.record_end_ind,msg.record_error_ind)
	recording = false
	if msg.record_end_ind == true then
		dispatch("AUDIO_RECORD_IND",true)
	elseif msg.record_error_ind == true then
		dispatch("AUDIO_RECORD_IND",false)
	end
end

--ע��ײ��ϱ���rtos.MSG_AUDIO�ⲿ��Ϣ�Ĵ�����
sys.regmsg(rtos.MSG_AUDIO,audiomsg)
--Ĭ����Ƶͨ������ΪAUX_LOUDSPEAKER
setaudiochannel(audio.AUX_LOUDSPEAKER)
--Ĭ�������ȼ�����Ϊ4����4�����м�ȼ������Ϊ0�������Ϊ7��
setspeakervol(audio.VOL4)
--Ĭ��MIC�����ȼ�����Ϊ1�������Ϊ0�������Ϊ15��
setmicrophonegain(audio.MIC_VOL1)


--[[
spriority����ǰ���ŵ���Ƶ���ȼ�
styp����ǰ���ŵ���Ƶ����
spath����ǰ���ŵ���Ƶ�ļ�·��
svol����ǰ��������
scb����ǰ���Ž������߳���Ļص�����
sdup����ǰ���ŵ���Ƶ�Ƿ���Ҫ�ظ�����
sduprd�����sdupΪtrue����ֵ��ʾ�ظ����ŵļ��(��λ����)��Ĭ���޼��
spending����Ҫ���ŵ���Ƶ�Ƿ���Ҫ���ڲ��ŵ���Ƶ�첽�������ٲ���
]]
local spriority,styp,spath,svol,scb,sdup,sduprd

--[[
��������playbegin
����  ���ر��ϴβ��ź��ٲ��ű�������
����  ��
		priority����Ƶ���ȼ�����ֵԽС�����ȼ�Խ��
		typ����Ƶ���ͣ�Ŀǰ��֧��"FILE"��"RECORD"
		path����Ƶ�ļ�·��
		vol������������ȡֵ��Χaudiocore.VOL0��audiocore.VOL7���˲�����ѡ
		cb����Ƶ���Ž������߳���ʱ�Ļص��������ص�ʱ����һ��������0��ʾ���ųɹ�������1��ʾ���ų���2��ʾ�������ȼ�������û�в��š��˲�����ѡ
		dup���Ƿ�ѭ�����ţ�trueѭ����false����nil��ѭ�����˲�����ѡ
		duprd�����ż��(��λ����)��dupΪtrueʱ����ֵ�������塣�˲�����ѡ
����ֵ�����óɹ�����true�����򷵻�nil
]]
local function playbegin(priority,typ,path,vol,cb,dup,duprd)
	print("playbegin")
	--���¸�ֵ��ǰ���Ų���
	spriority,styp,spath,svol,scb,sdup,sduprd,spending = priority,typ,path,vol,cb,dup,duprd

	--�������������������������
	if vol then
		setspeakervol(vol)
    end
	
	--���ò��Žӿڳɹ�
	if ((typ=="RECORD" and playrecord(true,false,tonumber(path)))
		or (typ=="FILE" and _play(path,dup and (not duprd or duprd==0)))) then
		return true
	--���ò��Žӿ�ʧ��
	else
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
	end
end

--[[
��������play
����  ��������Ƶ
����  ��
		priority��number���ͣ���ѡ��������Ƶ���ȼ�����ֵԽ�����ȼ�Խ��
		typ��string���ͣ���ѡ��������Ƶ���ͣ�Ŀǰ��֧��"FILE"��"RECORD"
		path����ѡ��������Ƶ�ļ�·������typ�йأ�
		    typΪ"FILE"ʱ��string���ͣ���ʾ��Ƶ�ļ�·��
			typΪ"RECORD"ʱ��number���ͣ���ʾ¼��ID
		vol��number���ͣ���ѡ����������������ȡֵ��Χaudiocore.VOL0��audiocore.VOL7
		cb��function���ͣ���ѡ��������Ƶ���Ž������߳���ʱ�Ļص��������ص�ʱ����һ��������0��ʾ���ųɹ�������1��ʾ���ų���2��ʾ�������ȼ�������û�в���
		dup��bool���ͣ���ѡ�������Ƿ�ѭ�����ţ�trueѭ����false����nil��ѭ��
		duprd��number���ͣ���ѡ���������ż��(��λ����)��dupΪtrueʱ����ֵ��������
����ֵ�����óɹ�����true�����򷵻�nil
]]
function play(priority,typ,path,vol,cb,dup,duprd)
	assert(priority and typ,"play para err")
	print("play",priority,typ,path,vol,cb,dup,duprd,styp)
	--����Ƶ���ڲ���
	if styp then
		--��Ҫ���ŵ���Ƶ���ȼ� ���� ���ڲ��ŵ���Ƶ���ȼ�
		if priority > spriority then
			--������ڲ��ŵ���Ƶ�лص���������ִ�лص����������2
			if scb then scb(2) end
			--ֹͣ���ڲ��ŵ���Ƶ
			if not stop() then
				spriority,styp,spath,svol,scb,sdup,sduprd,spending = priority,typ,path,vol,cb,dup,duprd,true
				return
			end
		--��Ҫ���ŵ���Ƶ���ȼ� ���� ���ڲ��ŵ���Ƶ���ȼ�
		elseif priority < spriority then
			--ֱ�ӷ���nil����������
			return
		--��Ҫ���ŵ���Ƶ���ȼ� ���� ���ڲ��ŵ���Ƶ���ȼ������������(1������ѭ�����ţ�2���û��ظ����ýӿڲ���ͬһ��Ƶ����)
		else
			--����ǵ�2�������ֱ�ӷ��أ���1�������ֱ��������
			if not sdup then
				return
			end
		end
	end

	playbegin(priority,typ,path,vol,cb,dup,duprd)
end

--[[
��������stop
����  ��ֹͣ��Ƶ����
����  ����
����ֵ��������Գɹ�ͬ��ֹͣ������true�����򷵻�nil
]]
function stop()
	if styp then
		local typ,path = styp,spath		
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
		--ֹͣѭ�����Ŷ�ʱ��
		sys.timer_stop_all(play)
		--ֹͣ��Ƶ����
		_stop()
		if typ=="RECORD" then stoprecord() return end
	end
	return true
end

--[[
��������playend
����  ����Ƶ���ųɹ�����������
����  ����
����ֵ����
]]
function playend()
	print("playend",sdup,sduprd)
	if styp=="RECORD" and not sdup then stoprecord() end
	--��Ҫ�ظ�����
	if sdup then
		--�����ظ����ż��
		if sduprd then
			sys.timer_start(play,sduprd,spriority,styp,spath,svol,scb,sdup,sduprd)
		end
	--����Ҫ�ظ�����
	else
		--������ڲ��ŵ���Ƶ�лص���������ִ�лص����������0
		if scb then scb(0) end
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
	end
end

--[[
��������playerr
����  ����Ƶ����ʧ�ܴ�����
����  ����
����ֵ����
]]
function playerr()
	print("playerr")
	if styp=="RECORD" then stoprecord() end
	--������ڲ��ŵ���Ƶ�лص���������ִ�лص����������1
	if scb then scb(1) end
	spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
end

local stopreqcb
--[[
��������audstopreq
����  ��lib�ű��䷢����ϢAUDIO_STOP_REQ�Ĵ�����
����  ��
		cb����Ƶֹͣ��Ļص�����
����ֵ����
]]
local function audstopreq(cb)
	if stop() and cb then cb() return end
	stopreqcb = cb
end

local procer =
{
	AUDIO_STOP_REQ = audstopreq,--lib�ű���ͨ��������Ϣ��ʵ����Ƶֹͣ���û��ű���Ҫ���ʹ���Ϣ
}
--ע����Ϣ��������
sys.regapp(procer)
