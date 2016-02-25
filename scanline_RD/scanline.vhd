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

	component Minimum is
	port (
		GlobalCost	: 	in GlobalCosts_array;
		disp		: 	out int_64
	);
	end component;

	component BRAM_UD is	
	port (
		clk: in std_logic;
		we: in std_logic;
		addr_a: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
		addr_b: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
		din_a: in std_logic_vector (DATA_WIDTH - 1 downto 0 );
		dout_b: out std_logic_vector (DATA_WIDTH -1 downto 0 )
	);
	end component;
	
	component BRAM_Disp is	
	port (
		clk: in std_logic;
		we: in std_logic;
		addr_a: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
		addr_b: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
		din_a: in std_logic_vector (5 downto 0 );
		dout_b: out std_logic_vector (5 downto 0 )
	);
	end component;


	signal addrRD_a	: Address_Width_array;
	signal addrRD_b	: Address_Width_array;
	signal dinRD_A	: GlobalCosts_array;
	signal doutRD_B	: GlobalCosts_array;

	signal addrDRD_a : std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal addrDRD_b : std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal dinDRD_a : std_logic_vector (5 downto 0 );
	signal doutDRD_b : std_logic_vector (5 downto 0 );
	
	
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
	signal dd				: std_logic_vector(5 downto 0);
	signal i				: std_logic_vector(1 downto 0);
	signal b				: std_logic;
	signal j				: integer := 0;
	
	signal GLOBAL_COST_MIN	: GlobalCosts_array;
	signal MIN_OUT			: int_64;		
begin

	min : Minimum
	port map(
		GlobalCost	=> GLOBAL_COST_MIN,
		disp		=> 	MIN_OUT
	);


	BRAM_loop : for k in 0 to dmax-1 generate
	begin
		BramUD : BRAM_UD
		port map(
			CLK		=> PIXEL_CLOCK,
			WE		=> '1',
			ADDR_A	=> ADDRRD_A(k),
			ADDR_B	=> ADDRRD_B(k),
			DIN_A	=> DINRD_A(k),
			DOUT_B	=> DOUTRD_B(k)
		);
	end generate BRAM_loop;

BramLineDisp : BRAM_Disp
	port map(
		clk => PIXEL_CLOCK,
		we =>'1',
		addr_a => addrDRD_a,
		addr_b => addrDRD_b,
		din_a=> dinDRD_a,
		dout_b=> doutDRD_b 
	);



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
				i <= i + 1;
			elsif(i = "01") then
				LineRightLR := LineRightLR(dmax - 2 downto 0) & RIGHT;
				LINE_RIGHT <= LineRightLR;
				LEFT_RL <= LEFT;
				i <= i + 1;
			elsif(i = "10") then
				LEFT_RL		<= (others => '0');
				LINE_RIGHT  <= (others =>(others => '0'));
				i <= i + 1;
			elsif(i = "11") then
			
				i <= i + 1;
			end if;
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
	variable d		: int_64;
	variable dRD	: int_64;
	variable GlobalCostRD : GlobalCosts_array;
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' then
			GLOBAL_COST_PREV <= (others =>(others => '0'));
			d := 0;
			dRD := 0;
			dd <= (others => '0');
			GlobalCostRD := (others =>(others => '0'));
			GLOBAL_COST_MIN <= (others =>(others => '0'));			
		elsif LINE_VALID_IN = '1'  then	
			GLOBAL_COST_MIN <= GLOBAL_COST;
			d := MIN_OUT;
			
--			d := 0;
--			for k in 0 to dmax - 1 loop
--				if(comparator1(GLOBAL_COST(d), GLOBAL_COST(k))) then
--					d := k;
--				end if;
--			end loop;


			if i = "00" then
				DINRD_A <= GLOBAL_COST;
				GlobalCostRD := DOUTRD_B;		
				
				ADDRRD_B <=(others =>  conv_std_logic_vector(j + 2,ADDR_WIDTH));
				ADDRRD_A <=(others => conv_std_logic_vector(j - 1,ADDR_WIDTH));
						
				for k in 0 to dmax - 1 loop
					if  DOUTRD_B(k) = "XXXXXXXX" then
						GlobalCostRD(k) := (others => '0') ;
					end if;
				end loop;	

--				if d * scale > 255 then
--					DATA_OUT <= conv_std_logic_vector(255,8);
--				else
--					DATA_OUT <= conv_std_logic_vector(d * scale, 8);
--				end if; 

				addrDRD_a	<=	conv_std_logic_vector(j - 1, ADDR_WIDTH);
--				dinDRD_a	<=	conv_std_logic_vector(d, 6);
				
				addrDRD_b <=	conv_std_logic_vector(j + 2, ADDR_WIDTH);
				
				if doutDRD_b = "XXXXXXXX" then
					dRD := 0;
				else
					dRD := conv_integer(doutDRD_b);
				end if;
				
			elsif i = "01" then				
				if d * scale > 255 then
					DATA_OUT <= conv_std_logic_vector(255,8);
				else
					DATA_OUT <= conv_std_logic_vector(d * scale, 8);
				end if; 
				
				dinDRD_a	<=	conv_std_logic_vector(d, 6);

				GLOBAL_COST_PREV <= (others =>(others => '1'));
			elsif i = "10" then
				GLOBAL_COST_PREV <= GlobalCostRD;
				dd <= conv_std_logic_vector(dRD, 6);
			
			
			elsif i= "11" then
				GLOBAL_COST_PREV <= (others =>(others => '1'));
			end if;
		end if;
	end if;
end process DISP;
 
end Behavioral;