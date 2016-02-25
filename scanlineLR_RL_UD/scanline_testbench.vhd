library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.gestioneBMP.all;
use work.const.all;

entity scanline_testbench is 
end scanline_testbench;

--Tempo disimulazione di almeno 3100000 ns (640x480)
architecture testbench of scanline_testbench is 
	
	component scanline is
	port(   
		  RESET 				: in  std_logic;
		  FRAME_VALID_IN 		: in  std_logic;
		  LINE_VALID_IN 		: in  std_logic;
		  LEFT 					: in  std_logic_vector (7 downto 0);
		  RIGHT 				: in  std_logic_vector (7 downto 0);
		  PIXEL_CLOCK 			: in std_logic;
		  PIPELINE_CLOCK		: in std_logic;
		  DATA_OUT 				: out  std_logic_vector (7 downto 0);
		  FRAME_VALID_OUT 		: out  std_logic;
		  LINE_VALID_OUT 		: out  std_logic;
		  PIXEL_VALID_OUT 		: out  std_logic
		);
	end component;
	
	signal ImageWidth, ImageHeight: integer := 0;
	
	-- inputs
	signal RESET 				: std_logic;
	signal FRAME_VALID_IN 		: std_logic := '0';
	signal LINE_VALID_IN 		: std_logic := '0';
	signal LEFT 				: std_logic_vector (7 downto 0);
	signal RIGHT 				: std_logic_vector (7 downto 0);
	signal PIXEL_CLOCK 			: std_logic := '0';
	signal PIPELINE_CLOCK		: std_logic := '0';
	signal DATA_OUT 			: std_logic_vector (7 downto 0);
	signal FRAME_VALID_OUT 		: std_logic;
	signal LINE_VALID_OUT 		: std_logic;
	signal PIXEL_VALID_OUT 		: std_logic;

begin 
	
	-- instanza scanline
	uut: scanline port map(
			  RESET				=>	RESET,				
			  FRAME_VALID_IN	=>	FRAME_VALID_IN,
			  LINE_VALID_IN		=>	LINE_VALID_IN,
			  LEFT				=>	LEFT, 	
			  RIGHT				=>	RIGHT,
			  PIXEL_CLOCK		=>	PIXEL_CLOCK,
			  PIPELINE_CLOCK	=>	PIPELINE_CLOCK,
			  DATA_OUT			=>	DATA_OUT,
			  FRAME_VALID_OUT	=>	FRAME_VALID_OUT,
			  LINE_VALID_OUT	=>	LINE_VALID_OUT,
			  PIXEL_VALID_OUT	=>	PIXEL_VALID_OUT
			); 
	
--	process(PIXEL_CLOCK) is 
--	begin
--			PIXEL_CLOCK <= not PIXEL_CLOCK after 5 ns;
--	end process;

	pixel_clock_process :process(PIPELINE_CLOCK) 
	variable i : integer := 0;
	begin
	if(PIPELINE_CLOCK'EVENT and PIPELINE_CLOCK = '1') then
		if(i mod 2 = 0) then
			pixel_clock <= not pixel_clock after 19ns;
		end if;
		i := i + 1;
	end if;
	end process;

	pipeline_clock_process :process
	begin
		PIPELINE_CLOCK <= '1';
		wait for 10ns;
		PIPELINE_CLOCK <= '0';
		wait for 10ns;
	end process;
	
	process is 
	begin
		--Lettura del file bmp (immagine RGB (24 bit) anche per greyscale)
		ReadFile_L("imageL.bmp");
		ReadFile_R("imageR.bmp");

		--Queste due chiamate restituiscono Width e Height del bmp appena aperto
		GetWidth_L(ImageWidth);
		GetHeigth_L(ImageHeight);
		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
		RESET <= '1';
		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
		RESET <= '0';
		FRAME_VALID_IN <= '1';
		
		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
		for y in 0 to ImageHeight-1 loop 
			LINE_VALID_IN <= '1';
			for x in 0 to ImageWidth-1 loop
				--questa chiamata inserisce in data il valore del pixel in bianco e nero
				GetGrayPixel_L(x, y, LEFT);
				GetGrayPixel_R(x, y, RIGHT);
				--questa chiamata inserisce nell'immagine in uscita il valore del pixel 
				--passato con data
				SetGrayPixel_L(x, y, DATA_OUT);
				wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
			end loop;
			LINE_VALID_IN <= '0';
			wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
		end loop;
		
		FRAME_VALID_IN <= '0';
		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
		report "Scrittura completata";
		--scrivo il file in uscita
		WriteFile_L("disparityMap.bmp");
		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
-----------------------------------------------------------------------------------
		--Lettura del file bmp (immagine RGB (24 bit) anche per greyscale)
		ReadFile_L("imageL1.bmp");
		ReadFile_R("imageR1.bmp");

		--Queste due chiamate restituiscono Width e Height del bmp appena aperto
		GetWidth_L(ImageWidth);
		GetHeigth_L(ImageHeight);
		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';

		FRAME_VALID_IN <= '1';		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
		for y in 0 to ImageHeight-1 loop 
			LINE_VALID_IN <= '1';
			for x in 0 to ImageWidth-1 loop
				--questa chiamata inserisce in data il valore del pixel in bianco e nero
				GetGrayPixel_L(x, y, LEFT);
				GetGrayPixel_R(x, y, RIGHT);
				--questa chiamata inserisce nell'immagine in uscita il valore del pixel 
				--passato con data
				SetGrayPixel_L(x, y, DATA_OUT);
				wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
			end loop;
			LINE_VALID_IN <= '0';
			wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
		end loop;
		
		FRAME_VALID_IN <= '0';
		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';
		report "Scrittura completata";
		--scrivo il file in uscita
		WriteFile_L("disparityMap1.bmp");
		
		wait until PIXEL_CLOCK'event and PIXEL_CLOCK = '1';

		
		wait;
	end process;
end;