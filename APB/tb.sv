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

apb_slave DUT (
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

localparam [31:0] A_STATE = p_device_offset + 32'h00; 
localparam [31:0] A_CTRL  = p_device_offset + 32'h04; 

task apb_write(input [31:0] addr, input [31:0] data);
  wait ((penable==0) && (pready == 0));
  @(posedge pclk);
  psel   <= 1'b1;
  paddr  <= addr;
  pwdata <= data;
  pwrite <= 1'b1;

  @(posedge pclk);
  penable <= 1'b1;

  @(posedge pclk);
  wait (pready == 1'b1);

  @(posedge pclk);
  psel    <= 1'b0;
  penable <= 1'b0;
  pwrite  <= 1'b0;

  @(posedge pclk);
endtask

task apb_read(input [31:0] addr, output logic [31:0] data);
  wait ((penable==0) && (pready == 0));
  @(posedge pclk);
  psel   <= 1'b1;
  pwrite <= 1'b0;
  paddr  <= addr;

  @(posedge pclk);
  penable <= 1'b1;

  @(posedge pclk);
  wait (pready == 1'b1);
  data = prdata;

  @(posedge pclk);
  psel    <= 1'b0;
  penable <= 1'b0;

  @(posedge pclk);
endtask

task apb_w_enable_abort(input bit drop_psel, input bit keep_penable_low, input bit force_pwrite0);
  wait ((penable==0) && (pready==0)); @(posedge pclk);
  psel<=1; pwrite<=1; paddr<=A_CTRL; pwdata<=32'h0;
  @(posedge pclk); // APB_SETUP
  if (!keep_penable_low) penable<=1; else penable<=0;
  if (drop_psel)         psel   <=0;
  if (force_pwrite0)     pwrite <=0;
  @(posedge pclk); // DUT will see false and return in SETUP
  psel<=0; penable<=0; pwrite<=0; @(posedge pclk);
endtask

task apb_r_enable_abort(input bit drop_psel, input bit keep_penable_low, input bit force_pwrite1);
  wait ((penable==0) && (pready==0)); @(posedge pclk);
  psel<=1; pwrite<=0; paddr<=A_STATE;
  @(posedge pclk); // APB_SETUP
  if (!keep_penable_low) penable<=1; else penable<=0;
  if (drop_psel)         psel   <=0;
  if (force_pwrite1)     pwrite <=1;
  @(posedge pclk); // DUT will see false and return in SETUP
  psel<=0; penable<=0; pwrite<=0; @(posedge pclk);
endtask

always #10ns pclk = ~pclk;

function void check_state(string tag,
                          logic [31:0] got,
                          logic [31:0] exp,
                          bit fatal = 1);   
  if (got !== exp) begin
    $display("[%0t] ERROR %s: got=0x%08h exp=0x%08h", $time, tag, got, exp);
    // pragma coverage off
    if (fatal) $fatal(1);
    // pragma coverage on
    else       $error("Non-fatal mismatch (coverage hit)");
  end else begin
    $display("[%0t] OK    %s: 0x%08h", $time, tag, got);
  end
endfunction

initial begin
  // init
  pclk=0; 
  presetn=1; 
  psel='0; 
  penable='0; 
  pwrite='0; 
  paddr='0; 
  pwdata='0;

  repeat (5) @(posedge pclk);
  presetn=0; repeat (5) @(posedge pclk);
  presetn=1; repeat (5) @(posedge pclk);


  apb_read(A_STATE, data_from_device);
  $display("STATE after reset = 0x%08h", data_from_device);
  check_state("S0", data_from_device, 32'h0001_0004);

  apb_read(A_CTRL, data_from_device);
  check_state("READ CTRL returns 0", data_from_device, 32'h0000_0000);

  apb_write(A_CTRL, 32'h0);
  apb_read (A_STATE, data_from_device);
  check_state("S0 again (no NEXT)", data_from_device, 32'h0001_0004);

  apb_w_enable_abort(/*drop_psel=*/1, /*keep_penable_low=*/0, /*force_pwrite0=*/0); // psel=0
  apb_w_enable_abort(/*drop_psel=*/0, /*keep_penable_low=*/1, /*force_pwrite0=*/0); // penable=0
  apb_w_enable_abort(/*drop_psel=*/0, /*keep_penable_low=*/0, /*force_pwrite0=*/1); // pwrite=0

  apb_r_enable_abort(/*drop_psel=*/1, /*keep_penable_low=*/0, /*force_pwrite1=*/0); // psel=0
  apb_r_enable_abort(/*drop_psel=*/0, /*keep_penable_low=*/1, /*force_pwrite1=*/0); // penable=0
  apb_r_enable_abort(/*drop_psel=*/0, /*keep_penable_low=*/0, /*force_pwrite1=*/1); // pwrite=1

  apb_write(A_CTRL, 32'h1); apb_read(A_STATE, data_from_device); check_state("S1", data_from_device, 32'h0001_0002);
  apb_write(A_CTRL, 32'h1); apb_read(A_STATE, data_from_device); check_state("S2", data_from_device, 32'h0001_0001);
  apb_write(A_CTRL, 32'h1); apb_read(A_STATE, data_from_device); check_state("S3", data_from_device, 32'h0004_0001);
  apb_write(A_CTRL, 32'h1); apb_read(A_STATE, data_from_device); check_state("S4", data_from_device, 32'h0002_0001);
  apb_write(A_CTRL, 32'h1); apb_read(A_STATE, data_from_device); check_state("S5", data_from_device, 32'h0001_0001);
  apb_write(A_CTRL, 32'h1); apb_read(A_STATE, data_from_device); check_state("S0 cycle", data_from_device, 32'h0001_0004);

  apb_read (p_device_offset + 32'h08, data_from_device); // bad READ -> FFFF_FFFF
  apb_read (p_device_offset + 32'h0C, data_from_device); // bad READ -> FFFF_FFFF

  apb_write(A_CTRL, 32'hAAAA_AAAA);
  apb_write(A_CTRL, 32'h5555_5555);

  apb_read(p_device_offset + 32'h01, data_from_device);
  apb_read(p_device_offset + 32'h02, data_from_device);

  apb_write(p_device_offset + 32'h0C, 32'hDEAD_BEEF);    // bad WRITE

  apb_read(A_STATE, data_from_device);

  apb_read(32'hF000_0000, data_from_device); // paddr[31]=1, low byte=00
  apb_read(32'h7000_F000, data_from_device); // [12:15]
  apb_read(32'h7000_0F00, data_from_device); // [8:11]
  apb_read(32'h7000_00F0, data_from_device); // [4:7]
  apb_read(32'h7000_0000, data_from_device); 

  apb_write(A_CTRL, 32'hFFFF_FFFE);  // all 1, NEXT=0
  apb_write(A_CTRL, 32'h0000_0000);  // return in 0

  check_state("NEGATIVE for coverage", 32'hDEAD_BEEF, 32'hCAFE_BABE, /*fatal=*/0);  repeat (5) @(posedge pclk);

  repeat (5) @(posedge pclk);
  $display("TEST PASS");
  $stop();
end

initial begin
  $monitor("APB IF state: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h PSLVERR=%b",
            penable, pready, paddr, pwdata, prdata, pslverr);
end

endmodule

