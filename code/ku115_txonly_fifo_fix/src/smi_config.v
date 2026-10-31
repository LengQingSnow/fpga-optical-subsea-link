`timescale 1 ns/1 ns
module smi_config
      #(
        parameter REF_CLK = 50,         //reference clock frequency(MHz)
        parameter MDC_CLK = 500         //mdc clock(KHz)
       )
       (
        input                 clk,
        input                 rst_n  ,
        
        output                mdc,      //mdc interface
        inout                 mdio,     //mdio interface
        output reg  [1:0]     speed,    //ethernet speed 00:10M 01:100M 10:1000M
        output reg            link,     //ethernet link signal
        output reg  [3:0]     led       //led 1110: 10M  1100: 100M 1000:1000M  1111: not link
		 
       );

reg  [4:0]         phy_addr      ;   //phy address 5'b0001
reg  [4:0]         reg_addr      ;   //phy register address
reg                write_req     ;   //write smi request
reg  [15:0]        write_data    ;   //write smi data
reg                read_req      ;   //read smi request
(* MARK_DEBUG="true" *)wire [15:0]        read_data     ;   //read smi data
wire               data_valid    ;   //read smi data valid
(* MARK_DEBUG="true" *)wire               done          ;	 //write or read finished
(* MARK_DEBUG="true" *)reg  [15:0]        read_data_buf ;   //read register data latch
(* MARK_DEBUG="true" *)reg  [31:0]        timer         ;	 //wait counter 
 
localparam IDLE            = 5'd0 ;
localparam R_GEN_REQ       = 5'd1 ;
localparam R_REG           = 5'd2 ;
localparam R_CHECK         = 5'd3 ;
localparam ETH_UNLINK      = 5'd4 ;
localparam ETH_1000M       = 5'd5 ;
localparam ETH_100M        = 5'd6 ;
localparam ETH_10M         = 5'd7 ;
localparam R_WAIT          = 5'd8 ;
localparam R_GEN_REQ1       = 5'd9 ;
localparam R_REG1           = 5'd10 ;
localparam R_CHECK1         = 5'd11 ;
localparam W_REG         = 5'd12 ;
localparam W_REG1         = 5'd13 ;
localparam W_REQ         = 5'd14 ;
localparam W_WAIT         = 5'd15 ;
localparam R_GEN_REQ2       = 5'd16 ;
localparam R_REG3           = 5'd17 ;
localparam R_CHECK2           = 5'd18 ;


(* MARK_DEBUG="true" *)reg [3:0] req_cnt;
(* MARK_DEBUG="true" *)reg [4:0]    state  ;
reg [4:0]    next_state ;

always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
      state  <=  IDLE  ;
    else
      state  <= next_state ;  
  end

reg phy_init_end;
reg[25:0] tm_cnt;
always @(posedge clk or negedge rst_n)
begin
if (~rst_n)
begin
  tm_cnt  <=  26'd0 ;
  end
else
begin
if(!phy_init_end)
  tm_cnt<=tm_cnt+1'b1;
  else  tm_cnt<=tm_cnt;    
  end
end

always @(posedge clk or negedge rst_n)
begin
  if (~rst_n)
  begin
    phy_init_end<=1'b0;
    end
  else
  begin
  if(tm_cnt>=26'd3000000)
  phy_init_end<=1'b1;  
    end
end  
  
always @(*)
  begin
   if(phy_init_end)
   begin
    case(state)
      IDLE        :
        begin          
          next_state <= W_REQ ;
        end
        
        W_REQ :
         begin
         if(req_cnt==4'd1)
                    next_state <= W_REG ;
         else if(req_cnt==4'd3)
                    next_state <= W_REG1 ;
          else if(req_cnt==4'd5)
                    next_state <= W_REG ;
                
           else
                 next_state<=W_REQ;
          
          end
          
        W_REG:
         begin
            
            if (done == 1'd1 &&req_cnt==4'd2)
               next_state <= W_REQ ;
            else if(done == 1'd1 &&req_cnt==4'd6)
               next_state <= R_GEN_REQ2 ;
            else
           next_state <= W_REG ;
         end   
        W_WAIT:
       begin
          if (timer == 32'd50_000_000)      //check every 1s
            next_state <= W_REQ ;
          else
            next_state <= W_WAIT ;
        end 
        W_REG1 :
        begin
         if (done)
                   next_state <= W_REQ ;
                    else
                   next_state <= W_REG1 ;
         end 
        R_GEN_REQ2:
                      next_state <= R_REG3 ;
        R_REG3  :
                begin
                    if (done)
                  next_state <= R_WAIT ;
                    else
                  next_state <= R_REG3 ;
                 end        
//        R_CHECK2:
//              begin
//                     if(data_valid)
//                         next_state <= R_WAIT ;
//                     else
//                        next_state<=R_CHECK2;
//              end
        R_GEN_REQ1        :                  //generate read request
                 next_state <= R_REG1 ;
        R_REG1        :                      //read register data
        begin
         if (done)
           next_state <= R_CHECK1 ;
         else
           next_state <= R_REG1 ;
        end   
        R_CHECK1          :
         begin
           if (~read_data[2])             //read register data  to check if ethernet link  0: unlink  1: link 
             next_state <= ETH_UNLINK ;             
           else
             next_state <= R_GEN_REQ ;
         end           
               
      R_GEN_REQ        :                  //generate read request
          next_state <= R_REG ;
      R_REG        :                      //read register data
        begin
          if (done)
            next_state <= R_CHECK ;
          else
            next_state <= R_REG ;
        end
      R_CHECK          :
        begin
        //  if (read_data[0])             //read register data bit 0 to check if ethernet link  1: unlink  0: link 
          //  next_state <= ETH_UNLINK ;
           if (read_data[6:4] == 3'b100)    //register data bit[6:4] check ethernet speed 001: 10M ; 010: 100M ; 100 : 1000M
            next_state <= ETH_1000M ;
          else if (read_data[6:4] == 3'b010)
            next_state <= ETH_100M ;
          else if (read_data[6:4] == 3'b001)
            next_state <= ETH_10M ;
          else
            next_state <= R_CHECK ;
        end
      ETH_UNLINK, ETH_1000M, ETH_100M, ETH_10M  :
    	  next_state <= R_WAIT ;
      R_WAIT   :
        begin
          if (timer == 32'd50_000_000)      //check every 1s
            next_state <= R_GEN_REQ1 ;
          else
            next_state <= R_WAIT ;
        end 
      default     :
        next_state <= IDLE ;
    endcase
    end
    else next_state<=state;
  end


//ethernet speed  
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  speed <= 2'b11 ;
	else if (state == ETH_10M)
	  speed <= 2'b00 ;
	else if (state == ETH_100M)
	  speed <= 2'b01 ;
	else if (state == ETH_1000M)
	  speed <= 2'b10 ;
  end

//ethernet link signal
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  link <= 1'b0 ;
	else if (state == ETH_UNLINK)
	  link <= 1'b0 ;
	else if (state == ETH_10M || state == ETH_100M || state == ETH_1000M)
	  link <= 1'b1 ;
  end

//led signal
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  led <= 4'd0 ;
	else if (link)
	begin
	  if (speed == 2'b00)
	    led <= 4'b1110 ;
	  else if (speed == 2'b01)
	    led <= 4'b1100 ;
	  else if (speed == 2'b10)
	    led <= 4'b1000 ;
	  else 
	    led <= 4'b1111 ;
	end
	else 
	  led <= 4'b1111 ;
  end  

//wait counter  
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  timer <= 32'd0 ;
	else if (state == R_WAIT||state == W_WAIT)
	  timer <= timer + 1'b1 ;
	else
	  timer <= 32'd0 ;
  end
  
  
  // req counter  
  always @(posedge clk or negedge rst_n)
    begin
      if (~rst_n)
        req_cnt <=4'd0 ;
      else if (state == W_REQ)
        req_cnt <= req_cnt + 4'd1 ;
      else
        req_cnt <= req_cnt ;
    end

//read smi request  
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  read_req <= 1'b0 ;
	else if (state == R_GEN_REQ||state == R_GEN_REQ1||state == R_GEN_REQ2)
	  read_req <= 1'b1 ;
	else
	  read_req <= 1'b0 ;
  end



//write smi request  
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  write_req <= 1'b0 ;
	else if (state == W_REQ)
	  write_req <= 1'b1 ;
	else
	  write_req <= 1'b0 ;
  end
  
//read data latch
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  read_data_buf <= 16'd0 ;
	else if (done&&state ==R_REG3)
	  read_data_buf <= read_data ;
	else
	  read_data_buf <=read_data_buf;
  end

//phy address
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  phy_addr <= 5'd0 ;
	else 
	  phy_addr <= 5'b00001 ;
  end

//phy register address
always @(posedge clk or negedge rst_n)
  begin
    if (~rst_n)
	  reg_addr <= 5'd0 ;
	 else if (state == R_REG1)
      reg_addr <= 5'b00001 ;
	else if (state == R_REG)
	  reg_addr <= 5'b11111 ;
	else if (state == W_REG)
        reg_addr <= 5'b01101 ;
 	else if (state == W_REG1||state == R_REG3 )
        reg_addr <= 5'b01110 ;
    else
       reg_addr<=5'd0;
  end
  
  
  //phy register address
  always @(posedge clk or negedge rst_n)
    begin
      if (~rst_n)
        write_data <= 16'd0 ;
      else //if(W_REQ)
        begin
            case(req_cnt)
              4'd2 :write_data<=16'h2;
              4'd4 :write_data<=16'h8;
              4'd6 :write_data<=16'h4002;
              default : write_data <= 16'd0 ;
              endcase
              
        end
  
    end
    
  
  


smi_read_write 
      #(
        .REF_CLK(REF_CLK),
        .MDC_CLK(MDC_CLK)
	   )
	   smi_inst
       (
        .clk              (clk         ),
        .rst_n            (phy_init_end),
        .mdc              (mdc         ),
        .mdio             (mdio        ),         
        .phy_addr         (phy_addr    ),
        .reg_addr         (reg_addr    ),		 
        .write_req        (write_req   ),
        .write_data       (write_data  ),
        .read_req         (read_req    ),
        .read_data        (read_data   ),
        .data_valid       (data_valid  ),
        .done             (done        )
       );

 
endmodule
