`timescale 1ns/1ps
module tb_day11;
reg clk;
reg rst_n;
reg in_valid;
reg [7:0] in_byte;
reg in_last;
wire out_valid;
wire [63:0] part1;
wire [63:0] part2;
wire overflow;
wire busy;

day11_top dut(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_byte(in_byte),.in_last(in_last),.out_valid(out_valid),.part1(part1),.part2(part2),.overflow(overflow),.busy(busy));

integer fd;
integer rfd;
integer i;
integer len;
reg [7:0] mem [0:19999];

initial begin
  clk = 0;
  forever #5 clk = ~clk;
end

initial begin
  rst_n = 0;
  in_valid = 0;
  in_byte = 0;
  in_last = 0;
  #40;
  rst_n = 1;
end

initial begin
  len = 0;
  fd = $fopen("input.txt","rb");
  if (fd == 0) begin
    $display("cannot open input.txt");
    $finish;
  end
  while (!$feof(fd) && len < 20000) begin
    mem[len] = $fgetc(fd);
    len = len + 1;
  end
  $fclose(fd);

  @(posedge rst_n);
  @(posedge clk);
  for (i=0;i<len;i=i+1) begin
    @(posedge clk);
    in_valid <= 1;
    in_byte <= mem[i];
    in_last <= (i==len-1);
  end
  @(posedge clk);
  in_valid <= 0;
  in_last <= 0;
end

initial begin
  wait(out_valid==1);
  rfd = $fopen("results.txt","w");
  if (rfd != 0) begin
    $fdisplay(rfd,"Part 1 (you -> out) = %0d", part1);
    $fdisplay(rfd,"Part 2 (svr -> out, visits fft & dac) = %0d", part2);
    $fdisplay(rfd,"overflow = %0d", overflow);
    $fclose(rfd);
  end
  $display("Part 1 (you -> out) = %0d", part1);
  $display("Part 2 (svr -> out, visits fft & dac) = %0d", part2);
  $display("overflow = %0d", overflow);
  #20;
  $finish;
end
endmodule
