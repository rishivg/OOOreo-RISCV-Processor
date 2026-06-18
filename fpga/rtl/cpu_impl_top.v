module cpu_impl_top (
  input  wire          clk,
  input  wire          rst,
  output wire [31:0]   bmem_addr,
  output wire          bmem_read,
  output wire          bmem_write,
  output wire [63:0]   bmem_wdata,
  input  wire          bmem_ready,
  input  wire [31:0]   bmem_raddr,
  input  wire [63:0]   bmem_rdata,
  input  wire          bmem_rvalid
);

  wire [825:0] unused_rvfi_flat;

  cpu core (
    .clk         (clk),
    .rst         (rst),
    .bmem_addr   (bmem_addr),
    .bmem_read   (bmem_read),
    .bmem_write  (bmem_write),
    .bmem_wdata  (bmem_wdata),
    .bmem_ready  (bmem_ready),
    .bmem_raddr  (bmem_raddr),
    .bmem_rdata  (bmem_rdata),
    .bmem_rvalid (bmem_rvalid),
    .rvfi_flat   (unused_rvfi_flat)
  );

endmodule
