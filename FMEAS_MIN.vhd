library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
---------------------------------------------------------------------------
entity FMEAS_MIN is
	generic (time_window: unsigned (19 downto 0) := X"1D4C5");	--- time_window set for 1ms
	port (clk:				in	std_logic;		-- global clock
		 	reset:				in	std_logic;	-- global reset
			freq_in:			in	std_logic;		-- unknown frequency
			edge_count_out:		out	std_logic_vector (15 downto 0);	-- output port for transfering data 
																							-- to DECISION_UNIT
			data_in: out std_logic;													-- output port for informing DECISION_UNIT
																							-- that data is ready
			enable_timer: in std_logic);											-- input signal coming from DECISION_UNIT for 
																							-- enabling this submodule
end FMEAS_MIN;
---------------------------------------------------------------------------
architecture behavior of FMEAS_MIN is
	
	-- creating internal signals
	signal ack_counter, ack_received, ack_timer_flop: std_logic;	-- signals related to acknowledgement controlled by
																						-- counter unit
	signal edge_counter, save_counter: unsigned (15 downto 0) := (others => '0');	-- for handeling cross clock domain
	-- creating state machines for counter unit
	type counter_state is (counter_standby, counter_increment);
	-- creating state machines for timer unit
	type timer_state is (timer_standby, timer_enable_counter, timer_increment, timer_stop_counter);
	-- creating required signals for handeling the state machines
	signal nx_timer, pr_timer: timer_state := timer_standby;
	signal nx_counter, pr_counter: counter_state := counter_standby;
	signal timer:				unsigned (19 downto 0);		-- the signal responsible for creating the time window
	-- signals related to activating and deactivating the counter unit controlled by timer unit
	signal activate_counter, activate_counter_flop, activate_counter_double_flop: std_logic;
	-- required signals for creating the "data_in" output port
	signal activate_counter_0, activate_counter_1: std_logic := '1';
begin

	-------------------------------------------------------
	---------- Activate_counter_double_flopping -----------
	-------------------------------------------------------
	Activate_counter_double_flopping: process(freq_in, reset)
	begin
		if (reset = '1') then
			activate_counter_flop <= 'U';
		elsif(rising_edge(freq_in)) then
			activate_counter_flop <= activate_counter;
			activate_counter_double_flop <= activate_counter_flop;
		end if;
	end process;
	-------------------------------------------------------
	---------- Activate_counter_double_flopping -----------
	----------------------- End ---------------------------
	
	-------------------------------------------------------
	------------------ data_in_edge -----------------------
	-------------------------------------------------------
	data_in_edge: process(clk, reset)
	begin
		if (reset = '1') then
			activate_counter_1 <= 'U';
		elsif(rising_edge(clk)) then
			activate_counter_0 <= activate_counter_double_flop;
			activate_counter_1 <= activate_counter_0;
		end if;
	end process;
	
	data_in <= not activate_counter_0 and activate_counter_1;	-- creating "data_in" output port
	-------------------------------------------------------
	------------------ data_in_edge -----------------------
	----------------------- End ---------------------------
	
	-------------------------------------------------------
	----------------- Counter_register --------------------
	-------------------------------------------------------
	Counter_register: process(freq_in, reset)
	begin
		if (reset = '1') then 
			pr_counter <= counter_standby;
		elsif (rising_edge(freq_in)) then
			pr_counter <= nx_counter;
		end if;
	end process;
	-------------------------------------------------------
	----------------- Counter_register --------------------
	----------------------- End ---------------------------
	
	
	-------------------------------------------------------
	-------------- Counter_combinational ------------------
	-------------------------------------------------------
	
	Counter_combinational: process(pr_counter, activate_counter_double_flop)
	begin
		case pr_counter is
		when counter_standby =>
			if (activate_counter_double_flop /= '1') then
				nx_counter <= counter_standby;
			else
				nx_counter <= counter_increment;
			end if;
		when counter_increment =>
			if (activate_counter_double_flop /= '1') then
				nx_counter <= counter_standby;
			else
				nx_counter <= counter_increment;
			end if;
		end case;
	end process;
	
	-------------------------------------------------------
	-------------- Counter_combinational ------------------
	----------------------- End ---------------------------
	
	
	----------------------------------------------------------
	-- a process counting the edges of the measurable input
	-- occuring during the measure time window
	----------------------------------------------------------
	Edge_counter_process:process(freq_in, reset)
	begin
		if (reset = '1') then
			edge_counter <= (others => '0');
		elsif (rising_edge(freq_in)) then
			if (pr_counter = counter_standby) then
				ack_counter <= '0';	-- acknowledging the timer unit that counter unit has stopped incrementing
				edge_counter <= (others => '0');
			elsif (pr_counter = counter_increment) then
				ack_counter <= '1';	-- acknowledging the timer unit that counter unit has started incrementing
				edge_counter <= edge_counter + 1;
			end if;
		end if;
	end process;
	-------------------------------------------------------
	---------------- Edge_counter_process -----------------
	----------------------- End ---------------------------

	
	-------------------------------------------------------
	---------------- ack_first_start_flop -----------------
	-------------------------------------------------------
	ack_first_start_flop: process(clk, reset)
	begin
		if (reset = '1') then
			ack_received <= 'U';
		elsif(rising_edge(clk)) then
			ack_received <= ack_counter;
			ack_timer_flop <= ack_received;
		end if;
	end process;
	-------------------------------------------------------
	--------------- ack_first_start_flop ------------------
	----------------------- End ---------------------------
	
	
	-------------------------------------------------------
	------------------ timer_register ---------------------
	-------------------------------------------------------
	timer_register: process(clk, reset)
	begin
		if (reset = '1') then
			pr_timer <= timer_standby;
		elsif (rising_edge(clk)) then
			pr_timer <= nx_timer;
		end if;
	end process;
	-------------------------------------------------------
	------------------ timer_register ---------------------
	----------------------- End ---------------------------
	
	-------------------------------------------------------
	---------------- timer_combinational ------------------
	-------------------------------------------------------
	timer_combinational: process (pr_timer, enable_timer, ack_timer_flop, timer)
	begin
		case pr_timer is
		
			when timer_standby =>
				-- wait till enable_timer becomes 1
				if (enable_timer /= '1') then
					nx_timer <= timer_standby;
				else
					nx_timer <= timer_enable_counter;
				end if;
				
			when timer_enable_counter =>
				-- wait till receive ack from counter
				if (ack_timer_flop = '1') then
					nx_timer <= timer_increment;
				elsif (enable_timer /= '1') then
					nx_timer <= timer_standby;
				end if;
					
			when timer_increment =>
			
				if (timer = time_window) then
					nx_timer <= timer_stop_counter;
				elsif (enable_timer /= '1') then
					nx_timer <= timer_standby;
				end if;
				
			when timer_stop_counter =>
				if (ack_timer_flop = '0') then
					nx_timer <= timer_enable_counter;
				elsif (enable_timer /= '1') then
					nx_timer <= timer_standby;	
				end if;
				
		end case;
	end process;
	-------------------------------------------------------
	--------------- timer_combinational -------------------
	----------------------- End ---------------------------
	
	----------------------------------------------------------
	-- a process for defining a measure time window
	----------------------------------------------------------
	Edge_timer_process:process(clk, reset)
	begin
		if (reset = '1') then
			timer <= (others => '0');
		elsif (rising_edge(clk)) then
			if (pr_timer = timer_Standby) then
				activate_counter <= '0';
			elsif (pr_timer = timer_enable_counter) then
				activate_counter <= '1';	-- restarting the counter unit
				timer <= (others => '0');
			elsif (pr_timer = timer_increment) then
				if(timer < time_window) then
					timer <= timer + 1;	-- incrementing the timer value to the max of "time_window"
				end if;
			elsif (pr_timer = timer_stop_counter) then
				-- double flopping technique --
				save_counter <= edge_counter;	
				edge_count_out <= std_logic_vector(save_counter);	-- converting the data to std_logic_vector
				-- end of double flopping technique --
				activate_counter <= '0';	-- stopping the counter unit
			end if;
		end if;
	end process;
	-------------------------------------------------------
	---------------- Edge_timer_process -------------------
	----------------------- End ---------------------------
	
	
	
	
	
end behavior;
---------------------------------------------------------------------------

