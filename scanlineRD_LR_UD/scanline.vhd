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
		LINE_VALID_OUT 		: out  std_logic;
		PIXEL_VALID_OUT		: out  std_logic
	);
end scanline;

architecture Behavioral of scanline is
	

	component BRAM_WF is	
	port (
		CLKA	: IN STD_LOGIC;
		WEA		: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		ADDRA	: IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		DINA	: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		CLKB	: IN STD_LOGIC;
		ADDRB	: IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		DOUTB	: OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
	end component;

	signal ADDRRD_A	: Address_Width_array;
	signal ADDRRD_B	: Address_Width_array;
	signal DINRD_A	: GlobalCosts_array;
	signal DOUTRD_B	: GlobalCosts_array;

	signal ADDRDRD_A	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal ADDRDRD_B	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal DINDRD_A		: std_logic_vector (7 downto 0 );
	signal DOUTDRD_B	: std_logic_vector (7 downto 0 );
	
	signal ADDRUD_A	: Address_Width_array;
	signal ADDRUD_B	: Address_Width_array;
	signal DINUD_A	: GlobalCosts_array;
	signal DOUTUD_B	: GlobalCosts_array;

	signal ADDRD_A	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal ADDRD_B	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal DIND_A	: std_logic_vector (7 downto 0 );
	signal DOUTD_B	: std_logic_vector (7 downto 0 );

	
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
	signal DD				: std_logic_vector(5 downto 0);
	signal I				: std_logic_vector(1 downto 0);
	signal J				: int_640;
	signal FIRST_LINE		: std_logic;
	
	signal GLOBAL_COST_TRE	: GlobalCosts_array;
	
	signal DPL0             : d_pl0_array;
	signal DPL1             : d_pl1_array;
	signal GC0              : GC0_array;
	signal GC1              : GC1_array;

begin

	BRAM_loop : for k in 0 to dmax - 1 generate
	begin
		BramUD : BRAM_WF
		port map(
			CLKA		=> PIXEL_CLOCK,
			CLKB		=> PIXEL_CLOCK,
			WEA		=> "1",
			ADDRA	=> ADDRUD_A(k),
			ADDRB	=> ADDRUD_B(k),
			DINA	=> DINUD_A(k),
			DOUTB	=> DOUTUD_B(k)
		);
		
		BramRD : BRAM_WF
		port map(
			CLKA		=> PIXEL_CLOCK,
			CLKB		=> PIXEL_CLOCK,
			WEA		=> "1",
			ADDRA	=> ADDRRD_A(k),
			ADDRB	=> ADDRRD_B(k),
			DINA	=> DINRD_A(k),
			DOUTB	=> DOUTRD_B(k)
		);
	end generate BRAM_loop;

	LineDispUD : BRAM_WF
	port map(
		CLKA		=> PIXEL_CLOCK,
		CLKB		=> PIXEL_CLOCK,
		WEA		=> "1",
		ADDRA	=> ADDRD_A,
		ADDRB	=> ADDRD_B,
		DINA	=> DIND_A,
		DOUTB	=> DOUTD_B 
	);

	LineDispRD : BRAM_WF
	port map(
		CLKA		=> PIXEL_CLOCK,
		CLKB		=> PIXEL_CLOCK,
		WEA		=>"1",
		ADDRA	=> ADDRDRD_A,
		ADDRB	=> ADDRDRD_B,
		DINA	=> DINDRD_A,
		DOUTB	=> DOUTDRD_B 
	);


ID : process(PIXEL_CLOCK) is
	variable LineRightLR : Line_array;
begin
	if PIXEL_CLOCK = '1' and PIXEL_CLOCK'EVENT then
		if RESET = '1' or FRAME_VALID_IN = '0' then
			FRAME_VALID_OUT <= '0';
--			LINE_VALID_OUT <= '0';
			j <= 0;
			LINE_RIGHT	<= (others =>(others => '0'));
			LEFT_RL		<= (others => '0');
			FIRST_LINE	<= '1';
			LineRightLR := (others =>(others => '0'));
			
			ADDRRD_B	<=(others =>(others => '0'));
			ADDRRD_A	<=(others =>(others => '0'));
			ADDRDRD_A	<= (others => '0');
			ADDRDRD_B	<= (others => '0');
			
			
			ADDRUD_B	<=(others =>(others => '0'));
			ADDRUD_A	<=(others =>(others => '0'));
			ADDRD_B		<=(others => '0');
			ADDRD_A		<=(others => '0');
			
		else
			if FRAME_VALID_IN = '1' then
				FRAME_VALID_OUT <= '1';
				if LINE_VALID_IN = '1'  then
					LineRightLR := LineRightLR(dmax - 2 downto 0) & RIGHT;
					LINE_RIGHT <= LineRightLR;
					LEFT_RL <= LEFT;
					j <= j + 1;
					
					ADDRUD_B <=(others =>  conv_std_logic_vector(j + 1,ADDR_WIDTH));
					ADDRUD_A <=(others => conv_std_logic_vector(j - 1,ADDR_WIDTH));					
					ADDRD_B <=conv_std_logic_vector(j + 1, ADDR_WIDTH);
					ADDRD_A <=conv_std_logic_vector(j - 1, ADDR_WIDTH);					

					ADDRRD_B <=(others =>	conv_std_logic_vector(j + 2,ADDR_WIDTH));
					ADDRRD_A <=(others =>	conv_std_logic_vector(j - 1,ADDR_WIDTH));					
					ADDRDRD_A	<=	conv_std_logic_vector(j - 1, ADDR_WIDTH);					
					ADDRDRD_B	<=	conv_std_logic_vector(j + 2, ADDR_WIDTH);
					
					if first_line = '1' then
						ADDRRD_A	<= (others =>	conv_std_logic_vector(j + 2,ADDR_WIDTH));
						ADDRDRD_A	<=	conv_std_logic_vector(j + 2, ADDR_WIDTH);
						ADDRUD_A <=(others => conv_std_logic_vector(j + 1,ADDR_WIDTH));
						ADDRD_A <=conv_std_logic_vector(j + 1, ADDR_WIDTH);
					end if;
					
				else
					if j = Width then
						FIRST_LINE <= '0';
					end if;
					j <= 0;
				end if;
			else
				FRAME_VALID_OUT <= '0';
			end if;
		end if; --RESET			
	end if; -- PIXEL CLOCK
end process ID;

LOCAL_EX_loop : for k in 0 to dmax-1 generate
begin
	LOCAL_EX : process(PIPELINE_CLOCK) is
		variable LocalCost : LP_element;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT then
			if RESET = '1' or FRAME_VALID_IN = '0' then
				LOCAL_COST(k) <= (others => '0');
			elsif LINE_VALID_IN = '1'  then
				if (LEFT_RL > LINE_RIGHT(k) )then
					LOCAL_COST(k) <= (LEFT_RL - LINE_RIGHT(k));
				else
					LOCAL_COST(k) <= (LINE_RIGHT(k) - LEFT_RL);
				end if;
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

EX0 : process(PIPELINE_CLOCK) is
	variable LP : LP_element := (others => '0');
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' or FRAME_VALID_IN = '0' then
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
		if RESET = '1' or FRAME_VALID_IN = '0' then
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
	variable d              : int_64;
	variable GlobalCost     : GlobalCosts_array;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
			if RESET = '1' or  FRAME_VALID_IN = '0'  then
				dpl0(k) <= 0;
				GC0(k)  <= (others => '0');
				GlobalCost := (others => (others => '0'));
			elsif LINE_VALID_IN = '1' then  
				if i = "10" then
					GlobalCost := GLOBAL_COST_TRE;                                  
				else
					GlobalCost := GLOBAL_COST;
				end if;
				d := 4 * k;
				for z in 4 * k + 1 to 4 * k + 3 loop
					if(comparator1(GlobalCost(d), GlobalCost(z))) then
						d := z;
					end if;
				end loop;                               
				dpl0(k) <= d - 4 * k;
				GC0(k)  <= GlobalCost(d);
			end if;
		end if; 
	end process DPL00;
end generate PL0;

PL1 : for k in 0 to dmax/16 - 1 generate
begin
	DPL01 : process(PIPELINE_CLOCK) is      
	variable d      : int_64;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
			if RESET = '1' or  FRAME_VALID_IN = '0'  then
				dpl1(k) <= 0;
				GC1(k)  <= (others => '0');
			elsif LINE_VALID_IN = '1' then                                  
				d := k * 4;
				for z in k * 4 + 1 to k * 4 + 3 loop
					if comparator1(GC0(d), GC0(z)) then
						d := z;
					end if;
				end loop;                               
				dpl1(k) <= 4 * (d - k * 4) + dpl0(d);
				GC1(k)  <= GC0(d);                                                      
			end if;
		end if;         
	end process DPL01;
end generate PL1;

DISP : process(PIPELINE_CLOCK) is	
	variable d		: int_64;
	variable dpl	: int_64;
	variable dRD 	: int_64;
	variable dLR	: int_64;
	variable dUD	: int_64;
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' or FRAME_VALID_IN = '0' then
			LINE_VALID_OUT <= '0';			
			PIXEL_VALID_OUT <= '0';			
			dd 					<= (others => '0');
			dRD := 0;
			dUD := 0;
			dLR := 0;
			DIND_A		<=(others => '0');
			DINDRD_A	<= (others => '0');
		elsif LINE_VALID_IN = '1'    then
			LINE_VALID_OUT <= '1';						
			PIXEL_VALID_OUT <= '1';						
			d := 0;
			for z in 0 to dmax / 16 - 1 loop
				if(GC1(d)> GC1(z)) then
					d := z;
				end if;                         
			end loop;
			dpl := dpl1(d) + d * 16;
			
			if  i = "00" then
				if conf = "000" or conf = "001" or conf = "010" or conf = "011" then
					DATA_OUT <= conv_std_logic_vector(dpl, 6) & "00";
				end if;
			elsif  i = "01" then				
				DINDRD_A	<=	conv_std_logic_vector(dpl, 8) ;
				if conf = "101" then
					DATA_OUT <= conv_std_logic_vector(dpl, 6) & "00";
				end if;
				if first_line = '1' then
					dd <= (others => '0');
				else
					dd <= DOUTDRD_B(5 downto 0);
				end if;				
			elsif  i = "10" then
				if conf = "100" then
					DATA_OUT <= conv_std_logic_vector(dpl, 6) & "00";
				end if;
				dd <= conv_std_logic_vector(dpl, 6);
			elsif  i = "11" then								
				DIND_A <= conv_std_logic_vector(dpl, 8);
				if conf = "110" then
					DATA_OUT <= conv_std_logic_vector(dpl, 6) & "00";
				end if;
				if first_line = '1' then
					dUD := 0;
				else
					dUD := conv_integer(DOUTD_B);
				end if;
				dd <= conv_std_logic_vector(dUD, 6);								
			end if;	--i
		else
			LINE_VALID_OUT <= '0';			
			PIXEL_VALID_OUT <= '0';			
		end if;	--line valid
	end if;	--reset
end process DISP;

GCP : process(PIPELINE_CLOCK) is      
	variable GlobalCostRD: GlobalCosts_array;
	variable GlobalCostLR : GlobalCosts_array;
	variable GlobalCostUD : GlobalCosts_array;
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' then
			GLOBAL_COST_PREV	<= (others => (others => '0'));
			GLOBAL_COST_TRE		<= (others => (others => '0'));
			i 					<= "00";			
			GlobalCostRD		:= (others => (others => '0'));
			GlobalCostUD		:= (others => (others => '0'));
			GlobalCostLR		:= (others => (others => '0'));
			DINRD_A 	<= (others =>(others => '0'));
			DINUD_A		<=(others =>(others => '0'));
		elsif LINE_VALID_IN = '1' then                                  
			i<= i + 1;
			if	i = "00" then								
				GlobalCostLR := GLOBAL_COST;
				if conf /= "001" then
					for k in 0 to dmax - 1 loop
						GLOBAL_COST_TRE(k) <= GLOBAL_COST_TRE(k) + GLOBAL_COST(k)(7 downto 2);
					end loop;					
				end if;
			elsif	i = "01" then			
				DINUD_A <= GLOBAL_COST;
				if first_line = '1' then
					GlobalCostUD := (others =>(others => '0'));		
				else
					GlobalCostUD := DOUTUD_B;
				end if;
				GLOBAL_COST_PREV <= GlobalCostRD;
				
				if conf /= "011" then
					for k in 0 to dmax - 1 loop
						GLOBAL_COST_TRE(k) <= GLOBAL_COST_TRE(k) + GlobalCostUD(k)(7 downto 2);
					end loop;					
				end if;
			elsif	i = "10" then								
				GLOBAL_COST_PREV <= GlobalCostLR;
				
				
				for k in 0 to dmax - 1 loop
					GLOBAL_COST_TRE(k) <= (others => '0');
				end loop;
			elsif	i = "11" then				
				DINRD_A <= GLOBAL_COST;
				if first_line = '1' then
					GlobalCostRD := (others =>(others => '0'));	
				else
					GlobalCostRD := DOUTRD_B;
				end if;
				
				GLOBAL_COST_PREV <= GlobalCostUD;
				if conf /= "010" then
					for k in 0 to dmax - 1 loop
						GLOBAL_COST_TRE(k) <= GLOBAL_COST_TRE(k) + GlobalCostRD(k)(7 downto 2);
					end loop;
				end if;
			end if;
		end if;
	end if;         
end process GCP;

end Behavioral;