--[[
ģ�����ƣ���ѧ�����
ģ�鹦�ܣ�ʵ�ֳ��õ���ѧ�⺯��
ģ������޸�ʱ�䣺2017.02.14
]]
module("maths")

--[[
��������sqrt
����  ����ƽ����
����  ��
		a����Ҫ��ƽ��������ֵ��number����
����ֵ��ƽ������number���͵�����
]]
function sqrt(a)
	local x
	if a == 0 or a == 1 then return a end
	x=a/2
	for i=1,100 do
		x=(x+a/x)/2
	end
	return x
end
