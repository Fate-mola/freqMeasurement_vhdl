library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
----------------------------------------------------------------------------------------------------
entity testbenchFMES is
end testbenchFMES;
----------------------------------------------------------------------------------------------------
architecture behavior of testbenchFMES is

	constant 	clock_cycle: 	time := 8.333 ns;						-- 120 MHz system clock
	signal 		freq_in_cycle:	time := 235 ns;							-- cycle time of the measurable frequency	#4255
	
	signal clk:					std_logic := '0';						-- system clock
	signal reset:				std_logic := '1';						-- system reset
	signal freq_in:				std_logic := '0';						-- signal, whose frequency has to be measured
	signal edge_count_out:		std_logic_vector (15 downto 0);			-- number of the measurable signal's edges occured during the measure time window (output of the frequency measurement circuit)
	signal frequency_MHz:		real;																-- a value computed by the test environment based on the output of the frequency measurement circuit
	signal enable_timer:	std_logic;
	signal data_in: std_logic;

begin
	
	-- instantiation of the frequency measurement circuit --
	L_DUT:	entity work.FMEAS_MIN(behavior)
						port map (clk,reset,freq_in,edge_count_out,data_in,enable_timer);
	
	-- the measured frequency [MHz]
	frequency_MHz <= real(to_integer(unsigned(edge_count_out))) / 8738.1333;




	-- TEST SEQUENCES --
	L_FREQ_IN_CYCLE: process
	begin
		wait for 500 ns;
		reset <= '0';
		wait for 400 ns;
		enable_timer <= '1';
				wait for 2 ms;
				-- the measurable frequency can be modified here:
				freq_in_cycle <= 456 ns;	-- #2192
		
				wait for 2 ms;
				-- the measurable frequency can be modified here:
				freq_in_cycle <= 370 ns;	-- #2702
		
				wait for 2 ms;
				-- the measurable frequency can be modified here:
				freq_in_cycle <= 143 ns;	-- #6993
				
				wait for 2 ms;
				-- the measurable frequency can be modified here:
				freq_in_cycle <= 1100 ns;	-- #909
		
		wait;
	end process;
	
	
	
	-- generating the clock and the measurable frequency --
	L_CLOCK: process
	begin
		wait for clock_cycle/2;
		clk <= not clk;
	end process;
	
	L_FREQ_IN: process
	begin
		wait for freq_in_cycle/2;
		freq_in <= not freq_in;
	end process;

end behavior;
----------------------------------------------------------------------------------------------------
