--[[
ģ�����ƣ�Lua�Դ��ӿڲ���
ģ�鹦�ܣ�����ĳЩLua�Դ��Ľӿڣ���ܵ����쳣ʱ����
ģ������޸�ʱ�䣺2017.02.14
]]

--����Lua�Դ���os.time�ӿ�
local oldostime = os.time

--[[
��������safeostime
����  ����װ�Զ����os.time�ӿ�
����  ��
		t�����ڱ����û�д��룬ʹ��ϵͳ��ǰʱ��
����ֵ��tʱ�����1970��1��1��0ʱ0��0��������������
]]
function safeostime(t)
	return oldostime(t) or 0
end

--Lua�Դ���os.time�ӿ�ָ���Զ����safeostime�ӿ�
os.time = safeostime
