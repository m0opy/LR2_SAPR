module apb_slave

(
  input pclk, 			
  input presetn, 		
  input [31:0] paddr, 		
  input [31:0] pwdata, 		
  input psel, 			
  input penable, 		
  input pwrite, 		
  output logic pready, 		
  output logic pslverr, 	
  output logic [31:0] prdata 	
);

logic [31:0] reg_state;   	// 0x00 -- ??????? ?????????
logic [31:0] reg_ctrl;          // 0x04 -- ???????????

// FSM ?????????
typedef enum logic [2:0] {
  S0, S1, S2, S3, S4, S5
} tlc_state_t;

tlc_state_t state;

localparam R = 3'b001;
localparam Y = 3'b010;
localparam G = 3'b100;

//APB FSM
enum logic [1:0] {
  APB_SETUP,	
  APB_W_ENABLE,	
  APB_R_ENABLE	
} apb_st;

// ??????????? ??????? ??????? NEXT: ???? ?????? CTRL(0)=1 ? ???? ENABLE
wire next_cmd = (apb_st==APB_W_ENABLE) && psel && penable && pwrite && (paddr[7:0]==8'h04) && pwdata[0];

always @(posedge pclk)		
  if (!presetn)			
  begin
    prdata <= '0;			
    pslverr <= 1'b0;		
    pready <= 1'b0;			
    reg_ctrl <= 32'h0;
    state <= S0;
    reg_state <= {16'(R), 16'(G)};  // {B, A}
    apb_st <= APB_SETUP;	
  end
  else				
  begin
    case(apb_st)
      APB_SETUP:		
      begin: apb_setup_st
	prdata <= '0;		
	pslverr <= 1'b0;	
	pready <= 1'b0;		
	// ENABLE => PSEL = 1 && PENABLE = 0
	if (psel && !penable)
	begin
	  if (pwrite == 1'b1)	
	  begin
	    apb_st <= APB_W_ENABLE; 
	  end
	else			  
	begin
	  apb_st <= APB_R_ENABLE;   
	end
      end
    end: apb_setup_st

  APB_W_ENABLE:
  begin: apb_w_en_st
    if (psel && penable && pwrite)
    begin
      pready <= 1'b1;
	unique case (paddr[7:0])
            8'h04: begin
              reg_ctrl <= pwdata;
              $display("[%0t] APB WRITE CTRL <= %h", $time, pwdata);
            end
            default: begin
              pslverr <= 1'b1;
              $display("[%0t] APB WRITE ERROR addr=%h", $time, paddr);
            end
          endcase
      apb_st <= APB_SETUP; 
    end
  end: apb_w_en_st
  
  APB_R_ENABLE:
  begin: apb_r_en_st
    if (psel && penable && !pwrite)
    begin
      pready <= 1'b1; 
      unique case (paddr[7:0])
	8'h00: prdata <= reg_state; // STATE
        8'h04: prdata <= 32'h0; // CTRL read = 0
        default: begin
          pslverr <= 1'b1;
          prdata  <= 32'hDEAD_BEEF;
        end
      endcase
      apb_st <= APB_SETUP;
    end
  end: apb_r_en_st

  default:
  begin
    pslverr <= 1'b1; 
  end
endcase

case(state)
  S0: if (next_cmd) state <= S1; // A=G, B=R
  S1: if (next_cmd) state <= S2; // A=Y, B=R
  S2: if (next_cmd) state <= S3; // A=R, B=R
  S3: if (next_cmd) state <= S4; // A=R, B=G
  S4: if (next_cmd) state <= S5; // A=R, B=Y
  S5: if (next_cmd) state <= S0; // A=R, B=R
endcase

case (state)
  S0: reg_state <= {16'(R), 16'(G)}; // A=G, B=R
  S1: reg_state <= {16'(R), 16'(Y)}; // A=Y, B=R
  S2: reg_state <= {16'(R), 16'(R)}; // A=R, B=R
  S3: reg_state <= {16'(G), 16'(R)}; // A=R, B=G
  S4: reg_state <= {16'(Y), 16'(R)}; // A=R, B=Y
  S5: reg_state <= {16'(R), 16'(R)}; // A=R, B=R
  default: reg_state <= 32'h0;
endcase

end
endmodule



