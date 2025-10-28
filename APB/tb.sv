module TB;

logic pclk;		
logic presetn;		
logic psel;		
logic penable;		
logic pwrite;		
logic [31:0] paddr;	
logic [31:0] pwdata;	
wire [31:0] prdata;	
wire pready;		
wire pslverr;		

parameter p_device_offset = 32'h7000_0000; 

logic [31:0] data_from_device; 

apb_slave DUT
(
  .pclk(pclk), 		
  .presetn, 			
  .paddr(paddr), 		
  .pwdata(pwdata), 		
  .psel(psel), 			
  .penable(penable), 	 	
  .pwrite(pwrite), 	
  .pready(pready), 	
  .pslverr(pslverr), 		
  .prdata(prdata) 	
);

localparam [31:0] A_STATE = p_device_offset + 32'h00; // ??????? ?????????
localparam [31:0] A_CTRL  = p_device_offset + 32'h04; // ??????? NEXT

task apb_write(input [31:0] addr, input [31:0] data); 
  wait ((penable==0) && (pready == 0)); 
  @(posedge pclk); 		
  psel <= 1'b1; 		
  paddr[31:0] <= addr[31:0]; 	
  pwdata[31:0] <= data[31:0]; 	
  pwrite <= 1'b1; 		
 
  @(posedge pclk);		
  penable <= 1'b1;		

  @(posedge pclk);		
  wait (pready == 1'b1);	

  @(posedge pclk);		
  psel <= 1'b0;			
  penable <= 1'b0;		
  pwrite <= 1'b0;		

  @(posedge pclk);		
endtask


task apb_read(input [31:0] addr, output logic [31:0] data); 
  wait ((penable==0) && (pready == 0)); 
  @(posedge pclk); 		
  psel <= 1'b1; 		
  pwrite <= 1'b0; 		
  paddr[31:0] <= addr[31:0]; 	

  @(posedge pclk);		
  penable <= 1'b1;		

  @(posedge pclk);		
  wait (pready == 1'b1);	
  data[31:0] = prdata[31:0];	

  @(posedge pclk);		
  psel <= 1'b0;			
  penable <= 1'b0;		

  @(posedge pclk);		
endtask

always
#10ns pclk=~pclk;  		

initial
begin
  pclk=0;
  presetn=1'b1; 
  psel='0; 
  penable='0;
  pwrite='0;
  paddr='0;
  pwdata='0;

  repeat (5) @(posedge pclk); 	
  presetn=1'b0; 		
  repeat (5) @(posedge pclk); 	
  presetn=1'b1; 		
  repeat (5) @(posedge pclk); 	

  // ????? ????? ?????? ?????? STATE (?????? ???? A=G, B=R)
  apb_read(A_STATE, data_from_device);
  $display("STATE after reset = 0x%08h", data_from_device);

  // ?????? 6 ????? NEXT ? ????? ??????? ?????? STATE
  repeat (6) begin
    apb_write(A_CTRL, 32'h1);    // NEXT
    apb_read (A_STATE, data_from_device);
    $display("STATE = 0x%08h", data_from_device);
  end

  // (???????????) ???????? ???????? ?????
  apb_read(p_device_offset + 32'h08, data_from_device); // ?????? ??????????? pslverr

  repeat (10) @(posedge pclk);
  $stop();
end

initial
begin 
  $monitor("APB IF state: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h", penable, pready, paddr, pwdata, prdata);
end

endmodule
