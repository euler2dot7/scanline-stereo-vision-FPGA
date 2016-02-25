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
	component BRAM_WF is	
	port (
		clk: in std_logic;
		we: in std_logic;
		addr_a: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
		addr_b: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
		din_a: in std_logic_vector (DATA_WIDTH - 1 downto 0 );
		dout_b: out std_logic_vector (DATA_WIDTH -1 downto 0 )
	);
	end component;
	
	component BRAM_RF is
	port (
		CLK		: in std_logic;
		WE		: in std_logic;
		ADDR_A	: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
		DIN		: in std_logic_vector (DATA_WIDTH - 1 downto 0 );
		DOUT	: out std_logic_vector (DATA_WIDTH -1 downto 0 )
	);
	end component;

	signal ADDRL_A	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal ADDRL_B	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal DINL		:  std_logic_vector (DATA_WIDTH - 1 downto 0 );
	signal DOUTL	: std_logic_vector (DATA_WIDTH - 1 downto 0 );
	
	signal ADDRR_A	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal ADDRR_B	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal DINR		: std_logic_vector (DATA_WIDTH - 1 downto 0 );
	signal DOUTR	: std_logic_vector (DATA_WIDTH - 1 downto 0 );

	signal ADDRD_A	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal D_IN_LR_DISP		: std_logic_vector (DATA_WIDTH - 1 downto 0 );
	signal DOUTD	: std_logic_vector (DATA_WIDTH - 1 downto 0 );
	
	function comparator(A: std_logic_vector(7 downto 0); B: std_logic_vector(7 downto 0)) return boolean is
	begin
		return A(7 downto 0) > B(7 downto 0);
	end comparator;
	
	function comparator1(A: std_logic_vector(7 downto 0); B: std_logic_vector(7 downto 0)) return boolean is
	begin
		return A(7 downto 0) > B(7 downto 0);
	end comparator1;

	signal LOCAL_COST 		: GlobalCosts_array;
	signal GLOBAL_COST 		: GlobalCosts_array;
	signal GLOBAL_COST_PREV	: GlobalCosts_array;
	signal LINE_RIGHT 		: Line_array;
	signal LEFT_RL			: pixel;
	signal DD				: std_logic_vector(5 downto 0);
	signal I				: std_logic_vector(1 downto 0);
	signal B				: std_logic;
	signal J				: int_640;
	signal LineRight0		: Line_array;
	signal LineRight1		: Line_array;
	signal RL_Line			: RL_Line_array;
	signal first_line		: std_logic_vector(1 downto 0);
	signal z				: int_640;
begin

BramLineLeft : BRAM_RF
	port map(
		CLK => PIXEL_CLOCK,
		WE		=>'1',
		ADDR_A	=> ADDRL_A,
		DIN		=> DINL,
		DOUT	=> DOUTL 
	);

BramLineRight : BRAM_WF
		port map(
			CLK		=> PIXEL_CLOCK,
			WE 		=> '1',
			ADDR_A 	=> ADDRR_A,
			ADDR_B	=> ADDRR_B,
			DIN_A	=> DINR ,
			DOUT_B	=> DOUTR 
		);
		
BramLineDisp : BRAM_RF
	port map(
		CLK => PIXEL_CLOCK,
		WE =>'1',
		ADDR_A => ADDRD_A,
		DIN=> D_IN_LR_DISP,
		DOUT=> DOUTD 
	);


ID : process(PIXEL_CLOCK) is

begin
	if PIXEL_CLOCK = '1' and PIXEL_CLOCK'EVENT then
		if RESET = '1' then
			FRAME_VALID_OUT <= '0';
			LINE_VALID_OUT <= '0';
			j <= 0;
			z <= 0;
			b <= '0';
			ADDRD_A <= (others => '0');
			first_line <= "00";
			
		else
			if FRAME_VALID_IN = '1' then
				FRAME_VALID_OUT <= '1';
				if LINE_VALID_IN = '1' then
					LINE_VALID_OUT <= '1';					
					j <= j + 1;

					if b = '0' then
						z <= j;
					else
						z <= Width - j - 1;
					end if;
					
					ADDRD_A <= conv_std_logic_vector(z, ADDR_WIDTH);
				else
					if j = Width then
						b <= not b;
						if first_line = "00" then
							first_line <= "01";
						elsif first_line = "01" then
							first_line <= "10";
						elsif first_line = "10" then
							first_line <= "11";
						end if;
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
	variable LeftRL			: pixel;
begin
	if(PIPELINE_CLOCK'EVENT and PIPELINE_CLOCK = '1') then
	if RESET = '1' then
			LineRight0	<= (others =>(others => '0'));
			LineRight1	<= (others =>(others => '0'));
			LINE_RIGHT	<= (others =>(others => '0'));
			LEFT_RL		<= (others => '0');
			LeftRL		:= (others => '0');
			DINL <= (others => '0');
			DINR <= (others => '0');
			i <= "00";
			addrL_a <= (others => '0');
			addrR_a <= (others => '0');
			addrR_b <= (others => '0');
		else
			if(i = "00") then
			elsif(i = "01") then
				if b = '0' then
					addrL_a <= conv_std_logic_vector(j  , ADDR_WIDTH);
					addrR_a <= conv_std_logic_vector(j , ADDR_WIDTH);
					addrR_b <= conv_std_logic_vector(j  + dmax, ADDR_WIDTH);
					if j  < Width - dmax then
						LineRight0 <= doutR & LineRight0(dmax - 1 downto 1);
					else
						addrR_b <= conv_std_logic_vector(Width - 1, ADDR_WIDTH);
						LineRight0 <= "00000000" & LineRight0(dmax - 1 downto 1);
					end if;
					LineRight1 <= LineRight1(dmax - 2 downto 0) & RIGHT;
					LINE_RIGHT <= LineRight0;
				else
					addrL_a <= conv_std_logic_vector(Width - j - 1, ADDR_WIDTH);
					addrR_a <= conv_std_logic_vector(Width - j - 1, ADDR_WIDTH);
					addrR_b <= conv_std_logic_vector(Width - j - 1 - dmax, ADDR_WIDTH);
					if  j < Width - 1 - dmax then
						LineRight1 <= doutR & LineRight1(dmax - 1 downto 1);
					else
						addrR_b <= conv_std_logic_vector(0, ADDR_WIDTH);
						LineRight1 <= "00000000" & LineRight1(dmax - 1 downto 1);
					end if;				
					LineRight0 <= LineRight0( dmax - 2 downto 0) & RIGHT  ;
					LINE_RIGHT <= LineRight1;
				end if;
				
				LeftRL :=  doutL;
				dinL <= LEFT;
				dinR <= RIGHT;
				LEFT_RL <= LeftRL;
				
				if first_line /= "11" then
					LEFT_RL <= (others => '0');
					LINE_RIGHT <= (others => (others => '0'));
				end if;
			elsif(i = "10") then
			elsif(i = "11") then
			end if;
				i <= i + 1;

		end if;
	end if;
end process f;

LOCAL_EX_loop : for k in 0 to dmax-1 generate
begin
	LOCAL_EX : process(PIPELINE_CLOCK) is
		variable LocalCost : LP_element;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT then
			if RESET = '1' then
				LocalCost		:= (others => '0');
				LOCAL_COST(k)	<= (others => '0');
			elsif LINE_VALID_IN = '1'  then
				if (LEFT_RL > LINE_RIGHT(k) )then
					LocalCost := (LEFT_RL - LINE_RIGHT(k));
				else
					LocalCost := (LINE_RIGHT(k) - LEFT_RL);
				end if;
					LOCAL_COST(k) <= LocalCost;
			end if;
		end if;	
	end process LOCAL_EX;
end generate LOCAL_EX_loop;


GLOBAL_EX_loop : for k in 1 to dmax-2 generate
begin	
	EX : process(PIPELINE_CLOCK) is
		variable LP : LP_element ;
		variable nn : int_64;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT then
			if RESET = '1' then
				GLOBAL_COST(k) <= (others => '0');
				nn := 0;
				LP := (others => '0');
			elsif LINE_VALID_IN = '1' then
				nn := k - 1;
				LP := GLOBAL_COST_PREV(k);
				if(comparator(GLOBAL_COST_PREV(k - 1),GLOBAL_COST_PREV(k + 1))) then
					nn := k + 1;
				end if;
				if(comparator(GLOBAL_COST_PREV(k),GLOBAL_COST_PREV(nn) + P1)) then
					LP := GLOBAL_COST_PREV(nn) + P1;
				end if;		
				if(comparator(LP,P2 + GLOBAL_COST_PREV(conv_integer(dd)))) then
					LP := P2 + GLOBAL_COST_PREV(conv_integer(dd));
				end if;
				GLOBAL_COST(k) <= LOCAL_COST(k) + LP - GLOBAL_COST_PREV(conv_integer(dd));
			end if; --RESET		
		end if; --PIXEL_CLOCK
	end process EX;
end generate GLOBAL_EX_loop;

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


DISP : process(PIPELINE_CLOCK) is	
	variable d: int_64;
	variable z : integer;
	variable GlobalCostsRL: GlobalCosts_array;
	variable dRL : std_logic_vector(5 downto 0);
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' then
			GLOBAL_COST_PREV <= (others => (others => '0'));
			GlobalCostsRL	:= (others => (others => '0'));
			dRL				:= (others => '0');
			dd				<= (others => '0');
			DATA_OUT		<= (others => '0');
			D_IN_LR_DISP			<= (others => '0');
		elsif LINE_VALID_IN = '1'    then
			d := 0;
			for k in 0 to dmax - 1 loop
				if(comparator1(GLOBAL_COST(d), GLOBAL_COST(k))) then
					d := k;
				end if;
			end loop;

			if  i = "00" then				
				null;
			elsif  i = "01" then
				GLOBAL_COST_PREV <= GlobalCostsRL;
				dd <= dRL;
			elsif  i = "10" then
				GLOBAL_COST_PREV <= (others => ("00011111"));
			elsif  i = "11" then

				dRL		:= conv_std_logic_vector(d, 6);
				GlobalCostsRL := GLOBAL_COST;

				if first_line = "00" then
					D_IN_LR_DISP	<= (others => '0');
					DATA_OUT		<= (others => '0');
				else
					DATA_OUT 		<= DOUTD(4 downto 0) & "000";
					D_IN_LR_DISP	<= conv_std_logic_vector(d, 8);
				end if;

				GLOBAL_COST_PREV <= (others => ("11011000"));				
			end if;	--i
		end if;	--line valid
	end if;	--reset
end process DISP;
 
end Behavioral;	