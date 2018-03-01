--[[
ģ�����ƣ�Ӳ�����Ź�
ģ�鹦�ܣ�֧��Ӳ�����Ź�����
ģ������޸�ʱ�䣺2017.02.16
����ĵ��ο� doc\С��GPS��λ������ĵ�\Watchdog descritption.doc
]]

module(...,package.seeall)

--ģ�鸴λ��Ƭ������
local RST_SCMWD_PIN = pio.P0_16
--ģ��͵�Ƭ���໥ι������
local WATCHDOG_PIN = pio.P0_20

--scm_active����Ƭ���Ƿ�����������true��ʾ������false��nil��ʾ�쳣
--get_scm_cnt������ⵥƬ����ģ��ι���Ƿ���������ʣ�����
local scm_active,get_scm_cnt = true,20
--testcnt��ι�����Թ������Ѿ�ι���Ĵ���
--testing���Ƿ�����ι������
local testcnt,testing = 0

--[[
��������getscm
����  ����ȡ"��Ƭ����ģ��ι��������"��ƽ
����  ��
		tag��"normal"��ʾ����ι����"test"��ʾι������
����ֵ����
]]
local function getscm(tag)
	--������ڽ���ι�����ԣ�����������ι��
	if tag=="normal" and testing then return end
	--���ʣ�������һ
	get_scm_cnt = get_scm_cnt - 1
	--�����ι�����ԣ�ͣ������ι��������
	if tag=="test" then
		sys.timer_stop(getscm,"normal")
	end
	--���ʣ���������Ϊ0
	if get_scm_cnt > 0 then
		--ι������
		if tag=="test" then
			--�����⵽�ߵ�ƽ
			if pio.pin.getval(WATCHDOG_PIN) == 1 then				
				testcnt = testcnt+1
				--û����������3��ι����100����󣬼����´�ι��
				if testcnt<3 then
					sys.timer_start(feed,100,"test")
					get_scm_cnt = 20
					return
				--ι�����Խ���������3��ι������Ƭ���Ḵλģ��
				else
					testing = nil
				end
			end
		end
		--100����֮����ż��
		sys.timer_start(getscm,100,tag)
	--������
	else
		get_scm_cnt = 20
		if tag=="test" then
			testing = nil
		end
		--����ι�� ���� ��Ƭ�������쳣
		if tag=="normal" and not scm_active then
			--��λ��Ƭ��
			pio.pin.setval(0,RST_SCMWD_PIN)
			sys.timer_start(pio.pin.setval,100,1,RST_SCMWD_PIN)
			print("wdt reset 153b")
			scm_active = true
		end
	end
	--�����⵽�͵�ƽ�����ʾ��Ƭ����������
	if pio.pin.getval(WATCHDOG_PIN) == 0 and not scm_active then
		scm_active = true
		print("wdt scm_active = true")
	end
end

--[[
��������feedend
����  �����"��Ƭ����ģ��ι��"�Ƿ�����
����  ��
		tag��"normal"��ʾ����ι����"test"��ʾι������
����ֵ����
]]
local function feedend(tag)
	--������ڽ���ι�����ԣ�����������ι��
	if tag=="normal" and testing then return end
	--�໥ι����������Ϊ����
	pio.pin.close(WATCHDOG_PIN)
	pio.pin.setdir(pio.INPUT,WATCHDOG_PIN)
	print("wdt feedend",tag)
	--�����ι�����ԣ�ͣ������ι��������
	if tag=="test" then
		sys.timer_stop(getscm,"normal")
	end
	--100�����ȥ��һ��ι�����ŵ������ƽ
	--ÿ100����ȥ��һ�Σ�������20�Σ�ֻҪ��һ�ζ����͵�ƽ������Ϊ"��Ƭ����ģ��ι��"����
	sys.timer_start(getscm,100,tag)
end

--[[
��������feed
����  ��ģ�鿪ʼ�Ե�Ƭ��ι��
����  ��
		tag��"normal"��ʾ����ι����"test"��ʾι������
����ֵ����
]]
function feed(tag)
	--������ڽ���ι�����ԣ�����������ι��
	if tag=="normal" and testing then return end
	--�����Ƭ���������� ���� ���ڽ���ι������
	if scm_active or tag=="test" then
		scm_active = false
	end

	--�໥ι����������Ϊ�����"ģ�鿪ʼ�Ե�Ƭ��ι��"�����2��ĵ͵�ƽ
	pio.pin.close(WATCHDOG_PIN)
	pio.pin.setdir(pio.OUTPUT,WATCHDOG_PIN)
	pio.pin.setval(0,WATCHDOG_PIN)
	print("wdt feed",tag)
	--2���������´�����ι��
	sys.timer_start(feed,120000,"normal")
	--�����ι�����ԣ�ͣ������ι��������
	if tag=="test" then
		sys.timer_stop(feedend,"normal")
	end
	--2���ʼ���"��Ƭ����ģ��ι��"�Ƿ�����
	sys.timer_start(feedend,2000,tag)
end

--[[
��������open
����  ����Air810�������ϵ�Ӳ�����Ź����ܣ�������ι��
����  ����
����ֵ����
]]
function open()
	pio.pin.setdir(pio.OUTPUT,WATCHDOG_PIN)
	pio.pin.setval(1,WATCHDOG_PIN)
	feed("normal")
end

--[[
��������close
����  ���ر�Air810�������ϵ�Ӳ�����Ź�����
����  ����
����ֵ����
]]
function close()
	sys.timer_stop_all(feedend)
	sys.timer_stop_all(feed)
	sys.timer_stop_all(getscm)
	sys.timer_stop(pio.pin.setval,1,RST_SCMWD_PIN)
	pio.pin.close(RST_SCMWD_PIN)
	pio.pin.close(WATCHDOG_PIN)
	scm_active,get_scm_cnt,testcnt,testing = true,20,0
end

--[[
��������test
����  �����ԡ�Air810�������ϵ�Ӳ�����Ź���λAir810ģ�顱�Ĺ���
����  ����
����ֵ����
]]
function test()
	if not testing then
		testcnt,testing = 0,true
		feed("test")
	end
end


--[[
��������begin
����  ������ι������
����  ����
����ֵ����
]]
local function begin()
	--ģ�鸴λ��Ƭ�����ţ�Ĭ������ߵ�ƽ
	pio.pin.setdir(pio.OUTPUT1,RST_SCMWD_PIN)
	pio.pin.setval(1,RST_SCMWD_PIN)
	open()
end

--[[
��������setup
����  ������ι��ʹ�õ���������
����  ��
		rst��ģ�鸴λ��Ƭ������
		wd��ģ��͵�Ƭ���໥ι������
����ֵ����
]]
function setup(rst,wd)
	RST_SCMWD_PIN,WATCHDOG_PIN = rst,wd
	sys.timer_stop(begin)
	begin()
end

sys.timer_start(begin,2000)
