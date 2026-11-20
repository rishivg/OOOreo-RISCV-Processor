// Exact two-output Nangate45 full-adder pattern, extracted before ABC mapping.
// Keep both outputs: a sum-only match does not justify replacing a compressor.
module FA_X1(input A, B, CI, output CO, S);
  assign S = (A ^ B) ^ CI;
  assign CO = (A & B) | (A & CI) | (B & CI);
endmodule
