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

localparam R = 3'b001;
localparam Y = 3'b010;
localparam G = 3'b100;

logic [2:0] lamp_a;  // svetofor A
logic [2:0] lamp_b;  // svetofor B

// FSM svetofora
typedef enum logic [2:0] {
  S0, S1, S2, S3, S4, S5
} tlc_state_t;

tlc_state_t state;

//APB FSM
enum logic [1:0] {
  APB_SETUP,  
  APB_W_ENABLE,  
  APB_R_ENABLE  
} apb_st;

wire hit_ctrl = (paddr[7:0] == 8'h04);
wire next_cmd = (apb_st==APB_W_ENABLE) && psel && penable && pwrite && hit_ctrl && pwdata[0];

function automatic logic [31:0] pack_state32(input logic [2:0] a, input logic [2:0] b);
  logic [31:0] s;
  s = 32'h0;
  s[2:0]=a;
  s[18:16]=b;
  return s;
endfunction

always @(posedge pclk)    
  if (!presetn)      
  begin
    prdata <= '0;      
    pslverr <= 1'b0;    
    pready <= 1'b0;      
    state <= S0;
    lamp_a <= G;
    lamp_b <= R;
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
       if (psel && !penable) begin
         if (pwrite == 1'b1) begin
           apb_st <= APB_W_ENABLE; 
         end
         else begin
           apb_st <= APB_R_ENABLE;   
         end
      end
    end: apb_setup_st

    APB_W_ENABLE:
    begin: apb_w_en_stsim:/TB/paddr
      if (psel && penable && pwrite) begin
        pready <= 1'b1;
        unique case (paddr[7:0])
          8'h04: begin
            $display("[%0t] APB WRITE CTRL <= %h", $time, pwdata);
	    if (pwdata[0]) begin
              unique case (state)
                S0: state <= S1;
                S1: state <= S2;
                S2: state <= S3;
                S3: state <= S4;
                S4: state <= S5;
                S5: state <= S0;
                default: state <= S0;
              endcase
            end
          end
          default: begin
            pslverr <= 1'b1;
            $display("[%0t] APB WRITE ERROR addr=%h", $time, paddr);
          end
        endcase
        apb_st <= APB_SETUP; 
      end
      else begin
        pready <= 1'b0;
        apb_st <= APB_SETUP;
      end
    end: apb_w_en_st
  
    APB_R_ENABLE:
    begin: apb_r_en_st
      if (psel && penable && !pwrite) begin
        pready <= 1'b1; 
        unique case (paddr[7:0])
          8'h00: prdata <= pack_state32(lamp_a, lamp_b); 
          8'h04: prdata <= 32'h0; // CTRL read = 0
          default: begin
            pslverr <= 1'b1;
            prdata  <= 32'hFFFF_FFFF;
          end
        endcase
      apb_st <= APB_SETUP;
    end
    else begin
      pready <= 1'b0;
      apb_st <= APB_SETUP;
    end
    end: apb_r_en_st

    default:
    begin
      pslverr <= 1'b1; 
    end
  endcase

  unique case (state)
    S0: begin lamp_a <= G; lamp_b <= R; end // A=G, B=R  -> 0x0001_0004
    S1: begin lamp_a <= Y; lamp_b <= R; end // A=Y, B=R  -> 0x0001_0002
    S2: begin lamp_a <= R; lamp_b <= R; end // A=R, B=R  -> 0x0001_0001
    S3: begin lamp_a <= R; lamp_b <= G; end // A=R, B=G  -> 0x0004_0001
    S4: begin lamp_a <= R; lamp_b <= Y; end // A=R, B=Y  -> 0x0002_0001
    S5: begin lamp_a <= R; lamp_b <= R; end // A=R, B=R  -> 0x0001_0001
    default: begin lamp_a <= R; lamp_b <= R; end
  endcase
end
endmodule
