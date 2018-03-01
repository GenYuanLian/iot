--[[
ģ�����ƣ����߹������Ƿ���ģʽ��
ģ�鹦�ܣ�lua�ű�Ӧ�õ����߿���
ʹ�÷�ʽ��ο���script/demo/pm
ģ������޸�ʱ�䣺2017.02.13
]]

--[[
����������һ���ֵ�˵����
Ŀǰ�����ߴ��������ַ�ʽ��
һ���ǵײ�core�ڲ����Զ���������tcp���ͻ��߽�������ʱ�����Զ����ѣ����ͽ��ս����󣬻��Զ����ߣ��ⲿ�ֲ���lua�ű�����
��һ����lua�ű�ʹ��pm.sleep��pm.wake���п��ƣ����磬uart������Χ�豸��uart��������ǰ��Ҫ����ȥpm.wake���������ܱ�֤ǰ����յ����ݲ�����������Ҫͨ��ʱ������pm.sleep�������lcd����Ŀ��Ҳ��ͬ������
������ʱ��������30mA����
������ǹ�����ƵĲ����ߣ�һ��Ҫ��֤pm.wake("A")�ˣ��еط�ȥ����pm.sleep("A")
]]

--����ģ��,����������
local base = _G
local pmd = require"pmd"
local pairs = base.pairs
local assert = base.assert
module("pm")

--���ѱ�Ǳ�
local tags = {}
--luaӦ���Ƿ����ߣ�true���ߣ�����û����
local flag = true

--[[
��������isleep
����  ����ȡluaӦ�õ�����״̬
����  ����
����ֵ��true���ߣ�����û����
]]
function isleep()
	return flag
end

--[[
��������wake
����  ��luaӦ�û���ϵͳ
����  ��
		tag�����ѱ�ǣ��û��Զ���
����ֵ����
]]
function wake(tag)
	assert(tag and tag~=nil,"pm.wake tag invalid")
	--���ѱ��д˻��ѱ��λ����1
	tags[tag] = 1
	--���luaӦ�ô�������״̬
	if flag == true then
		--����Ϊ����״̬
		flag = false
		--���õײ�����ӿڣ���������ϵͳ
		pmd.sleep(0)
	end
end

--[[
��������sleep
����  ��luaӦ������ϵͳ
����  ��
		tag�����߱�ǣ��û��Զ��壬��wake�еı�Ǳ���һ��
����ֵ����
]]
function sleep(tag)
	assert(tag and tag~=nil,"pm.sleep tag invalid")
	--���ѱ��д����߱��λ����0
	tags[tag] = 0

	if tags[tag] < 0 then
		base.print("pm.sleep:error",tag)
		tags[tag] = 0
	end

	--ֻҪ�����κ�һ����ǻ���,��˯��
	for k,v in pairs(tags) do
		if v > 0 then
			return
		end
	end

	flag = true
	----���õײ�����ӿڣ���������ϵͳ
	pmd.sleep(1)
end
