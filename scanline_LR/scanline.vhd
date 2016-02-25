library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.const.all;

entity scanline is
	Port (  
		RESET 				: in  std_logic;
		FRAME_VALID_IN 		: in  std_logic;
		LINE_VALID_IN 		: in  std_logic;
		LEFT 				: in  std_logic_vector (7 downto 0);
		RIGHT 				: in  std_logic_vector (7 downto 0);
		PIXEL_CLOCK			: in  std_logic;    
		PIPELINE_CLOCK		: in  std_logic;    
		DATA_OUT 			: out  std_logic_vector (7 downto 0);
		FRAME_VALID_OUT 	: out  std_logic;
		LINE_VALID_OUT 		: out  std_logic
	);
end scanline;


architecture Behavioral of scanline is

	function comparator(A: std_logic_vector(7 downto 0); B: std_logic_vector(7 downto 0)) return boolean is
	begin
		return A(7 downto 5) > B(7 downto 5);
	end comparator;
	
	function comparator1(A: std_logic_vector(7 downto 0); B: std_logic_vector(7 downto 0)) return boolean is
	begin
		return A(7 downto 2) > B(7 downto 2);
	end comparator1;

	signal LOCAL_COST 		: GlobalCosts_array;
	signal GLOBAL_COST 		: GlobalCosts_array;
	signal GLOBAL_COST_PREV	: GlobalCosts_array;
	signal LINE_RIGHT 		: Line_array;
	signal LEFT_RL			: pixel;
	signal dd				: std_logic_vector(5 downto 0);
	signal i				: std_logic_vector(1 downto 0);
	signal b				: std_logic;
	signal j				: integer := 0;

	signal dpl0			: d_pl0_array;
	signal dpl1			: d_pl1_array;
	signal GC0			: GC0_array;
	signal GC1			: GC1_array;
begin


ID : process(PIXEL_CLOCK) is
begin
	if PIXEL_CLOCK = '1' and PIXEL_CLOCK'EVENT then
		if RESET = '1' then
			FRAME_VALID_OUT <= '0';
			LINE_VALID_OUT <= '0';
			j <= 0;
			b <= '0';
		else
			if FRAME_VALID_IN = '1' then
				FRAME_VALID_OUT <= '1';
				if LINE_VALID_IN = '1' then
					LINE_VALID_OUT <= '1';					
					j <= j + 1;
				else
					if j = Width then
						b <= not b;
					end if;
					LINE_VALID_OUT <= '0';					
					j <= 0;
				end if;
			else
				FRAME_VALID_OUT <= '0';
			end if;
		end if; --RESET			
	end if; -- PIXEL CLOCK
end process ID;

F : process(PIPELINE_CLOCK) is
	variable LineRightLR : Line_array;
begin

	if(PIPELINE_CLOCK'EVENT and PIPELINE_CLOCK = '1') then
		if RESET = '1' then
			LEFT_RL		<= (others => '0');
			LINE_RIGHT  <= (others =>(others => '0'));
			LineRightLR := (others =>(others => '0'));
			i <= "00";	
		elsif LINE_VALID_IN = '1' then
			if(i = "00") then
				LEFT_RL		<= (others => '0');
				LINE_RIGHT  <= (others =>(others => '0'));
			elsif(i = "01") then
				LEFT_RL		<= (others => '0');
				LINE_RIGHT  <= (others =>(others => '0'));
			elsif(i = "10") then
				LineRightLR := LineRightLR(dmax - 2 downto 0) & RIGHT;
				LINE_RIGHT <= LineRightLR;
				LEFT_RL <= LEFT;
			elsif(i = "11") then
				LEFT_RL		<= (others => '0');
				LINE_RIGHT  <= (others =>(others => '0'));
			end if;
				i <= i + 1;
		end if;
	end if;
end process F;

LOCAL_EX_loop : for k in 0 to dmax-1 generate
begin
	LOCAL_EX : process(PIPELINE_CLOCK) is
		variable LocalCost : LP_element;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT then
			if RESET = '1' then
				LocalCost := (others => '0');
				LOCAL_COST(k) <= (others => '0');
			elsif LINE_VALID_IN = '1' then
--					LocalCost := (abs( signed(LEFT_RL) - signed(LINE_RIGHT(k)) ));
				if (LEFT_RL > LINE_RIGHT(k) )then
					LocalCost := (LEFT_RL - LINE_RIGHT(k));
				else
					LocalCost := (LINE_RIGHT(k) - LEFT_RL);
				end if;
				if LocalCost = "XXXXXXXX" then
					LocalCost := (others => '0');
				end if;
				LOCAL_COST(k) <= LocalCost;
			end if;
		end if;	
	end process LOCAL_EX;
end generate LOCAL_EX_loop;

GLOBAL_EX_loop : for k in 1 to dmax-2 generate
begin	
	EX : process(PIPELINE_CLOCK) is
		variable LP		: LP_element ;
		variable GCP	: LP_element ;
		variable nn		: int_64;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT then
			if RESET = '1' or  FRAME_VALID_IN = '0'  then
				GLOBAL_COST(k) <= (others => '0');
				nn	:= 0;
				LP	:= (others => '0');
				GCP	:= (others => '0');
			elsif LINE_VALID_IN = '1' then
				nn	:= k - 1;
				LP := GLOBAL_COST_PREV(k);
				GCP := GLOBAL_COST_PREV(conv_integer(dd));
				if(comparator(GLOBAL_COST_PREV(k - 1),GLOBAL_COST_PREV(k + 1))) then
					nn := k + 1;
				end if;
				if(comparator(LP,GLOBAL_COST_PREV(nn) + P1)) then
					if(comparator(GLOBAL_COST_PREV(nn) + P1,P2 + GCP)) then
						GLOBAL_COST(k) <= LOCAL_COST(k) + P2 ;
					else
						GLOBAL_COST(k) <= LOCAL_COST(k) + GLOBAL_COST_PREV(nn) + P1 - GCP;
					end if;
				else 	
					if(comparator(LP,P2 + GCP)) then
						GLOBAL_COST(k) <= LOCAL_COST(k) + P2  ;
					else
						GLOBAL_COST(k) <= LOCAL_COST(k) + LP - GCP;
					end if;
				end if;		
			end if; --RESET		
		end if; --PIXEL_CLOCK
	end process EX;
end generate GLOBAL_EX_loop;

--GLOBAL_EX_loop : for k in 1 to dmax-2 generate
--begin	
--	EX : process(PIPELINE_CLOCK) is
--		variable LP : LP_element ;
--		variable nn : int_64;
--	begin
--		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT then
--			if RESET = '1' then
--				GLOBAL_COST(k) <= (others => '0');
--				nn := 0;
--				LP := (others => '0');
--			elsif LINE_VALID_IN = '1' then
--				nn := k - 1;
--				LP := GLOBAL_COST_PREV(k);
--				if(comparator(GLOBAL_COST_PREV(k - 1),GLOBAL_COST_PREV(k + 1))) then
--					nn := k + 1;
--				end if;
--				if(comparator(GLOBAL_COST_PREV(k),GLOBAL_COST_PREV(nn) + P1)) then
--					LP := GLOBAL_COST_PREV(nn) + P1;
--				end if;		
--				if(comparator(LP,P2 + GLOBAL_COST_PREV(conv_integer(dd)))) then
--					LP := P2 + GLOBAL_COST_PREV(conv_integer(dd));
--				end if;
--				GLOBAL_COST(k) <= LOCAL_COST(k) + LP - GLOBAL_COST_PREV(conv_integer(dd));
--			end if; --RESET		
--		end if; --PIXEL_CLOCK
--	end process EX;
--end generate GLOBAL_EX_loop;

EX0 : process(PIPELINE_CLOCK) is
	variable LP : LP_element := (others => '0');
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' then
				GLOBAL_COST(0) <= (others => '0');
				LP := (others => '0');				
		elsif LINE_VALID_IN = '1'  then
			LP := GLOBAL_COST_PREV(0);
			if(comparator(LP,GLOBAL_COST_PREV(1) + P1)) then
				LP := GLOBAL_COST_PREV(1) + P1;
			end if;				
			if(comparator(LP,P2 + GLOBAL_COST_PREV(conv_integer(dd)))) then
				LP := P2 + GLOBAL_COST_PREV(conv_integer(dd));
			end if;
			GLOBAL_COST(0) <= LOCAL_COST(0) + LP - GLOBAL_COST_PREV(conv_integer(dd));
		end if; --RESET		
	end if; --PIXEL_CLOCK
end process EX0;

EXDmax : process(PIPELINE_CLOCK) is
	variable LP : LP_element := (others => '0');
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' then
			LP := (others => '0');
			GLOBAL_COST(dmax - 1) <= (others => '0');
		elsif LINE_VALID_IN = '1'  then
			LP := GLOBAL_COST_PREV(dmax - 1);
			if(comparator(GLOBAL_COST_PREV(dmax - 1),GLOBAL_COST_PREV(dmax - 2) + P1)) then
				LP := GLOBAL_COST_PREV(dmax - 2) + P1;
			end if;				
			if(comparator(LP,P2 + GLOBAL_COST_PREV(conv_integer(dd)))) then
				LP := P2 + GLOBAL_COST_PREV(conv_integer(dd));
			end if;
			GLOBAL_COST(dmax - 1) <= LOCAL_COST(dmax - 1) + LP - GLOBAL_COST_PREV(conv_integer(dd));
		end if; --RESET
	end if; --PIXEL_CLOCK
end process EXDmax;

PL0 : for k in 0 to dmax/4 - 1 generate
begin
	DPL00 : process(PIPELINE_CLOCK) is	
	variable d	: int_4;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
			if RESET = '1' then
				dpl0(k)	<= 0;
				GC0(k)	<= (others => '0');
			elsif LINE_VALID_IN = '1' then	
				d := 0;
				for z in 1  to  3 loop
					if(comparator1(GLOBAL_COST(d + k * 4), GLOBAL_COST(z + k * 4))) then
						d := z;
					end if;
				end loop;				
				dpl0(k)	<= d;
				GC0(k)	<= GLOBAL_COST(d + k * 4)(7 downto (7 - apr));
			end if;
		end if;	
	end process DPL00;
end generate PL0;

PL1 : for k in 0 to dmax/16 - 1 generate
begin
	DPL01 : process(PIPELINE_CLOCK) is	
	variable d	: int_4;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
			if RESET = '1' then
				dpl1(k)	<= 0;
				GC1(k)	<= (others => '0');
			elsif LINE_VALID_IN = '1' then					
				d := 0;
				for z in 1 to 3 loop
					if(GC0(d + k * 4)> GC0(z + k * 4)) then
						d := z;
					end if;
				end loop;
				dpl1(k)	<= dpl0(d + k * 4) + d * 4;
				GC1(k)	<= GC0(d + k * 4);
			end if;
		end if;
	end process DPL01;
end generate PL1;

DISP : process(PIPELINE_CLOCK) is	
	variable d		: int_64;
	variable dLR	: int_64;
	variable GlobalCostLR : GlobalCosts_array;
	
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' then
			GLOBAL_COST_PREV <= (others =>(others => '0'));
			dLR := 0;
			dd <= (others => '0');
		elsif LINE_VALID_IN = '1'  then	
			d := 0;
			for z in 0 to dmax / 16 - 1 loop
				if(GC1(d) > GC1(z)) then
					d := z;
				end if;				
			end loop;
			d := dpl1(d) + d * 16;
			
			if i = "01" then
				GlobalCostLR := GLOBAL_COST;
			elsif i= "11" then
				GLOBAL_COST_PREV <= GlobalCostLR;
				dLR := d;
				DATA_OUT <= conv_std_logic_vector(dLR , 5) & "000";				
				dd <= conv_std_logic_vector(dLR, 6);
			end if;
		end if;
	end if;
end process DISP;
 
end Behavioral;