// fp_wire_test.v
// FrontPanel data-path test for the Opal Kelly XEM7310.
// Proves PC <-> FPGA communication over USB using okHost wire endpoints:
//   WireIn  0x00 : PC writes a value; low 8 bits drive the LEDs   (PC  -> FPGA)
//   WireOut 0x20 : free-running counter                           (FPGA -> PC, proves "alive")
//   WireOut 0x21 : loopback of WireIn 0x00                        (round-trip check)
//
// DEPENDENCY: add the Opal Kelly okHost library sources to the project
// (okHost, okWireIn, okWireOut, okWireOR) -- they live in your course's
// OK_library folder (e.g. ~/cs1410_lab/lab1/lab1a_server/OK_library).

module fp_wire_test (
    input  wire [4:0]  okUH,
    output wire [2:0]  okHU,
    inout  wire [31:0] okUHU,
    inout  wire        okAA,
    output wire [7:0]  led
);
    // ---- okHost: the USB / FrontPanel engine ----
    wire         okClk;       // clock supplied by the host interface
    wire [112:0] okHE;        // host  -> endpoints
    wire [64:0]  okEH;        // endpoints -> host

    okHost okHI (
        .okUH  (okUH),
        .okHU  (okHU),
        .okUHU (okUHU),
        .okAA  (okAA),
        .okClk (okClk),
        .okHE  (okHE),
        .okEH  (okEH)
    );

    // Combine the two WireOut endpoint outputs back into okEH
    localparam N = 2;                 // number of endpoints driving okEH
    wire [N*65-1:0] okEHx;
    okWireOR #(.N(N)) wireOR (.okEH(okEH), .okEHx(okEHx));

    // ---- WireIn 0x00 : PC -> FPGA ----
    wire [31:0] ep00;
    okWireIn ep00_wire (
        .okHE(okHE), .ep_addr(8'h00), .ep_dataout(ep00)
    );

    // LEDs show the low 8 bits of WireIn (board LEDs are active-LOW)
    assign led = ~ep00[7:0];

    // ---- free-running counter : proves the design is clocked & alive ----
    reg [31:0] counter = 32'd0;
    always @(posedge okClk)
        counter <= counter + 32'd1;

    // ---- WireOut 0x20 : counter,  WireOut 0x21 : loopback of WireIn ----
    okWireOut ep20_wire (
        .okHE(okHE), .okEH(okEHx[0*65 +: 65]), .ep_addr(8'h20), .ep_datain(counter)
    );
    okWireOut ep21_wire (
        .okHE(okHE), .okEH(okEHx[1*65 +: 65]), .ep_addr(8'h21), .ep_datain(ep00)
    );
endmodule