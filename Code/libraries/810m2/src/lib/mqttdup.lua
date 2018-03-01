--[[
ģ�����ƣ�publish�����ط�����
ģ�鹦�ܣ�QoSΪ1��publish�����ط�����
          ����publish���ĺ����DUP_TIME����û�յ�puback������Զ��ط�������ط�DUP_CNT�Σ������û�յ�puback�������ط����׳�MQTT_DUP_FAIL��Ϣ��Ȼ�����ñ���
ģ������޸�ʱ�䣺2017.02.24
]]

module(...,package.seeall)

--DUP_TIME������publish���ĺ�DUP_TIME�����ж���û���յ�puback
--DUP_CNT��û���յ�puback���ĵ�publish�����ط���������
--tlist��publish���Ĵ洢��
local DUP_TIME,DUP_CNT,tlist = 10,3,{}
local slen = string.len

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������mqttdupǰ׺
����  ����
����ֵ����
]]
local function print(...)
	_G.print("mqttdup",...)
end

--[[
��������timerfnc
����  ��1��Ķ�ʱ������������ѯtlist�е�publish�����Ƿ�ʱ����Ҫ�ط�
����  ����
����ֵ����
]]
local function timerfnc()
	print("timerfnc")
	for i=1,#tlist do
		print(i,tlist[i].tm)
		if tlist[i].tm > 0 then
			tlist[i].tm = tlist[i].tm-1
			if tlist[i].tm == 0 then
				sys.dispatch("MQTT_DUP_IND",tlist[i].sckidx,tlist[i].dat)
			end
		end
	end
end

--[[
��������timer
����  ���������߹ر�1��Ķ�ʱ��
����  ��
		start���������߹رգ�true������false����nil�ر�
����ֵ����
]]
local function timer(start)
	print("timer",start,#tlist)
	if start then
		if not sys.timer_is_active(timerfnc) then
			sys.timer_loop_start(timerfnc,1000)
		end
	else
		if #tlist == 0 then sys.timer_stop(timerfnc) end
	end
end

--[[
��������ins
����  ������һ��publish���ĵ��洢��
����  ��
		sckidx��socket idx
		typ�������Զ�������
		dat��publish��������
		seq��publish�������к�
		cb���û��ص�����
		cbtag���û��ص������ĵ�һ������
����ֵ����
]]
function ins(sckidx,typ,dat,seq,cb,cbtag)
	print("ins",typ,(slen(dat or "") > 200) and "" or common.binstohexs(dat),seq or "nil" or common.binstohex(seq))
	table.insert(tlist,{sckidx=sckidx,typ=typ,dat=dat,seq=seq,cb=cb,cbtag=cbtag,cnt=DUP_CNT,tm=DUP_TIME})
	timer(true)
end

--[[
��������rmv
����  ���Ӵ洢��ɾ��һ��publish����
����  ��
		sckidx��socket idx
		typ�������Զ�������
		dat��publish��������
		seq��publish�������к�
����ֵ����
]]
function rmv(sckidx,typ,dat,seq)
	print("rmv",typ or getyp(seq),(slen(dat or "") > 200) and "" or common.binstohexs(dat),seq or "nil" or common.binstohex(seq))
	for i=1,#tlist do
		if (sckidx == tlist[i].sckidx) and (not typ or typ == tlist[i].typ) and (not dat or dat == tlist[i].dat) and (not seq or seq == tlist[i].seq) then
			table.remove(tlist,i)
			break
		end
	end
	timer()
end

--[[
��������rmvall
����  ���Ӵ洢��ɾ������publish����
����  ��
		sckidx��socket idx
����ֵ����
]]
function rmvall(sckidx)
	tlist = {}
	for i=#tlist,1,-1 do
		if sckidx == tlist[i].sckidx then
			table.remove(tlist,i)
		end
	end
	timer()
end

--[[
��������rsm
����  ���ط�һ��publish���ĺ�Ļص�����
����  ��
		sckidx��socket idx
		s��publish��������
����ֵ����
]]
function rsm(sckidx,s)
	for i=1,#tlist do
		if sckidx==tlist[i].sckidx and tlist[i].dat==s then
			tlist[i].cnt = tlist[i].cnt - 1
			if tlist[i].cnt == 0 then
				sys.dispatch("MQTT_DUP_FAIL",tlist[i].sckidx,tlist[i].typ,tlist[i].seq,tlist[i].cb,tlist[i].cbtag)
				rmv(tlist[i].sckidx,nil,s) 
				return 
			end
			tlist[i].tm = DUP_TIME			
			break
		end
	end
end

--[[
��������getyp
����  ���������кŲ���publish�����û��Զ�������
����  ��
		sckidx��socket idx
		seq��publish�������к�
����ֵ���û��Զ������͡��û��ص��������û��ص������ĵ�һ������
]]
function getyp(sckidx,seq)
	for i=1,#tlist do
		if seq and seq == tlist[i].seq and sckidx==tlist[i].sckidx then
			return tlist[i].typ,tlist[i].cb,tlist[i].cbtag
		end
	end
end
