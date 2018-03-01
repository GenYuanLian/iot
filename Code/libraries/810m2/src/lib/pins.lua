--[[
ģ�����ƣ��������ù���
ģ�鹦�ܣ�������������롢�жϵ����ú͹���
ģ������޸�ʱ�䣺2017.03.04
]]

module(...,package.seeall)

local allpins = {}

--[[
��������init
����  ����ʼ��allpins���е���������
����  ����  
����ֵ����
]]
local function init()
	for _,v in ipairs(allpins) do
		if v.init == false then
			-- ������ʼ��
		elseif v.ptype == nil or v.ptype == "GPIO" then
			v.inited = true
			pio.pin.setdir(v.dir or pio.OUTPUT,v.pin)
			--[[if v.dir == nil or v.dir == pio.OUTPUT then
				set(v.defval or false,v)
			else]]
			if v.dir == pio.INPUT or v.dir == pio.INT then
				v.val = pio.pin.getval(v.pin) == v.valid
			end
		--[[elseif v.set then
			set(v.defval or false,v)]]
		end
	end
end

--[[
��������reg
����  ��ע��һ�����߶��PIN�ŵ����ã����ҳ�ʼ��PIN��
����  ��
		cfg1��PIN�����ã�table����		
		...��0������PIN������
����ֵ����
]]
function reg(cfg1,...)
	table.insert(allpins,cfg1)
	local i
	for i=1,arg.n do
		table.insert(allpins,unpack(arg,i,i))
		print("reg",unpack(arg,i,i).pin)
	end
	init()
end

--[[
��������dereg
����  ����ע��һ�����߶��PIN�ŵ����ã����ҹر�PIN��
����  ��
		cfg1��PIN�����ã�table����		
		...��0������PIN������
����ֵ����
]]
function dereg(cfg1,...)
	pio.pin.close(cfg1.pin)
	for k,v in pairs(allpins) do
		if v.pin==cfg1.pin then
			table.remove(allpins,k)
		end
	end
	
	for k,v in pairs(allpins) do
		pio.pin.close(unpack(arg,i,i).pin)
		if v.pin==unpack(arg,i,i).pin then
			table.remove(allpins,k)
		end
	end
end

--[[
��������get
����  ����ȡ������ж������ŵĵ�ƽ״̬
����  ��  
        p�� ���ŵ�����
����ֵ��������ŵĵ�ƽ���������õ�valid��ֵһ�£�����true�����򷵻�false
]]
function get(p)
	return pio.pin.getval(p.pin) == p.valid
end

--[[
��������set
����  ��������������ŵĵ�ƽ״̬
����  ��  
        bval��true��ʾ�����õ�validֵһ���ĵ�ƽ״̬��false��ʾ�෴״̬
		p�� ���ŵ�����
����ֵ����
]]
function set(bval,p)
	p.val = bval

	if not p.inited and (p.ptype == nil or p.ptype == "GPIO") then
		p.inited = true
		pio.pin.setdir(p.dir or pio.OUTPUT,p.pin)
	end

	if p.set then p.set(bval,p) return end

	if p.ptype ~= nil and p.ptype ~= "GPIO" then print("unknwon pin type:",p.ptype) return end

	local valid = p.valid == 0 and 0 or 1 -- Ĭ�ϸ���Ч
	local notvalid = p.valid == 0 and 1 or 0
	local val = bval == true and valid or notvalid

	if p.pin then pio.pin.setval(val,p.pin) end
end

--[[
��������setdir
����  ���������ŵķ���
����  ��  
        dir��pio.OUTPUT��pio.OUTPUT1��pio.INPUT����pio.INT����ϸ����ο����ļ�����ġ�dirֵ���塱
		p�� ���ŵ�����
����ֵ����
]]
function setdir(dir,p)
	if p and p.ptype == nil or p.ptype == "GPIO" then
		if not p.inited then
			p.inited = true
		end
		if p.pin then
			pio.pin.close(p.pin)
			pio.pin.setdir(dir,p.pin)
			p.dir = dir
		end
	end
end


--[[
��������intmsg
����  ���ж������ŵ��жϴ�����򣬻��׳�һ���߼��ж���Ϣ������ģ��ʹ��
����  ��  
        msg��table���ͣ�msg.int_id���жϵ�ƽ���ͣ�cpu.INT_GPIO_POSEDGE��ʾ�ߵ�ƽ�жϣ�msg.int_resnum���жϵ�����id
����ֵ����
]]
local function intmsg(msg)
	local status = 0

	if msg.int_id == cpu.INT_GPIO_POSEDGE then status = 1 end

	for _,v in ipairs(allpins) do
		if v.dir == pio.INT and msg.int_resnum == v.pin then
			v.val = v.valid == status
			if v.intcb then v.intcb(v.val) end
			return
		end
	end
end
--ע�������жϵĴ�����
sys.regmsg(rtos.MSG_INT,intmsg)
